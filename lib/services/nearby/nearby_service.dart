import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../features/nearby/domain/models/nearby_device.dart';
import '../../features/nearby/domain/models/queued_message.dart';

enum NearbyServiceStatus { disabled, searching, connected, error }

class NearbyService {
  NearbyService();

  static const String _serviceId = 'com.convo.nearby.mesh';
  static const Strategy _strategy = Strategy.P2P_CLUSTER;
  static const String _protocolVersion = 'convo-offline-v1';

  final Nearby _nearby = Nearby();

  bool _isEnabled = false;
  bool get isEnabled => _isEnabled;

  String _currentUserId = '';
  String _currentDisplayName = 'Anonymous';
  String _currentInitials = '?';

  final Map<String, NearbyDevice> _discoveredMap = {};
  final Map<String, NearbyDevice> _connectedMap = {};

  final _statusController = StreamController<NearbyServiceStatus>.broadcast();
  final _discoveredController =
      StreamController<List<NearbyDevice>>.broadcast();
  final _connectedController = StreamController<List<NearbyDevice>>.broadcast();
  final _incomingMessageController =
      StreamController<QueuedMessage>.broadcast();
  final _messageAckController = StreamController<String>.broadcast();

  Stream<NearbyServiceStatus> get statusStream => _statusController.stream;
  Stream<List<NearbyDevice>> get discoveredDevicesStream =>
      _discoveredController.stream;
  Stream<List<NearbyDevice>> get connectedDevicesStream =>
      _connectedController.stream;
  Stream<QueuedMessage> get incomingMessageStream =>
      _incomingMessageController.stream;
  Stream<String> get messageAckStream => _messageAckController.stream;

  List<NearbyDevice> get discoveredDevices => _discoveredMap.values.toList();
  List<NearbyDevice> get connectedDevices => _connectedMap.values.toList();

  bool isConnectedToUser(String targetUserId) {
    return _connectedMap.values.any((d) => d.userId == targetUserId);
  }

  String? getEndpointIdForUser(String targetUserId) {
    for (final entry in _connectedMap.entries) {
      if (entry.value.userId == targetUserId) {
        return entry.key;
      }
    }
    return null;
  }

  /// Checks and requests runtime Bluetooth and Location permissions for Nearby Connections.
  Future<bool> checkAndRequestPermissions() async {
    try {
      if (defaultTargetPlatform != TargetPlatform.android) {
        return true; // Graceful fallback on non-Android platforms
      }

      final permissions = [
        Permission.location,
        Permission.bluetoothScan,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
      ];

      final statuses = await permissions.request();
      final allGranted = statuses.values.every(
        (s) => s.isGranted || s.isLimited,
      );
      return allGranted;
    } catch (e) {
      debugPrint('Notice requesting nearby permissions: $e');
      return true;
    }
  }

  /// Enables Nearby Discovery & Advertising.
  Future<bool> enableNearby({
    required String userId,
    required String displayName,
    required String avatarInitials,
  }) async {
    final granted = await checkAndRequestPermissions();
    if (!granted) {
      _statusController.add(NearbyServiceStatus.error);
      return false;
    }

    _currentUserId = userId;
    _currentDisplayName = displayName.trim().isNotEmpty
        ? displayName
        : 'CONVO Peer';
    _currentInitials = avatarInitials;

    try {
      await disableNearby(); // Reset any existing session

      _isEnabled = true;
      _discoveredMap.clear();
      _connectedMap.clear();
      _statusController.add(NearbyServiceStatus.searching);
      _notifyDeviceLists();

      // 1. Start Advertising so peers can discover this device
      await _nearby.startAdvertising(
        _currentDisplayName,
        _strategy,
        onConnectionInitiated: _handleConnectionInitiated,
        onConnectionResult: _handleConnectionResult,
        onDisconnected: _handleDisconnected,
        serviceId: _serviceId,
      );

      // 2. Start Discovery to find other nearby peers
      await _nearby.startDiscovery(
        _currentDisplayName,
        _strategy,
        onEndpointFound: (endpointId, endpointName, serviceId) {
          debugPrint('Discovered peer endpoint: $endpointId ($endpointName)');
          _discoveredMap[endpointId] = NearbyDevice(
            endpointId: endpointId,
            displayName: endpointName,
            status: NearbyDeviceStatus.discovered,
            lastSeen: DateTime.now(),
          );
          _notifyDeviceLists();
        },
        onEndpointLost: (endpointId) {
          debugPrint('Lost peer endpoint: $endpointId');
          _discoveredMap.remove(endpointId);
          _notifyDeviceLists();
        },
        serviceId: _serviceId,
      );

      return true;
    } catch (e) {
      debugPrint('Error enabling Nearby Connections: $e');
      _statusController.add(NearbyServiceStatus.error);
      return false;
    }
  }

  /// Disables Nearby mode and terminates all active connections.
  Future<void> disableNearby() async {
    _isEnabled = false;
    try {
      await _nearby.stopAdvertising();
      await _nearby.stopDiscovery();
      await _nearby.stopAllEndpoints();
    } catch (e) {
      debugPrint('Notice stopping nearby endpoints: $e');
    }
    _discoveredMap.clear();
    _connectedMap.clear();
    _statusController.add(NearbyServiceStatus.disabled);
    _notifyDeviceLists();
  }

  /// Initiates connection request to a discovered peer.
  Future<bool> connectToDevice(NearbyDevice device) async {
    try {
      _discoveredMap[device.endpointId] = device.copyWith(
        status: NearbyDeviceStatus.connecting,
        isOutgoing: true,
      );
      _notifyDeviceLists();

      return await _nearby.requestConnection(
        _currentDisplayName,
        device.endpointId,
        onConnectionInitiated: _handleConnectionInitiated,
        onConnectionResult: _handleConnectionResult,
        onDisconnected: _handleDisconnected,
      );
    } catch (e) {
      debugPrint('Error connecting to nearby device: $e');
      _discoveredMap[device.endpointId] = device.copyWith(
        status: NearbyDeviceStatus.discovered,
      );
      _notifyDeviceLists();
      return false;
    }
  }

  /// Disconnects from a specific peer endpoint.
  Future<void> disconnectFromDevice(String endpointId) async {
    try {
      await _nearby.disconnectFromEndpoint(endpointId);
      _handleDisconnected(endpointId);
    } catch (e) {
      debugPrint('Error disconnecting from endpoint $endpointId: $e');
    }
  }

  /// Sends an offline chat message directly to a connected peer.
  Future<bool> sendOfflineMessage({
    required String endpointId,
    required QueuedMessage message,
  }) async {
    try {
      final payload = {
        'type': 'chat_message',
        'version': _protocolVersion,
        'message': message.toMap(),
      };

      final jsonStr = jsonEncode(payload);
      final bytes = Uint8List.fromList(utf8.encode(jsonStr));

      await _nearby.sendBytesPayload(endpointId, bytes);
      return true;
    } catch (e) {
      debugPrint('Error sending offline message: $e');
      return false;
    }
  }

  // --- Internal Handlers ---

  void _handleConnectionInitiated(
    String endpointId,
    ConnectionInfo connectionInfo,
  ) async {
    debugPrint(
      'Connection initiated with $endpointId (${connectionInfo.endpointName})',
    );

    try {
      // Auto-accept connection after mutual user intent
      await _nearby.acceptConnection(
        endpointId,
        onPayLoadRecieved: (epId, payload) {
          if (payload.type == PayloadType.BYTES && payload.bytes != null) {
            _handleReceivedBytes(epId, payload.bytes!);
          }
        },
      );
    } catch (e) {
      debugPrint('Error accepting connection: $e');
    }
  }

  void _handleConnectionResult(String endpointId, Status status) async {
    debugPrint('Connection result for $endpointId: $status');

    if (status == Status.CONNECTED) {
      final existing = _discoveredMap[endpointId];
      final connectedDevice =
          (existing ??
                  NearbyDevice(
                    endpointId: endpointId,
                    displayName: 'Peer',
                    lastSeen: DateTime.now(),
                  ))
              .copyWith(status: NearbyDeviceStatus.connected);

      _connectedMap[endpointId] = connectedDevice;
      _discoveredMap.remove(endpointId);
      _statusController.add(NearbyServiceStatus.connected);
      _notifyDeviceLists();

      // Send Handshake
      _sendHandshake(endpointId);
    } else {
      _connectedMap.remove(endpointId);
      final existing = _discoveredMap[endpointId];
      if (existing != null) {
        _discoveredMap[endpointId] = existing.copyWith(
          status: NearbyDeviceStatus.discovered,
        );
      }
      _notifyDeviceLists();
    }
  }

  void _handleDisconnected(String endpointId) {
    debugPrint('Endpoint disconnected: $endpointId');
    _connectedMap.remove(endpointId);
    if (_connectedMap.isEmpty) {
      _statusController.add(
        _isEnabled
            ? NearbyServiceStatus.searching
            : NearbyServiceStatus.disabled,
      );
    }
    _notifyDeviceLists();
  }

  void _sendHandshake(String endpointId) {
    try {
      final handshake = {
        'type': 'handshake',
        'version': _protocolVersion,
        'userId': _currentUserId,
        'displayName': _currentDisplayName,
        'avatarInitials': _currentInitials,
      };
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode(handshake)));
      _nearby.sendBytesPayload(endpointId, bytes);
    } catch (e) {
      debugPrint('Error sending handshake: $e');
    }
  }

  void _sendHandshakeAck(String endpointId) {
    try {
      final ack = {
        'type': 'handshake_ack',
        'version': _protocolVersion,
        'userId': _currentUserId,
        'displayName': _currentDisplayName,
        'avatarInitials': _currentInitials,
      };
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode(ack)));
      _nearby.sendBytesPayload(endpointId, bytes);
    } catch (e) {
      debugPrint('Error sending handshake ack: $e');
    }
  }

  void _handleReceivedBytes(String endpointId, Uint8List bytes) {
    try {
      final jsonStr = utf8.decode(bytes);
      final data = jsonDecode(jsonStr);
      if (data is! Map<String, dynamic>) return;

      final type = data['type'] as String?;
      final version = data['version'] as String?;

      // Validate Protocol Version
      if (version != _protocolVersion) {
        debugPrint('Rejected incompatible nearby peer protocol: $version');
        return;
      }

      if (type == 'handshake') {
        final peerUserId = data['userId'] as String? ?? '';
        final peerName = data['displayName'] as String? ?? 'Peer';
        final peerInitials = data['avatarInitials'] as String? ?? '?';

        if (_connectedMap.containsKey(endpointId)) {
          _connectedMap[endpointId] = _connectedMap[endpointId]!.copyWith(
            userId: peerUserId,
            displayName: peerName,
            avatarInitials: peerInitials,
          );
          _notifyDeviceLists();
        }
        _sendHandshakeAck(endpointId);
      } else if (type == 'handshake_ack') {
        final peerUserId = data['userId'] as String? ?? '';
        final peerName = data['displayName'] as String? ?? 'Peer';
        final peerInitials = data['avatarInitials'] as String? ?? '?';

        if (_connectedMap.containsKey(endpointId)) {
          _connectedMap[endpointId] = _connectedMap[endpointId]!.copyWith(
            userId: peerUserId,
            displayName: peerName,
            avatarInitials: peerInitials,
          );
          _notifyDeviceLists();
        }
      } else if (type == 'chat_message') {
        final msgData = data['message'];
        if (msgData is Map<String, dynamic>) {
          final message = QueuedMessage.fromMap(msgData);
          _incomingMessageController.add(message);

          // Send back delivery ACK
          _sendDeliveryAck(endpointId, message.localMessageId);
        }
      } else if (type == 'message_ack') {
        final localMessageId = data['localMessageId'] as String?;
        if (localMessageId != null && localMessageId.isNotEmpty) {
          _messageAckController.add(localMessageId);
        }
      }
    } catch (e) {
      debugPrint('Error processing nearby payload: $e');
    }
  }

  void _sendDeliveryAck(String endpointId, String localMessageId) {
    try {
      final ack = {
        'type': 'message_ack',
        'version': _protocolVersion,
        'localMessageId': localMessageId,
      };
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode(ack)));
      _nearby.sendBytesPayload(endpointId, bytes);
    } catch (e) {
      debugPrint('Error sending delivery ack: $e');
    }
  }

  void _notifyDeviceLists() {
    _discoveredController.add(List.unmodifiable(_discoveredMap.values));
    _connectedController.add(List.unmodifiable(_connectedMap.values));
  }

  void dispose() {
    disableNearby();
    _statusController.close();
    _discoveredController.close();
    _connectedController.close();
    _incomingMessageController.close();
    _messageAckController.close();
  }
}
