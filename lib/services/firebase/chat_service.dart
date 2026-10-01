import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

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
          .snapshots()
          .map((snapshot) {
            final list = snapshot.docs
                .map((doc) => ConversationModel.fromFirestore(doc))
                .toList();
            list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
            if (list.length > limit) {
              return list.sublist(0, limit);
            }
            return list;
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
      }).handleError((error) {
        debugPrint('messagesStream notice for $conversationId: $error');
        return <MessageModel>[];
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
    String? senderName,
    String? senderPhotoUrl,
    List<String>? recipientIds,
    Map<String, dynamic>? metadata,
    DateTime? expiresAt,
    bool isSecret = false,
    bool isForwarded = false,
    String? forwardedFrom,
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
      senderName: senderName,
      senderPhotoUrl: senderPhotoUrl,
      reactions: {},
      isDeleted: false,
      metadata: metadata,
      expiresAt: expiresAt,
      isSecret: isSecret,
      isForwarded: isForwarded,
      forwardedFrom: forwardedFrom,
    );

    final batch = _firestore.batch();

    // 1. Insert message
    batch.set(messageDocRef, {
      ...message.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. Update or create conversation summary
    final conversationDocRef = _conversationsRef.doc(conversationId);
    final convDoc = await conversationDocRef.get();

    if (!convDoc.exists || convDoc.data() == null) {
      final isGroup = receiverId == 'group';
      final participants = isGroup
          ? (recipientIds ?? [senderId])
          : [senderId, receiverId];
      final unreadMap = <String, int>{};
      for (final p in participants) {
        unreadMap[p] = (p == senderId) ? 0 : 1;
      }

      batch.set(conversationDocRef, {
        'id': conversationId,
        'participants': participants,
        'participantDetails': {
          senderId: {
            'name': senderName ?? 'CONVO User',
            'photoUrl': senderPhotoUrl,
          },
        },
        'lastMessage': text.trim(),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageSenderId': senderId,
        'unreadCounts': unreadMap,
        'type': isGroup ? 'group' : 'direct',
        'admins': isGroup ? [senderId] : const [],
        'createdBy': isGroup ? senderId : null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      final Map<String, dynamic> convUpdates = {
        'lastMessage': text.trim(),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageSenderId': senderId,
        'updatedAt': FieldValue.serverTimestamp(),
        'typing.$senderId': FieldValue.delete(),
      };

      var effectiveRecipients = recipientIds;
      if (receiverId == 'group' &&
          (effectiveRecipients == null || effectiveRecipients.isEmpty)) {
        final rawParts = convDoc.data()!['participants'];
        if (rawParts is List) {
          effectiveRecipients =
              rawParts.map((e) => e.toString()).toList();
        }
      }

      if (effectiveRecipients != null && effectiveRecipients.isNotEmpty) {
        for (final recId in effectiveRecipients) {
          if (recId != senderId && recId.isNotEmpty) {
            convUpdates['unreadCounts.$recId'] = FieldValue.increment(1);
          }
        }
      } else if (receiverId.isNotEmpty && receiverId != 'group') {
        convUpdates['unreadCounts.$receiverId'] = FieldValue.increment(1);
      }

      batch.update(conversationDocRef, convUpdates);
    }

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
    String? senderName,
    String? senderPhotoUrl,
    List<String>? recipientIds,
    Map<String, dynamic>? metadata,
    DateTime? expiresAt,
    bool isSecret = false,
    bool isForwarded = false,
    String? forwardedFrom,
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
      senderName: senderName,
      senderPhotoUrl: senderPhotoUrl,
      reactions: {},
      isDeleted: false,
      metadata: metadata,
      expiresAt: expiresAt,
      isSecret: isSecret,
      isForwarded: isForwarded,
      forwardedFrom: forwardedFrom,
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
    final convDoc = await conversationDocRef.get();

    if (!convDoc.exists || convDoc.data() == null) {
      final isGroup = receiverId == 'group';
      final participants = isGroup
          ? (recipientIds ?? [senderId])
          : [senderId, receiverId];
      final unreadMap = <String, int>{};
      for (final p in participants) {
        unreadMap[p] = (p == senderId) ? 0 : 1;
      }

      batch.set(conversationDocRef, {
        'id': conversationId,
        'participants': participants,
        'participantDetails': {
          senderId: {
            'name': senderName ?? 'CONVO User',
            'photoUrl': senderPhotoUrl,
          },
        },
        'lastMessage': previewText,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageSenderId': senderId,
        'unreadCounts': unreadMap,
        'type': isGroup ? 'group' : 'direct',
        'admins': isGroup ? [senderId] : const [],
        'createdBy': isGroup ? senderId : null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      final Map<String, dynamic> convUpdates = {
        'lastMessage': previewText,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageSenderId': senderId,
        'updatedAt': FieldValue.serverTimestamp(),
        'typing.$senderId': FieldValue.delete(),
      };

      var effectiveRecipients = recipientIds;
      if (receiverId == 'group' &&
          (effectiveRecipients == null || effectiveRecipients.isEmpty)) {
        final rawParts = convDoc.data()!['participants'];
        if (rawParts is List) {
          effectiveRecipients =
              rawParts.map((e) => e.toString()).toList();
        }
      }

      if (effectiveRecipients != null && effectiveRecipients.isNotEmpty) {
        for (final recId in effectiveRecipients) {
          if (recId != senderId && recId.isNotEmpty) {
            convUpdates['unreadCounts.$recId'] = FieldValue.increment(1);
          }
        }
      } else if (receiverId.isNotEmpty && receiverId != 'group') {
        convUpdates['unreadCounts.$receiverId'] = FieldValue.increment(1);
      }

      batch.update(conversationDocRef, convUpdates);
    }

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

  /// Deletes a message only for the current user.
  Future<void> deleteMessageForMe({
    required String conversationId,
    required String messageId,
    required String userId,
  }) async {
    final messageDocRef = _conversationsRef
        .doc(conversationId)
        .collection('messages')
        .doc(messageId);

    await messageDocRef.update({
      'deletedFor': FieldValue.arrayUnion([userId]),
    });
  }

  /// Updates typing status of a user in a conversation with debouncing and safe writes.
  Future<void> setTypingStatus({
    required String conversationId,
    required String userId,
    required bool isTyping,
  }) async {
    try {
      final convRef = _conversationsRef.doc(conversationId);
      if (isTyping) {
        await convRef.update({
          'typing.$userId': FieldValue.serverTimestamp(),
        });
      } else {
        await convRef.update({
          'typing.$userId': FieldValue.delete(),
        });
      }
    } catch (_) {
      // Non-critical typing indicator update failure
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

  /// Gets a conversation by ID.
  Future<ConversationModel?> getConversation(String conversationId) async {
    try {
      final doc = await _conversationsRef.doc(conversationId).get();
      if (!doc.exists || doc.data() == null) return null;
      return ConversationModel.fromFirestore(doc);
    } catch (_) {
      return null;
    }
  }

  /// Real-time stream of a specific conversation's document metadata.
  Stream<ConversationModel?> conversationStream(String conversationId) {
    if (Firebase.apps.isEmpty) return const Stream.empty();
    return _conversationsRef.doc(conversationId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return ConversationModel.fromFirestore(doc);
    });
  }

  /// Creates a new group conversation with creator as initial admin.
  Future<ConversationModel> createGroupConversation({
    required String name,
    required ConvoUser creator,
    required List<ConvoUser> initialMembers,
    String? photoUrl,
    String? description,
  }) async {
    final docRef = _conversationsRef.doc();
    final allParticipants = <String>{
      creator.uid,
      ...initialMembers.map((m) => m.uid),
    }.toList();

    final participantDetails = <String, Map<String, dynamic>>{
      creator.uid: {
        'name': creator.name,
        'email': creator.email,
        'photoUrl': creator.photoUrl,
      },
    };
    for (final member in initialMembers) {
      participantDetails[member.uid] = {
        'name': member.name,
        'email': member.email,
        'photoUrl': member.photoUrl,
      };
    }

    final unreadCounts = <String, int>{};
    for (final uid in allParticipants) {
      unreadCounts[uid] = 0;
    }

    final initialMessage = '${creator.name} created group "$name"';
    final now = DateTime.now();

    final group = ConversationModel(
      id: docRef.id,
      participants: allParticipants,
      participantDetails: participantDetails,
      lastMessage: initialMessage,
      lastMessageAt: now,
      lastMessageSenderId: creator.uid,
      unreadCounts: unreadCounts,
      type: 'group',
      name: name.trim(),
      photoUrl: photoUrl,
      description: description?.trim(),
      createdBy: creator.uid,
      admins: [creator.uid],
      mutedBy: const [],
      createdAt: now,
      updatedAt: now,
    );

    await docRef.set({
      ...group.toMap(),
      'lastMessageAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Create system message announcing creation
    final msgDocRef = docRef.collection('messages').doc();
    final systemMessage = MessageModel(
      id: msgDocRef.id,
      conversationId: docRef.id,
      senderId: creator.uid,
      receiverId: 'group',
      text: initialMessage,
      type: 'system',
      senderName: creator.name,
      createdAt: now,
    );
    await msgDocRef.set({
      ...systemMessage.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return group;
  }

  /// Updates group info (name, description, photoUrl) - Admin only.
  Future<void> updateGroupInfo({
    required String conversationId,
    required String updaterId,
    String? name,
    String? description,
    String? photoUrl,
    bool removePhoto = false,
  }) async {
    final doc = await _conversationsRef.doc(conversationId).get();
    if (!doc.exists) throw Exception('Group conversation not found');
    final conv = ConversationModel.fromFirestore(doc);
    if (!conv.isAdmin(updaterId)) {
      throw Exception('Only group admins can update group information');
    }

    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (name != null && name.trim().isNotEmpty) updates['name'] = name.trim();
    if (description != null) updates['description'] = description.trim();
    if (removePhoto) {
      updates['photoUrl'] = FieldValue.delete();
    } else if (photoUrl != null) {
      updates['photoUrl'] = photoUrl;
    }

    await _conversationsRef.doc(conversationId).update(updates);
  }

  /// Adds members to a group - Admin only.
  Future<void> addGroupMembers({
    required String conversationId,
    required ConvoUser admin,
    required List<ConvoUser> newMembers,
  }) async {
    final doc = await _conversationsRef.doc(conversationId).get();
    if (!doc.exists) throw Exception('Group conversation not found');
    final conv = ConversationModel.fromFirestore(doc);
    if (!conv.isAdmin(admin.uid)) {
      throw Exception('Only group admins can add members');
    }

    final newUids = newMembers.map((m) => m.uid).toList();
    final names = newMembers.map((m) => m.name).join(', ');
    final updates = <String, dynamic>{
      'participants': FieldValue.arrayUnion(newUids),
      'lastMessage': '${admin.name} added $names',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageSenderId': admin.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    for (final member in newMembers) {
      updates['participantDetails.${member.uid}'] = {
        'name': member.name,
        'email': member.email,
        'photoUrl': member.photoUrl,
      };
      updates['unreadCounts.${member.uid}'] = 0;
    }

    final batch = _firestore.batch();
    batch.update(_conversationsRef.doc(conversationId), updates);

    // Announce member addition
    final msgDocRef =
        _conversationsRef.doc(conversationId).collection('messages').doc();
    final systemMsg = MessageModel(
      id: msgDocRef.id,
      conversationId: conversationId,
      senderId: admin.uid,
      receiverId: 'group',
      text: '${admin.name} added $names',
      type: 'system',
      senderName: admin.name,
      createdAt: DateTime.now(),
    );
    batch.set(msgDocRef, {
      ...systemMsg.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Removes a member from a group - Admin only.
  Future<void> removeGroupMember({
    required String conversationId,
    required ConvoUser admin,
    required String memberId,
    required String memberName,
  }) async {
    final doc = await _conversationsRef.doc(conversationId).get();
    if (!doc.exists) throw Exception('Group conversation not found');
    final conv = ConversationModel.fromFirestore(doc);
    if (!conv.isAdmin(admin.uid)) {
      throw Exception('Only group admins can remove members');
    }
    if (memberId == conv.createdBy && admin.uid != conv.createdBy) {
      throw Exception('Cannot remove group creator');
    }

    final batch = _firestore.batch();
    batch.update(_conversationsRef.doc(conversationId), {
      'participants': FieldValue.arrayRemove([memberId]),
      'admins': FieldValue.arrayRemove([memberId]),
      'participantDetails.$memberId': FieldValue.delete(),
      'unreadCounts.$memberId': FieldValue.delete(),
      'lastMessage': '${admin.name} removed $memberName',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageSenderId': admin.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final msgDocRef =
        _conversationsRef.doc(conversationId).collection('messages').doc();
    final systemMsg = MessageModel(
      id: msgDocRef.id,
      conversationId: conversationId,
      senderId: admin.uid,
      receiverId: 'group',
      text: '${admin.name} removed $memberName',
      type: 'system',
      senderName: admin.name,
      createdAt: DateTime.now(),
    );
    batch.set(msgDocRef, {
      ...systemMsg.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Promotes a member to Admin.
  Future<void> promoteToAdmin({
    required String conversationId,
    required String adminId,
    required String memberId,
  }) async {
    final doc = await _conversationsRef.doc(conversationId).get();
    if (!doc.exists) throw Exception('Group conversation not found');
    final conv = ConversationModel.fromFirestore(doc);
    if (!conv.isAdmin(adminId)) {
      throw Exception('Only admins can promote members to admin');
    }

    await _conversationsRef.doc(conversationId).update({
      'admins': FieldValue.arrayUnion([memberId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Demotes an Admin to regular member.
  Future<void> demoteAdmin({
    required String conversationId,
    required String currentAdminId,
    required String targetAdminId,
  }) async {
    final doc = await _conversationsRef.doc(conversationId).get();
    if (!doc.exists) throw Exception('Group conversation not found');
    final conv = ConversationModel.fromFirestore(doc);
    if (!conv.isAdmin(currentAdminId)) {
      throw Exception('Only admins can manage roles');
    }
    if (targetAdminId == conv.createdBy) {
      throw Exception('Cannot demote group creator');
    }

    await _conversationsRef.doc(conversationId).update({
      'admins': FieldValue.arrayRemove([targetAdminId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Member leaves group. Handles safe admin reassignment if the leaving user was the sole admin.
  Future<void> leaveGroup({
    required String conversationId,
    required String userId,
    required String userName,
  }) async {
    final doc = await _conversationsRef.doc(conversationId).get();
    if (!doc.exists) return;
    final conv = ConversationModel.fromFirestore(doc);

    final remainingParticipants =
        conv.participants.where((uid) => uid != userId).toList();

    final updates = <String, dynamic>{
      'participants': FieldValue.arrayRemove([userId]),
      'participantDetails.$userId': FieldValue.delete(),
      'unreadCounts.$userId': FieldValue.delete(),
      'mutedBy': FieldValue.arrayRemove([userId]),
      'lastMessage': '$userName left the group',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageSenderId': userId,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // If leaving user was an admin, handle admin list update safely:
    // Only admins modify the admins array (keeps Firestore security rules valid for non-admins)
    if (conv.isAdmin(userId)) {
      final remainingAdmins =
          conv.admins.where((uid) => uid != userId).toList();
      if (remainingAdmins.isEmpty && remainingParticipants.isNotEmpty) {
        // Sole admin leaving with remaining members: assign next member as admin
        updates['admins'] = [remainingParticipants.first];
      } else {
        updates['admins'] = FieldValue.arrayRemove([userId]);
      }
    }

    final batch = _firestore.batch();
    batch.update(_conversationsRef.doc(conversationId), updates);

    // Add departure notice
    final msgDocRef =
        _conversationsRef.doc(conversationId).collection('messages').doc();
    final systemMsg = MessageModel(
      id: msgDocRef.id,
      conversationId: conversationId,
      senderId: userId,
      receiverId: 'group',
      text: '$userName left the group',
      type: 'system',
      senderName: userName,
      createdAt: DateTime.now(),
    );
    batch.set(msgDocRef, {
      ...systemMsg.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Toggles notifications mute state for a user on a group conversation.
  Future<void> toggleGroupMute({
    required String conversationId,
    required String userId,
    required bool mute,
  }) async {
    await _conversationsRef.doc(conversationId).update({
      'mutedBy': mute
          ? FieldValue.arrayUnion([userId])
          : FieldValue.arrayRemove([userId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
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

