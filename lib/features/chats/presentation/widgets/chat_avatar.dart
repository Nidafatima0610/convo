import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/convo_avatar.dart';

/// Reusable Chat Avatar component supporting 1-to-1 users, groups,
/// and live presence indicators (online, offline, nearby peer).
class ChatAvatar extends StatelessWidget {
  const ChatAvatar({
    super.key,
    required this.initials,
    this.photoUrl,
    this.size = 48,
    this.status = ConvoAvatarStatus.none,
    this.isGroup = false,
    this.isNearbyConnected = false,
    this.showStatusDot = true,
    this.onTap,
  });

  final String initials;
  final String? photoUrl;
  final double size;
  final ConvoAvatarStatus status;
  final bool isGroup;
  final bool isNearbyConnected;
  final bool showStatusDot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dotSize = (size * 0.28).clamp(8.0, 16.0);
    final isOnline = status == ConvoAvatarStatus.online;

    Widget avatarCore;
    if (isGroup && (photoUrl == null || photoUrl!.isEmpty)) {
      avatarCore = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withValues(alpha: 0.8),
              AppColors.accentPurple,
            ],
          ),
        ),
        child: Center(
          child: Icon(
            Icons.groups_rounded,
            color: Colors.white,
            size: size * 0.52,
          ),
        ),
      );
    } else {
      avatarCore = ConvoAvatar(
        initials: initials,
        photoUrl: photoUrl,
        size: size,
        status: ConvoAvatarStatus.none, // We render custom dot below
      );
    }

    Widget content = SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatarCore,
          if (showStatusDot && !isGroup && (isOnline || isNearbyConnected))
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  color: isNearbyConnected
                      ? AppColors.accentPurple
                      : AppColors.success,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: (dotSize * 0.2).clamp(1.5, 2.5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isNearbyConnected
                              ? AppColors.accentPurple
                              : AppColors.success)
                          .withValues(alpha: 0.45),
                      blurRadius: 4,
                      spreadRadius: 0.5,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size),
        child: content,
      );
    }

    return content;
  }
}
