import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/extensions.dart';
import '../providers/chat_providers.dart';

class VoiceMessageBubble extends ConsumerStatefulWidget {
  const VoiceMessageBubble({
    super.key,
    required this.audioUrl,
    this.durationMs,
    required this.isMe,
  });

  final String audioUrl;
  final int? durationMs;
  final bool isMe;

  @override
  ConsumerState<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends ConsumerState<VoiceMessageBubble> {
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.durationMs != null && widget.durationMs! > 0) {
      _totalDuration = Duration(milliseconds: widget.durationMs!);
    }
  }

  void _togglePlayPause() {
    final audioService = ref.read(audioServiceProvider);

    if (_isPlaying) {
      audioService.pauseAudio();
      setState(() => _isPlaying = false);
    } else {
      setState(() => _isPlaying = true);
      audioService.playAudio(
        widget.audioUrl,
        onComplete: () {
          if (mounted) {
            setState(() {
              _isPlaying = false;
              _position = Duration.zero;
            });
          }
        },
        onPositionChanged: (pos) {
          if (mounted) {
            setState(() => _position = pos);
          }
        },
        onDurationChanged: (dur) {
          if (mounted && dur > Duration.zero) {
            setState(() => _totalDuration = dur);
          }
        },
      );
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString();
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.isMe
        ? Colors.white
        : context.colorScheme.primary;
    final trackColor = widget.isMe
        ? Colors.white.withValues(alpha: 0.3)
        : context.colorScheme.primary.withValues(alpha: 0.2);

    final displayDuration = _isPlaying
        ? _position
        : (_totalDuration > Duration.zero
              ? _totalDuration
              : Duration(milliseconds: widget.durationMs ?? 0));

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/Pause circular button
          InkWell(
            onTap: _togglePlayPause,
            borderRadius: AppRadius.borderPill,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: widget.isMe
                    ? Colors.white.withValues(alpha: 0.2)
                    : context.colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: activeColor,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Waveform bars simulation
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 24,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(18, (index) {
                      // Simulated waveform heights
                      final heights = [
                        8.0,
                        14.0,
                        20.0,
                        12.0,
                        18.0,
                        22.0,
                        10.0,
                        16.0,
                        24.0,
                        14.0,
                        18.0,
                        12.0,
                        20.0,
                        16.0,
                        8.0,
                        14.0,
                        10.0,
                        12.0,
                      ];
                      final progressFraction = _totalDuration.inMilliseconds > 0
                          ? _position.inMilliseconds /
                                _totalDuration.inMilliseconds
                          : 0.0;
                      final barFraction = index / 18.0;
                      final isPlayed = barFraction <= progressFraction;

                      return Container(
                        width: 3,
                        height: heights[index % heights.length],
                        decoration: BoxDecoration(
                          color: isPlayed ? activeColor : trackColor,
                          borderRadius: AppRadius.borderPill,
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDuration(displayDuration),
                  style: AppTypography.labelSmall.copyWith(
                    color: widget.isMe
                        ? Colors.white.withValues(alpha: 0.8)
                        : context.colorScheme.primary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
