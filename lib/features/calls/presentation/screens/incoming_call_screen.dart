import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/convo_avatar.dart';
import '../../domain/models/call_model.dart';
import '../providers/call_providers.dart';

class IncomingCallScreen extends ConsumerStatefulWidget {
  const IncomingCallScreen({super.key, required this.call});

  final CallModel call;

  @override
  ConsumerState<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends ConsumerState<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _acceptCall() async {
    final success = await ref
        .read(activeCallControllerProvider.notifier)
        .acceptCall(widget.call);

    if (mounted) {
      if (success) {
        context.pushReplacement('/call/active');
      } else {
        context.pop();
      }
    }
  }

  Future<void> _declineCall() async {
    await ref
        .read(activeCallControllerProvider.notifier)
        .rejectCall(widget.call.callId);

    if (mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to call updates; if caller cancels, dismiss
    ref.listen(incomingCallStreamProvider, (prev, next) {
      final ringingCall = next.asData?.value;
      if (ringingCall == null || ringingCall.callId != widget.call.callId) {
        if (mounted) context.pop();
      }
    });

    final isVideo = widget.call.isVideo;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _declineCall();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF090D16),
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 1),

              // Call Type Pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: AppRadius.borderPill,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isVideo
                          ? Icons.videocam_rounded
                          : Icons.phone_in_talk_rounded,
                      color: AppColors.accent,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isVideo ? 'Incoming Video Call' : 'Incoming Voice Call',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Pulsing Avatar
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 36,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: ConvoAvatar(
                    initials: widget.call.callerName.isNotEmpty
                        ? widget.call.callerName.substring(0, 1)
                        : '?',
                    size: 120,
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // Caller Name
              Text(
                widget.call.callerName,
                style: AppTypography.headlineMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),

              Text(
                'CONVO Mesh Audio/Video',
                style: AppTypography.bodySmall.copyWith(color: Colors.white70),
              ),

              const Spacer(flex: 2),

              // Action Buttons: Decline & Accept
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Decline
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: _declineCall,
                          borderRadius: BorderRadius.circular(40),
                          child: Container(
                            width: 68,
                            height: 68,
                            decoration: const BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x66EF4444),
                                  blurRadius: 16,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.call_end_rounded,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Decline',
                          style: AppTypography.labelMedium.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),

                    // Accept
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: _acceptCall,
                          borderRadius: BorderRadius.circular(40),
                          child: Container(
                            width: 68,
                            height: 68,
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x6610B981),
                                  blurRadius: 16,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Icon(
                              isVideo
                                  ? Icons.videocam_rounded
                                  : Icons.call_rounded,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Accept',
                          style: AppTypography.labelMedium.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}
