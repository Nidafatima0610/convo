import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/extensions.dart';

enum ChatMagicAction {
  stickers,
  mood,
  games,
  voiceEffects,
  reactions,
  capsule,
  secretChat,
}

class ChatMagicSheet extends StatelessWidget {
  const ChatMagicSheet({
    super.key,
    required this.onActionSelected,
    this.currentMoodLabel,
    this.isSecretActive = false,
  });

  final ValueChanged<ChatMagicAction> onActionSelected;
  final String? currentMoodLabel;
  final bool isSecretActive;

  static Future<void> show(
    BuildContext context, {
    required ValueChanged<ChatMagicAction> onActionSelected,
    String? currentMoodLabel,
    bool isSecretActive = false,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ChatMagicSheet(
        onActionSelected: onActionSelected,
        currentMoodLabel: currentMoodLabel,
        isSecretActive: isSecretActive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.convoColors.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).padding.bottom + AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.convoColors.textTertiary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppColors.meshGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CONVO Chat Magic',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      'Signature interactive conversation powers',
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

          const SizedBox(height: AppSpacing.lg),

          // Grid of Magic features
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1.55,
            children: [
              _buildFeatureCard(
                context,
                title: 'Stickers',
                subtitle: 'Studio & Packs',
                emoji: '🎨',
                color: const Color(0xFFE91E63),
                action: ChatMagicAction.stickers,
              ),
              _buildFeatureCard(
                context,
                title: 'Chat Mood',
                subtitle: currentMoodLabel ?? 'Set conversation vibe',
                emoji: '🎭',
                color: const Color(0xFF9C27B0),
                action: ChatMagicAction.mood,
                badge: currentMoodLabel != null ? 'Active' : null,
              ),
              _buildFeatureCard(
                context,
                title: 'Chat Games',
                subtitle: 'Trivia, Would You Rather',
                emoji: '🎲',
                color: const Color(0xFFFF9800),
                action: ChatMagicAction.games,
              ),
              _buildFeatureCard(
                context,
                title: 'Voice Effects',
                subtitle: 'Robot, Deep, Echo, Fun',
                emoji: '🎤',
                color: const Color(0xFF00BCD4),
                action: ChatMagicAction.voiceEffects,
              ),
              _buildFeatureCard(
                context,
                title: 'Reaction FX',
                subtitle: 'Animated expressive burst',
                emoji: '❤️',
                color: const Color(0xFFE53935),
                action: ChatMagicAction.reactions,
              ),
              _buildFeatureCard(
                context,
                title: 'Capsule',
                subtitle: 'Time-locked future message',
                emoji: '⏳',
                color: const Color(0xFF4CAF50),
                action: ChatMagicAction.capsule,
              ),
              _buildFeatureCard(
                context,
                title: 'Secret Chat',
                subtitle: isSecretActive
                    ? 'Auto-destruct ON'
                    : 'Self-destruct timer',
                emoji: '👻',
                color: const Color(0xFF673AB7),
                action: ChatMagicAction.secretChat,
                badge: isSecretActive ? 'ON' : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String emoji,
    required Color color,
    required ChatMagicAction action,
    String? badge,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          onActionSelected(action);
        },
        borderRadius: AppRadius.cardMd,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm + 2),
          decoration: BoxDecoration(
            color: context.convoColors.surfaceSubtle,
            borderRadius: AppRadius.cardMd,
            border: Border.all(
              color: badge != null
                  ? color.withValues(alpha: 0.5)
                  : context.convoColors.cardBorder,
              width: badge != null ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 18)),
                  ),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: context.convoColors.textTertiary,
                      fontSize: 10,
                    ),
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
