import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/convo_app_bar.dart';
import '../../../../core/widgets/convo_badge.dart';
import '../../../../core/widgets/convo_card.dart';
import '../../../moods/domain/models/chat_mood.dart';
import '../../../stickers/presentation/providers/sticker_providers.dart';
import '../../../voice_effects/domain/models/voice_effect.dart';

class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: const ConvoAppBar(
        title: 'Discover',
        subtitle: 'CONVO Chat Magic & Creative Labs',
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          children: [
            _buildHeroBanner(context),
            const SizedBox(height: AppSpacing.xl),

            // Section 1: Chat Magic Features
            Text(
              'CHAT MAGIC SUITE',
              style: AppTypography.labelMedium.copyWith(
                color: context.convoColors.textTertiary,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            _buildFeatureCard(
              context: context,
              title: 'Sticker Studio',
              description: 'Create custom stickers with photos, emojis, colors & custom text captions.',
              badgeText: 'LAUNCH',
              badgeVariant: ConvoBadgeVariant.accent,
              icon: Icons.brush_rounded,
              gradient: const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
              ),
              onTap: () => context.push(AppRoutes.stickerStudio),
            ),
            const SizedBox(height: AppSpacing.md),

            _buildFeatureCard(
              context: context,
              title: 'Message Capsules',
              description: 'Schedule messages locked in time capsules that unlock in the future.',
              badgeText: 'VIEW VAULT',
              badgeVariant: ConvoBadgeVariant.accent,
              icon: Icons.hourglass_top_rounded,
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF3B82F6)],
              ),
              onTap: () => context.push(AppRoutes.capsules),
            ),
            const SizedBox(height: AppSpacing.md),

            _buildFeatureCard(
              context: context,
              title: 'Sticker Packs',
              description: 'Browse Official CONVO Pulse, Mesh, and custom created sticker packs.',
              badgeText: 'EXPLORE',
              badgeVariant: ConvoBadgeVariant.primary,
              icon: Icons.auto_awesome_motion_rounded,
              gradient: const LinearGradient(
                colors: [Color(0xFFEC4899), Color(0xFFF43F5E)],
              ),
              onTap: () => _showPacksModal(context, ref),
            ),
            const SizedBox(height: AppSpacing.md),

            _buildFeatureCard(
              context: context,
              title: 'Chat Moods',
              description: '7 ambient moods to set the conversational vibe: Love, Chill, Funny, Angry & more.',
              badgeText: 'EXPLORE',
              badgeVariant: ConvoBadgeVariant.subtle,
              icon: Icons.palette_rounded,
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
              ),
              onTap: () => _showMoodsModal(context),
            ),
            const SizedBox(height: AppSpacing.md),

            _buildFeatureCard(
              context: context,
              title: 'Interactive Chat Games',
              description: 'Would You Rather, This or That, Truth or Dare, Emoji Guess & Quick Quiz directly in chat bubbles.',
              badgeText: '5 GAMES',
              badgeVariant: ConvoBadgeVariant.accent,
              icon: Icons.sports_esports_rounded,
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
              ),
              onTap: () => _showGamesModal(context),
            ),
            const SizedBox(height: AppSpacing.md),

            _buildFeatureCard(
              context: context,
              title: 'Voice Message Effects',
              description: 'Preview and transform recordings non-destructively: Normal, Robot, Deep, Funny & Echo.',
              badgeText: 'PREVIEW',
              badgeVariant: ConvoBadgeVariant.subtle,
              icon: Icons.graphic_eq_rounded,
              gradient: const LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
              ),
              onTap: () => _showVoiceEffectsModal(context),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: AppColors.meshGradient,
        borderRadius: AppRadius.borderXl,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ConvoBadge(
            label: 'CHAT MAGIC HUB',
            variant: ConvoBadgeVariant.accent,
            icon: Icons.auto_awesome_rounded,
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Interactive & Expressive',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Explore stickers, games, time capsules, voice filters, and secret disappearing modes built for CONVO.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required BuildContext context,
    required String title,
    required String description,
    required String badgeText,
    required ConvoBadgeVariant badgeVariant,
    required IconData icon,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return ConvoCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: AppRadius.borderMd,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(child: Icon(icon, color: Colors.white, size: 24)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: AppTypography.titleMedium.copyWith(
                          color: context.convoColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    ConvoBadge(label: badgeText, variant: badgeVariant),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  description,
                  style: AppTypography.bodySmall.copyWith(
                    color: context.convoColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right_rounded,
            color: context.convoColors.textTertiary,
            size: 20,
          ),
        ],
      ),
    );
  }

  void _showPacksModal(BuildContext context, WidgetRef ref) {
    final starters = ref.read(starterStickersProvider);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Official CONVO Packs',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push(AppRoutes.stickerStudio);
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Open Studio'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Included with your CONVO account:',
              style: AppTypography.bodySmall.copyWith(
                color: context.convoColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: starters.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final sticker = starters[i];
                  return Container(
                    width: 80,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.convoColors.surfaceSubtle,
                      borderRadius: AppRadius.cardMd,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          sticker.emoji,
                          style: const TextStyle(fontSize: 28),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          sticker.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  void _showMoodsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chat Moods Available',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Set conversation atmosphere from any chat via the ✨ Chat Magic menu.',
              style: AppTypography.bodySmall.copyWith(
                color: context.convoColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ChatMood.presets.map((mood) {
                return Chip(
                  avatar: Text(
                    mood.emoji,
                    style: const TextStyle(fontSize: 16),
                  ),
                  label: Text(mood.label),
                  backgroundColor: context.convoColors.surfaceSubtle,
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  void _showGamesModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Interactive 2-Player Chat Games',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Launch directly into any 1-to-1 conversation via the ✨ Chat Magic menu. Both participants vote in live bubble cards!',
              style: AppTypography.bodySmall.copyWith(
                color: context.convoColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const ListTile(
              dense: true,
              leading: Text('🤔', style: TextStyle(fontSize: 22)),
              title: Text('Would You Rather'),
              subtitle: Text('Pick between two impossible choices'),
            ),
            const ListTile(
              dense: true,
              leading: Text('⚖️', style: TextStyle(fontSize: 22)),
              title: Text('This or That'),
              subtitle: Text('Fast-paced preference showdown'),
            ),
            const ListTile(
              dense: true,
              leading: Text('🧩', style: TextStyle(fontSize: 22)),
              title: Text('Emoji Guess'),
              subtitle: Text('Decode movies and songs in emoji'),
            ),
            const ListTile(
              dense: true,
              leading: Text('🎯', style: TextStyle(fontSize: 22)),
              title: Text('Truth or Dare & Quick Quiz'),
              subtitle: Text('Friendly questions and trivia challenge'),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  void _showVoiceEffectsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Voice Message Effects',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Non-destructively preview and modulate voice messages before dispatching.',
              style: AppTypography.bodySmall.copyWith(
                color: context.convoColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: VoiceEffectPreset.presets.map((preset) {
                return Chip(
                  avatar: Icon(preset.icon, size: 16),
                  label: Text('${preset.name} (${preset.description})'),
                  backgroundColor: context.convoColors.surfaceSubtle,
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}
