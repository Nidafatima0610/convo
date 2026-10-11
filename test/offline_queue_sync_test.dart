import 'package:flutter_test/flutter_test.dart';
import 'package:convo/features/nearby/domain/models/queued_message.dart';
import 'package:convo/services/local_storage/offline_queue_storage_service.dart';
import 'package:convo/services/nearby/nearby_service.dart';
import 'package:convo/services/nearby/offline_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OfflineSyncService & Smart Offline Queue Sync Tests', () {
    late OfflineQueueStorageService queueStorage;
    late NearbyService nearbyService;

    setUp(() async {
      queueStorage = OfflineQueueStorageService();
      await queueStorage.clearQueue();
      nearbyService = NearbyService();
    });

    tearDown(() {
      queueStorage.dispose();
      nearbyService.dispose();
    });

    test('New-conversation sync: processes write sequence and marks as synced', () async {
      final writtenMessages = <QueuedMessage>[];
      final syncService = OfflineSyncService(
        queueStorage: queueStorage,
        nearbyService: nearbyService,
        customWriter: (m) async {
          writtenMessages.add(m);
        },
      );

      final msg = QueuedMessage(
        localMessageId: 'msg_test_1',
        conversationId: 'user1_user2',
        senderId: 'user1',
        receiverId: 'user2',
        text: 'Hello offline world',
        createdAt: DateTime(2026, 10, 11, 12, 0),
        deliveryState: DeliveryState.queued,
        offlineOrigin: true,
      );

      await queueStorage.enqueueMessage(msg);
      expect((await queueStorage.loadQueue()).length, 1);
      expect((await queueStorage.loadQueue()).first.deliveryState, DeliveryState.queued);

      final syncedCount = await syncService.syncQueuedMessagesWithFirebase();

      expect(syncedCount, 1);
      expect(writtenMessages.length, 1);
      expect(writtenMessages.first.localMessageId, 'msg_test_1');
      expect(writtenMessages.first.senderId, 'user1');
      expect(writtenMessages.first.conversationId, 'user1_user2');

      final queueAfter = await queueStorage.loadQueue();
      expect(queueAfter.first.deliveryState, DeliveryState.synced);
      expect(queueAfter.first.isSynced, isTrue);

      syncService.dispose();
    });

    test('Retry behavior: failure retains message in queue, increments retryCount and does not mark synced', () async {
      int attempts = 0;
      final syncService = OfflineSyncService(
        queueStorage: queueStorage,
        nearbyService: nearbyService,
        customWriter: (m) async {
          attempts++;
          throw Exception('Simulated Firestore network timeout');
        },
      );

      final msg = QueuedMessage(
        localMessageId: 'msg_fail_test',
        conversationId: 'user1_user2',
        senderId: 'user1',
        receiverId: 'user2',
        text: 'Message that fails',
        createdAt: DateTime(2026, 10, 11, 12, 5),
        deliveryState: DeliveryState.queued,
        offlineOrigin: true,
      );

      await queueStorage.enqueueMessage(msg);

      final syncedCount = await syncService.syncQueuedMessagesWithFirebase();

      expect(syncedCount, 0);
      expect(attempts, 1);

      final queueAfter = await queueStorage.loadQueue();
      expect(queueAfter.length, 1);
      expect(queueAfter.first.deliveryState, DeliveryState.queued);
      expect(queueAfter.first.retryCount, 1);
      expect(queueAfter.first.isSynced, isFalse);

      syncService.dispose();
    });

    test('Duplicate prevention: re-enqueuing or retrying does not create duplicate entries', () async {
      final syncService = OfflineSyncService(
        queueStorage: queueStorage,
        nearbyService: nearbyService,
        customWriter: (m) async {},
      );

      final msg = QueuedMessage(
        localMessageId: 'msg_stable_unique_id',
        conversationId: 'user1_user2',
        senderId: 'user1',
        receiverId: 'user2',
        text: 'Duplicate prevention message',
        createdAt: DateTime(2026, 10, 11, 12, 10),
        deliveryState: DeliveryState.queued,
        offlineOrigin: true,
      );

      // Enqueue twice
      await queueStorage.enqueueMessage(msg);
      await queueStorage.enqueueMessage(msg);

      final queue = await queueStorage.loadQueue();
      expect(queue.length, 1, reason: 'Duplicate enqueue should update existing record, not duplicate it');

      // Sync successfully
      final syncedCount = await syncService.syncQueuedMessagesWithFirebase();
      expect(syncedCount, 1);

      // Re-running sync when already synced should sync 0 additional items
      final reSyncCount = await syncService.syncQueuedMessagesWithFirebase();
      expect(reSyncCount, 0);

      final finalQueue = await queueStorage.loadQueue();
      expect(finalQueue.length, 1);
      expect(finalQueue.first.isSynced, isTrue);

      syncService.dispose();
    });
  });
}
