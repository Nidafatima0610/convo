import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:go_router/go_router.dart';

import '../../core/routes/app_router.dart';

/// Top-level background message handler required by Firebase Messaging.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    debugPrint('Handling background FCM message: ${message.messageId}');
  } catch (e) {
    debugPrint('Background FCM handler notice: $e');
  }
}

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

  /// Holds the ID of the conversation the user is currently viewing.
  /// When set, foreground notifications for this conversation are suppressed.
  static String? activeConversationId;

  /// Stream controller for foreground notification events.
  final StreamController<RemoteMessage> _foregroundMessageController =
      StreamController<RemoteMessage>.broadcast();

  Stream<RemoteMessage> get foregroundMessageStream =>
      _foregroundMessageController.stream;

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
        // Safe runtime notification permission request
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
          try {
            await Permission.notification.request();
          } catch (_) {
            // Non-critical if permission handler isn't available
          }
        }

        final settings = await _fcm.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );

        debugPrint(
          'FCM notification authorization status: ${settings.authorizationStatus}',
        );

        // Foreground presentation options for iOS
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

        // 1. Terminated app state: User launched app by tapping notification
        _fcm.getInitialMessage().then((initialMessage) {
          if (initialMessage != null) {
            _handleNotificationTap(initialMessage);
          }
        });

        // 2. Background app state: User resumed app by tapping notification
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
          _handleNotificationTap(message);
        });

        // 3. Foreground app state: Handle incoming message while app is open
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          final conversationId = message.data['conversationId'] as String?;

          // If the user is currently looking at this conversation, suppress foreground notification
          if (conversationId != null &&
              activeConversationId != null &&
              activeConversationId == conversationId) {
            debugPrint(
              'Suppressing foreground notification: conversation $conversationId is currently active.',
            );
            return;
          }

          _foregroundMessageController.add(message);
        });

        _initialized = true;
      } catch (e) {
        debugPrint('FCM initialization notice: $e');
      }
    }
  }

  /// Navigates the user directly to the relevant conversation upon tapping a notification.
  void _handleNotificationTap(RemoteMessage message) {
    final conversationId = message.data['conversationId'] as String?;
    if (conversationId != null && conversationId.isNotEmpty) {
      navigateToConversation(conversationId);
    }
  }

  /// Global navigation helper to route to a specific chat using rootNavigatorKey.
  static void navigateToConversation(String conversationId) {
    if (conversationId.isEmpty) return;
    try {
      final context = rootNavigatorKey.currentContext;
      if (context != null) {
        context.push('/chat/$conversationId');
      }
    } catch (e) {
      debugPrint('Error navigating to conversation from notification: $e');
    }
  }

  /// Formats message notification previews safely according to message type and preview settings.
  static String formatMessagePreview({
    required String senderName,
    required String type,
    required String text,
    bool includePreview = true,
  }) {
    if (!includePreview) {
      return 'New message from $senderName';
    }

    switch (type.toLowerCase()) {
      case 'image':
        return '$senderName sent a photo';
      case 'video':
        return '$senderName sent a video';
      case 'voice':
        return '$senderName sent a voice message';
      case 'file':
        return '$senderName sent a file';
      case 'sticker':
        return '$senderName sent a sticker';
      case 'game':
        return '$senderName invited you to play a game';
      case 'capsule':
        return '$senderName sent a time capsule';
      case 'text':
      default:
        return text.trim().isNotEmpty
            ? text.trim()
            : '$senderName sent a message';
    }
  }

  /// Formats group message notification payload with group name as title, sender, and content as body.
  static GroupNotificationPayload formatGroupMessageNotification({
    required String groupName,
    required String senderName,
    required String type,
    String text = '',
    bool includePreview = true,
  }) {
    final title = groupName;
    if (!includePreview) {
      return GroupNotificationPayload(
        title: title,
        body: 'New message',
      );
    }

    String body;
    switch (type.toLowerCase()) {
      case 'image':
        body = '$senderName sent a photo';
        break;
      case 'video':
        body = '$senderName sent a video';
        break;
      case 'voice':
        body = '$senderName sent a voice message';
        break;
      case 'file':
        body = '$senderName sent a file';
        break;
      case 'sticker':
        body = '$senderName sent a sticker';
        break;
      case 'game':
        body = '$senderName started a game';
        break;
      case 'capsule':
        body = '$senderName locked a time capsule';
        break;
      case 'system':
        body = text.trim();
        break;
      case 'text':
      default:
        body = text.trim().isNotEmpty
            ? '$senderName: ${text.trim()}'
            : '$senderName sent a message';
        break;
    }

    return GroupNotificationPayload(title: title, body: body);
  }

  /// Formats group message notification previews with group name, sender, and content.
  static String formatGroupMessagePreview({
    required String groupName,
    required String senderName,
    required String type,
    String text = '',
    bool includePreview = true,
  }) {
    return formatGroupMessageNotification(
      groupName: groupName,
      senderName: senderName,
      type: type,
      text: text,
      includePreview: includePreview,
    ).body;
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

  void dispose() {
    _foregroundMessageController.close();
  }
}

class GroupNotificationPayload {
  const GroupNotificationPayload({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;
}

