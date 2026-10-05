import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/convo_avatar.dart';
import '../../../../core/widgets/convo_badge.dart';
import '../../../auth/domain/models/convo_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/chat_providers.dart';

class UserSearchModal extends ConsumerStatefulWidget {
  const UserSearchModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const UserSearchModal(),
    );
  }

  @override
  ConsumerState<UserSearchModal> createState() => _UserSearchModalState();
}

class _UserSearchModalState extends ConsumerState<UserSearchModal> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _isCreatingConversation = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _startConversation(ConvoUser otherUser) async {
    setState(() => _isCreatingConversation = true);
    try {
      final currentUserProfile = ref
          .read(currentUserProfileProvider)
          .asData
          ?.value;
      final authUser = ref.read(authStateChangesProvider).asData?.value;

      final currentUser =
          currentUserProfile ??
          ConvoUser(
            uid: authUser?.uid ?? '',
            name: authUser?.displayName ?? 'CONVO User',
            email: authUser?.email ?? '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

      final chatService = ref.read(chatServiceProvider);
      final conversation = await chatService.getOrCreateConversation(
        currentUser: currentUser,
        otherUser: otherUser,
      );

      if (mounted) {
        Navigator.of(context).pop();
        context.push('/chat/${conversation.id}', extra: otherUser);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open conversation: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreatingConversation = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchedUsersAsync = ref.watch(searchedUsersProvider(_query));

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: context.convoColors.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: context.convoColors.cardBorder, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: AppSpacing.sm),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.convoColors.cardBorder,
                borderRadius: AppRadius.borderPill,
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Start Conversation',
                        style: AppTypography.titleLarge.copyWith(
                          color: context.convoColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Select a registered CONVO user to begin chatting',
                        style: AppTypography.bodySmall.copyWith(
                          color: context.convoColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // New Group entry button
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: AppRadius.borderLg,
                onTap: () {
                  Navigator.of(context).pop();
                  context.push(AppRoutes.createGroup);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: context.colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: AppRadius.borderLg,
                    border: Border.all(
                      color:
                          context.colorScheme.primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: context.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.group_add_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'New Group',
                              style: AppTypography.titleMedium.copyWith(
                                color: context.convoColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Create a group with multiple contacts',
                              style: AppTypography.bodySmall.copyWith(
                                color: context.convoColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: context.colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Note to Self action
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: AppRadius.borderLg,
                onTap: () {
                  final currentUserProfile =
                      ref.read(currentUserProfileProvider).asData?.value;
                  final authUser =
                      ref.read(authStateChangesProvider).asData?.value;
                  if (authUser != null) {
                    final currentUser = currentUserProfile ??
                        ConvoUser(
                          uid: authUser.uid,
                          name: authUser.displayName ?? 'CONVO User',
                          email: authUser.email ?? '',
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                        );
                    _startConversation(currentUser);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.08),
                    borderRadius: AppRadius.borderLg,
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.bookmark_added_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Note to Self',
                              style: AppTypography.titleMedium.copyWith(
                                color: context.convoColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Send messages, media, or reminders to yourself',
                              style: AppTypography.bodySmall.copyWith(
                                color: context.convoColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.accent,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xs),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search by name or email...',
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
          ),

          const SizedBox(height: AppSpacing.sm),

          // Users list
          Expanded(
            child: Stack(
              children: [
                searchedUsersAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: AppColors.error,
                            size: 40,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Could not search users',
                            style: AppTypography.titleMedium.copyWith(
                              color: context.convoColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            err.toString(),
                            textAlign: TextAlign.center,
                            style: AppTypography.bodySmall.copyWith(
                              color: context.convoColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  data: (users) {
                    if (users.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_search_rounded,
                              size: 48,
                              color: context.convoColors.textTertiary,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              _query.isEmpty
                                  ? 'No other users found'
                                  : 'No users matching "$_query"',
                              style: AppTypography.titleMedium.copyWith(
                                color: context.convoColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              _query.isEmpty
                                  ? 'Create a second test account to test 1-to-1 messaging.'
                                  : 'Try searching with a different name or email.',
                              textAlign: TextAlign.center,
                              style: AppTypography.bodySmall.copyWith(
                                color: context.convoColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                      itemCount: users.length,
                      separatorBuilder: (_, _) => Divider(
                        color: context.convoColors.cardBorder,
                        height: 1,
                      ),
                      itemBuilder: (context, index) {
                        final user = users[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                            vertical: AppSpacing.xs,
                          ),
                          leading: ConvoAvatar(
                            initials: user.initials,
                            size: 46,
                            status: user.isOnline
                                ? ConvoAvatarStatus.online
                                : ConvoAvatarStatus.offline,
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  user.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.titleMedium.copyWith(
                                    color: context.convoColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (user.isOnline) ...[
                                const SizedBox(width: AppSpacing.xs),
                                const ConvoBadge(
                                  label: 'ONLINE',
                                  variant: ConvoBadgeVariant.accent,
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            user.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySmall.copyWith(
                              color: context.convoColors.textSecondary,
                            ),
                          ),
                          trailing: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: context.colorScheme.primary.withValues(
                                alpha: 0.12,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 18,
                              color: context.colorScheme.primary,
                            ),
                          ),
                          onTap: _isCreatingConversation
                              ? null
                              : () => _startConversation(user),
                        );
                      },
                    );
                  },
                ),
                if (_isCreatingConversation)
                  Container(
                    color: Colors.black26,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
