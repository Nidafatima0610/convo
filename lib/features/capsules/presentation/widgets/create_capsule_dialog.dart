import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/extensions.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/models/capsule_model.dart';

class CreateCapsuleDialog extends ConsumerStatefulWidget {
  const CreateCapsuleDialog({
    super.key,
    required this.conversationId,
    required this.receiverId,
    required this.receiverName,
    required this.onCapsuleCreated,
  });

  final String conversationId;
  final String receiverId;
  final String receiverName;
  final ValueChanged<CapsuleModel> onCapsuleCreated;

  static Future<void> show(
    BuildContext context, {
    required String conversationId,
    required String receiverId,
    required String receiverName,
    required ValueChanged<CapsuleModel> onCapsuleCreated,
  }) {
    return showDialog(
      context: context,
      builder: (context) => CreateCapsuleDialog(
        conversationId: conversationId,
        receiverId: receiverId,
        receiverName: receiverName,
        onCapsuleCreated: onCapsuleCreated,
      ),
    );
  }

  @override
  ConsumerState<CreateCapsuleDialog> createState() =>
      _CreateCapsuleDialogState();
}

class _CreateCapsuleDialogState extends ConsumerState<CreateCapsuleDialog> {
  final TextEditingController _messageController = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(hours: 24));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  DateTime get _effectiveUnlockDateTime {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  void _submitCapsule() {
    final text = _messageController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a capsule message.')),
      );
      return;
    }

    final unlockAt = _effectiveUnlockDateTime;
    if (unlockAt.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unlock time must be in the future.')),
      );
      return;
    }

    final user = ref.read(currentUserProfileProvider).asData?.value;
    final capsule = CapsuleModel(
      id: 'cap_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: widget.conversationId,
      senderId: user?.uid ?? '',
      senderName: user?.name ?? 'You',
      receiverId: widget.receiverId,
      receiverName: widget.receiverName,
      message: text,
      unlockAt: unlockAt,
      createdAt: DateTime.now(),
      status: CapsuleStatus.locked,
    );

    Navigator.of(context).pop();
    widget.onCapsuleCreated(capsule);
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate =
        '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}';
    final formattedTime = _selectedTime.format(context);

    return AlertDialog(
      backgroundColor: context.convoColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.borderXl),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.accentPurple.withValues(alpha: 0.12),
              borderRadius: AppRadius.borderSm,
            ),
            child: const Icon(
              Icons.hourglass_top_rounded,
              color: AppColors.accentPurple,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Message Capsule',
            style: AppTypography.titleLarge.copyWith(
              color: context.convoColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lock a message in time for ${widget.receiverName}. It will remain strictly encrypted & locked until the exact scheduled moment.',
              style: AppTypography.bodySmall.copyWith(
                color: context.convoColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Message text input
            TextField(
              controller: _messageController,
              maxLines: 3,
              maxLength: 250,
              decoration: InputDecoration(
                hintText:
                    'e.g. Open this tomorrow! Good luck for your interview ❤️',
                border: OutlineInputBorder(borderRadius: AppRadius.borderMd),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Unlock Date & Time selector
            Text(
              'UNLOCK SCHEDULE',
              style: AppTypography.labelMedium.copyWith(
                color: context.convoColors.textTertiary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_rounded, size: 16),
                    label: Text(formattedDate),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.borderMd,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.access_time_rounded, size: 16),
                    label: Text(formattedTime),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.borderMd,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitCapsule,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accentPurple,
          ),
          child: const Text('Lock & Schedule'),
        ),
      ],
    );
  }
}
