import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../features/nearby/domain/models/queued_message.dart';
import '../local_storage/offline_queue_storage_service.dart';
import 'nearby_service.dart';

class OfflineSyncService {
  OfflineSyncService({
    required this.queueStorage,
    required this.nearbyService,
    FirebaseFirestore? firestore,
    this.customWriter,
  }) : _customFirestore = firestore {
    _initListeners();
  }

  final OfflineQueueStorageService queueStorage;
  final NearbyService nearbyService;
  final FirebaseFirestore? _customFirestore;
  final Future<void> Function(QueuedMessage)? customWriter;

  OfflineQueueStorageService get _queueStorage => queueStorage;
  NearbyService get _nearbyService => nearbyService;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  StreamSubscription<QueuedMessage>? _incomingSub;
  StreamSubscription<String>? _ackSub;
  Timer? _periodicSyncTimer;

  bool get _isFirebaseAvailable {
    if (customWriter != null) return true;
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _initListeners() {
    // 1. Listen for incoming direct offline messages
    _incomingSub = _nearbyService.incomingMessageStream.listen((message) async {
      debugPrint(
        'Received offline message: id=${message.localMessageId}, type=${message.type}',
      );
      await _queueStorage.enqueueMessage(
        message.copyWith(deliveryState: DeliveryState.deliveredNearby),
      );
    });

    // 2. Listen for delivery ACKs from peers
    _ackSub = _nearbyService.messageAckStream.listen((localMessageId) async {
      debugPrint('Peer acknowledged offline message delivery: $localMessageId');
      await _queueStorage.updateMessageState(
        localMessageId,
        DeliveryState.deliveredNearby,
      );
    });

    // 3. Periodic sync attempt when internet is available
    _periodicSyncTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      syncQueuedMessagesWithFirebase();
    });
  }

  /// Sends a message either through Direct Nearby connection (if peer is connected)
  /// or enqueues it locally for Smart Offline synchronization.
  Future<DeliveryState> sendOrQueueMessage({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required String text,
    String type = 'text',
  }) async {
    final localMessageId =
        'msg_${senderId}_${DateTime.now().millisecondsSinceEpoch}';

    final queuedMessage = QueuedMessage(
      localMessageId: localMessageId,
      conversationId: conversationId,
      senderId: senderId,
      receiverId: receiverId,
      text: text,
      type: type,
      createdAt: DateTime.now(),
      deliveryState: DeliveryState.queued,
      offlineOrigin: true,
    );

    // Save locally first so it is never lost
    await _queueStorage.enqueueMessage(queuedMessage);

    // Check if receiver is directly connected via Nearby
    final peerEndpoint = _nearbyService.getEndpointIdForUser(receiverId);
    if (peerEndpoint != null) {
      final sentDirectly = await _nearbyService.sendOfflineMessage(
        endpointId: peerEndpoint,
        message: queuedMessage,
      );

      if (sentDirectly) {
        await _queueStorage.updateMessageState(
          localMessageId,
          DeliveryState.deliveredNearby,
        );
        return DeliveryState.deliveredNearby;
      }
    }

    // Try syncing immediately with Firebase if internet is active
    if (_isFirebaseAvailable) {
      try {
        await _writeToFirebase(queuedMessage).timeout(const Duration(seconds: 3));
        await _queueStorage.updateMessageState(
          localMessageId,
          DeliveryState.synced,
        );
        return DeliveryState.synced;
      } catch (_) {
        // Retain as queued for next automatic sync
      }
    }

    return DeliveryState.queued;
  }

  /// Flushes any pending offline messages addressed to a newly connected nearby peer.
  Future<void> flushMessagesToConnectedPeer(String peerUserId) async {
    final peerEndpoint = _nearbyService.getEndpointIdForUser(peerUserId);
    if (peerEndpoint == null) return;

    final queue = await _queueStorage.loadQueue();
    final pendingForPeer = queue.where(
      (m) => m.receiverId == peerUserId && m.isQueued,
    );

    for (final message in pendingForPeer) {
      final success = await _nearbyService.sendOfflineMessage(
        endpointId: peerEndpoint,
        message: message,
      );
      if (success) {
        await _queueStorage.updateMessageState(
          message.localMessageId,
          DeliveryState.deliveredNearby,
        );
      }
    }
  }

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  /// Synchronizes all queued / locally delivered messages to Firestore idempotently.
  Future<int> syncQueuedMessagesWithFirebase() async {
    if (_isSyncing) return 0;
    _isSyncing = true;

    try {
      if (!_isFirebaseAvailable) return 0;

      final queue = await _queueStorage.loadQueue();
      final toSync = queue
          .where((m) =>
              !m.isSynced &&
              !m.conversationId.startsWith('nearby_') &&
              m.receiverId.isNotEmpty)
          .toList();
      if (toSync.isEmpty) return 0;

      int syncedCount = 0;
      for (final message in toSync) {
        try {
          await _writeToFirebase(message);
          await _queueStorage.updateMessageState(
            message.localMessageId,
            DeliveryState.synced,
          );
          syncedCount++;
        } catch (e) {
          debugPrint('Sync retry notice for ${message.localMessageId}: $e');
          // Record retry count so that queue tracks attempts without message loss
          await _queueStorage.enqueueMessage(
            message.copyWith(retryCount: message.retryCount + 1),
          );
          break; // Stop iteration if network/auth is unavailable
        }
      }

      return syncedCount;
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _writeToFirebase(QueuedMessage m) async {
    final writer = customWriter;
    if (writer != null) {
      await writer(m);
      return;
    }

    final conversationDoc = _firestore
        .collection('conversations')
        .doc(m.conversationId);
    final messageDoc = conversationDoc
        .collection('messages')
        .doc(m.localMessageId);

    // 1. Check parent conversation existence with resilient timeout
    final convSnap = await conversationDoc
        .get(const GetOptions(source: Source.serverAndCache))
        .timeout(const Duration(seconds: 4));

    // 2. Commit conversation header and message in a SINGLE atomic batch.
    // Under firestore.rules, getAfter(/databases/.../conversations/$(conversationId))
    // succeeds atomically in the same batch transaction, ensuring neither
    // orphaned conversation nor orphaned message documents can ever be created.
    final batch = _firestore.batch();

    if (!convSnap.exists || convSnap.data() == null) {
      final isGroup = m.receiverId == 'group';
      batch.set(conversationDoc, {
        'id': m.conversationId,
        'participants': isGroup ? [m.senderId] : [m.senderId, m.receiverId],
        'lastMessage': m.text,
        'lastMessageAt': Timestamp.fromDate(m.createdAt),
        'lastMessageSenderId': m.senderId,
        'unreadCounts': isGroup ? {m.senderId: 0} : {m.senderId: 0, m.receiverId: 1},
        'type': isGroup ? 'group' : 'direct',
        if (isGroup) 'admins': [m.senderId],
        if (isGroup) 'createdBy': m.senderId,
        'createdAt': Timestamp.fromDate(m.createdAt),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      batch.update(conversationDoc, {
        'lastMessage': m.text,
        'lastMessageAt': Timestamp.fromDate(m.createdAt),
        'lastMessageSenderId': m.senderId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    batch.set(messageDoc, {
      'id': m.localMessageId,
      'conversationId': m.conversationId,
      'senderId': m.senderId,
      'receiverId': m.receiverId,
      'text': m.text,
      'type': m.type,
      'createdAt': Timestamp.fromDate(m.createdAt),
      'isRead': false,
      'offlineOrigin': m.offlineOrigin,
      'reactions': {},
    }, SetOptions(merge: true));

    await batch.commit().timeout(const Duration(seconds: 5));
  }

  void dispose() {
    _incomingSub?.cancel();
    _ackSub?.cancel();
    _periodicSyncTimer?.cancel();
  }
}
