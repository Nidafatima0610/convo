import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/convo_app_bar.dart';
import '../../../../core/widgets/convo_card.dart';
import '../../../chats/presentation/providers/chat_providers.dart';

class CapsulesScreen extends ConsumerStatefulWidget {
  const CapsulesScreen({super.key});

  @override
  ConsumerState<CapsulesScreen> createState() => _CapsulesScreenState();
}

class _CapsulesScreenState extends ConsumerState<CapsulesScreen> {
  int _selectedFilter = 0; // 0 = All, 1 = Locked, 2 = Unlocked

  @override
  Widget build(BuildContext context) {
    final conversations =
        ref.watch(userConversationsProvider).asData?.value ?? [];

    return Scaffold(
      appBar: ConvoAppBar(
        title: 'Message Capsules',
        subtitle: 'Time-locked ephemera & scheduled notes',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Chips
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('All Capsules'),
                    selected: _selectedFilter == 0,
                    selectedColor: context.colorScheme.primary,
                    labelStyle: TextStyle(
                      color: _selectedFilter == 0 ? Colors.white : null,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) => setState(() => _selectedFilter = 0),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ChoiceChip(
                    label: const Text('⏳ Locked'),
                    selected: _selectedFilter == 1,
                    selectedColor: AppColors.accentPurple,
                    labelStyle: TextStyle(
                      color: _selectedFilter == 1 ? Colors.white : null,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) => setState(() => _selectedFilter = 1),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ChoiceChip(
                    label: const Text('🔓 Ready / Opened'),
                    selected: _selectedFilter == 2,
                    selectedColor: AppColors.success,
                    labelStyle: TextStyle(
                      color: _selectedFilter == 2 ? Colors.white : null,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) => setState(() => _selectedFilter = 2),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Capsules List or Explanatory State
            Expanded(
              child: conversations.isEmpty
                  ? _buildEmptyState()
                  : ListView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      children: [
                        // Educational banner
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.accentPurple.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: AppRadius.borderMd,
                            border: Border.all(
                              color: AppColors.accentPurple.withValues(
                                alpha: 0.25,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.hourglass_bottom_rounded,
                                color: AppColors.accentPurple,
                                size: 28,
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Text(
                                  'Message Capsules remain server-locked until their scheduled unlock timestamp. Create one from any chat via the Chat Magic ✨ menu!',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: context.convoColors.textPrimary,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // Example active capsule preview card
                        _buildCapsulePreviewTile(
                          title: 'Happy Birthday Celebration! 🎉',
                          subtitle: 'Scheduled for Jordan Lee',
                          unlockText: 'Unlocks tomorrow at 9:00 AM',
                          isLocked: true,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildCapsulePreviewTile(
                          title: 'Good luck on your interview! ❤️',
                          subtitle: 'From Alex Rivera',
                          unlockText: 'Unlocked • Opened today',
                          isLocked: false,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.accentPurple.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.hourglass_empty_rounded,
                color: AppColors.accentPurple,
                size: 32,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No Message Capsules',
              style: AppTypography.titleLarge.copyWith(
                color: context.convoColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Schedule messages for birthdays, countdowns, or future reminders through Chat Magic ✨ in any 1-to-1 conversation.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: context.convoColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapsulePreviewTile({
    required String title,
    required String subtitle,
    required String unlockText,
    required bool isLocked,
  }) {
    return ConvoCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (isLocked ? AppColors.accentPurple : AppColors.success)
                  .withValues(alpha: 0.15),
              borderRadius: AppRadius.borderSm,
            ),
            child: Icon(
              isLocked ? Icons.lock_clock_rounded : Icons.lock_open_rounded,
              color: isLocked ? AppColors.accentPurple : AppColors.success,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.titleMedium.copyWith(
                    color: context.convoColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.bodySmall.copyWith(
                    color: context.convoColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  unlockText,
                  style: AppTypography.labelSmall.copyWith(
                    color: isLocked
                        ? AppColors.accentPurple
                        : AppColors.success,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
