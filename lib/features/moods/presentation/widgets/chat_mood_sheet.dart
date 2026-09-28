import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/extensions.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../chats/presentation/providers/chat_providers.dart';
import '../../domain/models/chat_mood.dart';

class ChatMoodSheet extends ConsumerStatefulWidget {
  const ChatMoodSheet({
    super.key,
    required this.conversationId,
    this.currentMood,
  });

  final String conversationId;
  final ChatMood? currentMood;

  static Future<void> show(
    BuildContext context, {
    required String conversationId,
    ChatMood? currentMood,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ChatMoodSheet(
        conversationId: conversationId,
        currentMood: currentMood,
      ),
    );
  }

  @override
  ConsumerState<ChatMoodSheet> createState() => _ChatMoodSheetState();
}

class _ChatMoodSheetState extends ConsumerState<ChatMoodSheet> {
  late ChatMoodType _selectedType;
  final TextEditingController _customController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.currentMood?.type ?? ChatMoodType.chill;
    if (widget.currentMood?.customText != null) {
      _customController.text = widget.currentMood!.customText!;
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  Future<void> _applyMood(ChatMoodPreset preset) async {
    final user = ref.read(currentUserProfileProvider).asData?.value;
    setState(() => _isSaving = true);

    try {
      final customText = _selectedType == ChatMoodType.custom
          ? _customController.text.trim()
          : null;

      final mood = ChatMood(
        type: preset.type,
        emoji: preset.emoji,
        label: preset.label,
        colorHex: preset.colorHex,
        customText: customText,
        setByUserId: user?.uid,
        setByName: user?.name,
        setAt: DateTime.now(),
      );

      final chatService = ref.read(chatServiceProvider);
      await chatService.updateConversationMood(
        conversationId: widget.conversationId,
        mood: mood,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chat mood set to ${preset.emoji} ${preset.label}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to update mood: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _clearMood() async {
    setState(() => _isSaving = true);
    try {
      final chatService = ref.read(chatServiceProvider);
      await chatService.clearConversationMood(widget.conversationId);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chat mood cleared.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to clear mood: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: context.convoColors.cardBackground,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.convoColors.cardBorder,
                  borderRadius: AppRadius.borderPill,
                ),
              ),
            ),

            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.accentPurple.withValues(alpha: 0.12),
                    borderRadius: AppRadius.borderSm,
                  ),
                  child: const Icon(
                    Icons.theater_comedy_rounded,
                    color: AppColors.accentPurple,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Conversation Mood',
                  style: AppTypography.titleLarge.copyWith(
                    color: context.convoColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (widget.currentMood != null)
                  TextButton(
                    onPressed: _isSaving ? null : _clearMood,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                    child: const Text('Clear'),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Set a shared aesthetic vibe for this conversation',
              style: AppTypography.bodySmall.copyWith(
                color: context.convoColors.textSecondary,
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Presets List
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: ChatMood.presets.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final preset = ChatMood.presets[index];
                  final isSelected = _selectedType == preset.type;
                  final hexColor = Color(
                    int.parse('FF${preset.colorHex}', radix: 16),
                  );

                  return InkWell(
                    onTap: _isSaving ? null : () => _applyMood(preset),
                    borderRadius: AppRadius.borderMd,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? hexColor.withValues(alpha: 0.14)
                            : context.convoColors.surfaceSubtle,
                        borderRadius: AppRadius.borderMd,
                        border: Border.all(
                          color: isSelected
                              ? hexColor
                              : context.convoColors.cardBorder,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            preset.emoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  preset.label,
                                  style: AppTypography.titleMedium.copyWith(
                                    color: context.convoColors.textPrimary,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  preset.tagline,
                                  style: AppTypography.labelSmall.copyWith(
                                    color: context.convoColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle_rounded,
                              color: hexColor,
                              size: 20,
                            ),
                        ],
                      ),
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
