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
