import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/extensions.dart';

class ConvoAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ConvoAppBar({
    super.key,
    this.title,
    this.showBrand = false,
    this.subtitle,
    this.actions,
    this.leading,
    this.bottom,
    this.centerTitle = false,
  });

  final String? title;
  final bool showBrand;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final PreferredSizeWidget? bottom;
  final bool centerTitle;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0.0));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      centerTitle: centerTitle,
      leading: leading,
      titleSpacing: leading != null ? 0 : AppSpacing.lg,
      title: showBrand
          ? _buildBrandTitle(context)
          : _buildStandardTitle(context),
      actions: [
        ...?actions,
        const SizedBox(width: AppSpacing.sm),
      ],
      bottom: bottom,
    );
  }

  Widget _buildBrandTitle(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            gradient: AppColors.meshGradient,
            borderRadius: AppRadius.borderSm,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.all_inclusive_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  AppConstants.appName,
                  style: AppTypography.titleLarge.copyWith(
                    color: context.convoColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs + 2),
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            Text(
              subtitle ?? AppConstants.appTagline,
              style: AppTypography.labelSmall.copyWith(
                color: context.convoColors.textTertiary,
                fontSize: 10,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStandardTitle(BuildContext context) {
    if (title == null) return const SizedBox.shrink();
    if (subtitle == null) {
      return Text(
        title!,
        style: AppTypography.headlineMedium.copyWith(
          color: context.convoColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return Column(
      crossAxisAlignment: centerTitle
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title!,
          style: AppTypography.titleLarge.copyWith(
            color: context.convoColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          subtitle!,
          style: AppTypography.bodySmall.copyWith(
            color: context.convoColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
