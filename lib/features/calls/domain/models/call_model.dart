import 'package:cloud_firestore/cloud_firestore.dart';

enum CallType {
  voice,
  video;

  static CallType fromString(String? type) {
    if (type == 'video') return CallType.video;
    return CallType.voice;
  }

  String toValue() => name;
}

enum CallStatus {
  ringing,
  accepted,
  rejected,
  missed,
  ended;

  static CallStatus fromString(String? status) {
    switch (status) {
      case 'accepted':
        return CallStatus.accepted;
      case 'rejected':
        return CallStatus.rejected;
      case 'missed':
        return CallStatus.missed;
      case 'ended':
        return CallStatus.ended;
      case 'ringing':
      default:
        return CallStatus.ringing;
    }
  }

  String toValue() => name;
}

class CallModel {
  const CallModel({
    required this.callId,
    required this.callerId,
    required this.callerName,
    this.callerPhoto,
    required this.receiverId,
    required this.receiverName,
    this.receiverPhoto,
    required this.type,
    required this.status,
    required this.participants,
    this.offer,
    this.answer,
    required this.createdAt,
    this.startedAt,
    this.endedAt,
    this.duration = 0,
  });

  final String callId;
  final String callerId;
  final String callerName;
  final String? callerPhoto;
  final String receiverId;
  final String receiverName;
  final String? receiverPhoto;
  final CallType type;
  final CallStatus status;
  final List<String> participants;
  final Map<String, dynamic>? offer;
  final Map<String, dynamic>? answer;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int duration; // in seconds

  bool get isVoice => type == CallType.voice;
  bool get isVideo => type == CallType.video;

  bool get isRinging => status == CallStatus.ringing;
  bool get isAccepted => status == CallStatus.accepted;
  bool get isRejected => status == CallStatus.rejected;
  bool get isMissed => status == CallStatus.missed;
  bool get isEnded => status == CallStatus.ended;

  bool isCaller(String currentUserId) => callerId == currentUserId;

  String otherUserId(String currentUserId) {
    return isCaller(currentUserId) ? receiverId : callerId;
  }

  String otherUserName(String currentUserId) {
    return isCaller(currentUserId) ? receiverName : callerName;
  }

  String? otherUserPhoto(String currentUserId) {
    return isCaller(currentUserId) ? receiverPhoto : callerPhoto;
  }

  factory CallModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return CallModel.fromMap(data, id: doc.id);
  }

  factory CallModel.fromMap(Map<String, dynamic> data, {String? id}) {
    DateTime parseTimestamp(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }
      return DateTime.now();
    }

    DateTime? parseNullableTimestamp(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    final callerId = data['callerId'] as String? ?? '';
    final receiverId = data['receiverId'] as String? ?? '';

    final rawParticipants = data['participants'];
    final List<String> participants = rawParticipants is List
        ? rawParticipants.map((e) => e.toString()).toList()
        : [callerId, receiverId].where((id) => id.isNotEmpty).toList();

    return CallModel(
      callId: id ?? data['callId'] as String? ?? '',
      callerId: callerId,
      callerName: data['callerName'] as String? ?? 'User',
      callerPhoto: data['callerPhoto'] as String?,
      receiverId: receiverId,
      receiverName: data['receiverName'] as String? ?? 'User',
      receiverPhoto: data['receiverPhoto'] as String?,
      type: CallType.fromString(data['type'] as String?),
      status: CallStatus.fromString(data['status'] as String?),
      participants: participants,
      offer: data['offer'] != null
          ? Map<String, dynamic>.from(data['offer'] as Map)
          : null,
      answer: data['answer'] != null
          ? Map<String, dynamic>.from(data['answer'] as Map)
          : null,
      createdAt: parseTimestamp(data['createdAt']),
      startedAt: parseNullableTimestamp(data['startedAt']),
      endedAt: parseNullableTimestamp(data['endedAt']),
      duration: (data['duration'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'callId': callId,
      'callerId': callerId,
      'callerName': callerName,
      'callerPhoto': callerPhoto,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverPhoto': receiverPhoto,
      'type': type.toValue(),
      'status': status.toValue(),
      'participants': participants,
      if (offer != null) 'offer': offer,
      if (answer != null) 'answer': answer,
      'createdAt': Timestamp.fromDate(createdAt),
      if (startedAt != null) 'startedAt': Timestamp.fromDate(startedAt!),
      if (endedAt != null) 'endedAt': Timestamp.fromDate(endedAt!),
      'duration': duration,
    };
  }

  CallModel copyWith({
    String? callId,
    String? callerId,
    String? callerName,
    String? callerPhoto,
    String? receiverId,
    String? receiverName,
    String? receiverPhoto,
    CallType? type,
    CallStatus? status,
    List<String>? participants,
    Map<String, dynamic>? offer,
    Map<String, dynamic>? answer,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? endedAt,
    int? duration,
  }) {
    return CallModel(
      callId: callId ?? this.callId,
      callerId: callerId ?? this.callerId,
      callerName: callerName ?? this.callerName,
      callerPhoto: callerPhoto ?? this.callerPhoto,
      receiverId: receiverId ?? this.receiverId,
      receiverName: receiverName ?? this.receiverName,
      receiverPhoto: receiverPhoto ?? this.receiverPhoto,
      type: type ?? this.type,
      status: status ?? this.status,
      participants: participants ?? this.participants,
      offer: offer ?? this.offer,
      answer: answer ?? this.answer,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      duration: duration ?? this.duration,
    );
  }
}
