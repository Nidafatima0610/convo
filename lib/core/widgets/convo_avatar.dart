import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/extensions.dart';

enum ConvoAvatarStatus { online, meshActive, offline, none }

class ConvoAvatar extends StatelessWidget {
  const ConvoAvatar({
    super.key,
    required this.initials,
    this.size = 56,
    this.status = ConvoAvatarStatus.none,
    this.showEditBadge = false,
    this.onTap,
  });

  final String initials;
  final double size;
  final ConvoAvatarStatus status;
  final bool showEditBadge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(context);
    final indicatorSize = (size * 0.26).clamp(10.0, 20.0);

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.accentDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.22),
                  blurRadius: size * 0.25,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                initials.toUpperCase(),
                style: AppTypography.titleLarge.copyWith(
                  color: Colors.white,
                  fontSize: size * 0.38,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          if (status != ConvoAvatarStatus.none)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: indicatorSize,
                height: indicatorSize,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: context.convoColors.cardBackground,
                    width: 2.5,
                  ),
                ),
              ),
            ),
          if (showEditBadge)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: context.colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: context.convoColors.cardBackground,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  size: 13,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _statusColor(BuildContext context) {
    switch (status) {
      case ConvoAvatarStatus.online:
        return AppColors.success;
      case ConvoAvatarStatus.meshActive:
        return AppColors.accent;
      case ConvoAvatarStatus.offline:
        return context.convoColors.textTertiary;
      case ConvoAvatarStatus.none:
        return Colors.transparent;
    }
  }
}
