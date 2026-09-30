import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/extensions.dart';

enum ConvoAvatarStatus { online, meshActive, offline, none }

class ConvoAvatar extends StatelessWidget {
  const ConvoAvatar({
    super.key,
    required this.initials,
    this.photoUrl,
    this.size = 56,
    this.status = ConvoAvatarStatus.none,
    this.showEditBadge = false,
    this.isLoading = false,
    this.onTap,
  });

  final String initials;
  final String? photoUrl;
  final double size;
  final ConvoAvatarStatus status;
  final bool showEditBadge;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(context);
    final indicatorSize = (size * 0.26).clamp(10.0, 20.0);
    final hasPhoto = photoUrl != null && photoUrl!.trim().isNotEmpty;

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
            child: ClipOval(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Default initials fallback
                  Center(
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

                  // Profile picture if available
                  if (hasPhoto)
                    Image.network(
                      photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Text(
                            initials.toUpperCase(),
                            style: AppTypography.titleLarge.copyWith(
                              color: Colors.white,
                              fontSize: size * 0.38,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: Text(
                            initials.toUpperCase(),
                            style: AppTypography.titleLarge.copyWith(
                              color: Colors.white,
                              fontSize: size * 0.38,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        );
                      },
                    ),

                  // Loading spinner overlay
                  if (isLoading)
                    Container(
                      color: Colors.black.withValues(alpha: 0.45),
                      child: Center(
                        child: SizedBox(
                          width: size * 0.35,
                          height: size * 0.35,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      ),
                    ),
                ],
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
