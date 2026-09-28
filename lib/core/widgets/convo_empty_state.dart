import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/extensions.dart';
import 'convo_button.dart';

class ConvoEmptyState extends StatelessWidget {
  const ConvoEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.actionLabel,
    this.onActionPressed,
    this.actionIcon,
    this.badge,
    this.customIllustration,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final IconData? actionIcon;
  final Widget? badge;
  final Widget? customIllustration;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.xxxl,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (customIllustration != null)
              customIllustration!
            else
              _buildDefaultIcon(context),
            const SizedBox(height: AppSpacing.xxl),
            if (badge != null) ...[
              badge!,
              const SizedBox(height: AppSpacing.md),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.headlineMedium.copyWith(
                color: context.convoColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color: context.convoColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: AppSpacing.xxl),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: ConvoButton(
                  label: actionLabel!,
                  icon: actionIcon,
                  onPressed: onActionPressed,
                  variant: ConvoButtonVariant.primaryGradient,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultIcon(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.convoColors.surfaceSubtle,
        border: Border.all(color: context.convoColors.cardBorder, width: 2),
        boxShadow: [
          BoxShadow(
            color: context.colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 32,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                context.colorScheme.primary.withValues(alpha: 0.15),
                AppColors.accent.withValues(alpha: 0.15),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Icon(icon, size: 30, color: context.colorScheme.primary),
        ),
      ),
    );
  }
}
