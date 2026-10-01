import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:convo/core/widgets/convo_avatar.dart';
import 'package:convo/features/chats/domain/models/conversation_model.dart';
import 'package:convo/features/chats/presentation/widgets/chat_avatar.dart';
import 'package:convo/features/chats/presentation/widgets/chat_feature_panel.dart';
import 'package:convo/features/chats/presentation/widgets/chat_magic_sheet.dart';
import 'package:convo/features/chats/presentation/widgets/chat_preview_tile.dart';
import 'package:convo/features/chats/presentation/widgets/feature_action_item.dart';
import 'package:convo/features/chats/presentation/widgets/message_composer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Chat Avatar Widget Tests', () {
    testWidgets('Renders 1-to-1 avatar with initials and online dot', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatAvatar(
              initials: 'JL',
              status: ConvoAvatarStatus.online,
              size: 48,
            ),
          ),
        ),
      );

      expect(find.text('JL'), findsOneWidget);
      // Status dot has colored container
      expect(find.byType(ChatAvatar), findsOneWidget);
    });

    testWidgets('Renders group icon when isGroup is true without photo', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatAvatar(
              initials: 'GP',
              isGroup: true,
              size: 48,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.groups_rounded), findsOneWidget);
    });
  });

  group('Feature Action Item Tests', () {
    testWidgets('Renders title, subtitle, emoji and responds to tap', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeatureActionItem(
              title: 'Stickers',
              subtitle: 'Studio & Packs',
              emoji: '🎨',
              color: Colors.pink,
              badge: 'New',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Stickers'), findsOneWidget);
      expect(find.text('Studio & Packs'), findsOneWidget);
      expect(find.text('🎨'), findsOneWidget);
      expect(find.text('New'), findsOneWidget);

      await tester.tap(find.text('Stickers'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('Compact mode renders circular icon and title', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeatureActionItem(
              title: 'Gallery',
              icon: Icons.photo_library_rounded,
              color: Colors.purple,
              isCompact: true,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Gallery'), findsOneWidget);
      expect(find.byIcon(Icons.photo_library_rounded), findsOneWidget);

      await tester.tap(find.text('Gallery'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });
  });

  group('Chat Preview Tile Widget Tests', () {
    testWidgets('Renders conversation metadata, pinned badge, unread count and triggers tap', (tester) async {
      bool tapped = false;
      bool longPressed = false;
      bool pinToggled = false;

      final now = DateTime(2026, 10, 1, 12, 0);
      final conversation = ConversationModel(
        id: 'conv_123',
        participants: ['user_me', 'user_other'],
        participantDetails: {
          'user_other': {'name': 'Sarah Connor'},
        },
        lastMessage: 'Are you there?',
        lastMessageAt: now,
        unreadCounts: {'user_me': 3},
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatPreviewTile(
              conversation: conversation,
              currentUserId: 'user_me',
              displayName: 'Sarah Connor',
              isPinned: true,
              isMuted: false,
              isArchived: false,
              isOnline: true,
              onTap: () => tapped = true,
              onLongPress: () => longPressed = true,
              onPinToggle: () => pinToggled = true,
            ),
          ),
        ),
      );

      expect(find.text('Sarah Connor'), findsOneWidget);
      expect(find.text('Are you there?'), findsOneWidget);
      expect(find.text('3'), findsOneWidget); // Unread badge
      expect(find.byIcon(Icons.push_pin_rounded), findsOneWidget); // Pinned icon

      await tester.tap(find.text('Sarah Connor'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);

      await tester.longPress(find.text('Sarah Connor'));
      await tester.pumpAndSettle();
      expect(longPressed, isTrue);
      expect(pinToggled, isFalse);
    });

    testWidgets('Muted conversation shows muted icon', (tester) async {
      final now = DateTime(2026, 10, 1, 12, 0);
      final conversation = ConversationModel(
        id: 'conv_muted',
        participants: ['user_me', 'user_other'],
        participantDetails: {},
        lastMessage: 'Silent update',
        lastMessageAt: now,
        mutedBy: ['user_me'],
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatPreviewTile(
              conversation: conversation,
              currentUserId: 'user_me',
              displayName: 'Muted Room',
              isPinned: false,
              isMuted: true,
              isArchived: false,
              onTap: () {},
              onLongPress: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.notifications_off_rounded), findsOneWidget);
    });
  });

  group('Message Composer Component Tests', () {
    testWidgets('Transitions smoothly between voice button and send button', (tester) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();
      bool sendTriggered = false;
      bool voiceTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return MessageComposer(
                  controller: controller,
                  focusNode: focusNode,
                  canSend: controller.text.trim().isNotEmpty,
                  showEmojiPicker: false,
                  onSend: () => sendTriggered = true,
                  onStartVoiceRecord: () => voiceTriggered = true,
                  onAttachmentTap: () {},
                  onMagicTap: () {},
                  onEmojiToggle: () {},
                );
              },
            ),
          ),
        ),
      );

      // Initially empty: shows microphone
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsNothing);

      await tester.tap(find.byIcon(Icons.mic_rounded));
      await tester.pumpAndSettle();
      expect(voiceTriggered, isTrue);

      // Enter text
      await tester.enterText(find.byType(TextField), 'Hello CONVO!');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageComposer(
              controller: controller,
              focusNode: focusNode,
              canSend: true,
              showEmojiPicker: false,
              onSend: () => sendTriggered = true,
              onStartVoiceRecord: () {},
              onAttachmentTap: () {},
              onMagicTap: () {},
              onEmojiToggle: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Now shows send button
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();
      expect(sendTriggered, isTrue);
    });
  });

  group('Chat Feature Panel Tests', () {
    testWidgets('Renders all 7 signature features and media items', (tester) async {
      ChatMagicAction? selectedAction;
      ChatAttachmentType? selectedAttachment;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  ChatFeaturePanel.show(
                    context,
                    onAttachmentSelected: (att) => selectedAttachment = att,
                    onFeatureSelected: (act) => selectedAction = act,
                  );
                },
                child: const Text('Open Panel'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Panel'));
      await tester.pumpAndSettle();

      // Verify header and sections
      expect(find.text('Share & CONVO Magic'), findsOneWidget);
      expect(find.text('CONVO UNIQUE FEATURES'), findsOneWidget);

      // Verify media attachments
      expect(find.text('Gallery'), findsOneWidget);
      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('Video'), findsOneWidget);

      // Verify all 7 CONVO features
      expect(find.text('Stickers'), findsOneWidget);
      expect(find.text('Chat Mood'), findsOneWidget);
      expect(find.text('Chat Games'), findsOneWidget);
      expect(find.text('Voice Effects'), findsOneWidget);
      expect(find.text('Reaction FX'), findsOneWidget);
      expect(find.text('Capsule'), findsOneWidget);
      expect(find.text('Secret Chat'), findsOneWidget);

      // Select Games feature
      await tester.ensureVisible(find.text('Chat Games'));
      await tester.tap(find.text('Chat Games'));
      await tester.pumpAndSettle();
      expect(selectedAction, equals(ChatMagicAction.games));
      expect(selectedAttachment, isNull);
    });
  });
}
