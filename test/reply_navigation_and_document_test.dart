import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:convo/features/chats/domain/models/message_model.dart';
import 'package:convo/features/chats/presentation/widgets/chat_feature_panel.dart';
import 'package:convo/features/chats/presentation/widgets/message_bubble.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Task 3: Reply Navigation & Quoted Message Tests', () {
    testWidgets('Tapping reply quote triggers onReplyTap callback with quoted message ID', (tester) async {
      String? tappedReplyId;

      final messageWithReply = MessageModel(
        id: 'msg_reply_1',
        conversationId: 'conv_1',
        senderId: 'user_a',
        receiverId: 'user_b',
        text: 'This is my reply to your previous statement',
        createdAt: DateTime(2026, 10, 11, 15, 0),
        replyToMessageId: 'orig_msg_42',
        replyToSnippet: 'Original question or prompt',
        replyToSenderName: 'Jordan Lee',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              message: messageWithReply,
              isMe: false,
              currentUserId: 'user_b',
              onReplyTap: (id) => tappedReplyId = id,
              onReply: () {},
              onReact: (_) {},
              onDelete: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Jordan Lee'), findsOneWidget);
      expect(find.text('Original question or prompt'), findsOneWidget);

      await tester.tap(find.text('Original question or prompt'));
      await tester.pumpAndSettle();

      expect(tappedReplyId, equals('orig_msg_42'));
    });
  });

  group('Task 4: Document Attachments Tests', () {
    testWidgets('ChatFeaturePanel renders Document option and selects ChatAttachmentType.document', (tester) async {
      ChatAttachmentType? selectedType;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  ChatFeaturePanel.show(
                    context,
                    onAttachmentSelected: (type) => selectedType = type,
                    onFeatureSelected: (_) {},
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Document'), findsOneWidget);
      expect(find.byIcon(Icons.insert_drive_file_rounded), findsOneWidget);

      await tester.tap(find.text('Document'));
      await tester.pumpAndSettle();

      expect(selectedType, equals(ChatAttachmentType.document));
    });

    testWidgets('MessageBubble renders file tile with icon, filename and formatted file size', (tester) async {
      final fileMessage = MessageModel(
        id: 'msg_file_1',
        conversationId: 'conv_1',
        senderId: 'user_a',
        receiverId: 'user_b',
        text: 'Quarterly_Report_2026.pdf',
        type: 'file',
        fileName: 'Quarterly_Report_2026.pdf',
        fileSize: 2621440, // 2.5 MB
        mediaUrl: 'https://example.com/Quarterly_Report_2026.pdf',
        createdAt: DateTime(2026, 10, 11, 15, 30),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              message: fileMessage,
              isMe: true,
              currentUserId: 'user_a',
              onReply: () {},
              onReact: (_) {},
              onDelete: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Quarterly_Report_2026.pdf'), findsOneWidget);
      expect(find.text('2.5 MB'), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf_rounded), findsOneWidget);
      expect(find.byIcon(Icons.download_rounded), findsOneWidget);
    });

    testWidgets('MessageBubble handles invalid or null mediaUrl safely without crashing', (tester) async {
      final invalidFileMessage = MessageModel(
        id: 'msg_file_invalid',
        conversationId: 'conv_1',
        senderId: 'user_a',
        receiverId: 'user_b',
        text: 'Corrupted.docx',
        type: 'file',
        fileName: 'Corrupted.docx',
        fileSize: 1024,
        mediaUrl: null, // No URL available
        createdAt: DateTime(2026, 10, 11, 15, 35),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              message: invalidFileMessage,
              isMe: false,
              currentUserId: 'user_b',
              onReply: () {},
              onReact: (_) {},
              onDelete: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // When mediaUrl is null, falls back safely to text rendering without exception
      expect(find.text('Corrupted.docx'), findsOneWidget);
    });
  });
}
