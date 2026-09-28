import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/extensions.dart';

enum ConvoBadgeVariant { primary, accent, warning, subtle }

class ConvoBadge extends StatelessWidget {
  const ConvoBadge({
    super.key,
    required this.label,
    this.variant = ConvoBadgeVariant.primary,
    this.icon,
  });

  final String label;
  final ConvoBadgeVariant variant;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (variant) {
      case ConvoBadgeVariant.primary:
        bg = context.colorScheme.primary.withValues(alpha: 0.12);
        fg = context.colorScheme.primary;
        break;
      case ConvoBadgeVariant.accent:
        bg = AppColors.accent.withValues(alpha: 0.14);
        fg = context.isDark ? AppColors.accentLight : AppColors.accentDark;
        break;
      case ConvoBadgeVariant.warning:
        bg = AppColors.amberGlow.withValues(alpha: 0.15);
        fg = AppColors.amberGlow;
        break;
      case ConvoBadgeVariant.subtle:
        bg = context.convoColors.surfaceSubtle;
        fg = context.convoColors.textSecondary;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.borderPill,
        border: Border.all(color: fg.withValues(alpha: 0.25), width: 0.75),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
