import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:convo/features/chats/domain/models/message_model.dart';
import 'package:convo/features/chats/presentation/widgets/message_bubble.dart';
import 'package:convo/features/nearby/domain/models/queued_message.dart';
import 'package:convo/services/nearby/nearby_service.dart';
import 'package:convo/services/nearby/offline_sync_service.dart';
import 'package:convo/services/local_storage/offline_queue_storage_service.dart';

class FakeOfflineQueueStorageService implements OfflineQueueStorageService {
  final List<QueuedMessage> _queue = [];

  @override
  Future<void> enqueueMessage(QueuedMessage message) async {
    _queue.removeWhere((m) => m.localMessageId == message.localMessageId);
    _queue.add(message);
  }

  @override
  Future<List<QueuedMessage>> loadQueue() async => List.unmodifiable(_queue);

  @override
  Future<void> updateMessageState(String localMessageId, DeliveryState state) async {
    final idx = _queue.indexWhere((m) => m.localMessageId == localMessageId);
    if (idx != -1) {
      _queue[idx] = _queue[idx].copyWith(deliveryState: state);
    }
  }

  @override
  Future<void> removeMessage(String localMessageId) async {
    _queue.removeWhere((m) => m.localMessageId == localMessageId);
  }

  @override
  Future<void> clearQueue() async {
    _queue.clear();
  }

  @override
  Future<int> pruneSyncedMessages({Duration olderThan = const Duration(hours: 24)}) async {
    final cutoff = DateTime.now().subtract(olderThan);
    final initial = _queue.length;
    _queue.removeWhere((m) => m.isSynced && m.createdAt.isBefore(cutoff));
    return initial - _queue.length;
  }

  @override
  List<QueuedMessage> get currentQueue => List.unmodifiable(_queue);

  @override
  Stream<List<QueuedMessage>> get queueStream => Stream.value(List.unmodifiable(_queue));

  Future<int> getPendingCount() async => _queue.where((m) => !m.isSynced).length;

  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 1 & 2: Truthful Delivery Status Model & UI Tests', () {
    test('QueuedMessage.toMessageModel() preserves deliveryState, uploadStatus and metadata', () {
      final queued = QueuedMessage(
        localMessageId: 'msg_q_1',
        conversationId: 'userA_userB',
        senderId: 'userA',
        receiverId: 'userB',
        text: 'Hello from offline queue',
        createdAt: DateTime.now(),
        deliveryState: DeliveryState.queued,
        retryCount: 2,
      );

      final model = queued.toMessageModel();
      expect(model.id, equals('msg_q_1'));
      expect(model.uploadStatus, equals('queued'));
      expect(model.isQueued, isTrue);
      expect(model.isSending, isFalse);
      expect(model.isDeliveredNearby, isFalse);
      expect(model.isFailed, isFalse);
      expect(model.metadata?['deliveryState'], equals('queued'));
      expect(model.metadata?['retryCount'], equals(2));
    });

    test('QueuedMessage.toMessageModel() preserves deliveredNearby state', () {
      final nearbyMsg = QueuedMessage(
        localMessageId: 'msg_nb_1',
        conversationId: 'userA_userB',
        senderId: 'userA',
        receiverId: 'userB',
        text: 'Hello over Bluetooth',
        createdAt: DateTime.now(),
        deliveryState: DeliveryState.deliveredNearby,
      );

      final model = nearbyMsg.toMessageModel();
      expect(model.uploadStatus, equals('deliveredNearby'));
      expect(model.isDeliveredNearby, isTrue);
      expect(model.isQueued, isFalse);
    });

    testWidgets('MessageBubble displays clock icon for queued / pending messages', (tester) async {
      final queuedMsg = MessageModel(
        id: 'msg_1',
        conversationId: 'userA_userB',
        senderId: 'userA',
        receiverId: 'userB',
        text: 'Waiting for network connection',
        createdAt: DateTime.now(),
        uploadStatus: 'queued',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              message: queuedMsg,
              isMe: true,
              currentUserId: 'userA',
              onReply: () {},
              onReact: (_) {},
              onDelete: () {},
            ),
          ),
        ),
      );

      // Pending message must show schedule_rounded clock icon
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
      expect(find.byIcon(Icons.done_rounded), findsNothing);
      expect(find.byIcon(Icons.done_all_rounded), findsNothing);
    });

    testWidgets('MessageBubble displays double-check icon for deliveredNearby messages', (tester) async {
      final nearbyMsg = MessageModel(
        id: 'msg_2',
        conversationId: 'userA_userB',
        senderId: 'userA',
        receiverId: 'userB',
        text: 'Delivered via Nearby mesh',
        createdAt: DateTime.now(),
        uploadStatus: 'deliveredNearby',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              message: nearbyMsg,
              isMe: true,
              currentUserId: 'userA',
              onReply: () {},
              onReact: (_) {},
              onDelete: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.done_all_rounded), findsOneWidget);
      expect(find.byIcon(Icons.schedule_rounded), findsNothing);
    });

    testWidgets('MessageBubble displays single-check icon for sent (synced) unread messages', (tester) async {
      final syncedMsg = MessageModel(
        id: 'msg_3',
        conversationId: 'userA_userB',
        senderId: 'userA',
        receiverId: 'userB',
        text: 'Written to Firestore backend',
        createdAt: DateTime.now(),
        isRead: false,
        uploadStatus: 'success',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              message: syncedMsg,
              isMe: true,
              currentUserId: 'userA',
              onReply: () {},
              onReact: (_) {},
              onDelete: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.done_rounded), findsOneWidget);
      expect(find.byIcon(Icons.done_all_rounded), findsNothing);
      expect(find.byIcon(Icons.schedule_rounded), findsNothing);
    });

    testWidgets('MessageBubble displays error icon for failed messages', (tester) async {
      final failedMsg = MessageModel(
        id: 'msg_4',
        conversationId: 'userA_userB',
        senderId: 'userA',
        receiverId: 'userB',
        text: 'Failed to send',
        createdAt: DateTime.now(),
        uploadStatus: 'failed',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              message: failedMsg,
              isMe: true,
              currentUserId: 'userA',
              onReply: () {},
              onReact: (_) {},
              onDelete: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.done_rounded), findsNothing);
      expect(find.byIcon(Icons.schedule_rounded), findsNothing);
    });
  });

  group('Phase 3 & 4: OfflineSyncService & Nearby Transport Isolation', () {
    test('syncQueuedMessagesWithFirebase filters out ephemeral nearby_ conversations', () async {
      final fakeStorage = FakeOfflineQueueStorageService();
      final nearbyService = NearbyService();

      // Enqueue 1 valid conversation and 1 ephemeral nearby-only message
      await fakeStorage.enqueueMessage(
        QueuedMessage(
          localMessageId: 'valid_1',
          conversationId: 'userA_userB',
          senderId: 'userA',
          receiverId: 'userB',
          text: 'Valid cloud chat message',
          createdAt: DateTime.now(),
          deliveryState: DeliveryState.queued,
        ),
      );
      await fakeStorage.enqueueMessage(
        QueuedMessage(
          localMessageId: 'ephemeral_1',
          conversationId: 'nearby_ep_xyz123',
          senderId: 'userA',
          receiverId: '',
          text: 'Local mesh broadcast',
          createdAt: DateTime.now(),
          deliveryState: DeliveryState.queued,
        ),
      );

      final syncedIds = <String>[];
      final syncService = OfflineSyncService(
        queueStorage: fakeStorage,
        nearbyService: nearbyService,
        customWriter: (msg) async {
          syncedIds.add(msg.localMessageId);
        },
      );

      final count = await syncService.syncQueuedMessagesWithFirebase();
      expect(count, equals(1));
      expect(syncedIds, contains('valid_1'));
      expect(syncedIds, isNot(contains('ephemeral_1')));

      syncService.dispose();
      nearbyService.dispose();
    });

    test('NearbyService provides clean non-Android fallback and lifecycle management', () async {
      final service = NearbyService();
      expect(service.isEnabled, isFalse);

      final permGranted = await service.checkAndRequestPermissions();
      expect(permGranted, isTrue);

      service.dispose();
      expect(service.isEnabled, isFalse);
    });
  });
}
