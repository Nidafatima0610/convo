import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../features/auth/domain/models/convo_user.dart';
import '../../features/chats/domain/models/conversation_model.dart';
import '../../features/chats/domain/models/message_model.dart';
import '../../features/moods/domain/models/chat_mood.dart';

class ChatService {
  ChatService({FirebaseFirestore? firestore}) : _customFirestore = firestore;

  final FirebaseFirestore? _customFirestore;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _conversationsRef =>
      _firestore.collection('conversations');

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  /// Fetches an existing conversation or creates a new deterministic one for two users.
  Future<ConversationModel> getOrCreateConversation({
    required ConvoUser currentUser,
    required ConvoUser otherUser,
  }) async {
    final conversationId = ConversationModel.getConversationId(
      currentUser.uid,
      otherUser.uid,
    );
    final docRef = _conversationsRef.doc(conversationId);
    final doc = await docRef.get();

    if (doc.exists && doc.data() != null) {
      // If conversation already exists, update participant details to keep names/photos fresh
      await docRef.set({
        'participantDetails': {
          currentUser.uid: {
            'name': currentUser.name,
            'email': currentUser.email,
            'photoUrl': currentUser.photoUrl,
          },
          otherUser.uid: {
            'name': otherUser.name,
            'email': otherUser.email,
            'photoUrl': otherUser.photoUrl,
          },
        },
      }, SetOptions(merge: true));

      final updatedDoc = await docRef.get();
      return ConversationModel.fromFirestore(updatedDoc);
    }

    // New conversation
    final newConversation = ConversationModel(
      id: conversationId,
      participants: [currentUser.uid, otherUser.uid],
      participantDetails: {
        currentUser.uid: {
          'name': currentUser.name,
          'email': currentUser.email,
          'photoUrl': currentUser.photoUrl,
        },
        otherUser.uid: {
          'name': otherUser.name,
          'email': otherUser.email,
          'photoUrl': otherUser.photoUrl,
        },
      },
      lastMessage: '',
      lastMessageAt: DateTime.now(),
      lastMessageSenderId: '',
      unreadCounts: {currentUser.uid: 0, otherUser.uid: 0},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await docRef.set(newConversation.toMap());
    return newConversation;
  }

  final Map<String, DocumentSnapshot<Map<String, dynamic>>> _lastStreamDocs = {};

  DocumentSnapshot<Map<String, dynamic>>? getLastDocumentForConversation(
    String conversationId,
  ) => _lastStreamDocs[conversationId];

  /// Real-time stream of all conversations for the given user, ordered by most recent activity.
  Stream<List<ConversationModel>> conversationsStream(
    String currentUserId, {
    int limit = 30,
  }) {
    try {
      if (Firebase.apps.isEmpty) return const Stream.empty();
      return _conversationsRef
          .where('participants', arrayContains: currentUserId)
          .orderBy('updatedAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => ConversationModel.fromFirestore(doc))
                .toList();
          });
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Real-time snapshot stream of messages inside a conversation.
  Stream<QuerySnapshot<Map<String, dynamic>>> messagesSnapshotsStream(
    String conversationId, {
    int limit = 25,
  }) {
    if (Firebase.apps.isEmpty) return const Stream.empty();
    return _conversationsRef
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  /// Real-time stream of messages inside a conversation, ordered descending for reverse list view.
  Stream<List<MessageModel>> messagesStream(
    String conversationId, {
    int limit = 25,
  }) {
    try {
      if (Firebase.apps.isEmpty) return const Stream.empty();
      return messagesSnapshotsStream(conversationId, limit: limit).map((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          _lastStreamDocs[conversationId] = snapshot.docs.last;
        }
        return snapshot.docs
            .map((doc) => MessageModel.fromFirestore(doc))
            .toList();
      });
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Fetches older messages using cursor-based pagination (startAfterDocument).
  Future<PaginatedMessagesResult> fetchOlderMessages({
    required String conversationId,
    DocumentSnapshot<Map<String, dynamic>>? startAfterDocument,
    DateTime? startAfterTimestamp,
    int limit = 25,
  }) async {
    try {
      if (Firebase.apps.isEmpty) {
        return const PaginatedMessagesResult(
          messages: [],
          lastDocument: null,
          hasMore: false,
        );
      }

      Query<Map<String, dynamic>> query = _conversationsRef
          .doc(conversationId)
          .collection('messages')
          .orderBy('createdAt', descending: true);

      final cursorDoc = startAfterDocument ?? _lastStreamDocs[conversationId];
      if (cursorDoc != null) {
        query = query.startAfterDocument(cursorDoc);
      } else if (startAfterTimestamp != null) {
        query = query.startAfter([Timestamp.fromDate(startAfterTimestamp)]);
      }

      query = query.limit(limit);

      final snapshot = await query.get();
      final messages = snapshot.docs
          .map((doc) => MessageModel.fromFirestore(doc))
          .toList();

      final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      final hasMore = snapshot.docs.length >= limit;

      return PaginatedMessagesResult(
        messages: messages,
        lastDocument: lastDoc,
        hasMore: hasMore,
      );
    } catch (e) {
      return PaginatedMessagesResult(
        messages: [],
        lastDocument: null,
        hasMore: false,
        error: e.toString(),
      );
    }
  }

  /// Fetches older conversations for a user using cursor-based pagination.
  Future<PaginatedConversationsResult> fetchOlderConversations({
    required String currentUserId,
    DocumentSnapshot<Map<String, dynamic>>? startAfterDocument,
    DateTime? startAfterTimestamp,
    int limit = 30,
  }) async {
    try {
      if (Firebase.apps.isEmpty) {
        return const PaginatedConversationsResult(
          conversations: [],
          lastDocument: null,
          hasMore: false,
        );
      }

      Query<Map<String, dynamic>> query = _conversationsRef
          .where('participants', arrayContains: currentUserId)
          .orderBy('updatedAt', descending: true);

      if (startAfterDocument != null) {
        query = query.startAfterDocument(startAfterDocument);
      } else if (startAfterTimestamp != null) {
        query = query.startAfter([Timestamp.fromDate(startAfterTimestamp)]);
      }

      query = query.limit(limit);

      final snapshot = await query.get();
      final conversations = snapshot.docs
          .map((doc) => ConversationModel.fromFirestore(doc))
          .toList();

      final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      final hasMore = snapshot.docs.length >= limit;

      return PaginatedConversationsResult(
        conversations: conversations,
        lastDocument: lastDoc,
        hasMore: hasMore,
      );
    } catch (e) {
      return PaginatedConversationsResult(
        conversations: [],
        lastDocument: null,
        hasMore: false,
        error: e.toString(),
      );
    }
  }

  /// Sends a new message and updates conversation metadata and recipient unread count in a batch.
  Future<MessageModel> sendMessage({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required String text,
    String type = 'text',
    String? replyToMessageId,
    String? replyToSnippet,
    String? replyToSenderName,
    Map<String, dynamic>? metadata,
    DateTime? expiresAt,
    bool isSecret = false,
  }) async {
    final messageDocRef = _conversationsRef
        .doc(conversationId)
        .collection('messages')
        .doc();

    final now = DateTime.now();
    final message = MessageModel(
      id: messageDocRef.id,
      conversationId: conversationId,
      senderId: senderId,
      receiverId: receiverId,
      text: text.trim(),
      type: type,
      createdAt: now,
      isRead: false,
      replyToMessageId: replyToMessageId,
      replyToSnippet: replyToSnippet,
      replyToSenderName: replyToSenderName,
      reactions: {},
      isDeleted: false,
      metadata: metadata,
      expiresAt: expiresAt,
      isSecret: isSecret,
    );

    final batch = _firestore.batch();

    // 1. Insert message
    batch.set(messageDocRef, {
      ...message.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. Update conversation summary
    final conversationDocRef = _conversationsRef.doc(conversationId);
    batch.update(conversationDocRef, {
      'lastMessage': text.trim(),
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageSenderId': senderId,
      'unreadCounts.$receiverId': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return message;
  }

  /// Sends a media message (image, video, voice, file) and updates conversation preview and unread count.
  Future<MessageModel> sendMediaMessage({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required String type,
    required String mediaUrl,
    String text = '',
    String? thumbnailUrl,
    String? fileName,
    int? fileSize,
    int? durationMs,
    String? replyToMessageId,
    String? replyToSnippet,
    String? replyToSenderName,
    Map<String, dynamic>? metadata,
    DateTime? expiresAt,
    bool isSecret = false,
  }) async {
    final messageDocRef = _conversationsRef
        .doc(conversationId)
        .collection('messages')
        .doc();

    final now = DateTime.now();
    final message = MessageModel(
      id: messageDocRef.id,
      conversationId: conversationId,
      senderId: senderId,
      receiverId: receiverId,
      text: text.trim(),
      type: type,
      mediaUrl: mediaUrl,
      thumbnailUrl: thumbnailUrl,
      fileName: fileName,
      fileSize: fileSize,
      durationMs: durationMs,
      uploadStatus: 'success',
      createdAt: now,
      isRead: false,
      replyToMessageId: replyToMessageId,
      replyToSnippet: replyToSnippet,
      replyToSenderName: replyToSenderName,
      reactions: {},
      isDeleted: false,
      metadata: metadata,
      expiresAt: expiresAt,
      isSecret: isSecret,
    );

    final batch = _firestore.batch();

    batch.set(messageDocRef, {
      ...message.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    String previewText;
    if (text.trim().isNotEmpty) {
      previewText = text.trim();
    } else {
      switch (type) {
        case 'image':
          previewText = 'Photo';
          break;
        case 'video':
          previewText = 'Video';
          break;
        case 'voice':
          previewText = 'Voice message';
          break;
        default:
          previewText = 'Attachment';
          break;
      }
    }

    final conversationDocRef = _conversationsRef.doc(conversationId);
    batch.update(conversationDocRef, {
      'lastMessage': previewText,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageSenderId': senderId,
      'unreadCounts.$receiverId': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return message;
  }

  /// Clears all messages in a conversation.
  Future<void> clearConversationMessages({
    required String conversationId,
  }) async {
    final messagesSnap = await _conversationsRef
        .doc(conversationId)
        .collection('messages')
        .limit(100)
        .get();

    final batch = _firestore.batch();
    for (final doc in messagesSnap.docs) {
      batch.delete(doc.reference);
    }

    batch.update(_conversationsRef.doc(conversationId), {
      'lastMessage': '',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Marks unread messages in the conversation as read by the current user.
  Future<void> markConversationAsRead({
    required String conversationId,
    required String currentUserId,
  }) async {
    try {
      // 1. Clear unread counter on the conversation document
      await _conversationsRef.doc(conversationId).update({
        'unreadCounts.$currentUserId': 0,
      });

      // 2. Query any unread messages sent to this user
      final unreadSnap = await _conversationsRef
          .doc(conversationId)
          .collection('messages')
          .where('receiverId', isEqualTo: currentUserId)
          .where('isRead', isEqualTo: false)
          .limit(50)
          .get();

      if (unreadSnap.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final doc in unreadSnap.docs) {
          batch.update(doc.reference, {
            'isRead': true,
            'readAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }
    } catch (_) {
      // Non-critical read state update error
    }
  }

  /// Toggles a reaction emoji on a message. If user already reacted with this emoji, removes it.
  Future<void> toggleReaction({
    required String conversationId,
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    final messageDocRef = _conversationsRef
        .doc(conversationId)
        .collection('messages')
        .doc(messageId);

    final doc = await messageDocRef.get();
    if (!doc.exists) return;

    final currentReaction = doc.data()?['reactions']?[userId] as String?;

    if (currentReaction == emoji) {
      // Remove reaction
      await messageDocRef.update({'reactions.$userId': FieldValue.delete()});
    } else {
      // Add or replace reaction
      await messageDocRef.update({'reactions.$userId': emoji});
    }
  }

  /// Soft deletes a message, preserving chronological order for synchronization.
  Future<void> deleteMessage({
    required String conversationId,
    required String messageId,
    required String userId,
  }) async {
    final messageDocRef = _conversationsRef
        .doc(conversationId)
        .collection('messages')
        .doc(messageId);

    final doc = await messageDocRef.get();
    if (!doc.exists) return;

    final senderId = doc.data()?['senderId'] as String?;
    if (senderId != userId) {
      throw Exception('Only the sender can delete their message.');
    }

    await messageDocRef.update({
      'isDeleted': true,
      'text': 'This message was deleted',
      'deletedAt': FieldValue.serverTimestamp(),
      'reactions': {},
    });

    // Check if this was the last message on the conversation doc
    final convDoc = await _conversationsRef.doc(conversationId).get();
    if (convDoc.exists) {
      final lastMsgSenderId = convDoc.data()?['lastMessageSenderId'] as String?;
      if (lastMsgSenderId == userId) {
        await _conversationsRef.doc(conversationId).update({
          'lastMessage': 'Message was deleted',
        });
      }
    }
  }

  /// Searches registered users excluding the current user.
  Future<List<ConvoUser>> searchUsers({
    required String query,
    required String currentUserId,
  }) async {
    final trimmed = query.trim().toLowerCase();

    // Fetch registered users (limiting to 40 for efficient reads)
    final snapshot = await _usersRef.limit(40).get();

    final users = snapshot.docs
        .map((doc) => ConvoUser.fromFirestore(doc))
        .where((user) => user.uid != currentUserId)
        .where((user) {
          if (trimmed.isEmpty) return true;
          final nameMatch = user.name.toLowerCase().contains(trimmed);
          final emailMatch = user.email.toLowerCase().contains(trimmed);
          return nameMatch || emailMatch;
        })
        .toList();

    return users;
  }

  /// Sets or updates the mood of a conversation.
  Future<void> updateConversationMood({
    required String conversationId,
    required ChatMood mood,
  }) async {
    await _conversationsRef.doc(conversationId).update({
      'mood': mood.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Clears the mood of a conversation.
  Future<void> clearConversationMood(String conversationId) async {
    await _conversationsRef.doc(conversationId).update({
      'mood': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Updates disappearing messages timer duration (seconds) or disables it (null/0).
  Future<void> updateDisappearingDuration({
    required String conversationId,
    required int? durationSeconds,
  }) async {
    await _conversationsRef.doc(conversationId).update({
      'disappearingDuration': durationSeconds != null && durationSeconds > 0
          ? durationSeconds
          : null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Submits a player's answer to an interactive chat game.
  Future<void> submitGameAnswer({
    required String conversationId,
    required String messageId,
    required String userId,
    required String answer,
  }) async {
    final messageDocRef = _conversationsRef
        .doc(conversationId)
        .collection('messages')
        .doc(messageId);

    await messageDocRef.update({'metadata.game.answers.$userId': answer});
  }
}

class PaginatedMessagesResult {
  const PaginatedMessagesResult({
    required this.messages,
    this.lastDocument,
    required this.hasMore,
    this.error,
  });

  final List<MessageModel> messages;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;
  final String? error;
}

class PaginatedConversationsResult {
  const PaginatedConversationsResult({
    required this.conversations,
    this.lastDocument,
    required this.hasMore,
    this.error,
  });

  final List<ConversationModel> conversations;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;
  final String? error;
}

