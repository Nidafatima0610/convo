import 'package:convo/features/chats/domain/models/message_model.dart';
import 'package:convo/features/chats/presentation/providers/chat_providers.dart';
import 'package:convo/features/nearby/domain/models/queued_message.dart';
import 'package:convo/features/nearby/presentation/providers/nearby_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Chat Pagination & Real-time Stream Architecture Tests', () {
    const testConversationId = 'userA_userB';

    MessageModel createTestMessage({
      required String id,
      required DateTime createdAt,
      String text = 'Hello',
      String senderId = 'userA',
      String receiverId = 'userB',
      Map<String, String> reactions = const {},
      bool isDeleted = false,
      bool isSecret = false,
      DateTime? expiresAt,
    }) {
      return MessageModel(
        id: id,
        conversationId: testConversationId,
        senderId: senderId,
        receiverId: receiverId,
        text: text,
        createdAt: createdAt,
        reactions: reactions,
        isDeleted: isDeleted,
        isSecret: isSecret,
        expiresAt: expiresAt,
      );
    }

    test('MessagesPaginationState copyWith works correctly', () {
      final now = DateTime.now();
      final msg1 = createTestMessage(id: 'm1', createdAt: now);
      const state = MessagesPaginationState(messages: []);

      expect(state.isLoadingMore, isFalse);
      expect(state.hasMore, isTrue);
      expect(state.error, isNull);

      final updated = state.copyWith(
        messages: [msg1],
        isLoadingMore: true,
        hasMore: false,
        error: 'Failed to load',
      );

      expect(updated.messages.length, 1);
      expect(updated.isLoadingMore, isTrue);
      expect(updated.hasMore, isFalse);
      expect(updated.error, 'Failed to load');

      final cleared = updated.copyWith(clearError: true, isLoadingMore: false);
      expect(cleared.error, isNull);
      expect(cleared.isLoadingMore, isFalse);
    });

    testWidgets(
        'Initial load delivers stream messages and detects hasMore based on pageSize',
        (tester) async {
      final baseTime = DateTime(2026, 9, 28, 12, 0, 0);

      // Create 10 messages (fewer than kMessagesPageSize = 25)
      final initialMessages = List.generate(
        10,
        (i) => createTestMessage(
          id: 'msg_$i',
          text: 'Message $i',
          createdAt: baseTime.add(Duration(minutes: i)),
        ),
      );

      MessagesPaginationState? capturedState;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conversationMessagesProvider(testConversationId)
                .overrideWith((ref) => Stream.value(initialMessages)),
            offlineQueueStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                capturedState = ref.watch(
                  conversationPaginatedMessagesProvider(testConversationId),
                );
                return Text('Count: ${capturedState?.messages.length ?? 0}');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(capturedState, isNotNull);
      expect(capturedState!.messages.length, 10);
      // Since 10 < 25, hasMore should be false
      expect(capturedState!.hasMore, isFalse);
      expect(capturedState!.isLoadingMore, isFalse);

      // Newest message (index 0) should have the latest timestamp
      expect(capturedState!.messages.first.id, 'msg_9');
      // Oldest message should be at the end
      expect(capturedState!.messages.last.id, 'msg_0');
    });

    testWidgets('Initial load with 25 messages preserves hasMore = true',
        (tester) async {
      final baseTime = DateTime(2026, 9, 28, 12, 0, 0);

      // Create 25 messages
      final initialMessages = List.generate(
        25,
        (i) => createTestMessage(
          id: 'msg_$i',
          text: 'Message $i',
          createdAt: baseTime.add(Duration(minutes: i)),
        ),
      );

      MessagesPaginationState? capturedState;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conversationMessagesProvider(testConversationId)
                .overrideWith((ref) => Stream.value(initialMessages)),
            offlineQueueStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                capturedState = ref.watch(
                  conversationPaginatedMessagesProvider(testConversationId),
                );
                return Text('Count: ${capturedState?.messages.length ?? 0}');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(capturedState, isNotNull);
      expect(capturedState!.messages.length, 25);
      expect(capturedState!.hasMore, isTrue);
    });

    testWidgets(
        'Deduplication: Prevents duplicate messages across stream, older batches and offline queue',
        (tester) async {
      final baseTime = DateTime(2026, 9, 28, 12, 0, 0);

      final streamMessages = [
        createTestMessage(
          id: 'msg_stream_1',
          createdAt: baseTime.add(const Duration(minutes: 5)),
          text: 'From Stream',
        ),
        createTestMessage(
          id: 'msg_shared',
          createdAt: baseTime.add(const Duration(minutes: 4)),
          text: 'Confirmed in Stream',
        ),
      ];

      final offlineQueued = [
        QueuedMessage(
          localMessageId: 'msg_shared', // Same ID as in stream (simulates synced offline message)
          conversationId: testConversationId,
          senderId: 'userA',
          receiverId: 'userB',
          text: 'Offline Queued Copy',
          createdAt: baseTime.add(const Duration(minutes: 4)),
          deliveryState: DeliveryState.synced,
        ),
        QueuedMessage(
          localMessageId: 'msg_pending_offline',
          conversationId: testConversationId,
          senderId: 'userA',
          receiverId: 'userB',
          text: 'Pending Local Only',
          createdAt: baseTime.add(const Duration(minutes: 6)),
          deliveryState: DeliveryState.queued,
        ),
      ];

      MessagesPaginationState? capturedState;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conversationMessagesProvider(testConversationId)
                .overrideWith((ref) => Stream.value(streamMessages)),
            offlineQueueStreamProvider
                .overrideWith((ref) => Stream.value(offlineQueued)),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                capturedState = ref.watch(
                  conversationPaginatedMessagesProvider(testConversationId),
                );
                return Text('Count: ${capturedState?.messages.length ?? 0}');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(capturedState, isNotNull);
      // Total messages should be 3 (msg_stream_1, msg_shared, msg_pending_offline)
      expect(capturedState!.messages.length, 3);

      final messageIds = capturedState!.messages.map((m) => m.id).toList();
      expect(messageIds.toSet().length, 3,
          reason: 'No duplicate message IDs should exist');

      // The confirmed stream version of msg_shared should take precedence
      final sharedMsg =
          capturedState!.messages.firstWhere((m) => m.id == 'msg_shared');
      expect(sharedMsg.text, 'Confirmed in Stream');

      // Descending order: msg_pending_offline (min 6) -> msg_stream_1 (min 5) -> msg_shared (min 4)
      expect(capturedState!.messages[0].id, 'msg_pending_offline');
      expect(capturedState!.messages[1].id, 'msg_stream_1');
      expect(capturedState!.messages[2].id, 'msg_shared');
    });

    testWidgets('Expired secret messages are automatically filtered out',
        (tester) async {
      final now = DateTime.now();

      final messages = [
        createTestMessage(
          id: 'active_secret',
          createdAt: now.subtract(const Duration(seconds: 10)),
          isSecret: true,
          expiresAt: now.add(const Duration(seconds: 30)),
        ),
        createTestMessage(
          id: 'expired_secret',
          createdAt: now.subtract(const Duration(minutes: 2)),
          isSecret: true,
          expiresAt: now.subtract(const Duration(seconds: 10)),
        ),
        createTestMessage(
          id: 'normal_msg',
          createdAt: now.subtract(const Duration(minutes: 1)),
        ),
      ];

      MessagesPaginationState? capturedState;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conversationMessagesProvider(testConversationId)
                .overrideWith((ref) => Stream.value(messages)),
            offlineQueueStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                capturedState = ref.watch(
                  conversationPaginatedMessagesProvider(testConversationId),
                );
                return Text('Count: ${capturedState?.messages.length ?? 0}');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(capturedState, isNotNull);
      final ids = capturedState!.messages.map((m) => m.id).toSet();
      expect(ids.contains('active_secret'), isTrue);
      expect(ids.contains('normal_msg'), isTrue);
      expect(ids.contains('expired_secret'), isFalse,
          reason: 'Expired secret message must be filtered');
    });

    testWidgets(
        'updateLocalReaction updates reaction immediately without full list reload',
        (tester) async {
      final now = DateTime.now();
      final messages = [
        createTestMessage(
          id: 'msg_react',
          createdAt: now,
          reactions: {},
        ),
      ];

      late WidgetRef capturedRef;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conversationMessagesProvider(testConversationId)
                .overrideWith((ref) => Stream.value(messages)),
            offlineQueueStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                final state = ref.watch(
                  conversationPaginatedMessagesProvider(testConversationId),
                );
                final reaction =
                    state.messages.isNotEmpty ? state.messages.first.reactions['userA'] : null;
                return Text('Reaction: $reaction');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final notifier = capturedRef.read(
        conversationPaginatedMessagesProvider(testConversationId).notifier,
      );

      // Add reaction
      notifier.updateLocalReaction('msg_react', 'userA', '❤️');
      await tester.pump();
      expect(find.text('Reaction: ❤️'), findsOneWidget);

      // Toggle reaction off
      notifier.updateLocalReaction('msg_react', 'userA', '❤️');
      await tester.pump();
      expect(find.text('Reaction: null'), findsOneWidget);
    });

    testWidgets('markMessageDeleted updates deleted status immediately',
        (tester) async {
      final now = DateTime.now();
      final messages = [
        createTestMessage(
          id: 'msg_del',
          createdAt: now,
          text: 'Original message content',
        ),
      ];

      late WidgetRef capturedRef;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conversationMessagesProvider(testConversationId)
                .overrideWith((ref) => Stream.value(messages)),
            offlineQueueStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                final state = ref.watch(
                  conversationPaginatedMessagesProvider(testConversationId),
                );
                final text = state.messages.isNotEmpty ? state.messages.first.text : '';
                return Text('Text: $text');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Text: Original message content'), findsOneWidget);

      final notifier = capturedRef.read(
        conversationPaginatedMessagesProvider(testConversationId).notifier,
      );

      notifier.markMessageDeleted('msg_del');
      await tester.pump();

      expect(find.text('Text: This message was deleted'), findsOneWidget);
    });

    testWidgets(
        'conversationCombinedMessagesProvider exposes paginated stream cleanly',
        (tester) async {
      final now = DateTime.now();
      final messages = [
        createTestMessage(id: 'm1', createdAt: now),
      ];

      int messageCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conversationMessagesProvider(testConversationId)
                .overrideWith((ref) => Stream.value(messages)),
            offlineQueueStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                final asyncVal = ref.watch(
                  conversationCombinedMessagesProvider(testConversationId),
                );
                messageCount = asyncVal.asData?.value.length ?? 0;
                return Text('Count: $messageCount');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(messageCount, 1);
      expect(find.text('Count: 1'), findsOneWidget);
    });
  });
}
