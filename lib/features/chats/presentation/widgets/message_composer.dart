import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/extensions.dart';
import '../../domain/models/message_model.dart';

/// Reusable Message Composer widget with smooth transition between voice & send states,
/// attachment menu button, emoji picker toggle, chat magic shortcut, and reply preview.
class MessageComposer extends StatelessWidget {
  const MessageComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.canSend,
    required this.showEmojiPicker,
    required this.onSend,
    required this.onStartVoiceRecord,
    required this.onAttachmentTap,
    required this.onMagicTap,
    required this.onEmojiToggle,
    this.replyingMessage,
    this.currentUserId = '',
    this.otherUserName = 'User',
    this.onReplyClear,
    this.hintText = 'Message...',
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool canSend;
  final bool showEmojiPicker;
  final VoidCallback onSend;
  final VoidCallback onStartVoiceRecord;
  final VoidCallback onAttachmentTap;
  final VoidCallback onMagicTap;
  final VoidCallback onEmojiToggle;
  final MessageModel? replyingMessage;
  final String currentUserId;
  final String otherUserName;
  final VoidCallback? onReplyClear;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Replying Quote Banner
        if (replyingMessage != null)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: context.convoColors.surfaceSubtle,
              border: Border(
                top: BorderSide(
                  color: context.convoColors.cardBorder,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 32,
                  decoration: BoxDecoration(
                    color: context.colorScheme.primary,
                    borderRadius: AppRadius.borderPill,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        replyingMessage!.senderId == currentUserId
                            ? 'Replying to Yourself'
                            : 'Replying to ${replyingMessage!.senderName ?? otherUserName}',
                        style: AppTypography.labelSmall.copyWith(
                          color: context.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        replyingMessage!.isMedia
                            ? '[${replyingMessage!.type.toUpperCase()}]'
                            : replyingMessage!.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: context.convoColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onReplyClear != null)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: onReplyClear,
                  ),
              ],
            ),
          ),

        // Main Composer Input Bar
        Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.xs,
            AppSpacing.sm,
            AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: context.convoColors.cardBackground,
            border: Border(
              top: BorderSide(color: context.convoColors.cardBorder, width: 1),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Emoji Button
              IconButton(
                icon: Icon(
                  showEmojiPicker
                      ? Icons.keyboard_rounded
                      : Icons.sentiment_satisfied_alt_rounded,
                  color: showEmojiPicker
                      ? context.colorScheme.primary
                      : context.convoColors.textTertiary,
                  size: 24,
                ),
                tooltip: 'Emoji',
                onPressed: onEmojiToggle,
              ),

              // Attachment Button
              IconButton(
                icon: Icon(
                  Icons.attach_file_rounded,
                  color: context.colorScheme.primary,
                  size: 24,
                ),
                tooltip: 'Add attachment',
                onPressed: onAttachmentTap,
              ),

              // Chat Magic Hub Button
              IconButton(
                icon: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
                tooltip: 'Chat Magic',
                onPressed: onMagicTap,
              ),

              // Text Input Field
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: context.convoColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: context.convoColors.cardBorder,
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    focusNode: focusNode,
                    controller: controller,
                    maxLines: 4,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: hintText,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      isDense: true,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: AppSpacing.xs),

              // Animated Transition between Voice button and Send button
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(
                    scale: animation,
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: canSend
                    ? Container(
                        key: const ValueKey('send_button'),
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: const BoxDecoration(
                          gradient: AppColors.meshGradient,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.send_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                          tooltip: 'Send message',
                          onPressed: onSend,
                        ),
                      )
                    : Container(
                        key: const ValueKey('voice_button'),
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: context.colorScheme.primary.withValues(
                            alpha: 0.12,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.mic_rounded,
                            size: 22,
                            color: context.colorScheme.primary,
                          ),
                          tooltip: 'Hold or tap to record voice message',
                          onPressed: onStartVoiceRecord,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
