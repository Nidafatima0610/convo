import '../../../chats/domain/models/message_model.dart';

enum DeliveryState {
  queued,
  sending,
  deliveredNearby,
  synced,
  failed;

  static DeliveryState fromString(String? val) {
    switch (val) {
      case 'sending':
        return DeliveryState.sending;
      case 'deliveredNearby':
        return DeliveryState.deliveredNearby;
      case 'synced':
        return DeliveryState.synced;
      case 'failed':
        return DeliveryState.failed;
      case 'queued':
      default:
        return DeliveryState.queued;
    }
  }

  String toValue() => name;
}

class QueuedMessage {
  const QueuedMessage({
    required this.localMessageId,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    required this.text,
    this.type = 'text',
    required this.createdAt,
    this.deliveryState = DeliveryState.queued,
    this.offlineOrigin = true,
    this.retryCount = 0,
  });

  final String localMessageId;
  final String conversationId;
  final String senderId;
  final String receiverId;
  final String text;
  final String type;
  final DateTime createdAt;
  final DeliveryState deliveryState;
  final bool offlineOrigin;
  final int retryCount;

  bool get isQueued => deliveryState == DeliveryState.queued;
  bool get isDeliveredNearby => deliveryState == DeliveryState.deliveredNearby;
  bool get isSynced => deliveryState == DeliveryState.synced;
  bool get isFailed => deliveryState == DeliveryState.failed;

  MessageModel toMessageModel() {
    return MessageModel(
      id: localMessageId,
      conversationId: conversationId,
      senderId: senderId,
      receiverId: receiverId,
      text: text,
      type: type,
      createdAt: createdAt,
      isRead: false,
      offlineOrigin: offlineOrigin,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'localMessageId': localMessageId,
      'conversationId': conversationId,
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'type': type,
      'createdAt': createdAt.toIso8601String(),
      'deliveryState': deliveryState.toValue(),
      'offlineOrigin': offlineOrigin,
      'retryCount': retryCount,
    };
  }

  factory QueuedMessage.fromMap(Map<String, dynamic> map) {
    return QueuedMessage(
      localMessageId: map['localMessageId'] as String? ?? '',
      conversationId: map['conversationId'] as String? ?? '',
      senderId: map['senderId'] as String? ?? '',
      receiverId: map['receiverId'] as String? ?? '',
      text: map['text'] as String? ?? '',
      type: map['type'] as String? ?? 'text',
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      deliveryState: DeliveryState.fromString(map['deliveryState'] as String?),
      offlineOrigin: map['offlineOrigin'] as bool? ?? true,
      retryCount: (map['retryCount'] as num?)?.toInt() ?? 0,
    );
  }

  QueuedMessage copyWith({
    String? localMessageId,
    String? conversationId,
    String? senderId,
    String? receiverId,
    String? text,
    String? type,
    DateTime? createdAt,
    DeliveryState? deliveryState,
    bool? offlineOrigin,
    int? retryCount,
  }) {
    return QueuedMessage(
      localMessageId: localMessageId ?? this.localMessageId,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      text: text ?? this.text,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      deliveryState: deliveryState ?? this.deliveryState,
      offlineOrigin: offlineOrigin ?? this.offlineOrigin,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}
