import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/auth/domain/models/convo_user.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
    : _customFirestore = firestore;

  final FirebaseFirestore? _customFirestore;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  DateTime? _lastPresenceWrittenTime;
  bool? _lastPresenceOnline;

  /// Creates or updates a user document in `users/{uid}` using the UID as document ID.
  Future<void> createUserProfile(ConvoUser user) async {
    await _usersRef.doc(user.uid).set(user.toMap(), SetOptions(merge: true));
  }

  /// Fetches a user document from `users/{uid}`.
  Future<ConvoUser?> getUserProfile(String uid) async {
    final doc = await _usersRef.doc(uid).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }
    return ConvoUser.fromFirestore(doc);
  }

  /// Real-time stream of the user document in `users/{uid}`.
  Stream<ConvoUser?> userProfileStream(String uid) {
    try {
      return _usersRef.doc(uid).snapshots().map((snapshot) {
        if (!snapshot.exists || snapshot.data() == null) {
          return null;
        }
        return ConvoUser.fromFirestore(snapshot);
      });
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Updates online presence in `users/{uid}` with throttling to prevent excessive Firestore writes.
  Future<void> updateUserOnlineStatus(
    String uid,
    bool isOnline, {
    bool force = false,
  }) async {
    final now = DateTime.now();
    if (!force &&
        _lastPresenceOnline == isOnline &&
        _lastPresenceWrittenTime != null &&
        now.difference(_lastPresenceWrittenTime!).inSeconds < 30) {
      return;
    }
    _lastPresenceOnline = isOnline;
    _lastPresenceWrittenTime = now;

    try {
      final updates = <String, dynamic>{
        'isOnline': isOnline,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (!isOnline) {
        updates['lastSeen'] = FieldValue.serverTimestamp();
      }
      await _usersRef.doc(uid).update(updates);
    } catch (_) {
      // Non-critical presence update error
    }
  }

  /// Updates user profile details (name, photoUrl, bio).
  Future<void> updateUserProfile({
    required String uid,
    String? name,
    String? photoUrl,
    String? bio,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (name != null) updates['name'] = name.trim();
    if (photoUrl != null) updates['photoUrl'] = photoUrl;
    if (bio != null) updates['bio'] = bio.trim();

    await _usersRef.doc(uid).update(updates);
  }

  /// Updates only the user's bio/about.
  Future<void> updateUserBio(String uid, String bio) async {
    await _usersRef.doc(uid).update({
      'bio': bio.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Updates or removes the user's profile picture.
  Future<void> updateUserProfilePicture(String uid, String? photoUrl) async {
    await _usersRef.doc(uid).update({
      'photoUrl': photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Updates user privacy settings.
  Future<void> updatePrivacySettings(
    String uid,
    Map<String, dynamic> privacySettings,
  ) async {
    await _usersRef.doc(uid).update({
      'privacySettings': privacySettings,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Updates user notification settings.
  Future<void> updateNotificationSettings(
    String uid,
    Map<String, dynamic> notificationSettings,
  ) async {
    await _usersRef.doc(uid).update({
      'notificationSettings': notificationSettings,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Updates the FCM device registration token for push notifications.
  Future<void> updateFcmToken(String uid, String token) async {
    try {
      await _usersRef.doc(uid).set({
        'fcmToken': token,
        'fcmUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Non-critical
    }
  }

  /// Blocks another user by appending their UID to `blockedUsers`.
  Future<void> blockUser(String currentUserId, String targetUserId) async {
    await _usersRef.doc(currentUserId).update({
      'blockedUsers': FieldValue.arrayUnion([targetUserId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Unblocks a user by removing their UID from `blockedUsers`.
  Future<void> unblockUser(String currentUserId, String targetUserId) async {
    await _usersRef.doc(currentUserId).update({
      'blockedUsers': FieldValue.arrayRemove([targetUserId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
