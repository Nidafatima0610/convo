import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../services/local_storage/offline_queue_storage_service.dart';
import '../../../../services/nearby/nearby_service.dart';
import '../../../../services/nearby/offline_sync_service.dart';
import '../../../auth/domain/models/convo_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/models/nearby_device.dart';
import '../../domain/models/queued_message.dart';

final offlineQueueStorageServiceProvider = Provider<OfflineQueueStorageService>(
  (ref) {
    final service = OfflineQueueStorageService();
    ref.onDispose(service.dispose);
    return service;
  },
);

final nearbyServiceProvider = Provider<NearbyService>((ref) {
  final service = NearbyService();
  ref.onDispose(service.dispose);
  return service;
});

final offlineSyncServiceProvider = Provider<OfflineSyncService>((ref) {
  final queueStorage = ref.watch(offlineQueueStorageServiceProvider);
  final nearby = ref.watch(nearbyServiceProvider);
  final service = OfflineSyncService(
    queueStorage: queueStorage,
    nearbyService: nearby,
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Stream of queued offline messages.
final offlineQueueStreamProvider = StreamProvider<List<QueuedMessage>>((ref) {
  final storage = ref.watch(offlineQueueStorageServiceProvider);
  return storage.queueStream;
});

class NearbyState {
  const NearbyState({
    this.isEnabled = false,
    this.status = NearbyServiceStatus.disabled,
    this.discoveredDevices = const [],
    this.connectedDevices = const [],
    this.errorMessage,
  });

  final bool isEnabled;
  final NearbyServiceStatus status;
  final List<NearbyDevice> discoveredDevices;
  final List<NearbyDevice> connectedDevices;
  final String? errorMessage;

  bool get isSearching => status == NearbyServiceStatus.searching;
  bool get hasConnectedPeers => connectedDevices.isNotEmpty;

  NearbyState copyWith({
    bool? isEnabled,
    NearbyServiceStatus? status,
    List<NearbyDevice>? discoveredDevices,
    List<NearbyDevice>? connectedDevices,
    String? errorMessage,
  }) {
    return NearbyState(
      isEnabled: isEnabled ?? this.isEnabled,
      status: status ?? this.status,
      discoveredDevices: discoveredDevices ?? this.discoveredDevices,
      connectedDevices: connectedDevices ?? this.connectedDevices,
      errorMessage: errorMessage,
    );
  }
}

class NearbyController extends Notifier<NearbyState> {
  StreamSubscription<NearbyServiceStatus>? _statusSub;
  StreamSubscription<List<NearbyDevice>>? _discoveredSub;
  StreamSubscription<List<NearbyDevice>>? _connectedSub;

  @override
  NearbyState build() {
    final nearby = ref.watch(nearbyServiceProvider);

    _statusSub = nearby.statusStream.listen((status) {
      state = state.copyWith(
        status: status,
        isEnabled: status != NearbyServiceStatus.disabled,
      );
    });

    _discoveredSub = nearby.discoveredDevicesStream.listen((devices) {
      state = state.copyWith(discoveredDevices: devices);
    });

    _connectedSub = nearby.connectedDevicesStream.listen((devices) {
      state = state.copyWith(connectedDevices: devices);
      // Flush offline messages to any newly connected peer
      for (final device in devices) {
        if (device.userId != null && device.userId!.isNotEmpty) {
          ref
              .read(offlineSyncServiceProvider)
              .flushMessagesToConnectedPeer(device.userId!);
        }
      }
    });

    ref.onDispose(() {
      _statusSub?.cancel();
      _discoveredSub?.cancel();
      _connectedSub?.cancel();
    });

    return NearbyState(
      isEnabled: nearby.isEnabled,
      status: nearby.isEnabled
          ? NearbyServiceStatus.searching
          : NearbyServiceStatus.disabled,
      discoveredDevices: nearby.discoveredDevices,
      connectedDevices: nearby.connectedDevices,
    );
  }

  NearbyService get _nearby => ref.read(nearbyServiceProvider);

  /// Toggles Nearby discovery/advertising mode on or off.
  Future<bool> toggleNearby(bool enable) async {
    if (!enable) {
      await _nearby.disableNearby();
      state = state.copyWith(
        isEnabled: false,
        status: NearbyServiceStatus.disabled,
        discoveredDevices: const [],
        connectedDevices: const [],
      );
      return true;
    }

    final user = ref.read(currentUserProfileProvider).asData?.value;
    final userId = user?.uid ?? 'anon_${DateTime.now().millisecondsSinceEpoch}';
    final displayName = user?.name ?? 'CONVO User';
    final initials = displayName.isNotEmpty ? displayName.substring(0, 1) : '?';

    final success = await _nearby.enableNearby(
      userId: userId,
      displayName: displayName,
      avatarInitials: initials,
    );

    if (success) {
      state = state.copyWith(
        isEnabled: true,
        status: NearbyServiceStatus.searching,
        errorMessage: null,
      );
    } else {
      state = state.copyWith(
        isEnabled: false,
        status: NearbyServiceStatus.error,
        errorMessage:
            'Bluetooth or Location permission is required for Nearby mesh.',
      );
    }

    return success;
  }

  /// Explicit helper to enable Nearby mode.
  Future<bool> enableNearby([ConvoUser? user]) async {
    return toggleNearby(true);
  }

  /// Explicit helper to disable Nearby mode.
  Future<void> disableNearby() async {
    await toggleNearby(false);
  }

  /// Connects to a discovered nearby peer.
  Future<bool> connectToDevice(NearbyDevice device) async {
    return await _nearby.connectToDevice(device);
  }

  /// Disconnects from a connected peer.
  Future<void> disconnectDevice(String endpointId) async {
    await _nearby.disconnectFromDevice(endpointId);
  }

  /// Clears the local offline message queue.
  Future<void> clearOfflineQueue() async {
    await ref.read(offlineQueueStorageServiceProvider).clearQueue();
  }

  /// Triggers immediate synchronization with Firebase.
  Future<int> syncQueueWithFirebase() async {
    return await ref
        .read(offlineSyncServiceProvider)
        .syncQueuedMessagesWithFirebase();
  }
}

final nearbyControllerProvider =
    NotifierProvider<NearbyController, NearbyState>(NearbyController.new);
