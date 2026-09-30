import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/convo_avatar.dart';
import '../../../capsules/presentation/widgets/capsule_card_widget.dart';
import '../../../games/presentation/widgets/game_card_widget.dart';
import '../../../reactions/presentation/widgets/animated_reaction_pill.dart';
import '../../domain/models/message_model.dart';
import 'image_viewer_screen.dart';
import 'voice_message_bubble.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.currentUserId,
    required this.onReply,
    required this.onReact,
    required this.onDelete,
    this.onDeleteForMe,
    this.onDeleteForEveryone,
    this.onForward,
    this.onToggleStar,
    this.isStarred = false,
    this.isSelected = false,
    this.isSelectionMode = false,
    this.onToggleSelect,
    this.onSelectMessage,
    this.onReplyTap,
    this.showSenderName = false,
  });

  final MessageModel message;
  final bool isMe;
  final String currentUserId;
  final VoidCallback onReply;
  final ValueChanged<String> onReact;
  final VoidCallback onDelete;
  final VoidCallback? onDeleteForMe;
  final VoidCallback? onDeleteForEveryone;
  final VoidCallback? onForward;
  final VoidCallback? onToggleStar;
  final bool isStarred;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback? onToggleSelect;
  final VoidCallback? onSelectMessage;
  final ValueChanged<String>? onReplyTap;
  final bool showSenderName;

  static const List<String> availableReactions = [
    '❤️',
    '😂',
    '👍',
    '😮',
    '😢',
    '🔥',
    '🎉',
  ];

  void _showActionMenu(BuildContext context) {
    if (isSelectionMode) {
      onToggleSelect?.call();
      return;
    }
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _MessageActionSheet(
        message: message,
        isMe: isMe,
        isStarred: isStarred,
        onReply: () {
          Navigator.of(sheetContext).pop();
          onReply();
        },
        onReact: (emoji) {
          Navigator.of(sheetContext).pop();
          onReact(emoji);
        },
        onToggleStar: onToggleStar != null
            ? () {
                Navigator.of(sheetContext).pop();
                onToggleStar!();
              }
            : null,
        onSelectMessage: onSelectMessage != null
            ? () {
                Navigator.of(sheetContext).pop();
                onSelectMessage!();
              }
            : null,
        onDelete: () {
          Navigator.of(sheetContext).pop();
          _showDeleteDialog(context);
        },
        onForward: onForward != null
            ? () {
                Navigator.of(sheetContext).pop();
                onForward!();
              }
            : null,
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: context.convoColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderXl),
        title: Text(
          'Delete Message?',
          style: AppTypography.titleLarge.copyWith(
            color: context.convoColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          isMe
              ? 'Choose whether to delete this message only for yourself or for everyone in this chat.'
              : 'This message will be removed from your chat on this device.',
          style: AppTypography.bodyMedium.copyWith(
            color: context.convoColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              if (onDeleteForMe != null) {
                onDeleteForMe!();
              } else {
                onDelete();
              }
            },
            child: const Text('Delete for me'),
          ),
          if (isMe)
            FilledButton(
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                if (onDeleteForEveryone != null) {
                  onDeleteForEveryone!();
                } else {
                  onDelete();
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete for everyone'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // System message representation (e.g. member added/removed, group created, left)
    if (message.type == 'system') {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(
            vertical: 6,
            horizontal: AppSpacing.lg,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: context.convoColors.surfaceSubtle,
            borderRadius: AppRadius.borderPill,
            border: Border.all(
              color: context.convoColors.cardBorder,
              width: 0.8,
            ),
          ),
          child: Text(
            message.text,
            textAlign: TextAlign.center,
            style: AppTypography.labelSmall.copyWith(
              color: context.convoColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    final bubbleColor = isMe
        ? context.colorScheme.primary
        : context.convoColors.cardBackground;
    final textColor = isMe ? Colors.white : context.convoColors.textPrimary;
    final timeColor = isMe
        ? Colors.white.withValues(alpha: 0.75)
        : context.convoColors.textTertiary;

    final bubbleWidget = GestureDetector(
      onTap: isSelectionMode ? onToggleSelect : null,
      onLongPress: () => _showActionMenu(context),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: message.isMedia ? 4 : AppSpacing.md,
          vertical: message.isMedia ? 4 : AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? bubbleColor.withValues(alpha: 0.85)
              : bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: isSelected
              ? Border.all(color: Colors.amber, width: 2)
              : (isMe
                  ? null
                  : Border.all(
                      color: context.convoColors.cardBorder,
                      width: 1,
                    )),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: context.isDark ? 0.2 : 0.04,
              ),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            // Forwarded Indicator
            if (message.isForwarded && !message.isDeleted) ...[
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: message.isMedia ? 8 : 2,
                  vertical: 2,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.forward_rounded,
                      size: 13,
                      color: isMe ? Colors.white70 : context.convoColors.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      message.forwardedFrom != null && message.forwardedFrom!.isNotEmpty
                          ? 'Forwarded from ${message.forwardedFrom}'
                          : 'Forwarded',
                      style: AppTypography.labelSmall.copyWith(
                        color: isMe ? Colors.white70 : context.convoColors.textTertiary,
                        fontStyle: FontStyle.italic,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Group Chat Sender Name & Avatar
            if (showSenderName &&
                !isMe &&
                message.senderName != null &&
                message.senderName!.isNotEmpty) ...[
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: message.isMedia ? 8 : 2,
                  vertical: 2,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (message.senderPhotoUrl != null &&
                        message.senderPhotoUrl!.isNotEmpty) ...[
                      ConvoAvatar(
                        initials: message.senderName!.isNotEmpty
                            ? (message.senderName!.length >= 2
                                ? message.senderName!
                                    .substring(0, 2)
                                    .toUpperCase()
                                : message.senderName![0].toUpperCase())
                            : 'CO',
                        photoUrl: message.senderPhotoUrl,
                        size: 16,
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      message.senderName!,
                      style: AppTypography.labelSmall.copyWith(
                        color: context.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],

                  // Replying Quote Preview
                  if (message.isReply && !message.isDeleted) ...[
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: message.isMedia ? 8 : 0,
                        vertical: 4,
                      ),
                      child: _buildReplyPreview(context, isMe),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                  ],

                  // Media Body (Image / Video / Voice) or Soft-Deleted state
                  if (message.isDeleted)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.block_rounded,
                            size: 15,
                            color: textColor.withValues(alpha: 0.65),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Flexible(
                            child: Text(
                              'This message was deleted',
                              style: AppTypography.bodySmall.copyWith(
                                color: textColor.withValues(alpha: 0.65),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (message.isImage && message.mediaUrl != null)
                    _buildImageContent(context)
                  else if (message.isVideo && message.mediaUrl != null)
                    _buildVideoContent(context)
                  else if (message.isVoice && message.mediaUrl != null)
                    VoiceMessageBubble(
                      audioUrl: message.mediaUrl!,
                      durationMs: message.durationMs,
                      isMe: isMe,
                    )
                  else if (message.isSticker)
                    _buildStickerContent(context)
                  else if (message.isGame && message.metadata?['game'] != null)
                    GameCardWidget(
                      message: message,
                      currentUserId: currentUserId,
                      isMe: isMe,
                    )
                  else if (message.isCapsule &&
                      message.metadata?['capsule'] != null)
                    CapsuleCardWidget(message: message, isMe: isMe)
                  else
                    Text(
                      message.text,
                      style: AppTypography.bodyMedium.copyWith(
                        color: textColor,
                        height: 1.35,
                      ),
                    ),

                  // Optional caption for image/video
                  if (!message.isDeleted &&
                      message.text.isNotEmpty &&
                      (message.isImage || message.isVideo)) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
                      child: Text(
                        message.text,
                        style: AppTypography.bodyMedium.copyWith(
                          color: textColor,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 4),

                  // Timestamp & Read Receipts
                  Padding(
                    padding: EdgeInsets.only(
                      right: message.isMedia ? 8 : 0,
                      left: message.isMedia ? 8 : 0,
                      bottom: message.isMedia ? 4 : 0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (message.isSecret) ...[
                          Icon(
                            Icons.timer_outlined,
                            size: 11,
                            color: isMe ? Colors.white70 : AppColors.primary,
                          ),
                          const SizedBox(width: 3),
                        ],
                        if (message.offlineOrigin) ...[
                          Icon(
                            Icons.radar_rounded,
                            size: 11,
                            color: isMe ? Colors.white70 : AppColors.accent,
                          ),
                          const SizedBox(width: 3),
                        ],
                        Text(
                          DateFormatter.formatTime(message.createdAt),
                          style: AppTypography.labelSmall.copyWith(
                            color: timeColor,
                            fontSize: 10,
                          ),
                        ),
                        if (isStarred) ...[
                          const SizedBox(width: 3),
                          const Icon(
                            Icons.star_rounded,
                            size: 13,
                            color: Colors.amber,
                          ),
                        ],
                        if (isMe && !message.isDeleted) ...[
                          const SizedBox(width: 4),
                          Icon(
                            message.isRead
                                ? Icons.done_all_rounded
                                : Icons.done_rounded,
                            size: 14,
                            color: message.isRead
                                ? (isMe
                                      ? AppColors.accentLight
                                      : AppColors.primary)
                                : timeColor,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );

    final fullMessage = Column(
      crossAxisAlignment:
          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        bubbleWidget,
        if (message.reactions.isNotEmpty && !message.isDeleted) ...[
          const SizedBox(height: 2),
          _buildReactionsRow(context),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 3,
      ),
      child: isSelectionMode
          ? InkWell(
              onTap: onToggleSelect,
              borderRadius: BorderRadius.circular(16),
              child: Row(
                mainAxisAlignment:
                    isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (!isMe) ...[
                    Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: isSelected
                          ? context.colorScheme.primary
                          : context.convoColors.textTertiary,
                      size: 22,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Flexible(child: fullMessage),
                  if (isMe) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: isSelected
                          ? context.colorScheme.primary
                          : context.convoColors.textTertiary,
                      size: 22,
                    ),
                  ],
                ],
              ),
            )
          : fullMessage,
    );
  }

  Widget _buildImageContent(BuildContext context) {
    return GestureDetector(
      onTap: () {
        ImageViewerScreen.show(
          context,
          imageUrl: message.mediaUrl!,
          title: 'Photo',
          timestamp: message.createdAt,
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Hero(
          tag: 'image_${message.mediaUrl}',
          child: Image.network(
            message.mediaUrl!,
            width: double.infinity,
            height: 200,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                height: 180,
                color: Colors.black12,
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            },
            errorBuilder: (context, error, _) {
              return Container(
                height: 140,
                color: Colors.black12,
                child: const Center(
                  child: Icon(Icons.broken_image_rounded, size: 36),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildVideoContent(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (message.thumbnailUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                message.thumbnailUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: 180,
              ),
            ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: AppRadius.borderSm,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.videocam_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    message.fileName ?? 'Video',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyPreview(BuildContext context, bool isMe) {
    final quoteBg = isMe
        ? Colors.black.withValues(alpha: 0.15)
        : context.convoColors.surfaceSubtle;
    final accentLineColor = isMe ? Colors.white : context.colorScheme.primary;

    final previewWidget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: quoteBg,
        borderRadius: AppRadius.borderSm,
        border: Border(left: BorderSide(color: accentLineColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.replyToSenderName ?? 'Replied Message',
            style: AppTypography.labelSmall.copyWith(
              color: isMe ? Colors.white : context.colorScheme.primary,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            message.replyToSnippet ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySmall.copyWith(
              color: isMe
                  ? Colors.white.withValues(alpha: 0.85)
                  : context.convoColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );

    if (onReplyTap != null && message.replyToMessageId != null) {
      return InkWell(
        onTap: () => onReplyTap!(message.replyToMessageId!),
        borderRadius: AppRadius.borderSm,
        child: previewWidget,
      );
    }

    return previewWidget;
  }

  Widget _buildReactionsRow(BuildContext context) {
    final counts = message.reactionCounts;
    final myReaction = message.reactionOfUser(currentUserId);

    return Wrap(
      spacing: 4,
      children: counts.entries.map((entry) {
        final emoji = entry.key;
        final count = entry.value;
        final isMyReaction = myReaction == emoji;

        return AnimatedReactionPill(
          emoji: emoji,
          count: count,
          isReactedByMe: isMyReaction,
          onTap: () => onReact(emoji),
        );
      }).toList(),
    );
  }

  Widget _buildStickerContent(BuildContext context) {
    final stickerMap = message.metadata?['sticker'] is Map
        ? Map<String, dynamic>.from(message.metadata!['sticker'] as Map)
        : null;
    final imagePath = stickerMap?['imagePath'] as String? ?? message.mediaUrl;
    final emoji = stickerMap?['emoji'] as String?;
    final text = stickerMap?['name'] as String? ?? '';

    Widget imageWidget;
    if (imagePath != null && imagePath.isNotEmpty) {
      if (imagePath.startsWith('http')) {
        imageWidget = Image.network(
          imagePath,
          width: 130,
          height: 130,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const SizedBox(
              width: 130,
              height: 130,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          },
          errorBuilder: (_, _, _) =>
              const Icon(Icons.broken_image_rounded, size: 48),
        );
      } else {
        final file = File(imagePath);
        if (file.existsSync()) {
          imageWidget = Image.file(
            file,
            width: 130,
            height: 130,
            fit: BoxFit.contain,
          );
        } else {
          imageWidget = Container(
            width: 120,
            height: 120,
            alignment: Alignment.center,
            child: Text(emoji ?? '🎨', style: const TextStyle(fontSize: 56)),
          );
        }
      }
    } else {
      imageWidget = Container(
        width: 120,
        height: 120,
        alignment: Alignment.center,
        child: Text(emoji ?? '🎨', style: const TextStyle(fontSize: 56)),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(16), child: imageWidget),
        if (text.isNotEmpty &&
            !text.startsWith('Sticker') &&
            text != '🎨 Sticker') ...[
          const SizedBox(height: 4),
          Text(
            text,
            style: AppTypography.bodySmall.copyWith(
              color: isMe ? Colors.white : context.convoColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _MessageActionSheet extends StatelessWidget {
  const _MessageActionSheet({
    required this.message,
    required this.isMe,
    required this.onReply,
    required this.onReact,
    required this.onDelete,
    this.isStarred = false,
    this.onToggleStar,
    this.onSelectMessage,
    this.onForward,
  });

  final MessageModel message;
  final bool isMe;
  final VoidCallback onReply;
  final ValueChanged<String> onReact;
  final VoidCallback onDelete;
  final bool isStarred;
  final VoidCallback? onToggleStar;
  final VoidCallback? onSelectMessage;
  final VoidCallback? onForward;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: context.convoColors.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: context.convoColors.cardBorder, width: 1),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.convoColors.cardBorder,
                borderRadius: AppRadius.borderPill,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Reaction bar (only if message is not deleted)
            if (!message.isDeleted) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: context.convoColors.surfaceSubtle,
                  borderRadius: AppRadius.borderPill,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: MessageBubble.availableReactions.map((emoji) {
                    return InkWell(
                      onTap: () => onReact(emoji),
                      borderRadius: AppRadius.borderPill,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // Action Items
            if (!message.isDeleted) ...[
              ListTile(
                leading: const Icon(Icons.reply_rounded),
                title: const Text('Reply'),
                onTap: onReply,
              ),
              if (onForward != null)
                ListTile(
                  leading: const Icon(Icons.forward_rounded),
                  title: const Text('Forward'),
                  onTap: onForward,
                ),
              if (onToggleStar != null)
                ListTile(
                  leading: Icon(
                    isStarred ? Icons.star_rounded : Icons.star_border_rounded,
                    color: isStarred ? Colors.amber : null,
                  ),
                  title: Text(isStarred ? 'Unstar Message' : 'Star Message'),
                  onTap: onToggleStar,
                ),
              if (message.text.isNotEmpty && !message.isMedia)
                ListTile(
                  leading: const Icon(Icons.copy_rounded),
                  title: const Text('Copy Text'),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: message.text));
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Message copied to clipboard'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              if (message.isImage && message.mediaUrl != null) ...[
                ListTile(
                  leading: const Icon(Icons.fullscreen_rounded),
                  title: const Text('View Full Photo'),
                  onTap: () {
                    Navigator.of(context).pop();
                    ImageViewerScreen.show(
                      context,
                      imageUrl: message.mediaUrl!,
                      title: 'Photo',
                      timestamp: message.createdAt,
                    );
                  },
                ),
              ],
              if (onSelectMessage != null)
                ListTile(
                  leading: const Icon(Icons.check_circle_outline_rounded),
                  title: const Text('Select Message'),
                  onTap: onSelectMessage,
                ),
            ],

            // Delete action
            if (!message.isDeleted)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppColors.error,
                ),
                title: const Text(
                  'Delete Message',
                  style: TextStyle(color: AppColors.error),
                ),
                onTap: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}
