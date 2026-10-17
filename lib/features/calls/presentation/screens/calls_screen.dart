import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/convo_app_bar.dart';
import '../../../../core/widgets/convo_avatar.dart';
import '../../../../core/widgets/convo_badge.dart';
import '../../../../core/widgets/convo_empty_state.dart';
import '../../../auth/domain/models/convo_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/models/call_model.dart';
import '../providers/call_providers.dart';
import '../../../chats/presentation/providers/chat_providers.dart';

class CallsScreen extends ConsumerStatefulWidget {
  const CallsScreen({super.key});

  @override
  ConsumerState<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends ConsumerState<CallsScreen> {
  int _selectedFilterIndex = 0;
  final List<String> _callFilters = const ['All Calls', 'Missed'];

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (minutes > 0) {
      return '$minutes m $remainingSeconds s';
    }
    return '$seconds s';
  }

  Future<void> _initiateCall(CallModel call, {required bool isVideo}) async {
    final currentConvoUser = ref.read(currentUserProfileProvider).asData?.value;
    if (currentConvoUser == null) return;

    final otherUserId = call.otherUserId(currentConvoUser.uid);
    final otherUserName = call.otherUserName(currentConvoUser.uid);
    final otherUserPhoto = call.otherUserPhoto(currentConvoUser.uid);

    final receiverUser = ConvoUser(
      uid: otherUserId,
      name: otherUserName,
      email: '',
      photoUrl: otherUserPhoto,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final success = await ref
        .read(activeCallControllerProvider.notifier)
        .startCall(
          caller: currentConvoUser,
          receiver: receiverUser,
          type: isVideo ? CallType.video : CallType.voice,
        );

    if (success && mounted) {
      context.push('/call/active');
    }
  }

  Future<void> _startDirectCallWithUser(
    ConvoUser user, {
    required bool isVideo,
  }) async {
    final currentConvoUser = ref.read(currentUserProfileProvider).asData?.value;
    if (currentConvoUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to make calls')),
        );
      }
      return;
    }

    final success = await ref
        .read(activeCallControllerProvider.notifier)
        .startCall(
          caller: currentConvoUser,
          receiver: user,
          type: isVideo ? CallType.video : CallType.voice,
        );

    if (success && mounted) {
      context.push('/call/active');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId =
        ref.watch(authStateChangesProvider).asData?.value?.uid ?? '';
    final callHistoryAsync = ref.watch(callHistoryProvider);

    return Scaffold(
      appBar: ConvoAppBar(
        title: AppStrings.callsTitle,
        subtitle: 'Internet Audio & Video Calls',
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildCallFilters(),
            Expanded(
              child: callHistoryAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => ConvoEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Could Not Load Calls',
                  subtitle: error.toString(),
                  actionLabel: 'Retry',
                  onActionPressed: () => ref.invalidate(callHistoryProvider),
                ),
                data: (calls) {
                  // Filter calls based on selected filter
                  final filteredCalls = _selectedFilterIndex == 1
                      ? calls
                            .where(
                              (c) =>
                                  c.isMissed ||
                                  (c.isRejected && !c.isCaller(currentUserId)),
                            )
                            .toList()
                      : calls;

                  if (filteredCalls.isEmpty) {
                    return ConvoEmptyState(
                      icon: Icons.phone_outlined,
                      title: _selectedFilterIndex == 1
                          ? 'No Missed Calls'
                          : AppStrings.callsEmptyTitle,
                      subtitle: _selectedFilterIndex == 1
                          ? 'You have answered all previous calls.'
                          : AppStrings.callsEmptySubtitle,
                      actionLabel: _selectedFilterIndex == 1
                          ? null
                          : AppStrings.newCall,
                      actionIcon: Icons.add_call,
                      onActionPressed: _selectedFilterIndex == 1
                          ? null
                          : () => _showStartCallDialog(context),
                      badge: const ConvoBadge(
                        label: 'END-TO-END ENCRYPTED',
                        variant: ConvoBadgeVariant.primary,
                        icon: Icons.security_rounded,
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                    itemCount: filteredCalls.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: context.convoColors.cardBorder.withValues(
                        alpha: 0.5,
                      ),
                    ),
                    itemBuilder: (context, index) {
                      final call = filteredCalls[index];
                      final isMe = call.isCaller(currentUserId);
                      final otherName = call.otherUserName(currentUserId);
                      final isMissed =
                          call.isMissed || (call.isRejected && !isMe);

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 4,
                        ),
                        leading: ConvoAvatar(
                          initials: otherName.isNotEmpty
                              ? otherName.substring(0, 1)
                              : '?',
                          size: 46,
                        ),
                        title: Text(
                          otherName,
                          style: AppTypography.titleMedium.copyWith(
                            color: isMissed
                                ? AppColors.error
                                : context.convoColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Row(
                          children: [
                            Icon(
                              isMe
                                  ? Icons.call_made_rounded
                                  : (isMissed
                                        ? Icons.call_missed_rounded
                                        : Icons.call_received_rounded),
                              size: 15,
                              color: isMissed
                                  ? AppColors.error
                                  : (isMe
                                        ? context.colorScheme.primary
                                        : AppColors.success),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isMe
                                  ? 'Outgoing'
                                  : (isMissed ? 'Missed' : 'Incoming'),
                              style: AppTypography.labelSmall.copyWith(
                                color: isMissed
                                    ? AppColors.error
                                    : context.convoColors.textTertiary,
                              ),
                            ),
                            if (call.duration > 0) ...[
                              const SizedBox(width: 6),
                              Text(
                                '• ${_formatDuration(call.duration)}',
                                style: AppTypography.labelSmall.copyWith(
                                  color: context.convoColors.textTertiary,
                                ),
                              ),
                            ],
                            const SizedBox(width: 6),
                            Text(
                              '• ${DateFormatter.formatConversationTime(call.createdAt)}',
                              style: AppTypography.labelSmall.copyWith(
                                color: context.convoColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            call.isVideo
                                ? Icons.videocam_outlined
                                : Icons.phone_outlined,
                            color: context.colorScheme.primary,
                          ),
                          tooltip: call.isVideo ? 'Video Call' : 'Voice Call',
                          onPressed: () =>
                              _initiateCall(call, isVideo: call.isVideo),
                        ),
                        onTap: () => _initiateCall(call, isVideo: call.isVideo),
                      );
                    },
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
          heroTag: 'calls_new_call_fab',
          onPressed: () => _showStartCallDialog(context),
          icon: const Icon(Icons.add_call, size: 20, color: Colors.white),
          label: Text(
            AppStrings.newCall,
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

  void _showStartCallDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _StartCallModal(
        onStartCall: (user, isVideo) {
          Navigator.of(sheetCtx).pop();
          _startDirectCallWithUser(user, isVideo: isVideo);
        },
      ),
    );
  }

  Widget _buildCallFilters() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: _callFilters.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final isSelected = _selectedFilterIndex == index;
          final title = _callFilters[index];

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
            selectedColor: context.colorScheme.primary,
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
}

class _StartCallModal extends ConsumerStatefulWidget {
  const _StartCallModal({required this.onStartCall});

  final void Function(ConvoUser user, bool isVideo) onStartCall;

  @override
  ConsumerState<_StartCallModal> createState() => _StartCallModalState();
}

class _StartCallModalState extends ConsumerState<_StartCallModal> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId =
        ref.watch(authStateChangesProvider).asData?.value?.uid ?? '';
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
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: context.colorScheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add_call,
                    color: context.colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'New Call',
                        style: AppTypography.titleLarge.copyWith(
                          color: context.convoColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Choose a contact for voice or video call',
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

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search people to call...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: AppRadius.borderMd,
                  borderSide: BorderSide(color: context.convoColors.cardBorder),
                ),
              ),
              onChanged: (val) => setState(() => _query = val.trim()),
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // User List
          Expanded(
            child: searchedUsersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text(
                  'Could not load contacts: $err',
                  style: TextStyle(color: context.convoColors.textSecondary),
                ),
              ),
              data: (users) {
                final eligibleUsers =
                    users.where((u) => u.uid != currentUserId).toList();

                if (eligibleUsers.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_search_rounded,
                            size: 48,
                            color: context.convoColors.textTertiary,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            _query.isNotEmpty
                                ? 'No contacts match "$_query"'
                                : 'No contacts available to call',
                            style: AppTypography.titleMedium.copyWith(
                              color: context.convoColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xs,
                  ),
                  itemCount: eligibleUsers.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: context.convoColors.cardBorder.withValues(alpha: 0.5),
                  ),
                  itemBuilder: (context, index) {
                    final user = eligibleUsers[index];
                    final initials = user.name.isNotEmpty
                        ? user.name.substring(0, 1).toUpperCase()
                        : '?';

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 4,
                      ),
                      leading: ConvoAvatar(
                        initials: initials,
                        photoUrl: user.photoUrl,
                        size: 42,
                      ),
                      title: Text(
                        user.name,
                        style: AppTypography.titleMedium.copyWith(
                          color: context.convoColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        user.email.isNotEmpty
                            ? user.email
                            : (user.bio ?? 'CONVO User'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: context.convoColors.textSecondary,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.phone_outlined),
                            color: context.colorScheme.primary,
                            tooltip: 'Voice Call',
                            onPressed: () => widget.onStartCall(user, false),
                          ),
                          IconButton(
                            icon: const Icon(Icons.videocam_outlined),
                            color: AppColors.accent,
                            tooltip: 'Video Call',
                            onPressed: () => widget.onStartCall(user, true),
                          ),
                        ],
                      ),
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

