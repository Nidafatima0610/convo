import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:convo/core/constants/app_strings.dart';
import 'package:convo/features/auth/domain/models/convo_user.dart';
import 'package:convo/features/auth/presentation/providers/auth_providers.dart';
import 'package:convo/features/calls/presentation/providers/call_providers.dart';
import 'package:convo/features/calls/presentation/screens/calls_screen.dart';
import 'package:convo/features/chats/presentation/providers/chat_providers.dart';
import 'package:convo/features/profile/presentation/screens/profile_screen.dart';

import 'package:firebase_auth/firebase_auth.dart';

class _FakeAuthUser extends Fake implements User {
  @override
  String get uid => 'current_user_123';
}

void main() {
  final testCurrentUser = ConvoUser(
    uid: 'current_user_123',
    name: 'Umair Developer',
    email: 'umair@convo.app',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final testContactUser = ConvoUser(
    uid: 'contact_user_456',
    name: 'Sarah Connor',
    email: 'sarah@convo.app',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  testWidgets(
    'CallsScreen: Tapping New Call FAB opens interactive call picker with voice and video call buttons',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateChangesProvider.overrideWith(
              (ref) => Stream.value(_FakeAuthUser()),
            ),
            currentUserProfileProvider.overrideWith(
              (ref) => Stream.value(testCurrentUser),
            ),
            callHistoryProvider.overrideWith((ref) => Stream.value([])),
            searchedUsersProvider.overrideWith(
              (ref, query) async => [testCurrentUser, testContactUser],
            ),
          ],
          child: const MaterialApp(home: CallsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Find and tap the New Call FAB
      final newCallFab = find.widgetWithText(FloatingActionButton, AppStrings.newCall);
      expect(newCallFab, findsOneWidget);

      await tester.tap(newCallFab);
      await tester.pumpAndSettle();

      // Verify the new interactive calling modal is displayed
      expect(find.text('New Call'), findsAtLeastNWidgets(2));
      expect(find.text('Choose a contact for voice or video call'), findsOneWidget);
      expect(find.text('Search people to call...'), findsOneWidget);

      // Verify contact list renders eligible user (filtered self out)
      expect(find.text('Sarah Connor'), findsOneWidget);
      expect(find.text('sarah@convo.app'), findsOneWidget);

      // Verify voice and video calling action buttons are present
      expect(find.byTooltip('Voice Call'), findsOneWidget);
      expect(find.byTooltip('Video Call'), findsOneWidget);
    },
  );

  testWidgets(
    'ProfileScreen: Tapping Share Profile opens CONVO Mesh Identity modal with QR card and ID',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProfileProvider.overrideWith(
              (ref) => Stream.value(testCurrentUser),
            ),
          ],
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Profile screen rendered
      expect(find.text('Umair Developer'), findsOneWidget);
      expect(find.text(AppStrings.shareProfile), findsOneWidget);

      // Tap Share Profile button
      await tester.tap(find.text(AppStrings.shareProfile));
      await tester.pumpAndSettle();

      // Verify the CONVO Mesh Identity modal is displayed (no "coming soon" snackbar)
      expect(find.text('CONVO MESH IDENTITY'), findsOneWidget);
      expect(find.text('Point any CONVO scanner or camera to connect'), findsOneWidget);
      expect(find.text('CONVO ID'), findsOneWidget);
      expect(find.text('current_user_123'), findsOneWidget);
      expect(find.text('Copy Mesh Profile Link'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);

      // Tap Done to close
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('CONVO MESH IDENTITY'), findsNothing);
    },
  );
}
