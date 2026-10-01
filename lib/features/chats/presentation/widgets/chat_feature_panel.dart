import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/extensions.dart';
import 'chat_magic_sheet.dart';
import 'feature_action_item.dart';

enum ChatAttachmentType {
  gallery,
  camera,
  video,
}

/// Comprehensive modern attachment and feature panel providing unified entry
/// points for photos, camera, video, and all 7 signature CONVO features.
class ChatFeaturePanel extends StatelessWidget {
  const ChatFeaturePanel({
    super.key,
    required this.onAttachmentSelected,
    required this.onFeatureSelected,
    this.currentMoodLabel,
    this.isSecretActive = false,
  });

  final ValueChanged<ChatAttachmentType> onAttachmentSelected;
  final ValueChanged<ChatMagicAction> onFeatureSelected;
  final String? currentMoodLabel;
  final bool isSecretActive;

  static Future<void> show(
    BuildContext context, {
    required ValueChanged<ChatAttachmentType> onAttachmentSelected,
    required ValueChanged<ChatMagicAction> onFeatureSelected,
    String? currentMoodLabel,
    bool isSecretActive = false,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ChatFeaturePanel(
        onAttachmentSelected: onAttachmentSelected,
        onFeatureSelected: onFeatureSelected,
        currentMoodLabel: currentMoodLabel,
        isSecretActive: isSecretActive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return Container(
      constraints: BoxConstraints(
        maxHeight: maxHeight,
      ),
      decoration: BoxDecoration(
        color: context.convoColors.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: context.convoColors.cardBorder, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.md,
            bottom: bottomInset > 0
                ? bottomInset + AppSpacing.md
                : bottomPadding + AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: context.convoColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: const BoxDecoration(
                  gradient: AppColors.brandGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Share & CONVO Magic',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      'Send media or invoke signature communication features',
                      style: AppTypography.bodySmall.copyWith(
                        color: context.convoColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Quick Media Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FeatureActionItem(
                title: 'Gallery',
                icon: Icons.photo_library_rounded,
                color: AppColors.primary,
                isCompact: true,
                onTap: () {
                  Navigator.pop(context);
                  onAttachmentSelected(ChatAttachmentType.gallery);
                },
              ),
              FeatureActionItem(
                title: 'Camera',
                icon: Icons.camera_alt_rounded,
                color: AppColors.accent,
                isCompact: true,
                onTap: () {
                  Navigator.pop(context);
                  onAttachmentSelected(ChatAttachmentType.camera);
                },
              ),
              FeatureActionItem(
                title: 'Video',
                icon: Icons.videocam_rounded,
                color: AppColors.blueGlow,
                isCompact: true,
                onTap: () {
                  Navigator.pop(context);
                  onAttachmentSelected(ChatAttachmentType.video);
                },
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),
          Divider(color: context.convoColors.cardBorder, height: 1),
          const SizedBox(height: AppSpacing.md),

          Text(
            'CONVO UNIQUE FEATURES',
            style: AppTypography.labelSmall.copyWith(
              color: context.convoColors.textTertiary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Grid of CONVO signature features
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1.6,
            children: [
              FeatureActionItem(
                title: 'Stickers',
                subtitle: 'Studio & Packs',
                emoji: '🎨',
                color: const Color(0xFFE91E63),
                onTap: () {
                  Navigator.pop(context);
                  onFeatureSelected(ChatMagicAction.stickers);
                },
              ),
              FeatureActionItem(
                title: 'Chat Mood',
                subtitle: currentMoodLabel ?? 'Set conversation vibe',
                emoji: '🎭',
                color: const Color(0xFF9C27B0),
                badge: currentMoodLabel != null ? 'Active' : null,
                onTap: () {
                  Navigator.pop(context);
                  onFeatureSelected(ChatMagicAction.mood);
                },
              ),
              FeatureActionItem(
                title: 'Chat Games',
                subtitle: 'Trivia & Challenges',
                emoji: '🎲',
                color: const Color(0xFFFF9800),
                onTap: () {
                  Navigator.pop(context);
                  onFeatureSelected(ChatMagicAction.games);
                },
              ),
              FeatureActionItem(
                title: 'Voice Effects',
                subtitle: 'Robot, Deep, Echo, Fun',
                emoji: '🎤',
                color: const Color(0xFF00BCD4),
                onTap: () {
                  Navigator.pop(context);
                  onFeatureSelected(ChatMagicAction.voiceEffects);
                },
              ),
              FeatureActionItem(
                title: 'Reaction FX',
                subtitle: 'Animated expressive burst',
                emoji: '❤️',
                color: const Color(0xFFE53935),
                onTap: () {
                  Navigator.pop(context);
                  onFeatureSelected(ChatMagicAction.reactions);
                },
              ),
              FeatureActionItem(
                title: 'Capsule',
                subtitle: 'Time-locked future message',
                emoji: '⏳',
                color: const Color(0xFF4CAF50),
                onTap: () {
                  Navigator.pop(context);
                  onFeatureSelected(ChatMagicAction.capsule);
                },
              ),
              FeatureActionItem(
                title: 'Secret Chat',
                subtitle: isSecretActive
                    ? 'Auto-destruct ON'
                    : 'Self-destruct timer',
                emoji: '👻',
                color: const Color(0xFF673AB7),
                badge: isSecretActive ? 'ON' : null,
                onTap: () {
                  Navigator.pop(context);
                  onFeatureSelected(ChatMagicAction.secretChat);
                },
              ),
            ],
          ),
        ],
      ),
    ),
  ),
);
  }
}
