import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:convo/features/auth/domain/models/convo_user.dart';
import 'package:convo/features/auth/presentation/providers/auth_providers.dart';
import 'package:convo/features/chats/domain/models/conversation_model.dart';
import 'package:convo/features/chats/presentation/providers/chat_providers.dart';
import 'package:convo/features/chats/presentation/screens/chats_screen.dart';
import 'package:convo/features/nearby/domain/models/nearby_device.dart';
import 'package:convo/features/nearby/domain/models/queued_message.dart';
import 'package:convo/features/nearby/presentation/providers/nearby_providers.dart';
import 'package:convo/services/local_storage/chat_preferences_service.dart';
import 'package:convo/services/nearby/nearby_service.dart';

class FakeUser extends Fake implements User {
  @override
  String get uid => 'user_me';

  @override
  String? get displayName => 'Current User';

  @override
  String? get email => 'me@convo.app';
}

class FakeChatPrefsService extends Fake implements ChatPreferencesService {
  @override
  bool isMessageDeletedForMe(String messageId) => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fakeUser = FakeUser();
  final testUser = ConvoUser(
    uid: fakeUser.uid,
    name: fakeUser.displayName ?? 'Current User',
    email: fakeUser.email ?? 'me@convo.app',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  Widget createSubject({
    required List<ConversationModel> conversations,
    NearbyState nearbyState = const NearbyState(isEnabled: false),
    List<QueuedMessage> offlineQueue = const [],
  }) {
    return ProviderScope(
      overrides: [
        currentUserProfileProvider.overrideWith((ref) => Stream.value(testUser)),
        authStateChangesProvider.overrideWith((ref) => Stream.value(fakeUser)),
        userConversationsProvider.overrideWith((ref) => Stream.value(conversations)),
        chatPreferencesServiceProvider.overrideWithValue(FakeChatPrefsService()),
        pinnedChatIdsProvider.overrideWith(() => _MockPinnedNotifier()),
        archivedChatIdsProvider.overrideWith(() => _MockArchivedNotifier()),
        deletedChatIdsProvider.overrideWith(() => _MockDeletedNotifier()),
        nearbyControllerProvider.overrideWith(() => _MockNearbyController(nearbyState)),
        offlineQueueStreamProvider.overrideWith((ref) => Stream.value(offlineQueue)),
      ],
      child: const MaterialApp(
        home: ChatsScreen(),
      ),
    );
  }

  group('ChatsScreen Mesh Filter Tests', () {
    testWidgets('Mesh filter displays "Nearby Mesh Disabled" when offline mesh is disabled', (tester) async {
      await tester.pumpWidget(createSubject(
        conversations: [],
        nearbyState: const NearbyState(isEnabled: false),
      ));
      await tester.pumpAndSettle();

      // Tap Mesh tab chip
      await tester.tap(find.text('Mesh'));
      await tester.pumpAndSettle();

      expect(find.text('Nearby Mesh Disabled'), findsOneWidget);
      expect(find.text('Open Nearby Hub'), findsOneWidget);
    });

    testWidgets('Mesh filter displays "No Mesh Activity" when mesh is active but idle with no queue', (tester) async {
      await tester.pumpWidget(createSubject(
        conversations: [],
        nearbyState: const NearbyState(
          isEnabled: true,
          status: NearbyServiceStatus.searching,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mesh'));
      await tester.pumpAndSettle();

      expect(find.text('No Mesh Activity'), findsOneWidget);
      expect(find.text('Scan for Peers'), findsOneWidget);
    });

    testWidgets('Mesh filter displays genuine conversation when local queue contains messages', (tester) async {
      final queuedMsg = QueuedMessage(
        localMessageId: 'msg_local_123',
        conversationId: 'user_me_peer_offline',
        senderId: 'user_me',
        receiverId: 'peer_offline',
        text: 'Encrypted message via offline mesh',
        createdAt: DateTime(2026, 10, 11, 14, 0),
        deliveryState: DeliveryState.queued,
        offlineOrigin: true,
      );

      await tester.pumpWidget(createSubject(
        conversations: [],
        nearbyState: const NearbyState(isEnabled: true),
        offlineQueue: [queuedMsg],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mesh'));
      await tester.pumpAndSettle();

      // Should display real message text with 'You: ' prefix since senderId is current user
      expect(find.text('You: Encrypted message via offline mesh'), findsOneWidget);
      expect(find.text('Nearby Mesh Disabled'), findsNothing);
      expect(find.text('No Mesh Activity'), findsNothing);
    });

    testWidgets('Mesh filter displays genuine active connected peer conversations', (tester) async {
      final peerDevice = NearbyDevice(
        endpointId: 'endpoint_456',
        displayName: 'Bob Nearby',
        userId: 'user_bob',
        status: NearbyDeviceStatus.connected,
        lastSeen: DateTime(2026, 10, 11, 14, 30),
      );

      await tester.pumpWidget(createSubject(
        conversations: [],
        nearbyState: NearbyState(
          isEnabled: true,
          status: NearbyServiceStatus.connected,
          connectedDevices: [peerDevice],
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mesh'));
      await tester.pumpAndSettle();

      expect(find.text('Bob Nearby'), findsOneWidget);
      expect(find.text('Connected directly via Nearby Mesh'), findsOneWidget);
    });
  });
}

class _MockNearbyController extends NearbyController {
  _MockNearbyController(this._initialState);
  final NearbyState _initialState;

  @override
  NearbyState build() => _initialState;
}

class _MockPinnedNotifier extends PinnedChatIdsNotifier {
  @override
  Set<String> build() => const <String>{};
}

class _MockArchivedNotifier extends ArchivedChatIdsNotifier {
  @override
  Set<String> build() => const <String>{};
}

class _MockDeletedNotifier extends DeletedChatIdsNotifier {
  @override
  Set<String> build() => const <String>{};
}
