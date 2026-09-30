import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../services/firebase/auth_service.dart';
import '../../../../services/firebase/firestore_service.dart';
import '../../../chats/presentation/providers/chat_providers.dart'
    show mediaServiceProvider;
import '../../domain/models/convo_user.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

/// Real-time stream of the current Firebase Auth user
final authStateChangesProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

/// Real-time stream of the user profile document in Firestore `users/{uid}`
final currentUserProfileProvider = StreamProvider<ConvoUser?>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  final user = authState.asData?.value;

  if (user == null) {
    return Stream.value(null);
  }

  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.userProfileStream(user.uid);
});

/// Controller for auth actions (login, signup, reset password, logout)
final authControllerProvider =
    NotifierProvider<AuthController, AsyncValue<void>>(AuthController.new);

class AuthController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<bool> signIn({required String email, required String password}) async {
    state = const AsyncValue.loading();
    try {
      final authService = ref.read(authServiceProvider);
      final cred = await authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update online presence if user exists
      if (cred.user != null) {
        final firestoreService = ref.read(firestoreServiceProvider);
        await firestoreService.updateUserOnlineStatus(
          cred.user!.uid,
          true,
          force: true,
        );
      }

      state = const AsyncValue.data(null);
      return true;
    } on AuthException catch (e, st) {
      state = AsyncValue.error(e.message, st);
      return false;
    } catch (e, st) {
      state = AsyncValue.error(e.toString(), st);
      return false;
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    state = const AsyncValue.loading();
    try {
      final authService = ref.read(authServiceProvider);
      final cred = await authService.createUserWithEmailAndPassword(
        email: email,
        password: password,
        name: name,
      );

      final user = cred.user;
      if (user != null) {
        // Create the user document in Firestore `users/{uid}`
        final convoUser = ConvoUser(
          uid: user.uid,
          name: name.trim(),
          email: email.trim().toLowerCase(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isOnline: true,
        );

        final firestoreService = ref.read(firestoreServiceProvider);
        await firestoreService.createUserProfile(convoUser);
      }

      state = const AsyncValue.data(null);
      return true;
    } on AuthException catch (e, st) {
      state = AsyncValue.error(e.message, st);
      return false;
    } catch (e, st) {
      state = AsyncValue.error(e.toString(), st);
      return false;
    }
  }

  Future<bool> sendPasswordResetEmail({required String email}) async {
    state = const AsyncValue.loading();
    try {
      final authService = ref.read(authServiceProvider);
      await authService.sendPasswordResetEmail(email: email);
      state = const AsyncValue.data(null);
      return true;
    } on AuthException catch (e, st) {
      state = AsyncValue.error(e.message, st);
      return false;
    } catch (e, st) {
      state = AsyncValue.error(e.toString(), st);
      return false;
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      final currentUser = ref.read(authServiceProvider).currentUser;
      if (currentUser != null) {
        await ref
            .read(firestoreServiceProvider)
            .updateUserOnlineStatus(currentUser.uid, false, force: true);
      }
      await ref.read(authServiceProvider).signOut();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e.toString(), st);
    }
  }

  void resetError() {
    state = const AsyncValue.data(null);
  }
}

/// Controller for user profile modifications (display name, bio, DP, privacy, notification settings, block)
final profileControllerProvider =
    NotifierProvider<ProfileController, AsyncValue<void>>(
      ProfileController.new,
    );

class ProfileController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<bool> updateDisplayName(String name) async {
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (user == null) return false;

    state = const AsyncValue.loading();
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      await firestoreService.updateUserProfile(
        uid: user.uid,
        name: name.trim(),
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e.toString(), st);
      return false;
    }
  }

  Future<bool> updateBio(String bio) async {
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (user == null) return false;

    state = const AsyncValue.loading();
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      await firestoreService.updateUserBio(user.uid, bio.trim());
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e.toString(), st);
      return false;
    }
  }

  Future<String?> uploadProfilePicture(String filePath) async {
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (user == null) return null;

    state = const AsyncValue.loading();
    try {
      final mediaService = ref.read(mediaServiceProvider);
      final downloadUrl = await mediaService.uploadProfilePicture(
        filePath: filePath,
        userId: user.uid,
      );

      if (downloadUrl != null) {
        final firestoreService = ref.read(firestoreServiceProvider);
        await firestoreService.updateUserProfilePicture(user.uid, downloadUrl);
      }

      state = const AsyncValue.data(null);
      return downloadUrl;
    } catch (e, st) {
      state = AsyncValue.error(e.toString(), st);
      return null;
    }
  }

  Future<bool> removeProfilePicture() async {
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (user == null) return false;

    state = const AsyncValue.loading();
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      await firestoreService.updateUserProfilePicture(user.uid, null);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e.toString(), st);
      return false;
    }
  }

  Future<bool> updatePrivacySettings(Map<String, dynamic> settings) async {
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (user == null) return false;

    state = const AsyncValue.loading();
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      await firestoreService.updatePrivacySettings(user.uid, settings);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e.toString(), st);
      return false;
    }
  }

  Future<bool> updateNotificationSettings(
    Map<String, dynamic> settings,
  ) async {
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (user == null) return false;

    state = const AsyncValue.loading();
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      await firestoreService.updateNotificationSettings(user.uid, settings);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e.toString(), st);
      return false;
    }
  }

  Future<bool> blockUser(String targetUserId) async {
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (user == null) return false;

    state = const AsyncValue.loading();
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      await firestoreService.blockUser(user.uid, targetUserId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e.toString(), st);
      return false;
    }
  }

  Future<bool> unblockUser(String targetUserId) async {
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (user == null) return false;

    state = const AsyncValue.loading();
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      await firestoreService.unblockUser(user.uid, targetUserId);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e.toString(), st);
      return false;
    }
  }
}
