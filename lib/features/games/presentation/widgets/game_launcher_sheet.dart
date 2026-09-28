import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/extensions.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/models/game_model.dart';

class GameLauncherSheet extends ConsumerStatefulWidget {
  const GameLauncherSheet({
    super.key,
    required this.conversationId,
    required this.onGameSelected,
  });

  final String conversationId;
  final ValueChanged<GameModel> onGameSelected;

  static Future<void> show(
    BuildContext context, {
    required String conversationId,
    required ValueChanged<GameModel> onGameSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GameLauncherSheet(
        conversationId: conversationId,
        onGameSelected: onGameSelected,
      ),
    );
  }

  @override
  ConsumerState<GameLauncherSheet> createState() => _GameLauncherSheetState();
}

class _GameLauncherSheetState extends ConsumerState<GameLauncherSheet> {
  GameType _selectedType = GameType.wouldYouRather;
  late List<GameModel> _allTemplates;

  @override
  void initState() {
    super.initState();
    _allTemplates = GameModel.getPresetTemplates();
  }

  void _sendGame(GameModel template) {
    final user = ref.read(currentUserProfileProvider).asData?.value;
    final game = template.copyWith(
      id: 'game_${DateTime.now().millisecondsSinceEpoch}',
      creatorId: user?.uid ?? '',
      creatorName: user?.name ?? 'Player',
    );

    Navigator.of(context).pop();
    widget.onGameSelected(game);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _allTemplates
        .where((g) => g.gameType == _selectedType)
        .toList();

    return Container(
      height: 480,
      decoration: BoxDecoration(
        color: context.convoColors.cardBackground,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.convoColors.cardBorder,
                  borderRadius: AppRadius.borderPill,
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: AppRadius.borderSm,
                    ),
                    child: const Icon(
                      Icons.sports_esports_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'CONVO Chat Games',
                    style: AppTypography.titleLarge.copyWith(
                      color: context.convoColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Game Types horizontal bar
            SizedBox(
              height: 40,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                scrollDirection: Axis.horizontal,
                itemCount: GameType.values.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final type = GameType.values[index];
                  final isSelected = _selectedType == type;

                  return ChoiceChip(
                    avatar: Text(
                      type.emoji,
                      style: const TextStyle(fontSize: 14),
                    ),
                    label: Text(type.label),
                    selected: isSelected,
                    selectedColor: context.colorScheme.primary,
                    backgroundColor: context.convoColors.surfaceSubtle,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : context.convoColors.textPrimary,
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _selectedType = type);
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1),

            // Questions list
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  return Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: context.convoColors.surfaceSubtle,
                      borderRadius: AppRadius.borderMd,
                      border: Border.all(color: context.convoColors.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              item.title,
                              style: AppTypography.titleMedium.copyWith(
                                color: context.colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            FilledButton.tonal(
                              onPressed: () => _sendGame(item),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                              ),
                              child: const Text('Play'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.question,
                          style: AppTypography.bodyMedium.copyWith(
                            color: context.convoColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: item.options.map((opt) {
                            return Chip(
                              label: Text(
                                opt,
                                style: const TextStyle(fontSize: 11),
                              ),
                              backgroundColor:
                                  context.convoColors.cardBackground,
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
