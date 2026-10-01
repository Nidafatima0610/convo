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
import '../../../../core/widgets/convo_badge.dart';
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
              const SizedBox(height: AppSpacing.md),

              // Concept Badges
              Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: const [
                  ConvoBadge(
                    label: 'PEOPLE NEARBY',
                    variant: ConvoBadgeVariant.primary,
                    icon: Icons.people_outline_rounded,
                  ),
                  ConvoBadge(
                    label: 'OFFLINE CHAT',
                    variant: ConvoBadgeVariant.accent,
                    icon: Icons.wifi_off_rounded,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

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

              const SizedBox(height: AppSpacing.lg),

              // Offline Chat Concept Highlights Card
              _buildOfflineChatConceptCard(context),

              const SizedBox(height: AppSpacing.lg),

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

              // People Nearby Discovery Section
              _buildSectionHeader('PEOPLE NEARBY'),
              const SizedBox(height: 2),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'DISCOVERED PEERS NEARBY',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (!nearbyState.isEnabled)
                _buildDisabledDiscoveryPlaceholder(context)
              else if (nearbyState.discoveredDevices.isEmpty)
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

  Widget _buildOfflineChatConceptCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.convoColors.surfaceSubtle,
        borderRadius: AppRadius.borderLg,
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: AppRadius.borderSm,
                ),
                child: const Icon(
                  Icons.offline_bolt_rounded,
                  color: AppColors.accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'How Offline Chat Works',
                style: AppTypography.titleMedium.copyWith(
                  color: context.convoColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildConceptBullet(
            icon: Icons.bluetooth_searching_rounded,
            title: 'Direct Peer-to-Peer',
            description: 'Direct radios link nearby devices without cell towers.',
          ),
          const SizedBox(height: 6),
          _buildConceptBullet(
            icon: Icons.lock_outline_rounded,
            title: 'Zero Leak Encryption',
            description: 'Packets are encrypted; no phone numbers or emails exposed.',
          ),
          const SizedBox(height: 6),
          _buildConceptBullet(
            icon: Icons.sync_rounded,
            title: 'Smart Queue & Sync',
            description: 'Messages sync to cloud automatically when back online.',
          ),
        ],
      ),
    );
  }

  Widget _buildConceptBullet({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: AppColors.accent,
        ),
        const SizedBox(width: AppSpacing.xs + 2),
        Expanded(
          child: RichText(
            text: TextSpan(
              text: '$title: ',
              style: AppTypography.bodySmall.copyWith(
                color: context.convoColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
              children: [
                TextSpan(
                  text: description,
                  style: AppTypography.bodySmall.copyWith(
                    color: context.convoColors.textSecondary,
                    fontWeight: FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDisabledDiscoveryPlaceholder(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: context.convoColors.surfaceSubtle,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: context.convoColors.cardBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.convoColors.textTertiary.withValues(alpha: 0.12),
            ),
            child: Icon(
              Icons.radar_outlined,
              color: context.convoColors.textTertiary,
              size: 24,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Nearby Discovery Paused',
            style: AppTypography.titleMedium.copyWith(
              color: context.convoColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(
              'Turn on Nearby Offline Mode above to discover and message people nearby without internet.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: context.convoColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanningPlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: context.convoColors.surfaceSubtle,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: context.convoColors.cardBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withValues(alpha: 0.15),
            ),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.accent,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Searching for People Nearby',
            style: AppTypography.titleMedium.copyWith(
              color: context.convoColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(
              'Nearby people will appear here automatically when the feature is available and active peers are within Bluetooth or Wi-Fi range.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: context.convoColors.textSecondary,
                height: 1.4,
              ),
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
