import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/models/convo_user.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/screens/auth_loading_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/calls/domain/models/call_model.dart';
import '../../features/calls/presentation/screens/active_call_screen.dart';
import '../../features/calls/presentation/screens/calls_screen.dart';
import '../../features/calls/presentation/screens/incoming_call_screen.dart';
import '../../features/capsules/presentation/screens/capsules_screen.dart';
import '../../features/chats/presentation/screens/chat_details_screen.dart';
import '../../features/chats/presentation/screens/chat_screen.dart';
import '../../features/chats/presentation/screens/chats_screen.dart';
import '../../features/discover/presentation/screens/discover_screen.dart';
import '../../features/nearby/presentation/screens/nearby_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/stickers/presentation/screens/sticker_studio_screen.dart';
import '../widgets/app_shell.dart';
import 'app_routes.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);
final GlobalKey<NavigatorState> _chatsNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'chatsNav',
);
final GlobalKey<NavigatorState> _nearbyNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'nearbyNav',
);
final GlobalKey<NavigatorState> _callsNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'callsNav',
);
final GlobalKey<NavigatorState> _discoverNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'discoverNav');
final GlobalKey<NavigatorState> _profileNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'profileNav');

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ValueNotifier<int>(0);
  ref.listen(authStateChangesProvider, (previous, next) {
    refreshNotifier.value++;
  });
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.chats,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authStateChangesProvider);
      final currentPath = state.uri.path;

      // 1. Initial auth state resolution
      if (authState.isLoading) {
        if (currentPath == AppRoutes.splash) return null;
        return AppRoutes.splash;
      }

      final isLoggedIn = authState.asData?.value != null;
      final isAuthRoute =
          currentPath == AppRoutes.login ||
          currentPath == AppRoutes.signup ||
          currentPath == AppRoutes.forgotPassword;

      // 2. Logged out user guard
      if (!isLoggedIn) {
        if (isAuthRoute) {
          return null;
        }
        return AppRoutes.login;
      }

      // 3. Logged in user guard
      if (isAuthRoute || currentPath == AppRoutes.splash) {
        return AppRoutes.chats;
      }

      // Allow normal authenticated destination
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) => const AuthLoadingScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        name: 'signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        name: 'forgotPassword',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/chat/:conversationId',
        name: 'chat',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final conversationId = state.pathParameters['conversationId'] ?? '';
          final otherUser = state.extra as ConvoUser?;
          return ChatScreen(
            conversationId: conversationId,
            otherUser: otherUser,
          );
        },
        routes: [
          GoRoute(
            path: 'details',
            name: 'chatDetails',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) {
              final conversationId =
                  state.pathParameters['conversationId'] ?? '';
              final otherUser = state.extra as ConvoUser;
              return ChatDetailsScreen(
                conversationId: conversationId,
                otherUser: otherUser,
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.activeCall,
        name: 'activeCall',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ActiveCallScreen(),
      ),
      GoRoute(
        path: AppRoutes.incomingCall,
        name: 'incomingCall',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final call = state.extra as CallModel;
          return IncomingCallScreen(call: call);
        },
      ),
      GoRoute(
        path: AppRoutes.stickerStudio,
        name: 'stickerStudio',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const StickerStudioScreen(),
      ),
      GoRoute(
        path: AppRoutes.capsules,
        name: 'capsules',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const CapsulesScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: _chatsNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.chats,
                name: 'chats',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: ChatsScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _nearbyNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.nearby,
                name: 'nearby',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: NearbyScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _callsNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.calls,
                name: 'calls',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: CallsScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _discoverNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.discover,
                name: 'discover',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: DiscoverScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _profileNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                name: 'profile',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: ProfileScreen()),
                routes: [
                  GoRoute(
                    path: 'settings',
                    name: 'settings',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const SettingsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
