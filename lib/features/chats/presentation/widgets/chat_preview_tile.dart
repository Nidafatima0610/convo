import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/convo_avatar.dart';
import '../../domain/models/conversation_model.dart';
import 'chat_avatar.dart';

/// Reusable Chat Preview Tile displaying a conversation's avatar, name,
/// last message preview, timestamp, unread badge, pinned/muted states,
/// swipe gestures, and long-press interactions.
class ChatPreviewTile extends StatelessWidget {
  const ChatPreviewTile({
    super.key,
    required this.conversation,
    required this.currentUserId,
    required this.isPinned,
    required this.isMuted,
    required this.isArchived,
    this.isOnline = false,
    this.isNearbyConnected = false,
    this.photoUrl,
    required this.displayName,
    required this.onTap,
    required this.onLongPress,
    this.onPinToggle,
    this.onMuteToggle,
    this.onArchiveToggle,
    this.onDelete,
  });

  final ConversationModel conversation;
  final String currentUserId;
  final bool isPinned;
  final bool isMuted;
  final bool isArchived;
  final bool isOnline;
  final bool isNearbyConnected;
  final String? photoUrl;
  final String displayName;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onPinToggle;
  final VoidCallback? onMuteToggle;
  final VoidCallback? onArchiveToggle;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final unreadCount = conversation.unreadCountFor(currentUserId);
    final isGroup = conversation.isGroup;
    final isLastFromMe = conversation.lastMessageSenderId == currentUserId;

    final initials = displayName.isNotEmpty
        ? (displayName.length >= 2
            ? displayName.substring(0, 2).toUpperCase()
            : displayName[0].toUpperCase())
        : (isGroup ? 'GP' : 'CO');

    final lastMessageTime = DateFormatter.formatConversationTime(
      conversation.lastMessageAt,
    );

    // Build the tile body
    final tile = Material(
      color: isPinned
          ? context.colorScheme.primary.withValues(alpha: 0.04)
          : Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 4,
        ),
        onTap: onTap,
        onLongPress: onLongPress,
        leading: ChatAvatar(
          initials: initials,
          photoUrl: photoUrl,
          size: 52,
          isGroup: isGroup,
          status: isOnline ? ConvoAvatarStatus.online : ConvoAvatarStatus.offline,
          isNearbyConnected: isNearbyConnected,
        ),
        title: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleMedium.copyWith(
                        color: context.convoColors.textPrimary,
                        fontWeight: unreadCount > 0
                            ? FontWeight.w800
                            : (isPinned ? FontWeight.w700 : FontWeight.w600),
                      ),
                    ),
                  ),
                  if (isPinned) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.push_pin_rounded,
                      size: 14,
                      color: context.colorScheme.primary,
                    ),
                  ],
                  if (isMuted) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.notifications_off_rounded,
                      size: 14,
                      color: context.convoColors.textTertiary,
                    ),
                  ],
                  if (isGroup) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: context.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'GROUP',
                        style: TextStyle(
                          color: context.colorScheme.primary,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                  if (conversation.hasMood && conversation.moodEmoji != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      conversation.moodEmoji!,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              lastMessageTime,
              style: AppTypography.labelSmall.copyWith(
                color: unreadCount > 0
                    ? context.colorScheme.primary
                    : context.convoColors.textTertiary,
                fontWeight: unreadCount > 0 ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
        subtitle: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  _buildMessageIcon(context, conversation.lastMessage, unreadCount),
                  Expanded(
                    child: Text(
                      conversation.lastMessage.isEmpty
                          ? 'Started a new conversation'
                          : (isLastFromMe
                              ? 'You: ${conversation.lastMessage}'
                              : conversation.lastMessage),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: unreadCount > 0
                            ? context.convoColors.textPrimary
                            : (isMuted
                                ? context.convoColors.textTertiary
                                : context.convoColors.textSecondary),
                        fontWeight: unreadCount > 0
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: AppRadius.borderPill,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : unreadCount.toString(),
                  style: AppTypography.labelSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    // If swipe actions are not provided, return simple tile
    if (onPinToggle == null && onArchiveToggle == null && onDelete == null) {
      return tile;
    }

    // Dismissible with swipe actions:
    // Swipe Start -> End (right): Pin / Archive
    // Swipe End -> Start (left): Delete / Mute
    return Dismissible(
      key: Key('chat_tile_${conversation.id}'),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        HapticFeedback.mediumImpact();
        if (direction == DismissDirection.startToEnd) {
          // Right swipe: Quick Toggle Pin
          onPinToggle?.call();
          return false;
        } else {
          // Left swipe: Trigger delete confirmation or options
          if (onDelete != null) {
            onDelete!();
          }
          return false;
        }
      },
      background: Container(
        color: context.colorScheme.primary,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Row(
          children: [
            Icon(
              isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              isPinned ? 'Unpin' : 'Pin',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        color: AppColors.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
          ],
        ),
      ),
      child: tile,
    );
  }

  Widget _buildMessageIcon(
    BuildContext context,
    String lastMessage,
    int unreadCount,
  ) {
    final iconColor = unreadCount > 0
        ? context.colorScheme.primary
        : context.convoColors.textTertiary;

    if (lastMessage == 'Photo') {
      return Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Icon(Icons.photo_camera_rounded, size: 14, color: iconColor),
      );
    } else if (lastMessage == 'Video') {
      return Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Icon(Icons.videocam_rounded, size: 14, color: iconColor),
      );
    } else if (lastMessage == 'Voice message') {
      return Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Icon(Icons.mic_rounded, size: 14, color: iconColor),
      );
    } else if (lastMessage.contains('Sticker')) {
      return const Padding(
        padding: EdgeInsets.only(right: 4),
        child: Text('🎨 ', style: TextStyle(fontSize: 11)),
      );
    } else if (lastMessage.startsWith('🎲')) {
      return const Padding(
        padding: EdgeInsets.only(right: 4),
        child: Text('🎲 ', style: TextStyle(fontSize: 11)),
      );
    } else if (lastMessage.startsWith('⏳')) {
      return const Padding(
        padding: EdgeInsets.only(right: 4),
        child: Text('⏳ ', style: TextStyle(fontSize: 11)),
      );
    }
    return const SizedBox.shrink();
  }
}
