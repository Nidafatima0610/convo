import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/extensions.dart';

enum ConvoButtonVariant { primaryGradient, primaryFilled, tonal, outline }

class ConvoButton extends StatelessWidget {
  const ConvoButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = ConvoButtonVariant.primaryGradient,
    this.height = 50,
    this.isFullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ConvoButtonVariant variant;
  final double height;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;

    if (variant == ConvoButtonVariant.primaryGradient) {
      return Container(
        height: height,
        width: isFullWidth ? double.infinity : null,
        decoration: BoxDecoration(
          borderRadius: AppRadius.borderMd,
          gradient: isEnabled
              ? AppColors.meshGradient
              : LinearGradient(
                  colors: [
                    context.convoColors.surfaceSubtle,
                    context.convoColors.surfaceSubtle,
                  ],
                ),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: AppRadius.borderMd,
          child: InkWell(
            borderRadius: AppRadius.borderMd,
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Row(
                mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 18,
                      color: isEnabled
                          ? Colors.white
                          : context.convoColors.textTertiary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Text(
                    label,
                    style: AppTypography.titleMedium.copyWith(
                      color: isEnabled
                          ? Colors.white
                          : context.convoColors.textTertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (variant == ConvoButtonVariant.tonal) {
      return SizedBox(
        height: height,
        width: isFullWidth ? double.infinity : null,
        child: FilledButton.tonal(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: context.convoColors.surfaceSubtle,
            foregroundColor: context.colorScheme.primary,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          ),
          child: Row(
            mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(
                label,
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (variant == ConvoButtonVariant.outline) {
      return SizedBox(
        height: height,
        width: isFullWidth ? double.infinity : null,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: context.convoColors.cardBorder, width: 1.2),
            foregroundColor: context.convoColors.textPrimary,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          ),
          child: Row(
            mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: context.convoColors.textPrimary),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(
                label,
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

    return SizedBox(
      height: height,
      width: isFullWidth ? double.infinity : null,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
        ),
        child: Row(
          mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: AppSpacing.sm),
            ],
            Text(label),
          ],
        ),
      ),
    );
  }
}
