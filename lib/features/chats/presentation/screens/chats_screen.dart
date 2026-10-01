import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/convo_app_bar.dart';
import '../../../../core/widgets/convo_avatar.dart';
import '../../../../core/widgets/convo_badge.dart';
import '../../../../core/widgets/convo_empty_state.dart';
import '../../../auth/domain/models/convo_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../profile/domain/privacy_helper.dart';
import 'package:flutter/services.dart';
import '../../domain/models/conversation_model.dart';
import '../providers/chat_providers.dart';
import '../widgets/user_search_modal.dart';
import '../widgets/chat_preview_tile.dart';
import '../../../../services/local_storage/chat_preferences_service.dart';

class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({super.key});

  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends ConsumerState<ChatsScreen> {
  int _selectedFilterIndex = 0;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _filters = const ['All', 'Unread', 'Groups', 'Mesh'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onNewChatPressed() {
    UserSearchModal.show(context);
  }

  void _openConversation(ConversationModel conversation, String currentUserId) {
    if (conversation.isGroup) {
      context.push('/chat/${conversation.id}');
      return;
    }

    final otherId = conversation.otherParticipantId(currentUserId);
    final otherDetails = conversation.participantDetails[otherId];

    final otherUser = ConvoUser(
      uid: otherId,
      name: otherDetails?['name'] as String? ??
          conversation.otherParticipantName(currentUserId),
      email: otherDetails?['email'] as String? ?? '',
      photoUrl: otherDetails?['photoUrl'] as String? ??
          conversation.otherParticipantPhoto(currentUserId),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    context.push('/chat/${conversation.id}', extra: otherUser);
  }

  void _confirmDeleteConversation(
    BuildContext context,
    ConversationModel conversation,
    String displayName,
  ) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: context.convoColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderXl),
        title: Text(
          'Delete Conversation?',
          style: AppTypography.titleLarge.copyWith(
            color: context.convoColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this conversation with "$displayName"? Messages will be removed.',
          style: AppTypography.bodyMedium.copyWith(
            color: context.convoColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              ref
                  .read(chatControllerProvider.notifier)
                  .deleteConversation(conversation.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Deleted conversation with $displayName'),
                  behavior: SnackBarBehavior.floating,
                  action: SnackBarAction(
                    label: 'Undo',
                    onPressed: () {
                      ref
                          .read(deletedChatIdsProvider.notifier)
                          .restoreChat(conversation.id);
                    },
                  ),
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showConversationOptions(
    BuildContext context,
    ConversationModel conversation,
    bool isPinned,
    bool isArchived,
    bool isMuted,
    String displayName,
    String currentUserId,
  ) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: context.convoColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.convoColors.cardBorder,
                borderRadius: AppRadius.borderPill,
              ),
            ),
            ListTile(
              leading: Icon(
                isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                color: context.colorScheme.primary,
              ),
              title: Text(isPinned ? 'Unpin Conversation' : 'Pin to Top'),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                ref
                    .read(pinnedChatIdsProvider.notifier)
                    .togglePin(conversation.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isPinned ? 'Chat unpinned' : 'Chat pinned to top',
                    ),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(
                isArchived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
                color: context.colorScheme.primary,
              ),
              title: Text(
                isArchived ? 'Unarchive Conversation' : 'Archive Conversation',
              ),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                ref
                    .read(archivedChatIdsProvider.notifier)
                    .toggleArchive(conversation.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isArchived ? 'Chat unarchived' : 'Chat archived',
                    ),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(
                isMuted
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_off_outlined,
                color: context.colorScheme.primary,
              ),
              title: Text(
                isMuted ? 'Unmute Notifications' : 'Mute Notifications',
              ),
              onTap: () async {
                Navigator.of(sheetCtx).pop();
                await ref
                    .read(chatControllerProvider.notifier)
                    .toggleGroupMute(
                      conversationId: conversation.id,
                      mute: !isMuted,
                    );
              },
            ),
            ListTile(
              leading: const Icon(Icons.mark_chat_read_rounded),
              title: const Text('Mark as Read'),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                ref
                    .read(chatControllerProvider.notifier)
                    .markAsRead(conversation.id);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
              ),
              title: const Text(
                'Delete Conversation',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _confirmDeleteConversation(context, conversation, displayName);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId =
        ref.watch(authStateChangesProvider).asData?.value?.uid ?? '';
    final currentUserProfile =
        ref.watch(currentUserProfileProvider).asData?.value;
    final conversationsAsync = ref.watch(userConversationsProvider);

    final currentUserInitials = currentUserProfile?.initials ??
        (currentUserProfile?.name.isNotEmpty == true
            ? currentUserProfile!.name[0].toUpperCase()
            : 'CO');

    return Scaffold(
      appBar: ConvoAppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.md),
          child: Center(
            child: Semantics(
              label: 'View profile',
              button: true,
              child: InkWell(
                onTap: () => context.push(AppRoutes.profile),
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.brandGradient,
                  ),
                  child: ConvoAvatar(
                    initials: currentUserInitials,
                    photoUrl: currentUserProfile?.photoUrl,
                    size: 38,
                    status: ConvoAvatarStatus.online,
                  ),
                ),
              ),
            ),
          ),
        ),
        titleWidget: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppColors.brandGradient.createShader(bounds),
                  child: Text(
                    AppConstants.appName,
                    style: AppTypography.titleLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent,
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Text(
              'Encrypted • Mesh Ready',
              style: AppTypography.labelSmall.copyWith(
                color: context.convoColors.textTertiary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close_rounded : Icons.search_rounded,
              color: context.convoColors.textPrimary,
            ),
            tooltip: AppStrings.search,
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) _searchController.clear();
              });
            },
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: context.colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_rounded,
                color: context.colorScheme.primary,
                size: 20,
              ),
            ),
            tooltip: AppStrings.newChat,
            onPressed: _onNewChatPressed,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_isSearching) _buildSearchBar(),
            Expanded(
              child: conversationsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.error,
                          size: 44,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Error loading conversations',
                          style: AppTypography.titleMedium.copyWith(
                            color: context.convoColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          error.toString(),
                          textAlign: TextAlign.center,
                          style: AppTypography.bodySmall.copyWith(
                            color: context.convoColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        FilledButton.tonal(
                          onPressed: () =>
                              ref.refresh(userConversationsProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (conversations) {
                  return Column(
                    children: [
                      if (!_isSearching && conversations.isNotEmpty)
                        _buildActiveConversationsRow(
                          context,
                          conversations,
                          currentUserId,
                        ),
                      _buildFilterChips(),
                      Expanded(
                        child: _buildConversationList(
                          context,
                          conversations,
                          currentUserId,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: AppRadius.borderLg,
          gradient: AppColors.brandGradient,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          heroTag: 'chats_new_chat_fab',
          onPressed: _onNewChatPressed,
          icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.white),
          label: Text(
            AppStrings.newChat,
            style: AppTypography.labelLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          highlightElevation: 0,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
        ),
      ),
    );
  }

  Widget _buildActiveConversationsRow(
    BuildContext context,
    List<ConversationModel> conversations,
    String currentUserId,
  ) {
    final directConversations =
        conversations.where((c) => !c.isGroup).take(12).toList();

    return Container(
      height: 96,
      margin: const EdgeInsets.only(top: AppSpacing.xs, bottom: 2),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: directConversations.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          if (index == 0) {
            // Nearby Radar shortcut
            return InkWell(
              onTap: () => context.go(AppRoutes.nearby),
              borderRadius: BorderRadius.circular(28),
              child: SizedBox(
                width: 62,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.meshGradient,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.28),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.radar_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Nearby',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelSmall.copyWith(
                        color: context.convoColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final conv = directConversations[index - 1];
          final otherId = conv.otherParticipantId(currentUserId);
          final otherName = conv.otherParticipantName(currentUserId);
          final firstName = otherName.trim().split(' ').first;
          final initials = otherName.isNotEmpty
              ? (otherName.length >= 2
                    ? otherName.substring(0, 2).toUpperCase()
                    : otherName[0].toUpperCase())
              : 'CO';

          final presence =
              ref.watch(userPresenceProvider(otherId)).asData?.value;
          final isOnline = presence?.isOnline ?? false;

          return InkWell(
            onTap: () => _openConversation(conv, currentUserId),
            borderRadius: BorderRadius.circular(28),
            child: SizedBox(
              width: 62,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isOnline
                          ? AppColors.brandGradient
                          : LinearGradient(
                              colors: [
                                context.convoColors.cardBorder,
                                context.convoColors.cardBorder,
                              ],
                            ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(1.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.convoColors.cardBackground,
                      ),
                      child: ConvoAvatar(
                        initials: initials,
                        photoUrl: conv.otherParticipantPhoto(currentUserId),
                        size: 44,
                        status: isOnline
                            ? ConvoAvatarStatus.online
                            : ConvoAvatarStatus.offline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    firstName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSmall.copyWith(
                      color: context.convoColors.textPrimary,
                      fontWeight:
                          isOnline ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: context.convoColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: context.colorScheme.primary.withValues(alpha: 0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: context.colorScheme.primary.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          autofocus: true,
          style: AppTypography.bodyMedium.copyWith(
            color: context.convoColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: AppStrings.searchChatsHint,
            hintStyle: AppTypography.bodyMedium.copyWith(
              color: context.convoColors.textTertiary,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: context.colorScheme.primary,
              size: 22,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear_rounded,
                      size: 18,
                      color: context.convoColors.textTertiary,
                    ),
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                      });
                    },
                  )
                : null,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 12,
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: _filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final isSelected = _selectedFilterIndex == index;
          final title = _filters[index];

          return ChoiceChip(
            label: Text(title),
            selected: isSelected,
            onSelected: (selected) {
              if (selected) {
                setState(() => _selectedFilterIndex = index);
              }
            },
            showCheckmark: false,
            labelStyle: AppTypography.labelMedium.copyWith(
              color: isSelected
                  ? Colors.white
                  : context.convoColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
            backgroundColor: context.convoColors.surfaceSubtle,
            selectedColor: index == 3
                ? AppColors.accent
                : context.colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.borderPill,
              side: BorderSide(
                color: isSelected
                    ? Colors.transparent
                    : context.convoColors.cardBorder,
                width: 0.8,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildConversationList(
    BuildContext context,
    List<ConversationModel> conversations,
    String currentUserId,
  ) {
    final pinnedIds = ref.watch(pinnedChatIdsProvider);
    final archivedIds = ref.watch(archivedChatIdsProvider);
    final deletedIds = ref.watch(deletedChatIdsProvider);

    // 1. Filter out archived and deleted conversations from the main chat list (unless actively searching or viewing another tab)
    var filtered = conversations.where((c) {
      if (deletedIds.contains(c.id)) return false;
      if (_searchController.text.trim().isNotEmpty) return true;
      return !archivedIds.contains(c.id);
    }).toList();

    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((conv) {
        final name = conv.isGroup
            ? (conv.name ?? 'Group').toLowerCase()
            : conv.otherParticipantName(currentUserId).toLowerCase();
        final lastMsg = conv.lastMessage.toLowerCase();
        return name.contains(query) || lastMsg.contains(query);
      }).toList();
    }

    // 2. Filter by tab chip
    if (_selectedFilterIndex == 1) {
      // Unread only
      filtered = filtered
          .where((conv) => conv.unreadCountFor(currentUserId) > 0)
          .toList();
    } else if (_selectedFilterIndex == 2) {
      // Groups
      filtered = filtered.where((conv) => conv.isGroup).toList();
    } else if (_selectedFilterIndex == 3) {
      // Mesh placeholder (0 for now)
      filtered = [];
    }

    // 3. Sort: Pinned conversations at the top, then by updatedAt desc
    filtered.sort((a, b) {
      final aPinned = pinnedIds.contains(a.id);
      final bPinned = pinnedIds.contains(b.id);
      if (aPinned && !bPinned) return -1;
      if (!aPinned && bPinned) return 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });

    final bool showArchivedBanner = archivedIds.isNotEmpty &&
        _searchController.text.trim().isEmpty &&
        _selectedFilterIndex == 0;

    if (filtered.isEmpty && !showArchivedBanner) {
      if (_searchController.text.isNotEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 48,
                  color: context.convoColors.textTertiary,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'No conversations found',
                  style: AppTypography.titleMedium.copyWith(
                    color: context.convoColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'No active chat matching "${_searchController.text.trim()}"',
                  style: AppTypography.bodySmall.copyWith(
                    color: context.convoColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: () => UserSearchModal.show(context),
                  icon: const Icon(Icons.person_search_rounded, size: 18),
                  label: const Text('Search Registered Users'),
                ),
              ],
            ),
          ),
        );
      }

      if (_selectedFilterIndex == 1) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.mark_chat_read_rounded,
                size: 48,
                color: context.colorScheme.primary.withValues(alpha: 0.7),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'No Unread Messages',
                style: AppTypography.titleMedium.copyWith(
                  color: context.convoColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'You are all caught up on all your conversations!',
                style: AppTypography.bodySmall.copyWith(
                  color: context.convoColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      }

      if (_selectedFilterIndex == 2) {
        return ConvoEmptyState(
          icon: Icons.groups_rounded,
          title: 'No Groups Yet',
          subtitle:
              'Create a group to stay connected with friends, family, or teammates!',
          actionLabel: 'Create Group',
          actionIcon: Icons.add_rounded,
          badge: const ConvoBadge(
            label: 'COMMUNITY',
            variant: ConvoBadgeVariant.accent,
            icon: Icons.group_work_rounded,
          ),
          onActionPressed: () => context.push(AppRoutes.createGroup),
        );
      }

      // Default high-polish empty state
      return ConvoEmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: AppStrings.chatsEmptyTitle,
        subtitle: AppStrings.chatsEmptySubtitle,
        actionLabel: AppStrings.newChat,
        actionIcon: Icons.add_comment_rounded,
        badge: const ConvoBadge(
          label: 'ENCRYPTED MESSAGING',
          variant: ConvoBadgeVariant.primary,
          icon: Icons.lock_outline_rounded,
        ),
        onActionPressed: _onNewChatPressed,
      );
    }

    final totalItemCount = filtered.length + (showArchivedBanner ? 1 : 0);

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: totalItemCount,
      separatorBuilder: (_, _) => Divider(
        color: context.convoColors.cardBorder,
        height: 1,
        indent: 72,
        endIndent: AppSpacing.lg,
      ),
      itemBuilder: (context, index) {
        if (showArchivedBanner && index == 0) {
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: 2,
            ),
            leading: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: context.convoColors.surfaceSubtle,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.archive_outlined,
                color: context.colorScheme.primary,
                size: 24,
              ),
            ),
            title: Text(
              'Archived Chats',
              style: AppTypography.titleMedium.copyWith(
                color: context.convoColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              '${archivedIds.length} archived conversation${archivedIds.length > 1 ? 's' : ''}',
              style: AppTypography.bodySmall.copyWith(
                color: context.convoColors.textSecondary,
              ),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: context.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: AppRadius.borderPill,
              ),
              child: Text(
                '${archivedIds.length}',
                style: AppTypography.labelSmall.copyWith(
                  color: context.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            onTap: () => context.push(AppRoutes.archivedChats),
          );
        }

        final convIndex = showArchivedBanner ? index - 1 : index;
        final conversation = filtered[convIndex];
        final isGroup = conversation.isGroup;
        final isPinned = pinnedIds.contains(conversation.id);
        final isArchived = archivedIds.contains(conversation.id);
        final isMuted = conversation.isMutedFor(currentUserId);
        final displayName = isGroup
            ? (conversation.name ?? 'Group')
            : conversation.otherParticipantName(currentUserId);
        final otherId = isGroup
            ? ''
            : conversation.otherParticipantId(currentUserId);

        // Watch live presence of other user (only for direct 1-to-1 chats)
        final otherUserPresence = isGroup
            ? null
            : ref.watch(userPresenceProvider(otherId)).asData?.value;
        final currentUserProfile =
            ref.watch(currentUserProfileProvider).asData?.value;
        final isBlockedByMe = !isGroup &&
            (currentUserProfile?.isUserBlocked(otherId) ?? false);

        final canSeePhoto = isGroup ||
            otherUserPresence == null ||
            PrivacyHelper.canViewPhoto(
              targetUser: otherUserPresence,
              viewerUserId: currentUserId,
              hasConversation: true,
            );
        final canSeeOnline = !isGroup &&
            otherUserPresence != null &&
            !isBlockedByMe &&
            PrivacyHelper.canViewOnline(
              targetUser: otherUserPresence,
              viewerUserId: currentUserId,
              hasConversation: true,
            );
        final isOnline = canSeeOnline && otherUserPresence.isOnline;

        final photoUrl = isGroup
            ? conversation.photoUrl
            : (canSeePhoto
                ? (otherUserPresence?.photoUrl ??
                    conversation.otherParticipantPhoto(currentUserId))
                : null);

        return ChatPreviewTile(
          conversation: conversation,
          currentUserId: currentUserId,
          isPinned: isPinned,
          isMuted: isMuted,
          isArchived: isArchived,
          isOnline: isOnline,
          photoUrl: photoUrl,
          displayName: displayName,
          onTap: () => _openConversation(conversation, currentUserId),
          onLongPress: () => _showConversationOptions(
            context,
            conversation,
            isPinned,
            isArchived,
            isMuted,
            displayName,
            currentUserId,
          ),
          onPinToggle: () {
            ref.read(pinnedChatIdsProvider.notifier).togglePin(conversation.id);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(isPinned ? 'Chat unpinned' : 'Chat pinned to top'),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 1),
              ),
            );
          },
          onMuteToggle: () async {
            await ref.read(chatControllerProvider.notifier).toggleGroupMute(
                  conversationId: conversation.id,
                  mute: !isMuted,
                );
          },
          onArchiveToggle: () {
            ref.read(archivedChatIdsProvider.notifier).toggleArchive(conversation.id);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(isArchived ? 'Chat unarchived' : 'Chat archived'),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 1),
              ),
            );
          },
          onDelete: () => _confirmDeleteConversation(context, conversation, displayName),
        );
      },
    );
  }
}
