import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/convo_app_bar.dart';
import '../../../../core/widgets/convo_avatar.dart';
import '../../../../core/widgets/convo_card.dart';
import '../../../auth/domain/models/convo_user.dart';
import '../../domain/models/nearby_device.dart';
import '../providers/nearby_providers.dart';
import '../widgets/nearby_radar_widget.dart';

class NearbyScreen extends ConsumerStatefulWidget {
  const NearbyScreen({super.key});

  @override
  ConsumerState<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends ConsumerState<NearbyScreen> {
  void _showPrivacyExplanationModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.convoColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppRadius.radiusXl),
      ),
      builder: (modalContext) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    color: AppColors.accent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  'Privacy & Mesh Security',
                  style: AppTypography.titleLarge.copyWith(
                    color: context.convoColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'CONVO Nearby uses direct device-to-device radio signals (Bluetooth and local Wi-Fi) to exchange messages without any internet connection.\n\n'
              '• Your email and phone number are NEVER broadcasted.\n'
              '• Only your chosen display name is visible to peers.\n'
              '• Discovery is completely opt-in and can be turned off at any time.\n'
              '• When internet returns, queued messages sync automatically.',
              style: AppTypography.bodyMedium.copyWith(
                color: context.convoColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(modalContext).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: context.colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.borderMd,
                  ),
                ),
                child: const Text('Understood'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openChatWithPeer(NearbyDevice peer) {
    final peerUserId = peer.userId ?? peer.endpointId;
    final otherUser = ConvoUser(
      uid: peerUserId,
      name: peer.displayName,
      email: 'nearby@convo.mesh',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Derive a local conversation ID for the direct peer
    final conversationId = 'nearby_$peerUserId';
    context.push('/chat/$conversationId', extra: otherUser);
  }

  @override
  Widget build(BuildContext context) {
    final nearbyState = ref.watch(nearbyControllerProvider);
    final nearbyNotifier = ref.read(nearbyControllerProvider.notifier);

    return Scaffold(
      appBar: ConvoAppBar(
        title: 'CONVO Nearby',
        subtitle: 'Offline Mesh Network',
        actions: [
          IconButton(
            icon: const Icon(Icons.shield_outlined),
            tooltip: 'Mesh Privacy',
            onPressed: () => _showPrivacyExplanationModal(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Main animated radar mesh illustration
              const NearbyRadarWidget(),
              const SizedBox(height: AppSpacing.lg),

              // Title & Subtitle
              Text(
                'CONVO Nearby',
                textAlign: TextAlign.center,
                style: AppTypography.headlineLarge.copyWith(
                  color: context.convoColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(
                  'Message people around you — even without internet.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(
                    color: context.convoColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // Nearby Toggle Switch Card
              ConvoCard(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color:
                            (nearbyState.isEnabled
                                    ? AppColors.accent
                                    : Colors.grey)
                                .withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.radar_rounded,
                        color: nearbyState.isEnabled
                            ? AppColors.accent
                            : context.convoColors.textTertiary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nearby Offline Mode',
                            style: AppTypography.titleMedium.copyWith(
                              color: context.convoColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            nearbyState.isEnabled
                                ? (nearbyState.hasConnectedPeers
                                      ? 'Connected to direct peers'
                                      : 'Searching for CONVO peers...')
                                : 'Disabled (Privacy protected)',
                            style: AppTypography.labelSmall.copyWith(
                              color: nearbyState.isEnabled
                                  ? AppColors.accent
                                  : context.convoColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: nearbyState.isEnabled,
                      activeTrackColor: AppColors.accent,
                      onChanged: (enable) {
                        nearbyNotifier.toggleNearby(enable);
                      },
                    ),
                  ],
                ),
              ),

              if (nearbyState.errorMessage != null) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: AppRadius.borderMd,
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.error,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          nearbyState.errorMessage!,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.xl),

              // Connected Peers Section
              if (nearbyState.connectedDevices.isNotEmpty) ...[
                _buildSectionHeader('CONNECTED DIRECTLY (OFFLINE)'),
                const SizedBox(height: AppSpacing.sm),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: nearbyState.connectedDevices.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final device = nearbyState.connectedDevices[index];
                    return _buildConnectedDeviceTile(
                      device: device,
                      onChat: () => _openChatWithPeer(device),
                      onDisconnect: () =>
                          nearbyNotifier.disconnectDevice(device.endpointId),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
              ],

              // Discovered Peers Section (When Enabled)
              if (nearbyState.isEnabled) ...[
                _buildSectionHeader('DISCOVERED PEERS NEARBY'),
                const SizedBox(height: AppSpacing.sm),
                if (nearbyState.discoveredDevices.isEmpty)
                  _buildScanningPlaceholder()
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: nearbyState.discoveredDevices.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final device = nearbyState.discoveredDevices[index];
                      return _buildDiscoveredDeviceTile(
                        device: device,
                        onConnect: () => nearbyNotifier.connectToDevice(device),
                      );
                    },
                  ),
              ],

              const SizedBox(height: AppSpacing.xxxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: AppTypography.labelMedium.copyWith(
          color: context.convoColors.textTertiary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildScanningPlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.convoColors.surfaceSubtle,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: context.convoColors.cardBorder),
      ),
      child: Column(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Scanning for nearby devices...',
            style: AppTypography.titleMedium.copyWith(
              color: context.convoColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Ensure the other person has CONVO Nearby turned on.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: context.convoColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedDeviceTile({
    required NearbyDevice device,
    required VoidCallback onChat,
    required VoidCallback onDisconnect,
  }) {
    final initials =
        device.avatarInitials ??
        (device.displayName.isNotEmpty
            ? device.displayName.substring(0, 1)
            : '?');

    return ConvoCard(
      child: Row(
        children: [
          ConvoAvatar(
            initials: initials,
            size: 46,
            status: ConvoAvatarStatus.meshActive,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.displayName,
                  style: AppTypography.titleMedium.copyWith(
                    color: context.convoColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Direct Offline Mesh',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          FilledButton.tonal(
            onPressed: onChat,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              backgroundColor: context.colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Chat'),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            tooltip: 'Disconnect',
            onPressed: onDisconnect,
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoveredDeviceTile({
    required NearbyDevice device,
    required VoidCallback onConnect,
  }) {
    final initials = device.displayName.isNotEmpty
        ? device.displayName.substring(0, 1)
        : '?';

    return ConvoCard(
      child: Row(
        children: [
          ConvoAvatar(initials: initials, size: 44),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.displayName,
                  style: AppTypography.titleMedium.copyWith(
                    color: context.convoColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  device.isConnecting ? 'Connecting...' : 'CONVO Peer Found',
                  style: AppTypography.labelSmall.copyWith(
                    color: device.isConnecting
                        ? AppColors.amberGlow
                        : context.convoColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          if (device.isConnecting)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            FilledButton(
              onPressed: onConnect,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              child: const Text('Connect'),
            ),
        ],
      ),
    );
  }
}
