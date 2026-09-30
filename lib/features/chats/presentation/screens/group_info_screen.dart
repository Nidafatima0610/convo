import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/convo_app_bar.dart';
import '../../../../core/widgets/convo_avatar.dart';
import '../../../../core/widgets/convo_badge.dart';
import '../../../../core/widgets/convo_card.dart';
import '../../../auth/domain/models/convo_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/models/conversation_model.dart';
import '../providers/chat_providers.dart';
import 'chat_media_gallery_screen.dart';
import 'starred_messages_screen.dart';

class GroupInfoScreen extends ConsumerStatefulWidget {
  const GroupInfoScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends ConsumerState<GroupInfoScreen> {
  bool _isUploadingPhoto = false;

  void _showEditNameDialog(ConversationModel conversation) {
    final controller = TextEditingController(text: conversation.name ?? '');
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: context.convoColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderXl),
        title: Text(
          'Edit Group Name',
          style: AppTypography.titleLarge.copyWith(
            color: context.convoColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: TextField(
          controller: controller,
          maxLength: 50,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter group name...',
            labelText: 'Group Name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                Navigator.of(dialogCtx).pop();
                await ref
                    .read(chatControllerProvider.notifier)
                    .updateGroupInfo(
                      conversationId: widget.conversationId,
                      name: newName,
                    );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditDescriptionDialog(ConversationModel conversation) {
    final controller =
        TextEditingController(text: conversation.description ?? '');
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: context.convoColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderXl),
        title: Text(
          'Edit Description',
          style: AppTypography.titleLarge.copyWith(
            color: context.convoColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: TextField(
          controller: controller,
          maxLength: 150,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'What is this group about?',
            labelText: 'Description',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              await ref
                  .read(chatControllerProvider.notifier)
                  .updateGroupInfo(
                    conversationId: widget.conversationId,
                    description: controller.text.trim(),
                  );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPhotoPickerSheet(ConversationModel conversation) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.convoColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.lg,
            horizontal: AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: context.convoColors.cardBorder,
                  borderRadius: AppRadius.borderPill,
                ),
              ),
              Text(
                'Change Group Photo',
                style: AppTypography.titleMedium.copyWith(
                  color: context.convoColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: context.colorScheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.camera_alt_rounded,
                    color: context.colorScheme.primary,
                  ),
                ),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _pickAndUploadPhoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.accentPurple.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.photo_library_rounded,
                    color: AppColors.accentPurple,
                  ),
                ),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _pickAndUploadPhoto(ImageSource.gallery);
                },
              ),
              if (conversation.photoUrl != null)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.error,
                    ),
                  ),
                  title: const Text(
                    'Remove Photo',
                    style: TextStyle(color: AppColors.error),
                  ),
                  onTap: () async {
                    Navigator.of(sheetCtx).pop();
                    await ref
                        .read(chatControllerProvider.notifier)
                        .updateGroupInfo(
                          conversationId: widget.conversationId,
                          removePhoto: true,
                        );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    final currentUserId =
        ref.read(authStateChangesProvider).asData?.value?.uid ?? '';
    final mediaService = ref.read(mediaServiceProvider);

    final file = await mediaService.pickProfileImage(source: source);
    if (file == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final downloadUrl = await mediaService.uploadGroupPicture(
        filePath: file.path,
        groupId: widget.conversationId,
        uploaderId: currentUserId,
      );

      if (downloadUrl != null) {
        await ref
            .read(chatControllerProvider.notifier)
            .updateGroupInfo(
              conversationId: widget.conversationId,
              photoUrl: downloadUrl,
            );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update group photo: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  void _showAddMembersSheet(ConversationModel conversation) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.convoColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => _AddMembersModalSheet(
        conversationId: widget.conversationId,
        existingParticipantIds: conversation.participants,
      ),
    );
  }

  void _showLeaveGroupConfirmation(ConversationModel conversation) {
    final currentUserId =
        ref.read(authStateChangesProvider).asData?.value?.uid ?? '';
    final isSoleAdmin =
        conversation.isAdmin(currentUserId) &&
        conversation.admins.where((id) => id != currentUserId).isEmpty &&
        conversation.participants.length > 1;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: context.convoColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderXl),
        title: Row(
          children: [
            const Icon(Icons.exit_to_app_rounded, color: AppColors.error),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Leave Group',
              style: AppTypography.titleLarge.copyWith(
                color: context.convoColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to leave "${conversation.name ?? 'this group'}"?',
              style: AppTypography.bodyMedium.copyWith(
                color: context.convoColors.textSecondary,
              ),
            ),
            if (isSoleAdmin) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Note: As the only admin, another member will automatically be promoted to admin.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              final success = await ref
                  .read(chatControllerProvider.notifier)
                  .leaveGroup(conversationId: widget.conversationId);

              if (mounted && success) {
                // Navigate back to chats tab
                context.go('/chats');
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  void _showMemberActions(
    ConversationModel conversation,
    String memberId,
    String memberName,
    bool isTargetAdmin,
  ) {
    final currentUserId =
        ref.read(authStateChangesProvider).asData?.value?.uid ?? '';
    final isCurrentUserAdmin = conversation.isAdmin(currentUserId);
    final isCreator = conversation.createdBy == memberId;

    if (!isCurrentUserAdmin || memberId == currentUserId) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: context.convoColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.lg,
            horizontal: AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: context.convoColors.cardBorder,
                  borderRadius: AppRadius.borderPill,
                ),
              ),
              Text(
                memberName,
                style: AppTypography.titleMedium.copyWith(
                  color: context.convoColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (!isTargetAdmin)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color:
                          context.colorScheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.shield_outlined,
                      color: context.colorScheme.primary,
                    ),
                  ),
                  title: const Text('Make Group Admin'),
                  onTap: () async {
                    Navigator.of(sheetCtx).pop();
                    await ref
                        .read(chatControllerProvider.notifier)
                        .promoteToAdmin(
                          conversationId: widget.conversationId,
                          memberId: memberId,
                        );
                  },
                )
              else if (!isCreator)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.accentPurple.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      color: AppColors.accentPurple,
                    ),
                  ),
                  title: const Text('Dismiss as Admin'),
                  onTap: () async {
                    Navigator.of(sheetCtx).pop();
                    await ref
                        .read(chatControllerProvider.notifier)
                        .demoteAdmin(
                          conversationId: widget.conversationId,
                          memberId: memberId,
                        );
                  },
                ),
              if (!isCreator)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_remove_rounded,
                      color: AppColors.error,
                    ),
                  ),
                  title: Text(
                    'Remove from Group',
                    style: TextStyle(color: AppColors.error),
                  ),
                  onTap: () async {
                    Navigator.of(sheetCtx).pop();
                    await ref
                        .read(chatControllerProvider.notifier)
                        .removeGroupMember(
                          conversationId: widget.conversationId,
                          memberId: memberId,
                          memberName: memberName,
                        );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId =
        ref.watch(authStateChangesProvider).asData?.value?.uid ?? '';
    final conversationAsync =
        ref.watch(singleConversationProvider(widget.conversationId));

    return Scaffold(
      appBar: const ConvoAppBar(title: 'Group Info'),
      body: conversationAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text(
            'Error loading group: $err',
            style: TextStyle(color: context.convoColors.textSecondary),
          ),
        ),
        data: (conversation) {
          if (conversation == null) {
            return const Center(child: Text('Group not found'));
          }

          final isCurrentUserAdmin = conversation.isAdmin(currentUserId);
          final isMuted = conversation.isMutedFor(currentUserId);
          final groupName = conversation.name ?? 'Group Chat';
          final groupInitials = groupName.isNotEmpty
              ? (groupName.length >= 2
                    ? groupName.substring(0, 2).toUpperCase()
                    : groupName[0].toUpperCase())
              : 'GR';

          return ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            children: [
              // Header Card (DP, Name, Description, Stats)
              ConvoCard(
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        ConvoAvatar(
                          initials: groupInitials,
                          photoUrl: conversation.photoUrl,
                          size: 96,
                          isLoading: _isUploadingPhoto,
                        ),
                        if (isCurrentUserAdmin)
                          GestureDetector(
                            onTap: () => _showPhotoPickerSheet(conversation),
                            child: Container(
                              padding: const EdgeInsets.all(AppSpacing.xs),
                              decoration: BoxDecoration(
                                color: context.colorScheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: context.convoColors.cardBackground,
                                  width: 2.5,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            groupName,
                            textAlign: TextAlign.center,
                            style: AppTypography.titleLarge.copyWith(
                              color: context.convoColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (isCurrentUserAdmin) ...[
                          const SizedBox(width: AppSpacing.xs),
                          IconButton(
                            icon: const Icon(Icons.edit_rounded, size: 18),
                            color: context.colorScheme.primary,
                            tooltip: 'Edit Name',
                            onPressed: () =>
                                _showEditNameDialog(conversation),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Group • ${conversation.participants.length} members',
                      style: AppTypography.bodySmall.copyWith(
                        color: context.convoColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // Description row
                    InkWell(
                      onTap: isCurrentUserAdmin
                          ? () => _showEditDescriptionDialog(conversation)
                          : null,
                      borderRadius: AppRadius.borderMd,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 8,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                conversation.description != null &&
                                        conversation.description!.isNotEmpty
                                    ? conversation.description!
                                    : (isCurrentUserAdmin
                                          ? 'Add group description...'
                                          : 'No description provided.'),
                                textAlign: TextAlign.center,
                                style: AppTypography.bodySmall.copyWith(
                                  color: conversation.description != null
                                      ? context.convoColors.textPrimary
                                      : context.convoColors.textSecondary
                                            .withValues(alpha: 0.6),
                                  fontStyle: conversation.description == null
                                      ? FontStyle.italic
                                      : FontStyle.normal,
                                ),
                              ),
                            ),
                            if (isCurrentUserAdmin) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.edit_note_rounded,
                                size: 16,
                                color: context.colorScheme.primary,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Created ${DateFormatter.formatTimeAgo(conversation.createdAt)}',
                      style: AppTypography.labelSmall.copyWith(
                        color: context.convoColors.textSecondary
                            .withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Notification & Mute Settings Card
              ConvoCard(
                child: SwitchListTile(
                  title: Text(
                    'Mute Notifications',
                    style: AppTypography.titleMedium.copyWith(
                      color: context.convoColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    isMuted
                        ? 'Notifications for this group are muted'
                        : 'Receive alerts when members post messages',
                    style: AppTypography.bodySmall.copyWith(
                      color: context.convoColors.textSecondary,
                    ),
                  ),
                  secondary: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: isMuted
                          ? AppColors.error.withValues(alpha: 0.12)
                          : context.colorScheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isMuted
                          ? Icons.notifications_off_rounded
                          : Icons.notifications_active_rounded,
                      color: isMuted
                          ? AppColors.error
                          : context.colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  value: isMuted,
                  activeThumbColor: context.colorScheme.primary,
                  onChanged: (val) => ref
                      .read(chatControllerProvider.notifier)
                      .toggleGroupMute(
                        conversationId: widget.conversationId,
                        mute: val,
                      ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Media, Links & Files and Starred Messages Card
              ConvoCard(
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: context.colorScheme.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.perm_media_outlined,
                          color: context.colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        'Media, Links & Files',
                        style: AppTypography.titleMedium.copyWith(
                          color: context.convoColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Photos, videos, files and shared links',
                        style: AppTypography.bodySmall.copyWith(
                          color: context.convoColors.textSecondary,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChatMediaGalleryScreen(
                              conversationId: widget.conversationId,
                            ),
                          ),
                        );
                      },
                    ),
                    Divider(color: context.convoColors.cardBorder, height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.star_outline_rounded,
                          color: AppColors.accent,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        'Starred Messages',
                        style: AppTypography.titleMedium.copyWith(
                          color: context.convoColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Saved messages in this group',
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
                      leading: Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.accentPurple.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.search_rounded,
                          color: AppColors.accentPurple,
                          size: 20,
                        ),
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

              const SizedBox(height: AppSpacing.md),

              // Members Card
              ConvoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.sm,
                        AppSpacing.sm,
                        AppSpacing.sm,
                        AppSpacing.xs,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${conversation.participants.length} MEMBERS',
                            style: AppTypography.labelSmall.copyWith(
                              color: context.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            ),
                          ),
                          if (isCurrentUserAdmin)
                            TextButton.icon(
                              icon: const Icon(Icons.person_add_rounded, size: 16),
                              label: const Text('Add'),
                              onPressed: () =>
                                  _showAddMembersSheet(conversation),
                            ),
                        ],
                      ),
                    ),
                    const Divider(),
                    ...conversation.participants.map((memberId) {
                      final name = conversation.memberName(memberId);
                      final photo = conversation.memberPhoto(memberId);
                      final email = conversation.memberEmail(memberId);
                      final isAdmin = conversation.isAdmin(memberId);
                      final isCreator = conversation.createdBy == memberId;
                      final isMe = memberId == currentUserId;

                      return ListTile(
                        leading: ConvoAvatar(
                          initials: name.isNotEmpty
                              ? (name.length >= 2
                                    ? name.substring(0, 2).toUpperCase()
                                    : name[0].toUpperCase())
                              : 'CO',
                          photoUrl: photo,
                          size: 40,
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                isMe ? '$name (You)' : name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.titleMedium.copyWith(
                                  color: context.convoColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (isCreator) ...[
                              const SizedBox(width: AppSpacing.xs),
                              const ConvoBadge(
                                label: 'CREATOR',
                                variant: ConvoBadgeVariant.primary,
                              ),
                            ] else if (isAdmin) ...[
                              const SizedBox(width: AppSpacing.xs),
                              const ConvoBadge(
                                label: 'ADMIN',
                                variant: ConvoBadgeVariant.accent,
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          email != null && email.isNotEmpty
                              ? email
                              : 'Member',
                          style: AppTypography.bodySmall.copyWith(
                            color: context.convoColors.textSecondary,
                          ),
                        ),
                        trailing: isCurrentUserAdmin && !isMe
                            ? IconButton(
                                icon: const Icon(Icons.more_vert_rounded),
                                onPressed: () => _showMemberActions(
                                  conversation,
                                  memberId,
                                  name,
                                  isAdmin,
                                ),
                              )
                            : null,
                        onTap: isCurrentUserAdmin && !isMe
                            ? () => _showMemberActions(
                                  conversation,
                                  memberId,
                                  name,
                                  isAdmin,
                                )
                            : null,
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Danger Zone: Leave Group
              OutlinedButton.icon(
                icon: const Icon(Icons.exit_to_app_rounded, color: AppColors.error),
                label: const Text('Leave Group'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.borderLg,
                  ),
                ),
                onPressed: () => _showLeaveGroupConfirmation(conversation),
              ),

              const SizedBox(height: AppSpacing.xl),
            ],
          );
        },
      ),
    );
  }
}

class _AddMembersModalSheet extends ConsumerStatefulWidget {
  const _AddMembersModalSheet({
    required this.conversationId,
    required this.existingParticipantIds,
  });

  final String conversationId;
  final List<String> existingParticipantIds;

  @override
  ConsumerState<_AddMembersModalSheet> createState() =>
      _AddMembersModalSheetState();
}

class _AddMembersModalSheetState extends ConsumerState<_AddMembersModalSheet> {
  final TextEditingController _searchController = TextEditingController();
  final List<ConvoUser> _selected = [];
  String _query = '';
  bool _isAdding = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggle(ConvoUser user) {
    setState(() {
      final index = _selected.indexWhere((u) => u.uid == user.uid);
      if (index >= 0) {
        _selected.removeAt(index);
      } else {
        _selected.add(user);
      }
    });
  }

  Future<void> _submit() async {
    if (_selected.isEmpty) return;
    setState(() => _isAdding = true);
    try {
      final success = await ref
          .read(chatControllerProvider.notifier)
          .addGroupMembers(
            conversationId: widget.conversationId,
            newMembers: _selected,
          );

      if (mounted && success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added ${_selected.length} member${_selected.length > 1 ? 's' : ''} to group',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add members: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAdding = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(searchedUsersProvider(_query));

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: context.convoColors.cardBorder,
              borderRadius: AppRadius.borderPill,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Add Members',
                style: AppTypography.titleMedium.copyWith(
                  color: context.convoColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              FilledButton(
                onPressed: _selected.isNotEmpty && !_isAdding ? _submit : null,
                child: _isAdding
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text('Add (${_selected.length})'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search contacts to add...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
            ),
            onChanged: (val) => setState(() => _query = val),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: usersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
              data: (users) {
                // Filter out users who are already members
                final candidates = users
                    .where((u) => !widget.existingParticipantIds.contains(u.uid))
                    .toList();

                if (candidates.isEmpty) {
                  return Center(
                    child: Text(
                      'No new contacts to add',
                      style: TextStyle(
                        color: context.convoColors.textSecondary,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: candidates.length,
                  itemBuilder: (context, index) {
                    final user = candidates[index];
                    final isChecked =
                        _selected.any((u) => u.uid == user.uid);

                    return ListTile(
                      leading: ConvoAvatar(
                        initials: user.initials,
                        photoUrl: user.photoUrl,
                        size: 38,
                      ),
                      title: Text(
                        user.name,
                        style: AppTypography.titleMedium.copyWith(
                          color: context.convoColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        user.email,
                        style: AppTypography.bodySmall.copyWith(
                          color: context.convoColors.textSecondary,
                        ),
                      ),
                      trailing: Checkbox(
                        value: isChecked,
                        activeColor: context.colorScheme.primary,
                        onChanged: (_) => _toggle(user),
                      ),
                      onTap: () => _toggle(user),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
