import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/convo_avatar.dart';
import '../../../../core/widgets/convo_badge.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/call_providers.dart';

class ActiveCallScreen extends ConsumerStatefulWidget {
  const ActiveCallScreen({super.key});

  @override
  ConsumerState<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends ConsumerState<ActiveCallScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _endCall() async {
    await ref.read(activeCallControllerProvider.notifier).endCall();
    if (mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final callState = ref.watch(activeCallControllerProvider);
    final currentUserId =
        ref.watch(authStateChangesProvider).asData?.value?.uid ?? '';

    // Auto-pop when call has ended
    ref.listen(activeCallControllerProvider, (prev, next) {
      if (next.connectionState == CallConnectionState.ended &&
          prev?.connectionState != CallConnectionState.ended) {
        Future.delayed(const Duration(milliseconds: 900), () {
          if (!mounted) return;
          if (context.mounted && context.canPop()) {
            context.pop();
          }
        });
      }
    });

    final call = callState.call;
    final otherName = call?.otherUserName(currentUserId) ?? 'User';
    final otherPhoto = call?.otherUserPhoto(currentUserId);
    final isVideo = callState.isVideo;

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: const Color(0xFF070A12),
        body: Stack(
          children: [
            // Background / Video Renderer Area
            if (isVideo)
              _buildVideoArea(callState)
            else
              _buildVoiceArea(callState, otherName, otherPhoto),

            // Top Status & Navigation Bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                        tooltip: 'Minimize',
                        onPressed: () => context.pop(),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              otherName,
                              style: AppTypography.titleMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            _buildStatusSubtitle(callState),
                          ],
                        ),
                      ),
                      const ConvoBadge(
                        label: 'E2EE',
                        variant: ConvoBadgeVariant.primary,
                        icon: Icons.lock_outline_rounded,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Floating Local Video Preview (in Video Mode)
            if (isVideo && callState.webrtc != null)
              Positioned(
                top: 90,
                right: 16,
                child: _buildLocalVideoPip(callState),
              ),

            // Bottom Floating Controls Dock
            Positioned(
              bottom: 30,
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              child: SafeArea(child: _buildControlsDock(callState, isVideo)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSubtitle(ActiveCallState state) {
    String text;
    Color color = Colors.white70;

    switch (state.connectionState) {
      case CallConnectionState.ringing:
        text = 'Ringing...';
        color = AppColors.accent;
        break;
      case CallConnectionState.connecting:
        text = 'Connecting...';
        color = AppColors.amberGlow;
        break;
      case CallConnectionState.connected:
        text = _formatDuration(state.elapsedDuration);
        color = AppColors.success;
        break;
      case CallConnectionState.reconnecting:
        text = 'Reconnecting...';
        color = AppColors.warning;
        break;
      case CallConnectionState.ended:
        text = 'Call Ended';
        color = AppColors.error;
        break;
      case CallConnectionState.failed:
        text = state.errorMessage ?? 'Call Failed';
        color = AppColors.error;
        break;
      case CallConnectionState.idle:
        text = 'Ready';
        break;
    }

    return Text(
      text,
      style: AppTypography.labelSmall.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildVoiceArea(
    ActiveCallState state,
    String otherName,
    String? otherPhoto,
  ) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF090D16)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 48,
                    spreadRadius: 16,
                  ),
                ],
              ),
              child: ConvoAvatar(
                initials: otherName.isNotEmpty
                    ? otherName.substring(0, 1)
                    : '?',
                size: 130,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            otherName,
            style: AppTypography.headlineMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            state.isConnected
                ? _formatDuration(state.elapsedDuration)
                : (state.connectionState == CallConnectionState.ringing
                      ? 'Ringing...'
                      : 'Connecting to CONVO mesh...'),
            style: AppTypography.titleMedium.copyWith(
              color: state.isConnected ? AppColors.success : Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildVideoArea(ActiveCallState state) {
    if (state.webrtc != null && state.isConnected) {
      return SizedBox.expand(
        child: RTCVideoView(
          state.webrtc!.remoteRenderer,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        ),
      );
    }

    // Connecting or Ringing placeholder
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFF090D16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: AppSpacing.lg),
            Text(
              state.isRinging
                  ? 'Calling ${state.call?.receiverName}...'
                  : 'Establishing HD video stream...',
              style: AppTypography.bodyMedium.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalVideoPip(ActiveCallState state) {
    return Container(
      width: 105,
      height: 155,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: AppRadius.borderMd,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: AppRadius.borderMd,
        child: state.isCameraOff
            ? Container(
                color: const Color(0xFF1E293B),
                child: const Center(
                  child: Icon(
                    Icons.videocam_off_rounded,
                    color: Colors.white54,
                    size: 28,
                  ),
                ),
              )
            : RTCVideoView(
                state.webrtc!.localRenderer,
                mirror: true,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
      ),
    );
  }

  Widget _buildControlsDock(ActiveCallState state, bool isVideo) {
    final notifier = ref.read(activeCallControllerProvider.notifier);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xCC111827),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Microphone Toggle
          _CallControlButton(
            icon: state.isMicMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            label: state.isMicMuted ? 'Muted' : 'Mute',
            isActive: state.isMicMuted,
            activeColor: AppColors.error,
            onTap: notifier.toggleMicrophone,
          ),

          // Camera Toggle (Video Only)
          if (isVideo)
            _CallControlButton(
              icon: state.isCameraOff
                  ? Icons.videocam_off_rounded
                  : Icons.videocam_rounded,
              label: state.isCameraOff ? 'Cam Off' : 'Camera',
              isActive: state.isCameraOff,
              activeColor: AppColors.error,
              onTap: notifier.toggleCamera,
            ),

          // Switch Camera (Video Only)
          if (isVideo)
            _CallControlButton(
              icon: Icons.cameraswitch_rounded,
              label: 'Flip',
              isActive: false,
              onTap: notifier.switchCamera,
            ),

          // Speakerphone Toggle
          _CallControlButton(
            icon: state.isSpeakerOn
                ? Icons.volume_up_rounded
                : Icons.volume_down_rounded,
            label: state.isSpeakerOn ? 'Speaker' : 'Earpiece',
            isActive: state.isSpeakerOn,
            activeColor: AppColors.accent,
            onTap: notifier.toggleSpeaker,
          ),

          // End Call Button
          InkWell(
            onTap: _endCall,
            borderRadius: BorderRadius.circular(28),
            child: Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x66EF4444),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.call_end_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CallControlButton extends StatelessWidget {
  const _CallControlButton({
    required this.icon,
    required this.label,
    required this.isActive,
    this.activeColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final Color? activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final effectiveActiveColor = activeColor ?? AppColors.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isActive
                    ? effectiveActiveColor
                    : Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: Colors.white70,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
