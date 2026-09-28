import 'package:cloud_firestore/cloud_firestore.dart';

enum CapsuleStatus {
  scheduled,
  locked,
  ready,
  opened,
  cancelled;

  static CapsuleStatus fromString(String? val) {
    switch (val) {
      case 'scheduled':
        return CapsuleStatus.scheduled;
      case 'locked':
        return CapsuleStatus.locked;
      case 'ready':
        return CapsuleStatus.ready;
      case 'opened':
        return CapsuleStatus.opened;
      case 'cancelled':
        return CapsuleStatus.cancelled;
      default:
        return CapsuleStatus.locked;
    }
  }

  String toValue() => name;
}

class CapsuleModel {
  const CapsuleModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.receiverId,
    required this.receiverName,
    required this.message,
    this.mediaUrl,
    required this.unlockAt,
    required this.createdAt,
    this.status = CapsuleStatus.locked,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String receiverId;
  final String receiverName;
  final String message;
  final String? mediaUrl;
  final DateTime unlockAt;
  final DateTime createdAt;
  final CapsuleStatus status;

  bool get isUnlocked => DateTime.now().isAfter(unlockAt);
  bool get isLocked => !isUnlocked && status != CapsuleStatus.cancelled;

  Duration get timeRemaining {
    final diff = unlockAt.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  String get countdownString {
    final diff = timeRemaining;
    if (diff == Duration.zero) {
      return 'Ready to open!';
    }
    if (diff.inDays > 0) {
      return '${diff.inDays}d ${diff.inHours % 24}h remaining';
    }
    if (diff.inHours > 0) {
      return '${diff.inHours}h ${diff.inMinutes % 60}m remaining';
    }
    return '${diff.inMinutes}m ${diff.inSeconds % 60}s remaining';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'senderName': senderName,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'message': message,
      'mediaUrl': mediaUrl,
      'unlockAt': Timestamp.fromDate(unlockAt),
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status.toValue(),
    };
  }

  factory CapsuleModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      return DateTime.now();
    }

    final unlock = parseDate(map['unlockAt']);
    final rawStatus = CapsuleStatus.fromString(map['status'] as String?);
    final computedStatus =
        (rawStatus != CapsuleStatus.cancelled &&
            rawStatus != CapsuleStatus.opened &&
            DateTime.now().isAfter(unlock))
        ? CapsuleStatus.ready
        : rawStatus;

    return CapsuleModel(
      id: docId ?? map['id'] as String? ?? '',
      conversationId: map['conversationId'] as String? ?? '',
      senderId: map['senderId'] as String? ?? '',
      senderName: map['senderName'] as String? ?? 'Sender',
      receiverId: map['receiverId'] as String? ?? '',
      receiverName: map['receiverName'] as String? ?? 'Receiver',
      message: map['message'] as String? ?? '',
      mediaUrl: map['mediaUrl'] as String?,
      unlockAt: unlock,
      createdAt: parseDate(map['createdAt']),
      status: computedStatus,
    );
  }

  CapsuleModel copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderName,
    String? receiverId,
    String? receiverName,
    String? message,
    String? mediaUrl,
    DateTime? unlockAt,
    DateTime? createdAt,
    CapsuleStatus? status,
  }) {
    return CapsuleModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      receiverId: receiverId ?? this.receiverId,
      receiverName: receiverName ?? this.receiverName,
      message: message ?? this.message,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      unlockAt: unlockAt ?? this.unlockAt,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
    );
  }
}
