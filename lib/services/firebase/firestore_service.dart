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

  /// Updates online presence in `users/{uid}`.
  Future<void> updateUserOnlineStatus(String uid, bool isOnline) async {
    try {
      await _usersRef.doc(uid).update({
        'isOnline': isOnline,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Non-critical presence update error
    }
  }

  /// Updates user profile details (name, photoUrl).
  Future<void> updateUserProfile({
    required String uid,
    String? name,
    String? photoUrl,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (name != null) updates['name'] = name.trim();
    if (photoUrl != null) updates['photoUrl'] = photoUrl;

    await _usersRef.doc(uid).update(updates);
  }
}
