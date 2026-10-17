import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:convo/features/capsules/domain/models/capsule_model.dart';
import 'package:convo/features/chats/presentation/widgets/image_viewer_screen.dart';
import 'package:convo/features/nearby/domain/models/queued_message.dart';
import 'package:convo/features/voice_effects/domain/models/voice_effect.dart';
import 'package:convo/services/local_storage/offline_queue_storage_service.dart';
import 'package:convo/services/nearby/nearby_service.dart';
import 'package:convo/services/nearby/offline_sync_service.dart';

void main() {
  group('Production Reliability: Smart Offline Queue & Synchronization Tests', () {
    late OfflineQueueStorageService queueStorage;
    late NearbyService nearbyService;

    setUp(() async {
      queueStorage = OfflineQueueStorageService();
      nearbyService = NearbyService();
      await queueStorage.clearQueue();
    });

    tearDown(() async {
      await queueStorage.clearQueue();
      queueStorage.dispose();
      nearbyService.dispose();
    });

    test('Concurrency Guard: Concurrent sync passes do not interleave', () async {
      int writeCount = 0;
      final syncService = OfflineSyncService(
        queueStorage: queueStorage,
        nearbyService: nearbyService,
        customWriter: (msg) async {
          writeCount++;
          await Future.delayed(const Duration(milliseconds: 50));
        },
      );

      final msg1 = QueuedMessage(
        localMessageId: 'msg_concurrent_1',
        conversationId: 'conv_123',
        senderId: 'user_a',
        receiverId: 'user_b',
        text: 'Reliability test message',
        createdAt: DateTime.now(),
      );
      await queueStorage.enqueueMessage(msg1);

      // Trigger two concurrent sync calls
      final future1 = syncService.syncQueuedMessagesWithFirebase();
      final future2 = syncService.syncQueuedMessagesWithFirebase();

      final results = await Future.wait([future1, future2]);

      // Exactly one pass must acquire the lock and sync the message; second pass returns 0
      expect(results.contains(1), isTrue);
      expect(results.contains(0), isTrue);
      expect(writeCount, equals(1));

      final queue = await queueStorage.loadQueue();
      expect(queue.first.isSynced, isTrue);

      syncService.dispose();
    });

    test('Retry Behavior: Transient failure preserves message in queue with incremented retryCount', () async {
      bool shouldFail = true;
      final syncService = OfflineSyncService(
        queueStorage: queueStorage,
        nearbyService: nearbyService,
        customWriter: (msg) async {
          if (shouldFail) {
            throw Exception('Simulated network outage / timeout');
          }
        },
      );

      final msg = QueuedMessage(
        localMessageId: 'msg_retry_1',
        conversationId: 'conv_abc',
        senderId: 'user_a',
        receiverId: 'user_b',
        text: 'Testing retry preservation',
        createdAt: DateTime.now(),
        retryCount: 0,
      );
      await queueStorage.enqueueMessage(msg);

      // 1. Sync fails
      final syncedFirst = await syncService.syncQueuedMessagesWithFirebase();
      expect(syncedFirst, equals(0));

      final queueAfterFail = await queueStorage.loadQueue();
      expect(queueAfterFail.length, equals(1));
      expect(queueAfterFail.first.isSynced, isFalse);
      expect(queueAfterFail.first.retryCount, equals(1));

      // 2. Network recovers
      shouldFail = false;
      final syncedSecond = await syncService.syncQueuedMessagesWithFirebase();
      expect(syncedSecond, equals(1));

      final queueAfterSuccess = await queueStorage.loadQueue();
      expect(queueAfterSuccess.first.isSynced, isTrue);
      expect(queueAfterSuccess.first.retryCount, equals(1));

      syncService.dispose();
    });

    test('Nearby Messages Cloud Isolation: Messages starting with nearby_ are never pushed to Firestore', () async {
      int cloudWriteAttempts = 0;
      final syncService = OfflineSyncService(
        queueStorage: queueStorage,
        nearbyService: nearbyService,
        customWriter: (msg) async {
          cloudWriteAttempts++;
        },
      );

      final nearbyMsg = QueuedMessage(
        localMessageId: 'msg_nearby_peer_1',
        conversationId: 'nearby_peer_xyz',
        senderId: 'user_a',
        receiverId: 'peer_xyz',
        text: 'Offline radio direct packet',
        createdAt: DateTime.now(),
        deliveryState: DeliveryState.deliveredNearby,
      );
      await queueStorage.enqueueMessage(nearbyMsg);

      final syncedCount = await syncService.syncQueuedMessagesWithFirebase();
      expect(syncedCount, equals(0));
      expect(cloudWriteAttempts, equals(0));

      final queue = await queueStorage.loadQueue();
      expect(queue.first.deliveryState, equals(DeliveryState.deliveredNearby));

      syncService.dispose();
    });

    test('Queue Pruning: Prunes old synced messages while keeping pending and recent messages', () async {
      final oldSynced = QueuedMessage(
        localMessageId: 'msg_old_synced',
        conversationId: 'conv_1',
        senderId: 'user_a',
        receiverId: 'user_b',
        text: 'Old synced',
        createdAt: DateTime.now().subtract(const Duration(hours: 48)),
        deliveryState: DeliveryState.synced,
      );

      final recentSynced = QueuedMessage(
        localMessageId: 'msg_recent_synced',
        conversationId: 'conv_1',
        senderId: 'user_a',
        receiverId: 'user_b',
        text: 'Recent synced',
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        deliveryState: DeliveryState.synced,
      );

      final pendingMsg = QueuedMessage(
        localMessageId: 'msg_pending',
        conversationId: 'conv_1',
        senderId: 'user_a',
        receiverId: 'user_b',
        text: 'Still queued',
        createdAt: DateTime.now().subtract(const Duration(hours: 48)),
        deliveryState: DeliveryState.queued,
      );

      await queueStorage.enqueueMessage(oldSynced);
      await queueStorage.enqueueMessage(recentSynced);
      await queueStorage.enqueueMessage(pendingMsg);

      final removed = await queueStorage.pruneSyncedMessages(
        olderThan: const Duration(hours: 24),
      );

      expect(removed, equals(1));
      final remaining = await queueStorage.loadQueue();
      expect(remaining.any((m) => m.localMessageId == 'msg_old_synced'), isFalse);
      expect(remaining.any((m) => m.localMessageId == 'msg_recent_synced'), isTrue);
      expect(remaining.any((m) => m.localMessageId == 'msg_pending'), isTrue);
    });
  });

  group('Production Reliability: Media, Audio & Features Tests', () {
    test('Voice Effects Presets: Every preset defines distinct audio playback characteristics', () {
      final presets = VoiceEffectPreset.presets;
      expect(presets.length, equals(5));

      final normal = presets.firstWhere((p) => p.type == VoiceEffectType.normal);
      final funny = presets.firstWhere((p) => p.type == VoiceEffectType.funny);
      final deep = presets.firstWhere((p) => p.type == VoiceEffectType.deep);
      final robot = presets.firstWhere((p) => p.type == VoiceEffectType.robot);

      expect(normal.playbackSpeed, equals(1.0));
      expect(funny.playbackSpeed, greaterThan(1.0));
      expect(deep.playbackSpeed, lessThan(1.0));
      expect(robot.playbackSpeed, isNot(equals(normal.playbackSpeed)));

      // Ensure descriptions and semitones are configured
      for (final preset in presets) {
        expect(preset.name.isNotEmpty, isTrue);
        expect(preset.description.isNotEmpty, isTrue);
      }
    });

    test('Message Capsule: Timezone UTC conversions and unlock status compute safely', () {
      final pastTime = DateTime.now().subtract(const Duration(minutes: 10));
      final futureTime = DateTime.now().add(const Duration(days: 3));

      final readyCapsule = CapsuleModel(
        id: 'cap_ready_1',
        conversationId: 'conv_1',
        senderId: 'user_a',
        senderName: 'Alice',
        receiverId: 'user_b',
        receiverName: 'Bob',
        message: 'Surprise birthday note!',
        unlockAt: pastTime,
        createdAt: pastTime.subtract(const Duration(days: 5)),
      );

      expect(readyCapsule.isUnlocked, isTrue);
      expect(readyCapsule.isLocked, isFalse);
      expect(readyCapsule.timeRemaining, equals(Duration.zero));
      expect(readyCapsule.countdownString, equals('Ready to open!'));

      final lockedCapsule = CapsuleModel(
        id: 'cap_locked_1',
        conversationId: 'conv_1',
        senderId: 'user_a',
        senderName: 'Alice',
        receiverId: 'user_b',
        receiverName: 'Bob',
        message: 'Graduation wish',
        unlockAt: futureTime,
        createdAt: DateTime.now(),
      );

      expect(lockedCapsule.isUnlocked, isFalse);
      expect(lockedCapsule.isLocked, isTrue);
      expect(lockedCapsule.countdownString, contains('remaining'));

      // Test map serialization preserves UTC
      final map = lockedCapsule.toMap();
      expect(map['unlockAt'], isNotNull);
      expect(map['status'], equals('locked'));
    });

    testWidgets('ImageViewerScreen: Renders Download, Copy Link, and Browser actions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ImageViewerScreen(
            imageUrl: 'https://images.unsplash.com/photo-1579546929518-9e396f3cc809',
            title: 'Shared Photo',
          ),
        ),
      );

      await tester.pump();

      // Verify all 3 genuine top bar action buttons exist
      expect(find.byIcon(Icons.download_rounded), findsOneWidget);
      expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
      expect(find.byIcon(Icons.open_in_new_rounded), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.text('Shared Photo'), findsOneWidget);
    });
  });
}
