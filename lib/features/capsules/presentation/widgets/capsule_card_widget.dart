import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/extensions.dart';
import '../../../chats/domain/models/message_model.dart';
import '../../domain/models/capsule_model.dart';

class CapsuleCardWidget extends StatefulWidget {
  const CapsuleCardWidget({
    super.key,
    required this.message,
    required this.isMe,
  });

  final MessageModel message;
  final bool isMe;

  @override
  State<CapsuleCardWidget> createState() => _CapsuleCardWidgetState();
}

class _CapsuleCardWidgetState extends State<CapsuleCardWidget> {
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    // Update every minute for countdown refresh
    _countdownTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meta = widget.message.metadata;
    if (meta == null || meta['capsule'] == null) {
      return Text(widget.message.text);
    }

    final capsule = CapsuleModel.fromMap(
      Map<String, dynamic>.from(meta['capsule'] as Map),
    );
    final isUnlocked = capsule.isUnlocked;

    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.convoColors.cardBackground,
        borderRadius: AppRadius.borderMd,
        border: Border.all(
          color: isUnlocked
              ? AppColors.success.withValues(alpha: 0.5)
              : AppColors.accentPurple.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isUnlocked ? AppColors.success : AppColors.accentPurple)
                .withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Badge
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color:
                      (isUnlocked ? AppColors.success : AppColors.accentPurple)
                          .withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isUnlocked
                      ? Icons.lock_open_rounded
                      : Icons.hourglass_top_rounded,
                  size: 16,
                  color: isUnlocked
                      ? AppColors.success
                      : AppColors.accentPurple,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                isUnlocked ? 'Capsule Unlocked! 🎉' : 'Message Capsule ⏳',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: isUnlocked
                      ? AppColors.success
                      : AppColors.accentPurple,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),

          // Content Box
          if (isUnlocked) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.convoColors.surfaceSubtle,
                borderRadius: AppRadius.borderSm,
              ),
              child: Text(
                capsule.message,
                style: AppTypography.bodyMedium.copyWith(
                  color: context.convoColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Unlocked at ${capsule.unlockAt.day}/${capsule.unlockAt.month}/${capsule.unlockAt.year}',
              style: AppTypography.labelSmall.copyWith(
                color: context.convoColors.textTertiary,
                fontSize: 10,
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
              decoration: BoxDecoration(
                color: context.convoColors.surfaceSubtle,
                borderRadius: AppRadius.borderSm,
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.lock_clock_rounded,
                    color: AppColors.accentPurple,
                    size: 28,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Locked until scheduled time',
                    style: AppTypography.labelSmall.copyWith(
                      color: context.convoColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    capsule.countdownString,
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.accentPurple,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
