import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/extensions.dart';
import '../../../chats/domain/models/message_model.dart';
import '../../../chats/presentation/providers/chat_providers.dart';
import '../../domain/models/game_model.dart';

class GameCardWidget extends ConsumerWidget {
  const GameCardWidget({
    super.key,
    required this.message,
    required this.currentUserId,
    required this.isMe,
  });

  final MessageModel message;
  final String currentUserId;
  final bool isMe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = message.metadata;
    if (meta == null || meta['game'] == null) {
      return Text(message.text);
    }

    final game = GameModel.fromMap(
      Map<String, dynamic>.from(meta['game'] as Map),
    );
    final myAnswer = game.answerOf(currentUserId);
    final hasAnswered = myAnswer != null;

    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.convoColors.cardBackground,
        borderRadius: AppRadius.borderMd,
        border: Border.all(
          color: context.colorScheme.primary.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Game Badge
          Row(
            children: [
              Text(game.gameType.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: AppSpacing.xs),
              Text(
                game.title,
                style: AppTypography.titleMedium.copyWith(
                  color: context.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color:
                      (game.answers.length >= 2
                              ? AppColors.success
                              : AppColors.amberGlow)
                          .withValues(alpha: 0.15),
                  borderRadius: AppRadius.borderPill,
                ),
                child: Text(
                  game.answers.length >= 2 ? 'Completed' : 'Live Game',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: game.answers.length >= 2
                        ? AppColors.success
                        : AppColors.amberGlow,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Question
          Text(
            game.question,
            style: AppTypography.bodyMedium.copyWith(
              color: context.convoColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Options / Choices
          Column(
            children: game.options.map((option) {
              final isMyPick = myAnswer == option;
              final totalVotes = game.answers.values
                  .where((v) => v == option)
                  .length;

              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  onTap: () async {
                    await ref
                        .read(chatControllerProvider.notifier)
                        .submitGameAnswer(
                          conversationId: message.conversationId,
                          messageId: message.id,
                          answer: option,
                        );
                  },
                  borderRadius: AppRadius.borderSm,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isMyPick
                          ? context.colorScheme.primary.withValues(alpha: 0.15)
                          : context.convoColors.surfaceSubtle,
                      borderRadius: AppRadius.borderSm,
                      border: Border.all(
                        color: isMyPick
                            ? context.colorScheme.primary
                            : context.convoColors.cardBorder,
                        width: isMyPick ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            option,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isMyPick
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isMyPick
                                  ? context.colorScheme.primary
                                  : context.convoColors.textPrimary,
                            ),
                          ),
                        ),
                        if (isMyPick)
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        if (hasAnswered && totalVotes > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: context.colorScheme.primary.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$totalVotes',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: context.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          // Footer
          if (hasAnswered)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'You picked: $myAnswer',
                style: AppTypography.labelSmall.copyWith(
                  color: context.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
