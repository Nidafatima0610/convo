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
    final capsulesAsync = ref.watch(userCapsulesStreamProvider);
    final allCapsules = capsulesAsync.asData?.value ?? [];

    final filteredCapsules = allCapsules.where((c) {
      if (_selectedFilter == 1) return c.isLocked;
      if (_selectedFilter == 2) return !c.isLocked;
      return true;
    }).toList();

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
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  // Educational banner
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.accentPurple.withValues(alpha: 0.1),
                      borderRadius: AppRadius.borderMd,
                      border: Border.all(
                        color: AppColors.accentPurple.withValues(alpha: 0.25),
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

                  if (filteredCapsules.isEmpty)
                    _buildEmptyState()
                  else
                    ...filteredCapsules.map((capsule) {
                      final title = capsule.isUnlocked
                          ? capsule.message
                          : 'Locked Capsule (${capsule.countdownString})';
                      final subtitle =
                          'To ${capsule.receiverName} • From ${capsule.senderName}';
                      final unlockText = capsule.isUnlocked
                          ? 'Unlocked • Unlocked on ${capsule.unlockAt.day}/${capsule.unlockAt.month}/${capsule.unlockAt.year}'
                          : 'Unlocks on ${capsule.unlockAt.day}/${capsule.unlockAt.month}/${capsule.unlockAt.year} at ${capsule.unlockAt.hour}:${capsule.unlockAt.minute.toString().padLeft(2, '0')}';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _buildCapsulePreviewTile(
                          capsule: capsule,
                          title: title,
                          subtitle: subtitle,
                          unlockText: unlockText,
                          isLocked: capsule.isLocked,
                        ),
                      );
                    }),
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
    required dynamic capsule,
    required String title,
    required String subtitle,
    required String unlockText,
    required bool isLocked,
  }) {
    return ConvoCard(
      onTap: () {
        if (capsule.isUnlocked) {
          // Persist opened status in Firestore
          ref.read(chatServiceProvider).markCapsuleOpened(capsule.id);
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: context.convoColors.cardBackground,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.borderXl),
              title: Row(
                children: [
                  const Icon(Icons.lock_open_rounded, color: AppColors.success),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Capsule Unlocked! 🎉',
                    style: AppTypography.titleLarge.copyWith(
                      color: context.convoColors.textPrimary,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'From ${capsule.senderName} to ${capsule.receiverName}',
                    style: AppTypography.labelMedium.copyWith(
                      color: context.convoColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: context.convoColors.surfaceSubtle,
                      borderRadius: AppRadius.borderMd,
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      capsule.message,
                      style: AppTypography.bodyLarge.copyWith(
                        color: context.convoColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Unlocked at ${capsule.unlockAt.day}/${capsule.unlockAt.month}/${capsule.unlockAt.year}',
                    style: AppTypography.labelSmall.copyWith(
                      color: context.convoColors.textTertiary,
                    ),
                  ),
                ],
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        } else {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: context.convoColors.cardBackground,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.borderXl),
              title: Row(
                children: [
                  const Icon(Icons.lock_clock_rounded, color: AppColors.accentPurple),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Locked Capsule ⏳',
                    style: AppTypography.titleLarge.copyWith(
                      color: context.convoColors.textPrimary,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'This capsule remains securely locked until its scheduled unlock time.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: context.convoColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    capsule.countdownString,
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.accentPurple,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      },
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
