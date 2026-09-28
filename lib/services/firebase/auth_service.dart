import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService({FirebaseAuth? auth}) : _customAuth = auth;

  final FirebaseAuth? _customAuth;

  FirebaseAuth get _auth {
    return _customAuth ?? FirebaseAuth.instance;
  }

  Stream<User?> get authStateChanges {
    try {
      return _auth.authStateChanges();
    } catch (_) {
      return const Stream.empty();
    }
  }

  User? get currentUser {
    try {
      return _auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_handleAuthErrorCode(e));
    } catch (e) {
      throw AuthException('An unexpected error occurred. Please try again.');
    }
  }

  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (credential.user != null) {
        await credential.user!.updateDisplayName(name.trim());
      }
      return credential;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_handleAuthErrorCode(e));
    } catch (e) {
      throw AuthException('An unexpected error occurred. Please try again.');
    }
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_handleAuthErrorCode(e));
    } catch (e) {
      throw AuthException('Could not send reset email. Please try again.');
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw AuthException('Failed to sign out. Please try again.');
    }
  }

  String _handleAuthErrorCode(FirebaseAuthException e) {
    switch (e.code) {
      case 'configuration-not-found':
      case 'CONFIGURATION_NOT_FOUND':
        return 'Firebase Authentication is not enabled in the Firebase Console. Please enable Email/Password provider in Firebase Console > Build > Authentication.';
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password. Please verify your credentials.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'The email address format is invalid.';
      case 'weak-password':
        return 'The password provided is too weak. Use at least 6 characters.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few moments and try again.';
      case 'network-request-failed':
        return 'Network connection failed. Please check your internet connection.';
      case 'operation-not-allowed':
        return 'Email/Password sign-in is not enabled in Firebase Console.';
      default:
        if (e.message?.contains('CONFIGURATION_NOT_FOUND') == true) {
          return 'Firebase Authentication is not enabled in the Firebase Console. Please enable Email/Password provider in Firebase Console > Build > Authentication.';
        }
        return e.message ?? 'Authentication failed (${e.code}).';
    }
  }
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}
