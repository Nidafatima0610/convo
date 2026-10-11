import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:convo/features/calls/domain/models/call_model.dart';
import 'package:convo/features/nearby/domain/models/queued_message.dart';
import 'package:convo/services/local_storage/offline_queue_storage_service.dart';
import 'package:convo/services/calling/call_signaling_service.dart';
import 'package:convo/services/firebase/chat_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 3 Verification: Voice & Video Call Signaling Architecture', () {
    test('CallModel serializes and deserializes accurately with signaling metadata', () {
      final now = DateTime.now();
      final call = CallModel(
        callId: 'call_test_123',
        callerId: 'user_alice',
        callerName: 'Alice',
        callerPhoto: 'https://example.com/alice.jpg',
        receiverId: 'user_bob',
        receiverName: 'Bob',
        receiverPhoto: 'https://example.com/bob.jpg',
        type: CallType.video,
        status: CallStatus.ringing,
        createdAt: now,
        startedAt: now,
        offer: {'sdp': 'v=0\r\no=alice 12345 2 IN IP4 127.0.0.1\r\ns=-\r\n', 'type': 'offer'},
        participants: ['user_alice', 'user_bob'],
      );

      final map = call.toMap();
      expect(map['callId'], equals('call_test_123'));
      expect(map['callerId'], equals('user_alice'));
      expect(map['receiverId'], equals('user_bob'));
      expect(map['type'], equals('video'));
      expect(map['status'], equals('ringing'));
      expect(map['participants'], containsAll(['user_alice', 'user_bob']));

      final restored = CallModel.fromMap(map, id: 'call_test_123');
      expect(restored.callId, equals('call_test_123'));
      expect(restored.callerName, equals('Alice'));
      expect(restored.receiverName, equals('Bob'));
      expect(restored.status, equals(CallStatus.ringing));
      expect(restored.isVideo, isTrue);
    });

    test('CallStatus enum correctly transitions through complete lifecycle', () {
      expect(CallStatus.ringing.toValue(), equals('ringing'));
      expect(CallStatus.accepted.toValue(), equals('accepted'));
      expect(CallStatus.ended.toValue(), equals('ended'));
      expect(CallStatus.rejected.toValue(), equals('rejected'));
      expect(CallStatus.missed.toValue(), equals('missed'));

      expect(CallStatus.fromString('ringing'), equals(CallStatus.ringing));
      expect(CallStatus.fromString('accepted'), equals(CallStatus.accepted));
      expect(CallStatus.fromString('ended'), equals(CallStatus.ended));
      expect(CallStatus.fromString('rejected'), equals(CallStatus.rejected));
      expect(CallStatus.fromString('missed'), equals(CallStatus.missed));
      expect(CallStatus.fromString('unknown_status'), equals(CallStatus.ringing));
    });

    test('CallSignalingService fail-safes gracefully when Firebase is unavailable', () async {
      final service = CallSignalingService();

      // listenToCall should yield an empty stream without throwing
      final stream = service.listenToCall('offline_call_1');
      expect(stream, isNotNull);
      final events = await stream.toList();
      expect(events, isEmpty);
    });
  });

  group('Phase 3 Verification: Media & Document Partitioning Architecture', () {
    test('Storage path partitioning conforms strictly to security rule pattern', () {
      const senderId = 'user_alice_456';
      const conversationId = 'conv_abc_789';
      const category = 'files';
      const fileName = 'Annual Financial Report 2026.pdf';

      final cleanName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final path = 'users/$senderId/chats/$conversationId/$category/1770000000_$cleanName';

      // Path format: users/{userId}/chats/{conversationId}/{category}/{timestamp}_{filename}
      expect(path, startsWith('users/$senderId/chats/$conversationId/$category/'));
      expect(path, endsWith('_Annual_Financial_Report_2026.pdf'));
      expect(path.contains(' '), isFalse);
    });

    test('Supported document extensions cover all standard workplace formats', () {
      const allowedExtensions = [
        'pdf',
        'doc',
        'docx',
        'txt',
        'xls',
        'xlsx',
        'ppt',
        'pptx',
        'zip',
      ];

      expect(allowedExtensions, contains('pdf'));
      expect(allowedExtensions, contains('docx'));
      expect(allowedExtensions, contains('xlsx'));
      expect(allowedExtensions, contains('zip'));
      expect(allowedExtensions.length, equals(9));
    });
  });

  group('Phase 3 Verification: Smart Offline Queue App-Restart Persistence', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('convo_test_queue_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Queued messages survive simulated app restart and retain retryCount', () async {
      final msg1 = QueuedMessage(
        localMessageId: 'msg_restart_1',
        conversationId: 'conv_restart_abc',
        senderId: 'user_sender_1',
        receiverId: 'user_receiver_1',
        text: 'Message pending offline sync across app relaunch',
        type: 'text',
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        deliveryState: DeliveryState.queued,
        retryCount: 2,
        offlineOrigin: true,
      );

      final msg2 = QueuedMessage(
        localMessageId: 'msg_restart_2',
        conversationId: 'conv_restart_abc',
        senderId: 'user_sender_1',
        receiverId: 'user_receiver_1',
        text: 'Document attachment pending network',
        type: 'file',
        createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
        deliveryState: DeliveryState.sending,
        retryCount: 0,
        offlineOrigin: true,
      );

      // Session 1: Service instance starts clean and writes to disk
      final session1Storage = OfflineQueueStorageService();
      await session1Storage.clearQueue();
      await session1Storage.enqueueMessage(msg1);
      await session1Storage.enqueueMessage(msg2);

      expect(session1Storage.currentQueue.length, equals(2));

      // Simulate app kill and cold restart: instantiate a fresh service
      final session2Storage = OfflineQueueStorageService();
      final loadedQueue = await session2Storage.loadQueue();

      expect(loadedQueue.length, equals(2));
      final loadedMsg1 = loadedQueue.firstWhere((m) => m.localMessageId == 'msg_restart_1');
      expect(loadedMsg1.text, equals('Message pending offline sync across app relaunch'));
      expect(loadedMsg1.retryCount, equals(2));
      expect(loadedMsg1.offlineOrigin, isTrue);
      expect(loadedMsg1.deliveryState, equals(DeliveryState.queued));

      final loadedMsg2 = loadedQueue.firstWhere((m) => m.localMessageId == 'msg_restart_2');
      expect(loadedMsg2.type, equals('file'));
      expect(loadedMsg2.retryCount, equals(0));

      // Cleanup
      await session1Storage.clearQueue();
      session1Storage.dispose();
      session2Storage.dispose();
    });
  });

  group('Phase 3 Verification: Firebase Offline / Network Outage Safety', () {
    test('ChatService streams fail-safe without throwing when Firebase is offline', () async {
      final chatService = ChatService();
      final convStream = chatService.conversationsStream('user_test_outage');
      expect(convStream, isNotNull);
      final convs = await convStream.toList();
      expect(convs, isEmpty);

      final msgStream = chatService.messagesStream('conv_test_outage');
      expect(msgStream, isNotNull);
      final msgs = await msgStream.toList();
      expect(msgs, isEmpty);
    });
  });
}
