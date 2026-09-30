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
    this.type = 'direct',
    this.name,
    this.photoUrl,
    this.description,
    this.createdBy,
    this.admins = const [],
    this.mutedBy = const [],
    this.typing = const {},
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
  final int? disappearingDuration; // Duration in seconds (e.g. 60, 3600) or null if off
  final String type; // 'direct' or 'group'
  final String? name; // Group name
  final String? photoUrl; // Group DP
  final String? description; // Group description / about
  final String? createdBy; // Creator user UID
  final List<String> admins; // Admin user UIDs
  final List<String> mutedBy; // User UIDs who muted notifications
  final Map<String, dynamic> typing; // Maps userId -> bool or Timestamp
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isGroup => type == 'group' || (name != null && name!.isNotEmpty);
  bool get hasMood => mood != null;
  String? get moodEmoji => mood?['emoji'] as String?;
  String? get moodLabel => mood?['label'] as String?;
  bool get isDisappearingActive =>
      disappearingDuration != null && disappearingDuration! > 0;

  bool isAdmin(String userId) => admins.contains(userId) || createdBy == userId;
  bool isMutedFor(String userId) => mutedBy.contains(userId);

  /// Returns list of user IDs currently typing (excluding given userId)
  List<String> typingUsers(String currentUserId) {
    final list = <String>[];
    final now = DateTime.now();
    typing.forEach((uid, val) {
      if (uid == currentUserId) return;
      if (val == true) {
        list.add(uid);
      } else if (val is Timestamp) {
        if (now.difference(val.toDate()).inSeconds < 10) {
          list.add(uid);
        }
      }
    });
    return list;
  }

  String memberName(String userId) =>
      participantDetails[userId]?['name'] as String? ?? 'CONVO User';

  String? memberPhoto(String userId) =>
      participantDetails[userId]?['photoUrl'] as String?;

  String? memberEmail(String userId) =>
      participantDetails[userId]?['email'] as String?;

  /// Generates a deterministic conversation ID for two users.
  static String getConversationId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  /// Returns the other participant's UID given the current user's UID (for direct chat).
  String otherParticipantId(String currentUserId) {
    return participants.firstWhere(
      (uid) => uid != currentUserId,
      orElse: () => '',
    );
  }

  /// Returns conversation display name (Group name for groups, or other participant name for 1-to-1).
  String otherParticipantName(String currentUserId) {
    if (isGroup) {
      return name?.trim().isNotEmpty == true ? name! : 'Group Chat';
    }
    final otherId = otherParticipantId(currentUserId);
    final details = participantDetails[otherId];
    return details?['name'] as String? ?? 'CONVO User';
  }

  /// Returns other participant email or member count string for groups.
  String otherParticipantEmail(String currentUserId) {
    if (isGroup) {
      return '${participants.length} members';
    }
    final otherId = otherParticipantId(currentUserId);
    final details = participantDetails[otherId];
    return details?['email'] as String? ?? '';
  }

  /// Returns conversation photo URL (Group photo for groups, or other participant photo for 1-to-1).
  String? otherParticipantPhoto(String currentUserId) {
    if (isGroup) {
      return photoUrl;
    }
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
      'type': type,
      if (name != null) 'name': name,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (description != null) 'description': description,
      if (createdBy != null) 'createdBy': createdBy,
      'admins': admins,
      'mutedBy': mutedBy,
      'typing': typing,
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

    final rawAdmins = map['admins'];
    final admins = rawAdmins is List
        ? rawAdmins.map((e) => e.toString()).toList()
        : <String>[];

    final rawMuted = map['mutedBy'];
    final mutedBy = rawMuted is List
        ? rawMuted.map((e) => e.toString()).toList()
        : <String>[];

    final rawMood = map['mood'];
    final mood = rawMood is Map ? Map<String, dynamic>.from(rawMood) : null;
    final disappearingDuration = (map['disappearingDuration'] as num?)?.toInt();

    final rawTyping = map['typing'];
    final typing = rawTyping is Map ? Map<String, dynamic>.from(rawTyping) : <String, dynamic>{};

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
      type: map['type'] as String? ?? 'direct',
      name: map['name'] as String?,
      photoUrl: map['photoUrl'] as String?,
      description: map['description'] as String?,
      createdBy: map['createdBy'] as String?,
      admins: admins,
      mutedBy: mutedBy,
      typing: typing,
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
    String? type,
    String? name,
    String? photoUrl,
    String? description,
    String? createdBy,
    List<String>? admins,
    List<String>? mutedBy,
    Map<String, dynamic>? typing,
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
      type: type ?? this.type,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
      admins: admins ?? this.admins,
      mutedBy: mutedBy ?? this.mutedBy,
      typing: typing ?? this.typing,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
