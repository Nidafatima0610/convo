import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../services/audio/audio_service.dart';
import '../../../../services/firebase/chat_service.dart';
import '../../../../services/firebase/media_service.dart';
import '../../../../services/local_storage/chat_preferences_service.dart';
import '../../../../services/notifications/notification_service.dart';
import '../../../auth/domain/models/convo_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/models/conversation_model.dart';
import '../../domain/models/message_model.dart';
import '../../../nearby/presentation/providers/nearby_providers.dart';

final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService();
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final mediaServiceProvider = Provider<MediaService>((ref) {
  return MediaService();
});

final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  ref.onDispose(service.dispose);
  return service;
});

/// Tracks media upload progress per upload key: 0.0 to 1.0
final mediaUploadProgressProvider =
    NotifierProvider<MediaUploadProgressNotifier, Map<String, double>>(
      MediaUploadProgressNotifier.new,
    );

class MediaUploadProgressNotifier extends Notifier<Map<String, double>> {
  @override
  Map<String, double> build() => {};

  void setProgress(String key, double progress) {
    state = {...state, key: progress};
  }

  void remove(String key) {
    final updated = Map<String, double>.from(state)..remove(key);
    state = updated;
  }
}

/// Real-time stream of conversations for the currently logged-in user
final userConversationsProvider = StreamProvider<List<ConversationModel>>((
  ref,
) {
  final authUser = ref.watch(authStateChangesProvider).asData?.value;
  if (authUser == null) {
    return Stream.value([]);
  }

  final chatService = ref.watch(chatServiceProvider);
  return chatService.conversationsStream(authUser.uid);
});

/// Real-time stream of a specific conversation's document (for group metadata updates)
final singleConversationProvider =
    StreamProvider.family<ConversationModel?, String>((ref, conversationId) {
      final chatService = ref.watch(chatServiceProvider);
      return chatService.conversationStream(conversationId);
    });

const int kMessagesPageSize = 25;
const int kConversationsPageSize = 30;

class MessagesPaginationState {
  const MessagesPaginationState({
    required this.messages,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
    this.oldestDocument,
  });

  final List<MessageModel> messages;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;
  final DocumentSnapshot<Map<String, dynamic>>? oldestDocument;

  MessagesPaginationState copyWith({
    List<MessageModel>? messages,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
    DocumentSnapshot<Map<String, dynamic>>? oldestDocument,
    bool clearError = false,
  }) {
    return MessagesPaginationState(
      messages: messages ?? this.messages,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
      oldestDocument: oldestDocument ?? this.oldestDocument,
    );
  }
}

/// Real-time stream of messages inside a specific conversation (initial page).
final conversationMessagesProvider =
    StreamProvider.family<List<MessageModel>, String>((ref, conversationId) {
      final chatService = ref.watch(chatServiceProvider);
      return chatService.messagesStream(conversationId, limit: kMessagesPageSize);
    });

/// Notifier provider for cursor-paginated messages combining real-time stream + older pages + offline queue
final conversationPaginatedMessagesProvider = NotifierProvider.family<
    ConversationPaginatedMessagesNotifier,
    MessagesPaginationState,
    String>(
  (conversationId) => ConversationPaginatedMessagesNotifier(conversationId),
);

class ConversationPaginatedMessagesNotifier
    extends Notifier<MessagesPaginationState> {
  ConversationPaginatedMessagesNotifier(this.conversationId);

  final String conversationId;

  final List<MessageModel> _olderMessages = [];
  DocumentSnapshot<Map<String, dynamic>>? _oldestDocument;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;

  @override
  MessagesPaginationState build() {
    final firestoreMessages =
        ref.watch(conversationMessagesProvider(conversationId)).asData?.value ??
            [];
    final offlineQueue =
        ref.watch(offlineQueueStreamProvider).asData?.value ?? [];

    if (_olderMessages.isEmpty && firestoreMessages.isNotEmpty) {
      if (firestoreMessages.length < kMessagesPageSize) {
        _hasMore = false;
      }
    }

    final merged = _mergeMessages(
      streamMessages: firestoreMessages,
      olderMessages: _olderMessages,
      offlineQueue: offlineQueue,
    );

    return MessagesPaginationState(
      messages: merged,
      isLoadingMore: _isLoadingMore,
      hasMore: _hasMore,
      error: _error,
      oldestDocument: _oldestDocument,
    );
  }

  List<MessageModel> _mergeMessages({
    required List<MessageModel> streamMessages,
    required List<MessageModel> olderMessages,
    required List<dynamic> offlineQueue,
  }) {
    final Map<String, MessageModel> messageMap = {};

    // 1. Stream messages: freshest real-time updates (text, reactions, deleted status)
    for (final msg in streamMessages) {
      messageMap[msg.id] = msg;
    }

    // 2. Older messages: historical messages fetched via cursor pagination
    for (final msg in olderMessages) {
      messageMap.putIfAbsent(msg.id, () => msg);
    }

    // 3. Offline queue: messages saved locally pending sync or sent via Nearby mesh
    for (final queued in offlineQueue) {
      if (queued.conversationId == conversationId) {
        final offlineMsg = queued.toMessageModel();
        messageMap.putIfAbsent(offlineMsg.id, () => offlineMsg);
      }
    }

    // 4. Exclude expired secret messages and messages deleted for this user
    final currentUserId =
        ref.read(authStateChangesProvider).asData?.value?.uid ?? '';
    final prefsService = ref.read(chatPreferencesServiceProvider);
    final now = DateTime.now();
    final list = messageMap.values.where((m) {
      if (m.isSecret && m.expiresAt != null) {
        if (!now.isBefore(m.expiresAt!)) return false;
      }
      if (currentUserId.isNotEmpty) {
        if (m.deletedFor.contains(currentUserId)) return false;
        if (prefsService.isMessageDeletedForMe(m.id)) return false;
      }
      return true;
    }).toList();

    // 5. Order descending by createdAt: index 0 is newest, last index is oldest
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return list;
  }

  /// Fetches the next older page of messages using Firestore cursor pagination
  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    _error = null;
    state = state.copyWith(isLoadingMore: true, clearError: true);

    try {
      final chatService = ref.read(chatServiceProvider);

      final cursorDoc =
          _oldestDocument ?? chatService.getLastDocumentForConversation(conversationId);

      DateTime? fallbackTimestamp;
      if (cursorDoc == null && state.messages.isNotEmpty) {
        fallbackTimestamp = state.messages.last.createdAt;
      }

      if (cursorDoc == null && fallbackTimestamp == null) {
        _isLoadingMore = false;
        _hasMore = false;
        state = state.copyWith(isLoadingMore: false, hasMore: false);
        return;
      }

      final result = await chatService.fetchOlderMessages(
        conversationId: conversationId,
        startAfterDocument: cursorDoc,
        startAfterTimestamp: fallbackTimestamp,
        limit: kMessagesPageSize,
      );

      if (result.error != null) {
        _isLoadingMore = false;
        _error = result.error;
        state = state.copyWith(isLoadingMore: false, error: _error);
        return;
      }

      if (result.messages.isEmpty) {
        _isLoadingMore = false;
        _hasMore = false;
        state = state.copyWith(isLoadingMore: false, hasMore: false);
        return;
      }

      _oldestDocument = result.lastDocument;
      _hasMore = result.hasMore;

      for (final msg in result.messages) {
        if (!_olderMessages.any((m) => m.id == msg.id)) {
          _olderMessages.add(msg);
        }
      }

      _isLoadingMore = false;

      final streamMessages =
          ref.read(conversationMessagesProvider(conversationId)).asData?.value ??
              [];
      final offlineQueue =
          ref.read(offlineQueueStreamProvider).asData?.value ?? [];

      final merged = _mergeMessages(
        streamMessages: streamMessages,
        olderMessages: _olderMessages,
        offlineQueue: offlineQueue,
      );

      state = state.copyWith(
        messages: merged,
        isLoadingMore: false,
        hasMore: _hasMore,
        oldestDocument: _oldestDocument,
      );
    } catch (e) {
      _isLoadingMore = false;
      _error = e.toString();
      state = state.copyWith(isLoadingMore: false, error: _error);
    }
  }

  void updateLocalReaction(String messageId, String userId, String emoji) {
    for (int i = 0; i < _olderMessages.length; i++) {
      if (_olderMessages[i].id == messageId) {
        final newReactions = Map<String, String>.from(_olderMessages[i].reactions);
        if (newReactions[userId] == emoji) {
          newReactions.remove(userId);
        } else {
          newReactions[userId] = emoji;
        }
        _olderMessages[i] = _olderMessages[i].copyWith(reactions: newReactions);
        break;
      }
    }

    final updatedAll = state.messages.map((m) {
      if (m.id == messageId) {
        final newReactions = Map<String, String>.from(m.reactions);
        if (newReactions[userId] == emoji) {
          newReactions.remove(userId);
        } else {
          newReactions[userId] = emoji;
        }
        return m.copyWith(reactions: newReactions);
      }
      return m;
    }).toList();

    state = state.copyWith(messages: updatedAll);
  }

  void markMessageDeleted(String messageId) {
    for (int i = 0; i < _olderMessages.length; i++) {
      if (_olderMessages[i].id == messageId) {
        _olderMessages[i] = _olderMessages[i].copyWith(
          isDeleted: true,
          text: 'This message was deleted',
          deletedAt: DateTime.now(),
          reactions: {},
        );
        break;
      }
    }

    final updatedAll = state.messages.map((m) {
      if (m.id == messageId) {
        return m.copyWith(
          isDeleted: true,
          text: 'This message was deleted',
          deletedAt: DateTime.now(),
          reactions: {},
        );
      }
      return m;
    }).toList();

    state = state.copyWith(messages: updatedAll);
  }

  void markMessageDeletedForMe(String messageId) {
    _olderMessages.removeWhere((m) => m.id == messageId);
    final updatedAll = state.messages.where((m) => m.id != messageId).toList();
    state = state.copyWith(messages: updatedAll);
  }
}

/// Live list of users typing in a conversation (excluding current user)
final conversationTypingUsersProvider =
    Provider.family<List<String>, String>((ref, conversationId) {
  final currentUserId =
      ref.watch(authStateChangesProvider).asData?.value?.uid ?? '';
  final conv = ref.watch(singleConversationProvider(conversationId)).asData?.value;
  if (conv == null) return const [];
  return conv.typingUsers(currentUserId);
});

/// Real-time stream of messages inside a conversation, seamlessly combining Firestore messages
/// with local Smart Offline Queued / Nearby direct messages.
final conversationCombinedMessagesProvider =
    StreamProvider.family<List<MessageModel>, String>((ref, conversationId) {
      final initialAsync =
          ref.watch(conversationMessagesProvider(conversationId));
      final paginatedState =
          ref.watch(conversationPaginatedMessagesProvider(conversationId));

      if (initialAsync.isLoading && paginatedState.messages.isEmpty) {
        return const Stream.empty();
      }
      return Stream.value(paginatedState.messages);
    });

/// Real-time stream of another user's live profile and online status
final userPresenceProvider = StreamProvider.family<ConvoUser?, String>((
  ref,
  userId,
) {
  if (userId.isEmpty) return Stream.value(null);
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.userProfileStream(userId);
});

/// State provider for tracking which message the user is currently replying to
final replyingMessageProvider =
    NotifierProvider<ReplyingMessageNotifier, MessageModel?>(
      ReplyingMessageNotifier.new,
    );

class ReplyingMessageNotifier extends Notifier<MessageModel?> {
  @override
  MessageModel? build() => null;

  void setMessage(MessageModel? message) => state = message;
  void clear() => state = null;
}

/// Search query provider for finding users
final userSearchQueryProvider =
    NotifierProvider<UserSearchQueryNotifier, String>(
      UserSearchQueryNotifier.new,
    );

class UserSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
}

/// Fetches users matching the search query
final searchedUsersProvider = FutureProvider.family<List<ConvoUser>, String>((
  ref,
  query,
) async {
  final currentUserId =
      ref.watch(authStateChangesProvider).asData?.value?.uid ?? '';
  final chatService = ref.watch(chatServiceProvider);
  return chatService.searchUsers(query: query, currentUserId: currentUserId);
});

/// Action controller for chat operations (sending, deleting, reacting, reading, media)
final chatControllerProvider =
    NotifierProvider<ChatController, AsyncValue<void>>(ChatController.new);

class ChatController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<bool> sendMessage({
    required String conversationId,
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
    bool forceOfflineNearby = false,
    bool isForwarded = false,
    String? forwardedFrom,
  }) async {
    final currentUser = ref.read(authStateChangesProvider).asData?.value;
    if (currentUser == null || text.trim().isEmpty) return false;

    final currentProfile = ref.read(currentUserProfileProvider).asData?.value;
    final effectiveSenderName =
        senderName ?? currentProfile?.name ?? currentUser.displayName ?? 'CONVO User';
    final effectiveSenderPhotoUrl = senderPhotoUrl ?? currentProfile?.photoUrl;

    // Check if recipient is blocked (only for 1-to-1)
    if (receiverId != 'group' &&
        receiverId.isNotEmpty &&
        currentProfile != null &&
        currentProfile.isUserBlocked(receiverId)) {
      state = AsyncValue.error(
        'Cannot send message to a blocked contact.',
        StackTrace.current,
      );
      return false;
    }

    state = const AsyncValue.loading();
    try {
      final nearbyService = ref.read(nearbyServiceProvider);
      final isNearbyConnected = nearbyService.isConnectedToUser(receiverId);

      // If forceOfflineNearby or peer is directly connected via Nearby
      if (forceOfflineNearby || isNearbyConnected) {
        final offlineSync = ref.read(offlineSyncServiceProvider);
        await offlineSync.sendOrQueueMessage(
          conversationId: conversationId,
          senderId: currentUser.uid,
          receiverId: receiverId,
          text: text,
          type: type,
        );
        ref.read(replyingMessageProvider.notifier).clear();
        state = const AsyncValue.data(null);
        return true;
      }

      // Try standard Firebase messaging transport
      if (receiverId == 'group') {
        final chatService = ref.read(chatServiceProvider);
        await chatService.sendMessage(
          conversationId: conversationId,
          senderId: currentUser.uid,
          receiverId: 'group',
          text: text,
          type: type,
          replyToMessageId: replyToMessageId,
          replyToSnippet: replyToSnippet,
          replyToSenderName: replyToSenderName,
          senderName: effectiveSenderName,
          senderPhotoUrl: effectiveSenderPhotoUrl,
          recipientIds: recipientIds,
          metadata: metadata,
          expiresAt: expiresAt,
          isSecret: isSecret,
          isForwarded: isForwarded,
          forwardedFrom: forwardedFrom,
        );
      } else {
        try {
          final chatService = ref.read(chatServiceProvider);
          await chatService.sendMessage(
            conversationId: conversationId,
            senderId: currentUser.uid,
            receiverId: receiverId,
            text: text,
            type: type,
            replyToMessageId: replyToMessageId,
            replyToSnippet: replyToSnippet,
            replyToSenderName: replyToSenderName,
            senderName: effectiveSenderName,
            senderPhotoUrl: effectiveSenderPhotoUrl,
            recipientIds: recipientIds,
            metadata: metadata,
            expiresAt: expiresAt,
            isSecret: isSecret,
            isForwarded: isForwarded,
            forwardedFrom: forwardedFrom,
          );
        } catch (networkError) {
          debugPrint(
            'Notice: direct Firebase write fallback to offline sync for $conversationId: $networkError',
          );
          // Network unavailable or direct Firebase write failed: fallback to Smart Offline Queue for 1-to-1
          final offlineSync = ref.read(offlineSyncServiceProvider);
          await offlineSync.sendOrQueueMessage(
            conversationId: conversationId,
            senderId: currentUser.uid,
            receiverId: receiverId,
            text: text,
            type: type,
          );
        }
      }

      ref.read(replyingMessageProvider.notifier).clear();
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e.toString(), st);
      return false;
    }
  }

  Future<bool> sendMediaMessage({
    required String conversationId,
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
    final currentUser = ref.read(authStateChangesProvider).asData?.value;
    if (currentUser == null) return false;

    final currentProfile = ref.read(currentUserProfileProvider).asData?.value;
    final effectiveSenderName =
        senderName ?? currentProfile?.name ?? currentUser.displayName ?? 'CONVO User';
    final effectiveSenderPhotoUrl = senderPhotoUrl ?? currentProfile?.photoUrl;

    // Check if recipient is blocked (only for 1-to-1)
    if (receiverId != 'group' &&
        receiverId.isNotEmpty &&
        currentProfile != null &&
        currentProfile.isUserBlocked(receiverId)) {
      state = AsyncValue.error(
        'Cannot send message to a blocked contact.',
        StackTrace.current,
      );
      return false;
    }

    state = const AsyncValue.loading();
    try {
      final chatService = ref.read(chatServiceProvider);
      await chatService.sendMediaMessage(
        conversationId: conversationId,
        senderId: currentUser.uid,
        receiverId: receiverId,
        type: type,
        mediaUrl: mediaUrl,
        text: text,
        thumbnailUrl: thumbnailUrl,
        fileName: fileName,
        fileSize: fileSize,
        durationMs: durationMs,
        replyToMessageId: replyToMessageId,
        replyToSnippet: replyToSnippet,
        replyToSenderName: replyToSenderName,
        senderName: effectiveSenderName,
        senderPhotoUrl: effectiveSenderPhotoUrl,
        recipientIds: recipientIds,
        metadata: metadata,
        expiresAt: expiresAt,
        isSecret: isSecret,
        isForwarded: isForwarded,
        forwardedFrom: forwardedFrom,
      );

      ref.read(replyingMessageProvider.notifier).clear();
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e.toString(), st);
      return false;
    }
  }

  /// Creates a new group conversation
  Future<ConversationModel?> createGroup({
    required String name,
    List<ConvoUser>? initialMembers,
    List<ConvoUser>? members,
    String? photoUrl,
    String? description,
  }) async {
    final memberList = initialMembers ?? members ?? [];
    final authUser = ref.read(authStateChangesProvider).asData?.value;
    if (authUser == null) return null;
    final profile = ref.read(currentUserProfileProvider).asData?.value;
    final creator =
        profile ??
        ConvoUser(
          uid: authUser.uid,
          name: authUser.displayName ?? 'CONVO User',
          email: authUser.email ?? '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

    state = const AsyncValue.loading();
    try {
      final chatService = ref.read(chatServiceProvider);
      final group = await chatService.createGroupConversation(
        name: name,
        creator: creator,
        initialMembers: memberList,
        photoUrl: photoUrl,
        description: description,
      );
      state = const AsyncValue.data(null);
      return group;
    } catch (e, st) {
      state = AsyncValue.error(e.toString(), st);
      return null;
    }
  }

  /// Updates group metadata - Admin only
  Future<bool> updateGroupInfo({
    required String conversationId,
    String? name,
    String? description,
    String? photoUrl,
    bool removePhoto = false,
  }) async {
    final currentUserId = ref.read(authStateChangesProvider).asData?.value?.uid;
    if (currentUserId == null) return false;

    state = const AsyncValue.loading();
    try {
      final chatService = ref.read(chatServiceProvider);
      await chatService.updateGroupInfo(
        conversationId: conversationId,
        updaterId: currentUserId,
        name: name,
        description: description,
        photoUrl: photoUrl,
        removePhoto: removePhoto,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e.toString(), st);
      return false;
    }
  }

  /// Adds members to group - Admin only
  Future<bool> addGroupMembers({
    required String conversationId,
    required List<ConvoUser> newMembers,
  }) async {
    final authUser = ref.read(authStateChangesProvider).asData?.value;
    if (authUser == null) return false;
    final profile = ref.read(currentUserProfileProvider).asData?.value;
    final admin =
        profile ??
        ConvoUser(
          uid: authUser.uid,
          name: authUser.displayName ?? 'Admin',
          email: authUser.email ?? '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

    state = const AsyncValue.loading();
    try {
      final chatService = ref.read(chatServiceProvider);
      await chatService.addGroupMembers(
        conversationId: conversationId,
        admin: admin,
        newMembers: newMembers,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e.toString(), st);
      return false;
    }
  }

  /// Removes a member from group - Admin only
  Future<bool> removeGroupMember({
    required String conversationId,
    required String memberId,
    required String memberName,
  }) async {
    final authUser = ref.read(authStateChangesProvider).asData?.value;
    if (authUser == null) return false;
    final profile = ref.read(currentUserProfileProvider).asData?.value;
    final admin =
        profile ??
        ConvoUser(
          uid: authUser.uid,
          name: authUser.displayName ?? 'Admin',
          email: authUser.email ?? '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

    state = const AsyncValue.loading();
    try {
      final chatService = ref.read(chatServiceProvider);
      await chatService.removeGroupMember(
        conversationId: conversationId,
        admin: admin,
        memberId: memberId,
        memberName: memberName,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e.toString(), st);
      return false;
    }
  }

  /// Promotes a member to Admin
  Future<bool> promoteToAdmin({
    required String conversationId,
    required String memberId,
  }) async {
    final currentUserId = ref.read(authStateChangesProvider).asData?.value?.uid;
    if (currentUserId == null) return false;

    state = const AsyncValue.loading();
    try {
      final chatService = ref.read(chatServiceProvider);
      await chatService.promoteToAdmin(
        conversationId: conversationId,
        adminId: currentUserId,
        memberId: memberId,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e.toString(), st);
      return false;
    }
  }

  /// Demotes an Admin to regular member
  Future<bool> demoteAdmin({
    required String conversationId,
    String? memberId,
    String? targetAdminId,
  }) async {
    final targetId = memberId ?? targetAdminId;
    if (targetId == null) return false;
    final currentUserId = ref.read(authStateChangesProvider).asData?.value?.uid;
    if (currentUserId == null) return false;

    state = const AsyncValue.loading();
    try {
      final chatService = ref.read(chatServiceProvider);
      await chatService.demoteAdmin(
        conversationId: conversationId,
        currentAdminId: currentUserId,
        targetAdminId: targetId,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e.toString(), st);
      return false;
    }
  }

  /// Leaves group
  Future<bool> leaveGroup({
    required String conversationId,
  }) async {
    final authUser = ref.read(authStateChangesProvider).asData?.value;
    if (authUser == null) return false;
    final profile = ref.read(currentUserProfileProvider).asData?.value;
    final userName = profile?.name ?? authUser.displayName ?? 'A member';

    state = const AsyncValue.loading();
    try {
      final chatService = ref.read(chatServiceProvider);
      await chatService.leaveGroup(
        conversationId: conversationId,
        userId: authUser.uid,
        userName: userName,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e.toString(), st);
      return false;
    }
  }

  /// Toggles mute for a group
  Future<void> toggleGroupMute({
    required String conversationId,
    required bool mute,
  }) async {
    final currentUserId = ref.read(authStateChangesProvider).asData?.value?.uid;
    if (currentUserId == null) return;
    try {
      final chatService = ref.read(chatServiceProvider);
      await chatService.toggleGroupMute(
        conversationId: conversationId,
        userId: currentUserId,
        mute: mute,
      );
    } catch (_) {}
  }

  Future<void> submitGameAnswer({
    required String conversationId,
    required String messageId,
    required String answer,
  }) async {
    final currentUserId = ref.read(authStateChangesProvider).asData?.value?.uid;
    if (currentUserId == null) return;
    try {
      final chatService = ref.read(chatServiceProvider);
      await chatService.submitGameAnswer(
        conversationId: conversationId,
        messageId: messageId,
        userId: currentUserId,
        answer: answer,
      );
    } catch (_) {}
  }

  Future<void> markAsRead(String conversationId) async {
    final currentUserId = ref.read(authStateChangesProvider).asData?.value?.uid;
    if (currentUserId == null) return;

    try {
      final chatService = ref.read(chatServiceProvider);
      await chatService.markConversationAsRead(
        conversationId: conversationId,
        currentUserId: currentUserId,
      );
    } catch (_) {}
  }

  Future<void> toggleReaction({
    required String conversationId,
    required String messageId,
    required String emoji,
  }) async {
    final currentUserId = ref.read(authStateChangesProvider).asData?.value?.uid;
    if (currentUserId == null) return;

    ref
        .read(conversationPaginatedMessagesProvider(conversationId).notifier)
        .updateLocalReaction(messageId, currentUserId, emoji);

    try {
      final chatService = ref.read(chatServiceProvider);
      await chatService.toggleReaction(
        conversationId: conversationId,
        messageId: messageId,
        userId: currentUserId,
        emoji: emoji,
      );
    } catch (_) {}
  }

  Future<void> deleteMessage({
    required String conversationId,
    required String messageId,
  }) async {
    await deleteMessageForEveryone(
      conversationId: conversationId,
      messageId: messageId,
    );
  }

  /// Deletes a message for everyone (only available if user is the sender).
  Future<void> deleteMessageForEveryone({
    required String conversationId,
    required String messageId,
  }) async {
    final currentUserId = ref.read(authStateChangesProvider).asData?.value?.uid;
    if (currentUserId == null) return;

    ref
        .read(conversationPaginatedMessagesProvider(conversationId).notifier)
        .markMessageDeleted(messageId);

    try {
      final chatService = ref.read(chatServiceProvider);
      await chatService.deleteMessage(
        conversationId: conversationId,
        messageId: messageId,
        userId: currentUserId,
      );
    } catch (e, st) {
      state = AsyncValue.error(e.toString(), st);
    }
  }

  /// Deletes a message only for the current user.
  Future<void> deleteMessageForMe({
    required String conversationId,
    required String messageId,
  }) async {
    final currentUserId = ref.read(authStateChangesProvider).asData?.value?.uid;
    if (currentUserId == null) return;

    final prefsService = ref.read(chatPreferencesServiceProvider);
    await prefsService.markMessageDeletedForMe(messageId);

    ref
        .read(conversationPaginatedMessagesProvider(conversationId).notifier)
        .markMessageDeletedForMe(messageId);

    try {
      final chatService = ref.read(chatServiceProvider);
      await chatService.deleteMessageForMe(
        conversationId: conversationId,
        messageId: messageId,
        userId: currentUserId,
      );
    } catch (_) {
      // Handled via local storage if Firestore write fails
    }
  }

  /// Updates typing status with debouncing/throttling.
  Future<void> setTypingStatus({
    required String conversationId,
    required bool isTyping,
  }) async {
    final currentUserId = ref.read(authStateChangesProvider).asData?.value?.uid;
    if (currentUserId == null) return;

    final chatService = ref.read(chatServiceProvider);
    await chatService.setTypingStatus(
      conversationId: conversationId,
      userId: currentUserId,
      isTyping: isTyping,
    );
  }

  Future<void> clearChat(String conversationId) async {
    try {
      final chatService = ref.read(chatServiceProvider);
      await chatService.clearConversationMessages(
        conversationId: conversationId,
      );
    } catch (e, st) {
      state = AsyncValue.error(e.toString(), st);
    }
  }

  /// Deletes or hides conversation from view and clears unread/pinned state
  Future<void> deleteConversation(String conversationId) async {
    try {
      await clearChat(conversationId);
      ref.read(pinnedChatIdsProvider.notifier).unpin(conversationId);
      ref.read(archivedChatIdsProvider.notifier).unarchive(conversationId);
      await ref.read(deletedChatIdsProvider.notifier).deleteChat(conversationId);
    } catch (e, st) {
      state = AsyncValue.error(e.toString(), st);
    }
  }
}

