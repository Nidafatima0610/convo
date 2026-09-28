import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:convo/core/constants/app_constants.dart';
import 'package:convo/core/constants/app_strings.dart';
import 'package:convo/features/auth/domain/models/convo_user.dart';
import 'package:convo/features/auth/presentation/providers/auth_providers.dart';
import 'package:convo/features/calls/domain/models/call_model.dart';
import 'package:convo/features/calls/presentation/providers/call_providers.dart';
import 'package:convo/features/calls/presentation/screens/calls_screen.dart';
import 'package:convo/features/calls/presentation/screens/incoming_call_screen.dart';
import 'package:convo/features/chats/domain/models/conversation_model.dart';
import 'package:convo/features/chats/domain/models/message_model.dart';
import 'package:convo/features/chats/presentation/providers/chat_providers.dart';
import 'package:convo/features/chats/presentation/screens/chat_screen.dart';
import 'package:convo/features/chats/presentation/widgets/convo_emoji_picker.dart';
import 'package:convo/features/nearby/domain/models/nearby_device.dart';
import 'package:convo/features/nearby/presentation/providers/nearby_providers.dart';
import 'package:convo/features/nearby/presentation/screens/nearby_screen.dart';
import 'package:convo/features/settings/presentation/screens/settings_screen.dart';
import 'package:convo/services/nearby/nearby_service.dart';
import 'package:convo/main.dart';

class FakeUser extends Fake implements User {
  @override
  String get uid => 'test_uid_123';

  @override
  String? get displayName => 'Alex Rivera';

  @override
  String? get email => 'alex@convo.app';
}

void main() {
  testWidgets(
    'Logged out user sees Login screen and can navigate to Signup and Forgot Password',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
          ],
          child: const ConvoApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Login Screen is displayed
      expect(find.text(AppConstants.appName), findsOneWidget);
      expect(find.text('Sign In'), findsAtLeastNWidgets(1));
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);

      // Navigate to Signup screen
      await tester.ensureVisible(find.text('Create Account'));
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();
      expect(find.text('Create Your Account'), findsOneWidget);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);

      // Return to Login
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Sign In'), findsAtLeastNWidgets(1));

      // Navigate to Forgot Password screen
      await tester.ensureVisible(find.text('Forgot Password?'));
      await tester.tap(find.text('Forgot Password?'));
      await tester.pumpAndSettle();
      expect(find.text('Reset Password'), findsOneWidget);
      expect(find.text('Password Recovery'), findsOneWidget);
      expect(find.text('Send Reset Link'), findsOneWidget);
    },
  );

  testWidgets(
    'Logged in user enters CONVO app shell and profile displays Firestore data',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeUser = FakeUser();
      final fakeProfile = ConvoUser(
        uid: fakeUser.uid,
        name: 'Alex Rivera',
        email: 'alex@convo.app',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        isOnline: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateChangesProvider.overrideWith(
              (ref) => Stream.value(fakeUser),
            ),
            currentUserProfileProvider.overrideWith(
              (ref) => Stream.value(fakeProfile),
            ),
            userConversationsProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: const ConvoApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify main CONVO shell loads on initial Chats tab
      expect(find.text(AppConstants.appName), findsOneWidget);
      expect(find.text(AppStrings.chatsEmptyTitle), findsOneWidget);

      // Verify bottom navigation tabs exist
      expect(find.text(AppStrings.navChats), findsOneWidget);
      expect(find.text(AppStrings.navNearby), findsOneWidget);
      expect(find.text(AppStrings.navCalls), findsOneWidget);
      expect(find.text(AppStrings.navDiscover), findsOneWidget);
      expect(find.text(AppStrings.navProfile), findsOneWidget);

      // Navigate to Profile tab
      await tester.tap(find.byIcon(Icons.person_outline_rounded));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify authenticated user details from Firestore are displayed
      expect(find.text('Alex Rivera'), findsOneWidget);
      expect(find.text('alex@convo.app'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);

      // Verify Settings is accessible from Profile
      await tester.tap(find.byIcon(Icons.settings_outlined).first);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(AppStrings.settingsTitle), findsOneWidget);
    },
  );

  testWidgets(
    'Chat list displays active conversation and opens ChatScreen with real-time messages',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeUser = FakeUser();
      final partnerUser = ConvoUser(
        uid: 'user_target_456',
        name: 'Jordan Lee',
        email: 'jordan@convo.app',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        isOnline: true,
      );

      final conversationId = ConversationModel.getConversationId(
        fakeUser.uid,
        partnerUser.uid,
      );
      final fakeConversation = ConversationModel(
        id: conversationId,
        participants: [fakeUser.uid, partnerUser.uid],
        participantDetails: {
          fakeUser.uid: {'name': 'Alex Rivera', 'email': 'alex@convo.app'},
          partnerUser.uid: {'name': 'Jordan Lee', 'email': 'jordan@convo.app'},
        },
        lastMessage: 'Hey Alex, ready for CONVO mesh chat?',
        lastMessageAt: DateTime.now(),
        lastMessageSenderId: partnerUser.uid,
        unreadCounts: {fakeUser.uid: 1},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final fakeMessages = [
        MessageModel(
          id: 'msg_1',
          conversationId: conversationId,
          senderId: partnerUser.uid,
          receiverId: fakeUser.uid,
          text: 'Hey Alex, ready for CONVO mesh chat?',
          createdAt: DateTime.now(),
          isRead: false,
          reactions: {'test_uid_123': '🔥'},
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateChangesProvider.overrideWith(
              (ref) => Stream.value(fakeUser),
            ),
            userConversationsProvider.overrideWith(
              (ref) => Stream.value([fakeConversation]),
            ),
            conversationMessagesProvider(conversationId)
                .overrideWith((ref) => Stream.value(fakeMessages)),
            userPresenceProvider(partnerUser.uid)
                .overrideWith((ref) => Stream.value(partnerUser)),
          ],
          child: MaterialApp(
            home: ChatScreen(
              conversationId: conversationId,
              otherUser: partnerUser,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify ChatScreen header and call buttons
      expect(find.text('Jordan Lee'), findsOneWidget);
      expect(find.text('Active now'), findsOneWidget);
      expect(find.byIcon(Icons.phone_outlined), findsOneWidget);
      expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);

      // Verify message bubble content
      expect(find.text('Hey Alex, ready for CONVO mesh chat?'), findsOneWidget);
      expect(find.text('🔥'), findsOneWidget);

      // Verify message composer input (default state with mic and attachment)
      expect(find.text('Message...'), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(find.byIcon(Icons.attach_file_rounded), findsOneWidget);
      expect(
        find.byIcon(Icons.sentiment_satisfied_alt_rounded),
        findsOneWidget,
      );

      // Verify entering text switches mic button to send button
      await tester.enterText(find.byType(TextField), 'Hello CONVO');
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    },
  );

  testWidgets(
    'ChatScreen renders Voice, Video messages and handles Emoji drawer',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeUser = FakeUser();
      const conversationId = 'conv_media_test';
      final currentConvoUser = ConvoUser(
        uid: fakeUser.uid,
        email: fakeUser.email ?? 'alex@convo.app',
        name: fakeUser.displayName ?? 'Alex Rivera',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final otherConvoUser = ConvoUser(
        uid: 'test_user_b',
        email: 'jordan@convo.app',
        name: 'Jordan Lee',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final mediaConversation = ConversationModel(
        id: conversationId,
        participants: [currentConvoUser.uid, otherConvoUser.uid],
        participantDetails: {
          currentConvoUser.uid: {
            'name': currentConvoUser.name,
            'email': currentConvoUser.email,
          },
          otherConvoUser.uid: {
            'name': otherConvoUser.name,
            'email': otherConvoUser.email,
          },
        },
        lastMessage: 'Voice message',
        lastMessageAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final mediaMessages = [
        MessageModel(
          id: 'voice_msg_1',
          conversationId: conversationId,
          senderId: otherConvoUser.uid,
          receiverId: currentConvoUser.uid,
          text: '',
          type: 'voice',
          mediaUrl: 'https://example.com/test_voice.m4a',
          durationMs: 45000,
          createdAt: DateTime.now(),
          isRead: true,
        ),
        MessageModel(
          id: 'video_msg_1',
          conversationId: conversationId,
          senderId: currentConvoUser.uid,
          receiverId: otherConvoUser.uid,
          text: 'Check this out!',
          type: 'video',
          mediaUrl: 'https://example.com/test_video.mp4',
          fileName: 'clip.mp4',
          fileSize: 1048576,
          createdAt: DateTime.now(),
          isRead: true,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateChangesProvider.overrideWith(
              (ref) => Stream.value(fakeUser),
            ),
            userConversationsProvider.overrideWith(
              (ref) => Stream.value([mediaConversation]),
            ),
            conversationMessagesProvider(conversationId)
                .overrideWith((ref) => Stream.value(mediaMessages)),
            userPresenceProvider(otherConvoUser.uid)
                .overrideWith((ref) => Stream.value(otherConvoUser)),
          ],
          child: MaterialApp(
            home: ChatScreen(
              conversationId: conversationId,
              otherUser: otherConvoUser,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify voice message and video message play buttons and duration
      expect(find.byIcon(Icons.play_arrow_rounded), findsNWidgets(2));
      expect(find.text('0:45'), findsOneWidget);

      // Verify video message UI elements
      expect(find.text('clip.mp4'), findsOneWidget);
      expect(find.text('Check this out!'), findsOneWidget);

      // Tap emoji button to toggle emoji drawer
      await tester.tap(find.byIcon(Icons.sentiment_satisfied_alt_rounded));
      await tester.pumpAndSettle();

      // Verify emoji picker drawer is displayed
      expect(find.byType(ConvoEmojiPicker), findsOneWidget);
      expect(find.byIcon(Icons.backspace_outlined), findsOneWidget);

      // Select an emoji (e.g. 😀)
      await tester.tap(find.text('😀'));
      await tester.pumpAndSettle();

      // Text field now contains the emoji and send button is displayed
      expect(find.text('😀'), findsWidgets);
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    },
  );

  testWidgets(
    'CallsScreen displays real call history with voice/video indicators and filter tabs',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeUser = FakeUser();
      final callHistory = [
        CallModel(
          callId: 'call_1',
          callerId: 'user_target_456',
          callerName: 'Jordan Lee',
          receiverId: fakeUser.uid,
          receiverName: 'Alex Rivera',
          type: CallType.voice,
          status: CallStatus.ended,
          participants: [fakeUser.uid, 'user_target_456'],
          duration: 135,
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
        CallModel(
          callId: 'call_2',
          callerId: 'user_target_456',
          callerName: 'Jordan Lee',
          receiverId: fakeUser.uid,
          receiverName: 'Alex Rivera',
          type: CallType.video,
          status: CallStatus.missed,
          participants: [fakeUser.uid, 'user_target_456'],
          duration: 0,
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateChangesProvider.overrideWith(
              (ref) => Stream.value(fakeUser),
            ),
            callHistoryProvider.overrideWith(
              (ref) => Stream.value(callHistory),
            ),
          ],
          child: const MaterialApp(home: CallsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Screen Header and Filter chips
      expect(find.text(AppStrings.callsTitle), findsOneWidget);
      expect(find.text('All Calls'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Missed'), findsOneWidget);

      // Verify Call Items
      expect(find.text('Jordan Lee'), findsNWidgets(2));
      expect(find.text('Incoming'), findsOneWidget);
      expect(
        find.text('Missed'),
        findsNWidgets(2),
      ); // Chip and list tile status

      // Filter by Missed calls
      await tester.tap(find.widgetWithText(ChoiceChip, 'Missed'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ChoiceChip, 'Missed'), findsOneWidget);
      expect(find.text('Incoming'), findsNothing);
    },
  );

  testWidgets(
    'IncomingCallScreen displays caller details and Accept/Decline buttons',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final incomingCall = CallModel(
        callId: 'incoming_test_1',
        callerId: 'user_caller_789',
        callerName: 'Taylor Morgan',
        receiverId: 'test_uid_123',
        receiverName: 'Alex Rivera',
        type: CallType.video,
        status: CallStatus.ringing,
        participants: ['test_uid_123', 'user_caller_789'],
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            incomingCallStreamProvider.overrideWith(
              (ref) => Stream.value(incomingCall),
            ),
          ],
          child: MaterialApp(home: IncomingCallScreen(call: incomingCall)),
        ),
      );
      await tester.pump();

      // Verify caller info and call type
      expect(find.text('Taylor Morgan'), findsOneWidget);
      expect(find.text('Incoming Video Call'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
      expect(find.byIcon(Icons.call_end_rounded), findsOneWidget);
    },
  );

  testWidgets(
    'NearbyScreen renders in default privacy-first disabled state and shows privacy dialog',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nearbyControllerProvider.overrideWith(
              () => MockNearbyController(
                const NearbyState(
                  isEnabled: false,
                  status: NearbyServiceStatus.disabled,
                ),
              ),
            ),
          ],
          child: const MaterialApp(home: NearbyScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Verify header and privacy tagline
      expect(find.text('CONVO Nearby'), findsAtLeastNWidgets(1));
      expect(
        find.text('Message people around you — even without internet.'),
        findsOneWidget,
      );

      // Verify switch is off by default (Privacy-first)
      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, isFalse);

      // Verify disabled status description
      expect(find.text('Nearby Offline Mode'), findsOneWidget);
      expect(find.text('Disabled (Privacy protected)'), findsOneWidget);
      // Tap privacy action button and verify modal
      await tester.tap(find.byTooltip('Mesh Privacy'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Privacy & Mesh Security'), findsOneWidget);
      expect(find.text('Understood'), findsOneWidget);
      await tester.tap(find.text('Understood'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
    },
  );

  testWidgets(
    'NearbyScreen renders discovered and connected peer cards with Connect, Chat and Disconnect actions',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final discoveredDevice = NearbyDevice(
        endpointId: 'ep_disc_1',
        displayName: 'Sam River',
        status: NearbyDeviceStatus.discovered,
        lastSeen: DateTime.now(),
      );

      final connectedDevice = NearbyDevice(
        endpointId: 'ep_conn_1',
        displayName: 'Riley Brooks',
        userId: 'user_riley_123',
        status: NearbyDeviceStatus.connected,
        lastSeen: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nearbyControllerProvider.overrideWith(
              () => MockNearbyController(
                NearbyState(
                  isEnabled: true,
                  status: NearbyServiceStatus.connected,
                  discoveredDevices: [discoveredDevice],
                  connectedDevices: [connectedDevice],
                ),
              ),
            ),
          ],
          child: const MaterialApp(home: NearbyScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Verify connected peer section & buttons
      expect(find.text('CONNECTED DIRECTLY (OFFLINE)'), findsOneWidget);
      expect(find.text('Riley Brooks'), findsOneWidget);
      expect(find.text('Direct Offline Mesh'), findsOneWidget);
      expect(find.text('Chat'), findsOneWidget);
      expect(find.byTooltip('Disconnect'), findsOneWidget);

      // Verify discovered peer section & buttons
      expect(find.text('DISCOVERED PEERS NEARBY'), findsOneWidget);
      expect(find.text('Sam River'), findsOneWidget);
      expect(find.text('Connect'), findsOneWidget);
    },
  );

  testWidgets(
    'SettingsScreen renders NEARBY & OFFLINE MESH section with mode toggle and queue stats',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nearbyControllerProvider.overrideWith(
              () => MockNearbyController(
                const NearbyState(
                  isEnabled: true,
                  status: NearbyServiceStatus.searching,
                ),
              ),
            ),
            offlineQueueStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Nearby & Offline Mesh section
      expect(find.text('NEARBY & OFFLINE MESH'), findsOneWidget);
      expect(find.text('Nearby Offline Mode'), findsOneWidget);
      expect(find.text('Searching for nearby CONVO peers...'), findsOneWidget);
      expect(find.text('Nearby Privacy & Consent'), findsOneWidget);
      expect(find.text('Smart Offline Queue'), findsOneWidget);
      expect(find.text('Queue empty • All messages synced'), findsOneWidget);
    },
  );
}

class MockNearbyController extends NearbyController {
  MockNearbyController(this._initialState);
  final NearbyState _initialState;

  @override
  NearbyState build() => _initialState;
}
