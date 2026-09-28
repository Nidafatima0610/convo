import 'package:cloud_firestore/cloud_firestore.dart';

class ConversationModel {
  const ConversationModel({
    required this.id,
    required this.participants,
    required this.participantDetails,
    this.lastMessage = '',
    required this.lastMessageAt,
    this.lastMessageSenderId = '',
    this.unreadCounts = const {},
    this.mood,
    this.disappearingDuration,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final List<String> participants;
  final Map<String, Map<String, dynamic>> participantDetails;
  final String lastMessage;
  final DateTime lastMessageAt;
  final String lastMessageSenderId;
  final Map<String, int> unreadCounts;
  final Map<String, dynamic>? mood;
  final int?
  disappearingDuration; // Duration in seconds (e.g. 60, 3600) or null if off
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasMood => mood != null;
  String? get moodEmoji => mood?['emoji'] as String?;
  String? get moodLabel => mood?['label'] as String?;
  bool get isDisappearingActive =>
      disappearingDuration != null && disappearingDuration! > 0;

  /// Generates a deterministic conversation ID for two users.
  static String getConversationId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  /// Returns the other participant's UID given the current user's UID.
  String otherParticipantId(String currentUserId) {
    return participants.firstWhere(
      (uid) => uid != currentUserId,
      orElse: () => '',
    );
  }

  /// Returns the other participant's display name.
  String otherParticipantName(String currentUserId) {
    final otherId = otherParticipantId(currentUserId);
    final details = participantDetails[otherId];
    return details?['name'] as String? ?? 'CONVO User';
  }

  /// Returns the other participant's email.
  String otherParticipantEmail(String currentUserId) {
    final otherId = otherParticipantId(currentUserId);
    final details = participantDetails[otherId];
    return details?['email'] as String? ?? '';
  }

  /// Returns the other participant's photo URL if available.
  String? otherParticipantPhoto(String currentUserId) {
    final otherId = otherParticipantId(currentUserId);
    final details = participantDetails[otherId];
    return details?['photoUrl'] as String?;
  }

  /// Returns unread message count for the current user.
  int unreadCountFor(String currentUserId) {
    return unreadCounts[currentUserId] ?? 0;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'participants': participants,
      'participantDetails': participantDetails,
      'lastMessage': lastMessage,
      'lastMessageAt': Timestamp.fromDate(lastMessageAt),
      'lastMessageSenderId': lastMessageSenderId,
      'unreadCounts': unreadCounts,
      'mood': mood,
      'disappearingDuration': disappearingDuration,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory ConversationModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      } else if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      return DateTime.now();
    }

    final rawParticipants = map['participants'];
    final participants = rawParticipants is List
        ? rawParticipants.map((e) => e.toString()).toList()
        : <String>[];

    final rawDetails = map['participantDetails'];
    final participantDetails = <String, Map<String, dynamic>>{};
    if (rawDetails is Map) {
      rawDetails.forEach((key, val) {
        if (val is Map) {
          participantDetails[key.toString()] = Map<String, dynamic>.from(val);
        }
      });
    }

    final rawUnread = map['unreadCounts'];
    final unreadCounts = <String, int>{};
    if (rawUnread is Map) {
      rawUnread.forEach((key, val) {
        if (val is num) {
          unreadCounts[key.toString()] = val.toInt();
        }
      });
    }

    final rawMood = map['mood'];
    final mood = rawMood is Map ? Map<String, dynamic>.from(rawMood) : null;
    final disappearingDuration = (map['disappearingDuration'] as num?)?.toInt();

    return ConversationModel(
      id: docId ?? map['id'] as String? ?? '',
      participants: participants,
      participantDetails: participantDetails,
      lastMessage: map['lastMessage'] as String? ?? '',
      lastMessageAt: parseDate(map['lastMessageAt']),
      lastMessageSenderId: map['lastMessageSenderId'] as String? ?? '',
      unreadCounts: unreadCounts,
      mood: mood,
      disappearingDuration: disappearingDuration,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  factory ConversationModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return ConversationModel.fromMap(doc.data() ?? {}, docId: doc.id);
  }

  ConversationModel copyWith({
    String? id,
    List<String>? participants,
    Map<String, Map<String, dynamic>>? participantDetails,
    String? lastMessage,
    DateTime? lastMessageAt,
    String? lastMessageSenderId,
    Map<String, int>? unreadCounts,
    Map<String, dynamic>? mood,
    int? disappearingDuration,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ConversationModel(
      id: id ?? this.id,
      participants: participants ?? this.participants,
      participantDetails: participantDetails ?? this.participantDetails,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      unreadCounts: unreadCounts ?? this.unreadCounts,
      mood: mood ?? this.mood,
      disappearingDuration: disappearingDuration ?? this.disappearingDuration,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
