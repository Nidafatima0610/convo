import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/routes/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_radius.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_typography.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/presentation/providers/auth_providers.dart';
import 'features/chats/presentation/providers/chat_providers.dart';
import 'firebase_options.dart';
import 'services/local_storage/chat_preferences_service.dart';
import 'services/notifications/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge-to-edge system chrome setup
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  // Initialize SharedPreferences
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
    setGlobalSharedPreferences(prefs);
  } catch (e) {
    debugPrint('SharedPreferences init notice: $e');
  }

  // Initialize Firebase using FlutterFire generated options
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization notice: $e');
  }

  // Register background FCM handler
  if (kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS) {
    try {
      FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler,
      );
    } catch (e) {
      debugPrint('FCM background handler registration notice: $e');
    }
  }

  runApp(
    ProviderScope(
      overrides: [
        if (prefs != null) sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const ConvoApp(),
    ),
  );
}

class ConvoApp extends ConsumerStatefulWidget {
  const ConvoApp({super.key});

  @override
  ConsumerState<ConvoApp> createState() => _ConvoAppState();
}

class _ConvoAppState extends ConsumerState<ConvoApp> {
  AppLifecycleListener? _lifecycleListener;
  StreamSubscription<RemoteMessage>? _foregroundSub;

  @override
  void initState() {
    super.initState();

    // Safe presence tracking based on app lifecycle state
    _lifecycleListener = AppLifecycleListener(
      onResume: () => _updatePresence(true),
      onPause: () => _updatePresence(false, force: true),
      onDetach: () => _updatePresence(false, force: true),
      onHide: () => _updatePresence(false),
    );

    // Setup foreground notification handler
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifService = ref.read(notificationServiceProvider);
      _foregroundSub = notifService.foregroundMessageStream.listen(
        _onForegroundNotification,
      );
    });
  }

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    _foregroundSub?.cancel();
    super.dispose();
  }

  void _updatePresence(bool isOnline, {bool force = false}) {
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (user != null) {
      ref
          .read(firestoreServiceProvider)
          .updateUserOnlineStatus(user.uid, isOnline, force: force);
    }
  }

  void _onForegroundNotification(RemoteMessage message) {
    final profile = ref.read(currentUserProfileProvider).asData?.value;
    if (profile != null && !profile.notificationsEnabled) {
      return; // User disabled push notifications in settings
    }

    final data = message.data;
    final conversationId = data['conversationId'] as String?;
    final senderName = data['senderName'] as String? ?? 'CONVO User';
    final messageType = data['type'] as String? ?? 'text';
    final rawText = message.notification?.body ?? data['text'] as String? ?? '';

    final includePreview = profile?.notificationPreviewsEnabled ?? true;
    final previewText = NotificationService.formatMessagePreview(
      senderName: senderName,
      type: messageType,
      text: rawText,
      includePreview: includePreview,
    );

    final context = rootNavigatorKey.currentContext;
    if (context != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                senderName,
                style: AppTypography.titleMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                previewText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall.copyWith(color: Colors.white70),
              ),
            ],
          ),
          backgroundColor: AppColors.primaryDark,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
          action: conversationId != null && conversationId.isNotEmpty
              ? SnackBarAction(
                  label: 'OPEN',
                  textColor: AppColors.accent,
                  onPressed: () {
                    NotificationService.navigateToConversation(conversationId);
                  },
                )
              : null,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    // Initialize notification foundation when authenticated
    ref.listen(authStateChangesProvider, (previous, next) {
      final user = next.asData?.value;
      if (user != null) {
        ref.read(notificationServiceProvider).initialize(user.uid);
        ref
            .read(firestoreServiceProvider)
            .updateUserOnlineStatus(user.uid, true, force: true);
      }
    });

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
