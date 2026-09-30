import 'package:cloud_firestore/cloud_firestore.dart';

class ConvoUser {
  const ConvoUser({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl,
    this.bio,
    this.lastSeen,
    this.fcmToken,
    this.blockedUsers = const [],
    this.privacySettings = const {
      'lastSeen': 'everyone',
      'online': 'everyone',
      'photo': 'everyone',
      'bio': 'everyone',
    },
    this.notificationSettings = const {
      'enabled': true,
      'preview': true,
      'sound': true,
    },
    required this.createdAt,
    required this.updatedAt,
    this.isOnline = true,
  });

  final String uid;
  final String name;
  final String email;
  final String? photoUrl;
  final String? bio;
  final DateTime? lastSeen;
  final String? fcmToken;
  final List<String> blockedUsers;
  final Map<String, dynamic> privacySettings;
  final Map<String, dynamic> notificationSettings;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isOnline;

  String get effectiveBio =>
      (bio != null && bio!.trim().isNotEmpty)
          ? bio!.trim()
          : 'Hey there! I am using CONVO.';

  String get lastSeenPrivacy =>
      (privacySettings['lastSeen'] as String?) ?? 'everyone';

  String get onlinePrivacy =>
      (privacySettings['online'] as String?) ?? 'everyone';

  String get photoPrivacy =>
      (privacySettings['photo'] as String?) ?? 'everyone';

  String get bioPrivacy =>
      (privacySettings['bio'] as String?) ?? 'everyone';

  bool get notificationsEnabled =>
      (notificationSettings['enabled'] as bool?) ?? true;

  bool get notificationPreviewsEnabled =>
      (notificationSettings['preview'] as bool?) ?? true;

  bool get notificationSoundEnabled =>
      (notificationSettings['sound'] as bool?) ?? true;

  bool isUserBlocked(String userId) => blockedUsers.contains(userId);

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'bio': bio,
      'lastSeen': lastSeen != null ? Timestamp.fromDate(lastSeen!) : null,
      'fcmToken': fcmToken,
      'blockedUsers': blockedUsers,
      'privacySettings': privacySettings,
      'notificationSettings': notificationSettings,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isOnline': isOnline,
    };
  }

  factory ConvoUser.fromMap(Map<String, dynamic> map, {String? docId}) {
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

    DateTime? parseNullableDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      return null;
    }

    List<String> parseStringList(dynamic value) {
      if (value is List) {
        return value.map((e) => e.toString()).toList();
      }
      return const [];
    }

    Map<String, dynamic> parseMap(
      dynamic value,
      Map<String, dynamic> fallback,
    ) {
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
      return fallback;
    }

    return ConvoUser(
      uid: docId ?? map['uid'] as String? ?? '',
      name: map['name'] as String? ?? 'CONVO User',
      email: map['email'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      bio: map['bio'] as String?,
      lastSeen: parseNullableDate(map['lastSeen']),
      fcmToken: map['fcmToken'] as String?,
      blockedUsers: parseStringList(map['blockedUsers']),
      privacySettings: parseMap(map['privacySettings'], const {
        'lastSeen': 'everyone',
        'online': 'everyone',
        'photo': 'everyone',
        'bio': 'everyone',
      }),
      notificationSettings: parseMap(map['notificationSettings'], const {
        'enabled': true,
        'preview': true,
        'sound': true,
      }),
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
      isOnline: map['isOnline'] as bool? ?? false,
    );
  }

  factory ConvoUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ConvoUser.fromMap(data, docId: doc.id);
  }

  ConvoUser copyWith({
    String? uid,
    String? name,
    String? email,
    String? photoUrl,
    String? bio,
    DateTime? lastSeen,
    String? fcmToken,
    List<String>? blockedUsers,
    Map<String, dynamic>? privacySettings,
    Map<String, dynamic>? notificationSettings,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isOnline,
  }) {
    return ConvoUser(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      bio: bio ?? this.bio,
      lastSeen: lastSeen ?? this.lastSeen,
      fcmToken: fcmToken ?? this.fcmToken,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      privacySettings: privacySettings ?? this.privacySettings,
      notificationSettings: notificationSettings ?? this.notificationSettings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  String get initials {
    if (name.trim().isEmpty) return 'CO';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
  }
}
