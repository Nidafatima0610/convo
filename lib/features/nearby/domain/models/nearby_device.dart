enum NearbyDeviceStatus { discovered, connecting, connected, disconnected }

class NearbyDevice {
  const NearbyDevice({
    required this.endpointId,
    required this.displayName,
    this.userId,
    this.avatarInitials,
    this.status = NearbyDeviceStatus.discovered,
    this.connectionToken,
    this.isOutgoing = false,
    required this.lastSeen,
  });

  final String endpointId;
  final String displayName;
  final String? userId;
  final String? avatarInitials;
  final NearbyDeviceStatus status;
  final String? connectionToken;
  final bool isOutgoing;
  final DateTime lastSeen;

  bool get isConnected => status == NearbyDeviceStatus.connected;
  bool get isConnecting => status == NearbyDeviceStatus.connecting;

  NearbyDevice copyWith({
    String? endpointId,
    String? displayName,
    String? userId,
    String? avatarInitials,
    NearbyDeviceStatus? status,
    String? connectionToken,
    bool? isOutgoing,
    DateTime? lastSeen,
  }) {
    return NearbyDevice(
      endpointId: endpointId ?? this.endpointId,
      displayName: displayName ?? this.displayName,
      userId: userId ?? this.userId,
      avatarInitials: avatarInitials ?? this.avatarInitials,
      status: status ?? this.status,
      connectionToken: connectionToken ?? this.connectionToken,
      isOutgoing: isOutgoing ?? this.isOutgoing,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}
