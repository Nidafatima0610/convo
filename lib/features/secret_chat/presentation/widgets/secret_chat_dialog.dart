import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/extensions.dart';
import '../../../chats/domain/models/conversation_model.dart';
import '../../../chats/presentation/providers/chat_providers.dart';

class SecretChatDialog extends ConsumerStatefulWidget {
  const SecretChatDialog({super.key, required this.conversation});

  final ConversationModel conversation;

  static Future<void> show(
    BuildContext context,
    ConversationModel conversation,
  ) {
    return showDialog(
      context: context,
      builder: (context) => SecretChatDialog(conversation: conversation),
    );
  }

  @override
  ConsumerState<SecretChatDialog> createState() => _SecretChatDialogState();
}

class _SecretChatDialogState extends ConsumerState<SecretChatDialog> {
  late int? _selectedDuration;
  bool _isSaving = false;

  final List<Map<String, dynamic>> _options = const [
    {
      'label': 'Off',
      'seconds': null,
      'desc': 'Messages remain in chat indefinitely',
    },
    {
      'label': '10 seconds',
      'seconds': 10,
      'desc': 'Fast disappearing for quick secrets',
    },
    {
      'label': '1 minute',
      'seconds': 60,
      'desc': 'Disappears 60 seconds after sending',
    },
    {
      'label': '5 minutes',
      'seconds': 300,
      'desc': 'Disappears after 5 minutes',
    },
    {'label': '1 hour', 'seconds': 3600, 'desc': 'Disappears after 1 hour'},
    {
      'label': '1 day',
      'seconds': 86400,
      'desc': 'Disappears 24 hours after sending',
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedDuration = widget.conversation.disappearingDuration;
  }

  Future<void> _saveDuration() async {
    setState(() => _isSaving = true);
    try {
      final chatService = ref.read(chatServiceProvider);
      await chatService.updateDisappearingDuration(
        conversationId: widget.conversation.id,
        durationSeconds: _selectedDuration,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _selectedDuration == null
                  ? 'Disappearing messages turned off'
                  : 'Disappearing timer set to ${_formatDuration(_selectedDuration!)}',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update timer: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) {
      return '$seconds seconds';
    }
    if (seconds < 3600) {
      return '${seconds ~/ 60} minute${seconds ~/ 60 > 1 ? 's' : ''}';
    }
    if (seconds < 86400) {
      return '${seconds ~/ 3600} hour${seconds ~/ 3600 > 1 ? 's' : ''}';
    }
    return '${seconds ~/ 86400} day';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.dialog),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.timer_outlined,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Secret / Disappearing',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Auto-expire messages',
                  style: AppTypography.bodySmall.copyWith(
                    color: context.convoColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ..._options.map((option) {
              final seconds = option['seconds'] as int?;
              final isSelected = _selectedDuration == seconds;
              // ignore: deprecated_member_use
              return RadioListTile<int?>(
                dense: true,
                value: seconds,
                // ignore: deprecated_member_use
                groupValue: _selectedDuration,
                activeColor: context.colorScheme.primary,
                title: Text(
                  option['label'] as String,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  option['desc'] as String,
                  style: AppTypography.bodySmall.copyWith(
                    color: context.convoColors.textTertiary,
                    fontSize: 11,
                  ),
                ),
                // ignore: deprecated_member_use
                onChanged: (val) {
                  setState(() => _selectedDuration = val);
                },
              );
            }),
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: context.convoColors.surfaceSubtle,
                borderRadius: AppRadius.cardSm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Messages sent after setting this timer will be hidden and removed once the time elapses. Note: This does not prevent external camera capture or manual recording.',
                      style: AppTypography.bodySmall.copyWith(
                        fontSize: 10.5,
                        color: context.convoColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _saveDuration,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
