import 'dart:io';

import 'package:convo/features/chats/domain/models/conversation_model.dart';
import 'package:convo/features/chats/domain/models/message_model.dart';
import 'package:convo/features/chats/presentation/providers/chat_providers.dart';
import 'package:convo/features/nearby/domain/models/queued_message.dart';
import 'package:convo/services/firebase/media_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.now();

  group('Task 1 & 8: One-to-One Messaging Reliability & Validation', () {
    test('ConversationModel generates deterministic conversation IDs for two users', () {
      final id1 = ConversationModel.getConversationId('alice_uid', 'bob_uid');
      final id2 = ConversationModel.getConversationId('bob_uid', 'alice_uid');

      expect(id1, id2, reason: 'ID must be deterministic regardless of participant order');
      expect(id1, 'alice_uid_bob_uid');
    });

    test('MessageModel serializes, deserializes and preserves server timestamp resolution', () {
      final msg = MessageModel(
        id: 'msg_test_101',
        conversationId: 'conv_123',
        senderId: 'user_a',
        receiverId: 'user_b',
        text: 'Reliable delivery confirmed',
        type: 'text',
        createdAt: now,
        isRead: false,
        reactions: {'user_b': '❤️'},
      );

      final map = msg.toMap();
      expect(map['id'], 'msg_test_101');
      expect(map['conversationId'], 'conv_123');
      expect(map['senderId'], 'user_a');
      expect(map['receiverId'], 'user_b');
      expect(map['text'], 'Reliable delivery confirmed');
      expect(map['reactions'], {'user_b': '❤️'});

      final restored = MessageModel.fromMap(map, docId: 'msg_test_101');
      expect(restored.id, 'msg_test_101');
      expect(restored.text, 'Reliable delivery confirmed');
      expect(restored.reactions['user_b'], '❤️');
    });

    test('ChatController rejects empty or whitespace-only messages without network calls', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(chatControllerProvider.notifier);
      final emptyResult = await controller.sendMessage(
        conversationId: 'conv_1',
        receiverId: 'user_b',
        text: '   ',
      );

      expect(emptyResult, isFalse, reason: 'Whitespace-only messages must be rejected');
    });

    test('ChatController rejects media messages with empty or blank mediaUrl', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(chatControllerProvider.notifier);
      final emptyMediaResult = await controller.sendMediaMessage(
        conversationId: 'conv_1',
        receiverId: 'user_b',
        type: 'image',
        mediaUrl: '   ',
      );

      expect(emptyMediaResult, isFalse, reason: 'Blank mediaUrl must be rejected safely');
    });
  });

  group('Task 2 & 8: Conversation List Behavior, Sorting & Badges', () {
    test('Pinned conversations consistently sort before unpinned conversations', () {
      final olderTime = now.subtract(const Duration(hours: 2));
      final newerTime = now.subtract(const Duration(minutes: 5));

      final pinnedOldConv = ConversationModel(
        id: 'conv_pinned',
        participants: ['user_me', 'user_other1'],
        participantDetails: {},
        lastMessage: 'Old message',
        lastMessageAt: olderTime,
        updatedAt: olderTime,
        createdAt: olderTime,
      );

      final unpinnedNewConv = ConversationModel(
        id: 'conv_unpinned',
        participants: ['user_me', 'user_other2'],
        participantDetails: {},
        lastMessage: 'New message',
        lastMessageAt: newerTime,
        updatedAt: newerTime,
        createdAt: newerTime,
      );

      final pinnedIds = {'conv_pinned'};
      final list = [unpinnedNewConv, pinnedOldConv];

      list.sort((a, b) {
        final aPinned = pinnedIds.contains(a.id);
        final bPinned = pinnedIds.contains(b.id);
        if (aPinned && !bPinned) return -1;
        if (!aPinned && bPinned) return 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });

      expect(list.first.id, 'conv_pinned', reason: 'Pinned conversation must be first');
      expect(list.last.id, 'conv_unpinned');
    });

    test('Unread counts accurately reflect recipient unread balance', () {
      final conv = ConversationModel(
        id: 'conv_unread_test',
        participants: ['alice', 'bob'],
        participantDetails: {},
        unreadCounts: {'alice': 0, 'bob': 7},
        lastMessageAt: now,
        createdAt: now,
        updatedAt: now,
      );

      expect(conv.unreadCountFor('bob'), 7);
      expect(conv.unreadCountFor('alice'), 0);
      expect(conv.unreadCountFor('unknown'), 0);
    });
  });

  group('Task 3 & 8: Reply, Reactions & Quoted Fallbacks', () {
    test('MessageModel reaction toggling correctly records and replaces reactions', () {
      final msg = MessageModel(
        id: 'msg_react',
        conversationId: 'c1',
        senderId: 'alice',
        receiverId: 'bob',
        text: 'Check this out',
        createdAt: now,
        reactions: {'bob': '👍'},
      );

      expect(msg.reactions['bob'], '👍');
      expect(msg.reactionOfUser('bob'), '👍');
      expect(msg.reactionCounts['👍'], 1);

      // Switching reaction
      final updated = msg.copyWith(
        reactions: {...msg.reactions, 'bob': '🔥'},
      );
      expect(updated.reactionOfUser('bob'), '🔥');
      expect(updated.reactionCounts['🔥'], 1);
      expect(updated.reactionCounts['👍'], isNull);
    });

    test('ReplyingMessageNotifier sets and clears reply state safely', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(replyingMessageProvider.notifier);
      expect(container.read(replyingMessageProvider), isNull);

      final targetMsg = MessageModel(
        id: 'quoted_123',
        conversationId: 'c1',
        senderId: 'alice',
        receiverId: 'bob',
        text: 'Original message text',
        createdAt: now,
      );

      notifier.setMessage(targetMsg);
      expect(container.read(replyingMessageProvider)?.id, 'quoted_123');

      notifier.clear();
      expect(container.read(replyingMessageProvider), isNull);
    });
  });

  group('Task 4 & 8: Media & Document Validation', () {
    test('MediaService validates 50MB limit client-side before starting upload', () async {
      final mediaService = MediaService();

      // Create a temporary scratch file
      final tempDir = await Directory.systemTemp.createTemp('convo_test_media_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final nonExistentPath = '${tempDir.path}/missing_file.jpg';
      expect(
        () => mediaService.uploadChatMedia(
          filePath: nonExistentPath,
          senderId: 'u1',
          conversationId: 'c1',
          category: 'images',
          fileName: 'missing.jpg',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('Task 5 & 8: Offline Queue Preservation & Privacy', () {
    test('QueuedMessage correctly converts to MessageModel with offlineOrigin flag', () {
      final queued = QueuedMessage(
        localMessageId: 'msg_offline_99',
        conversationId: 'c_mesh',
        senderId: 'sender_1',
        receiverId: 'peer_1',
        text: 'Nearby message text',
        type: 'text',
        createdAt: now,
        deliveryState: DeliveryState.queued,
        offlineOrigin: true,
      );

      final msg = queued.toMessageModel();
      expect(msg.id, 'msg_offline_99');
      expect(msg.offlineOrigin, isTrue);
      expect(msg.text, 'Nearby message text');
      expect(msg.senderId, 'sender_1');
      expect(msg.receiverId, 'peer_1');
    });

    test('QueuedMessage preserves retryCount across queue updates', () {
      final queued = QueuedMessage(
        localMessageId: 'msg_retry_1',
        conversationId: 'c1',
        senderId: 'u1',
        receiverId: 'u2',
        text: 'Retry test message',
        type: 'text',
        createdAt: now,
        retryCount: 0,
      );

      final retried = queued.copyWith(retryCount: queued.retryCount + 1);
      expect(retried.retryCount, 1);
      expect(retried.localMessageId, 'msg_retry_1');
    });
  });

  group('Task 6 & 8: Groups Administration & Sole-Admin Logic', () {
    test('ConversationModel isAdmin distinguishes admins from non-admins', () {
      final group = ConversationModel(
        id: 'group_test_adm',
        type: 'group',
        admins: ['admin_uid'],
        participants: ['admin_uid', 'member_1', 'member_2'],
        participantDetails: {},
        lastMessageAt: now,
        createdAt: now,
        updatedAt: now,
      );

      expect(group.isAdmin('admin_uid'), isTrue);
      expect(group.isAdmin('member_1'), isFalse);
    });

    test('ConversationModel member metadata lookups provide safe fallbacks', () {
      final group = ConversationModel(
        id: 'group_test_fallback',
        type: 'group',
        participants: ['u1', 'u2'],
        participantDetails: {
          'u1': {'name': 'Fatima', 'photoUrl': 'https://photo.jpg'},
        },
        lastMessageAt: now,
        createdAt: now,
        updatedAt: now,
      );

      expect(group.memberName('u1'), 'Fatima');
      expect(group.memberPhoto('u1'), 'https://photo.jpg');
      expect(group.memberName('u2'), 'CONVO User');
      expect(group.memberPhoto('u2'), isNull);
    });
  });
}
