import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  NotificationService({
    FirebaseMessaging? customMessaging,
    FirebaseFirestore? customFirestore,
  }) : _messaging = customMessaging,
       _firestore = customFirestore;

  final FirebaseMessaging? _messaging;
  final FirebaseFirestore? _firestore;

  FirebaseMessaging get _fcm => _messaging ?? FirebaseMessaging.instance;
  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  bool _initialized = false;

  Future<void> initialize(String? currentUserId) async {
    if (_initialized) return;

    try {
      if (Firebase.apps.isEmpty) return;
    } catch (_) {
      return;
    }

    // FCM is primarily supported on Android, iOS, and Web
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        final settings = await _fcm.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );

        debugPrint(
          'FCM notification authorization status: ${settings.authorizationStatus}',
        );

        // Foreground notification options for iOS
        await _fcm.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

        // Register token if user is signed in
        if (currentUserId != null && currentUserId.isNotEmpty) {
          await registerDeviceToken(currentUserId);
        }

        // Listen for token refreshes
        _fcm.onTokenRefresh.listen((newToken) {
          if (currentUserId != null && currentUserId.isNotEmpty) {
            _saveTokenToFirestore(currentUserId, newToken);
          }
        });

        // Listen for foreground incoming messages
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          final notification = message.notification;
          if (notification != null) {
            debugPrint(
              'Foreground notification received: ${notification.title} - ${notification.body}',
            );
          }
        });

        _initialized = true;
      } catch (e) {
        debugPrint('FCM initialization notice: $e');
      }
    }
  }

  /// Retrieves device registration token and persists it to the user's Firestore document.
  Future<String?> registerDeviceToken(String uid) async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        await _saveTokenToFirestore(uid, token);
        return token;
      }
    } catch (e) {
      debugPrint('FCM token acquisition notice: $e');
    }
    return null;
  }

  Future<void> _saveTokenToFirestore(String uid, String token) async {
    try {
      await _db.collection('users').doc(uid).set({
        'fcmToken': token,
        'fcmUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Non-critical token sync error
    }
  }
}
