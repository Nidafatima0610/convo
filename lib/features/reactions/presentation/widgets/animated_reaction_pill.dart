import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/utils/extensions.dart';

class AnimatedReactionPill extends StatefulWidget {
  const AnimatedReactionPill({
    super.key,
    required this.emoji,
    required this.count,
    required this.isReactedByMe,
    required this.onTap,
  });

  final String emoji;
  final int count;
  final bool isReactedByMe;
  final VoidCallback onTap;

  @override
  State<AnimatedReactionPill> createState() => _AnimatedReactionPillState();
}

class _AnimatedReactionPillState extends State<AnimatedReactionPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.8,
          end: 1.25,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.25,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 50,
      ),
    ]).animate(_controller);

    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedReactionPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.count != widget.count ||
        oldWidget.isReactedByMe != widget.isReactedByMe) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTap: () {
          _controller.forward(from: 0.0);
          widget.onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: widget.isReactedByMe
                ? context.colorScheme.primary.withValues(alpha: 0.18)
                : context.convoColors.surfaceSubtle,
            borderRadius: AppRadius.borderPill,
            border: Border.all(
              color: widget.isReactedByMe
                  ? context.colorScheme.primary
                  : context.convoColors.cardBorder,
              width: widget.isReactedByMe ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.emoji, style: const TextStyle(fontSize: 14)),
              if (widget.count > 1) ...[
                const SizedBox(width: 3),
                Text(
                  '${widget.count}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: widget.isReactedByMe
                        ? context.colorScheme.primary
                        : context.convoColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
