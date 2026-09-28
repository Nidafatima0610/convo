import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/extensions.dart';
import '../../../chats/presentation/providers/chat_providers.dart';
import '../../domain/models/voice_effect.dart';

class VoiceEffectPreviewBar extends ConsumerStatefulWidget {
  const VoiceEffectPreviewBar({
    super.key,
    required this.filePath,
    required this.durationSeconds,
    required this.onSend,
    required this.onDiscard,
  });

  final String filePath;
  final int durationSeconds;
  final Future<void> Function(String path, VoiceEffectPreset effect) onSend;
  final VoidCallback onDiscard;

  @override
  ConsumerState<VoiceEffectPreviewBar> createState() =>
      _VoiceEffectPreviewBarState();
}

class _VoiceEffectPreviewBarState extends ConsumerState<VoiceEffectPreviewBar> {
  VoiceEffectPreset _selectedEffect = VoiceEffectPreset.presets.first;
  bool _isPlaying = false;
  bool _isSending = false;
  StreamSubscription? _playerStateSub;

  @override
  void initState() {
    super.initState();
    final audioService = ref.read(audioServiceProvider);
    _playerStateSub = audioService.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = audioService.isPlaying(widget.filePath);
        });
      }
    });
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    final audioService = ref.read(audioServiceProvider);
    audioService.stop();
    super.dispose();
  }

  Future<void> _togglePreview() async {
    final audioService = ref.read(audioServiceProvider);
    if (_isPlaying) {
      await audioService.pause();
      setState(() => _isPlaying = false);
    } else {
      await audioService.play(
        widget.filePath,
        playbackRate: _selectedEffect.playbackSpeed,
      );
      setState(() => _isPlaying = true);
    }
  }

  void _selectEffect(VoiceEffectPreset effect) async {
    setState(() => _selectedEffect = effect);
    final audioService = ref.read(audioServiceProvider);
    if (_isPlaying) {
      await audioService.stop();
      await audioService.play(
        widget.filePath,
        playbackRate: effect.playbackSpeed,
      );
    }
  }

  Future<void> _handleSend() async {
    final audioService = ref.read(audioServiceProvider);
    await audioService.stop();
    setState(() => _isSending = true);
    try {
      await widget.onSend(widget.filePath, _selectedEffect);
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final minutes = (widget.durationSeconds ~/ 60).toString();
    final seconds = (widget.durationSeconds % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.convoColors.cardBackground,
        border: Border(
          top: BorderSide(color: context.convoColors.cardBorder, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Audio waveform & Play/Pause bar
          Row(
            children: [
              IconButton.filledTonal(
                icon: Icon(
                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 24,
                ),
                color: context.colorScheme.primary,
                onPressed: _togglePreview,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '$minutes:$seconds',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.convoColors.textPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Container(
                  height: 32,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(24, (index) {
                      final height = (index % 5 + 2) * 5.0;
                      return Container(
                        width: 3,
                        height: height,
                        decoration: BoxDecoration(
                          color: _isPlaying
                              ? context.colorScheme.primary
                              : context.convoColors.textTertiary.withValues(
                                  alpha: 0.5,
                                ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
                ),
                tooltip: 'Discard',
                onPressed: widget.onDiscard,
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: AppColors.meshGradient,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: _isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                  onPressed: _isSending ? null : _handleSend,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Effects selector chips
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: VoiceEffectPreset.presets.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final preset = VoiceEffectPreset.presets[index];
                final isSelected = _selectedEffect.type == preset.type;

                return ChoiceChip(
                  avatar: Icon(
                    preset.icon,
                    size: 16,
                    color: isSelected
                        ? Colors.white
                        : context.convoColors.textSecondary,
                  ),
                  label: Text(preset.name),
                  selected: isSelected,
                  selectedColor: context.colorScheme.primary,
                  backgroundColor: context.convoColors.surfaceSubtle,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : context.convoColors.textPrimary,
                  ),
                  onSelected: (val) {
                    if (val) _selectEffect(preset);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
