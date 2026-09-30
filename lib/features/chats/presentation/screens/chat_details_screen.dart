import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/convo_app_bar.dart';
import '../../../../core/widgets/convo_avatar.dart';
import '../../../../core/widgets/convo_badge.dart';
import '../../../../core/widgets/convo_card.dart';
import '../../../auth/domain/models/convo_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../calls/domain/models/call_model.dart';
import '../../../calls/presentation/providers/call_providers.dart';
import '../../../profile/domain/privacy_helper.dart';
import '../providers/chat_providers.dart';
import 'chat_media_gallery_screen.dart';
import 'starred_messages_screen.dart';

class ChatDetailsScreen extends ConsumerStatefulWidget {
  const ChatDetailsScreen({
    super.key,
    required this.conversationId,
    required this.otherUser,
  });

  final String conversationId;
  final ConvoUser otherUser;

  @override
  ConsumerState<ChatDetailsScreen> createState() => _ChatDetailsScreenState();
}

class _ChatDetailsScreenState extends ConsumerState<ChatDetailsScreen> {
  bool _notificationsMuted = false;

  void _showClearChatConfirmation() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.convoColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderXl),
        title: Row(
          children: [
            const Icon(Icons.delete_sweep_rounded, color: AppColors.error),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Clear Conversation',
              style: AppTypography.titleLarge.copyWith(
                color: context.convoColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to clear all messages in this conversation? This cannot be undone.',
          style: AppTypography.bodyMedium.copyWith(
            color: context.convoColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await ref
                  .read(chatControllerProvider.notifier)
                  .clearChat(widget.conversationId);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Conversation cleared'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                context.pop(); // Pop details back to chat
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Future<void> _startCall(ConvoUser receiver, {required bool isVideo}) async {
    final currentUser = ref.read(currentUserProfileProvider).asData?.value;
    if (currentUser == null) return;

    final success = await ref
        .read(activeCallControllerProvider.notifier)
        .startCall(
          caller: currentUser,
          receiver: receiver,
          type: isVideo ? CallType.video : CallType.voice,
        );

    if (success && mounted) {
      context.push('/call/active');
    }
  }

  @override
  Widget build(BuildContext context) {
    final liveUser =
        ref.watch(userPresenceProvider(widget.otherUser.uid)).asData?.value ??
        widget.otherUser;
    final currentUser = ref.watch(currentUserProfileProvider).asData?.value;
    final isBlockedByMe =
        currentUser?.isUserBlocked(widget.otherUser.uid) ?? false;

    final canSeePhoto = PrivacyHelper.canViewPhoto(
      targetUser: liveUser,
      viewerUserId: currentUser?.uid,
      hasConversation: true,
    );
    final canSeeOnline = PrivacyHelper.canViewOnline(
      targetUser: liveUser,
      viewerUserId: currentUser?.uid,
      hasConversation: true,
    );
    final canSeeBio = PrivacyHelper.canViewBio(
      targetUser: liveUser,
      viewerUserId: currentUser?.uid,
      hasConversation: true,
    );

    final messagesAsync = ref.watch(
      conversationMessagesProvider(widget.conversationId),
    );

    final mediaMessages =
        messagesAsync.asData?.value
            .where((m) => m.isMedia && !m.isDeleted && m.mediaUrl != null)
            .toList() ??
        [];

    final initials = liveUser.name.isNotEmpty
        ? (liveUser.name.length >= 2
              ? liveUser.name.substring(0, 2).toUpperCase()
              : liveUser.name[0].toUpperCase())
        : 'CO';

    return Scaffold(
      appBar: ConvoAppBar(
        title: 'Conversation Info',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Column(
            children: [
              // Avatar & User Header
              Center(
                child: Column(
                  children: [
                    ConvoAvatar(
                      initials: initials,
                      photoUrl: canSeePhoto ? liveUser.photoUrl : null,
                      size: 88,
                      status: canSeeOnline
                          ? (liveUser.isOnline
                                ? ConvoAvatarStatus.online
                                : ConvoAvatarStatus.offline)
                          : ConvoAvatarStatus.none,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      liveUser.name,
                      style: AppTypography.headlineLarge.copyWith(
                        color: context.convoColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (canSeeBio &&
                        liveUser.bio != null &&
                        liveUser.bio!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        liveUser.bio!.trim(),
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyMedium.copyWith(
                          color: context.convoColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      liveUser.email,
                      style: AppTypography.bodySmall.copyWith(
                        color: context.convoColors.textTertiary,
                      ),
                    ),
                    if (isBlockedByMe) ...[
                      const SizedBox(height: AppSpacing.sm),
                      const ConvoBadge(
                        label: 'BLOCKED',
                        variant: ConvoBadgeVariant.warning,
                        icon: Icons.block_rounded,
                      ),
                    ] else if (canSeeOnline) ...[
                      const SizedBox(height: AppSpacing.sm),
                      ConvoBadge(
                        label: liveUser.isOnline ? 'ACTIVE NOW' : 'OFFLINE',
                        variant: liveUser.isOnline
                            ? ConvoBadgeVariant.accent
                            : ConvoBadgeVariant.subtle,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),

                    // Quick Action Buttons Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _DetailActionButton(
                          icon: Icons.phone_outlined,
                          label: 'Voice',
                          onTap: () => _startCall(liveUser, isVideo: false),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        _DetailActionButton(
                          icon: Icons.videocam_outlined,
                          label: 'Video',
                          onTap: () => _startCall(liveUser, isVideo: true),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        _DetailActionButton(
                          icon: Icons.search_rounded,
                          label: 'Search',
                          onTap: () {
                            context.pop();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // Shared Media Section
              ConvoCard(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatMediaGalleryScreen(
                        conversationId: widget.conversationId,
                      ),
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.perm_media_outlined,
                          size: 20,
                          color: context.colorScheme.primary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Media, Links & Files',
                            style: AppTypography.titleMedium.copyWith(
                              color: context.convoColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${mediaMessages.length}',
                              style: AppTypography.bodySmall.copyWith(
                                color: context.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: context.convoColors.textTertiary,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (mediaMessages.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No photos, videos, or files shared yet.',
                          style: AppTypography.bodySmall.copyWith(
                            color: context.convoColors.textTertiary,
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        height: 70,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: mediaMessages.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final m = mediaMessages[index];
                            if (m.isImage) {
                              return ClipRRect(
                                borderRadius: AppRadius.borderSm,
                                child: Image.network(
                                  m.mediaUrl!,
                                  width: 70,
                                  height: 70,
                                  fit: BoxFit.cover,
                                ),
                              );
                            }
                            return Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                color: context.convoColors.surfaceSubtle,
                                borderRadius: AppRadius.borderSm,
                              ),
                              child: Icon(
                                m.isVideo
                                    ? Icons.videocam_rounded
                                    : Icons.mic_rounded,
                                color: context.colorScheme.primary,
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Settings & Controls
              ConvoCard(
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: Icon(
                        _notificationsMuted
                            ? Icons.notifications_off_outlined
                            : Icons.notifications_outlined,
                        color: context.colorScheme.primary,
                      ),
                      title: Text(
                        'Mute Notifications',
                        style: AppTypography.titleMedium.copyWith(
                          color: context.convoColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Silence notifications from this conversation',
                        style: AppTypography.bodySmall.copyWith(
                          color: context.convoColors.textSecondary,
                        ),
                      ),
                      value: _notificationsMuted,
                      onChanged: (val) {
                        setState(() => _notificationsMuted = val);
                      },
                    ),
                    Divider(color: context.convoColors.cardBorder, height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.star_outline_rounded,
                        color: AppColors.accent,
                      ),
                      title: Text(
                        'Starred Messages',
                        style: AppTypography.titleMedium.copyWith(
                          color: context.convoColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Saved messages in this conversation',
                        style: AppTypography.bodySmall.copyWith(
                          color: context.convoColors.textSecondary,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => StarredMessagesScreen(
                              conversationId: widget.conversationId,
                            ),
                          ),
                        );
                      },
                    ),
                    Divider(color: context.convoColors.cardBorder, height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.search_rounded,
                        color: context.colorScheme.primary,
                      ),
                      title: Text(
                        'Search in Conversation',
                        style: AppTypography.titleMedium.copyWith(
                          color: context.convoColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        context.pop(true);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // Danger Zone: Block / Unblock Contact
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _toggleBlockUser(isBlockedByMe),
                  icon: Icon(
                    isBlockedByMe
                        ? Icons.check_circle_outline_rounded
                        : Icons.block_rounded,
                    color: isBlockedByMe ? AppColors.primary : AppColors.error,
                    size: 18,
                  ),
                  label: Text(
                    isBlockedByMe ? 'Unblock Contact' : 'Block Contact',
                    style: AppTypography.titleMedium.copyWith(
                      color:
                          isBlockedByMe ? AppColors.primary : AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: (isBlockedByMe
                              ? AppColors.primary
                              : AppColors.error)
                          .withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.borderMd,
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Danger Zone: Clear Chat
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showClearChatConfirmation,
                  icon: const Icon(
                    Icons.delete_sweep_rounded,
                    color: AppColors.error,
                    size: 18,
                  ),
                  label: Text(
                    'Clear Conversation',
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: AppColors.error.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.borderMd,
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleBlockUser(bool currentlyBlocked) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.convoColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderXl),
        title: Row(
          children: [
            Icon(
              currentlyBlocked
                  ? Icons.check_circle_outline_rounded
                  : Icons.block_rounded,
              color: currentlyBlocked ? AppColors.primary : AppColors.error,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              currentlyBlocked ? 'Unblock User?' : 'Block User?',
              style: AppTypography.titleLarge.copyWith(
                color: context.convoColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Text(
          currentlyBlocked
              ? 'This contact will be able to send you messages and view your permitted profile details.'
              : 'Blocked contacts will not be able to send you messages. Historical messages will remain intact.',
          style: AppTypography.bodyMedium.copyWith(
            color: context.convoColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              if (currentlyBlocked) {
                await ref
                    .read(profileControllerProvider.notifier)
                    .unblockUser(widget.otherUser.uid);
              } else {
                await ref
                    .read(profileControllerProvider.notifier)
                    .blockUser(widget.otherUser.uid);
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      currentlyBlocked
                          ? 'Contact unblocked.'
                          : 'Contact blocked.',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor:
                  currentlyBlocked ? AppColors.primary : AppColors.error,
            ),
            child: Text(currentlyBlocked ? 'Unblock' : 'Block'),
          ),
        ],
      ),
    );
  }
}

class _DetailActionButton extends StatelessWidget {
  const _DetailActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.borderMd,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: context.colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: context.colorScheme.primary, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: context.convoColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
