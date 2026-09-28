import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/convo_app_bar.dart';
import '../../../../core/widgets/convo_badge.dart';
import '../../../../core/widgets/convo_card.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../nearby/presentation/providers/nearby_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: ConvoAppBar(
        title: AppStrings.settingsTitle,
        subtitle: 'Preferences & Security',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          children: [
            _buildSectionHeader(context, 'PREFERENCES'),
            const SizedBox(height: AppSpacing.sm),
            _buildThemeSelectorCard(context, ref, themeMode),
            const SizedBox(height: AppSpacing.md),
            _buildSettingsItem(
              context,
              icon: Icons.notifications_none_rounded,
              iconColor: AppColors.blueGlow,
              title: AppStrings.notifications,
              subtitle: AppStrings.notificationsDesc,
              onTap: () => _showPlaceholderModal(
                context,
                title: AppStrings.notifications,
                description: 'Configure push notification priority, mesh alert vibrations, and conversation channels.',
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _buildSectionHeader(context, 'NEARBY & OFFLINE MESH'),
            const SizedBox(height: AppSpacing.sm),
            _buildNearbyModeCard(context, ref),
            const SizedBox(height: AppSpacing.md),
            _buildSettingsItem(
              context,
              icon: Icons.shield_outlined,
              iconColor: AppColors.accentPurple,
              title: 'Nearby Privacy & Consent',
              subtitle: 'Opt-in discovery • Session tokens • Zero leaks',
              onTap: () => _showNearbyPrivacyModal(context),
            ),
            const SizedBox(height: AppSpacing.md),
            _buildOfflineQueueCard(context, ref),
            const SizedBox(height: AppSpacing.xl),
            _buildSectionHeader(context, 'PRIVACY & SECURITY'),
            const SizedBox(height: AppSpacing.sm),
            _buildSettingsItem(
              context,
              icon: Icons.lock_outline_rounded,
              iconColor: AppColors.accent,
              title: AppStrings.privacy,
              subtitle: AppStrings.privacyDesc,
              onTap: () => _showPlaceholderModal(
                context,
                title: AppStrings.privacy,
                description: 'Manage your local Bluetooth mesh discovery range, visibility to peers, and profile discovery.',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _buildSettingsItem(
              context,
              icon: Icons.security_rounded,
              iconColor: AppColors.amberGlow,
              title: AppStrings.security,
              subtitle: AppStrings.securityDesc,
              onTap: () => _showPlaceholderModal(
                context,
                title: AppStrings.security,
                description: 'Setup biometric app lock, local encrypted key backups, and zero-knowledge session pins.',
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _buildSectionHeader(context, 'ABOUT & SYSTEM'),
            const SizedBox(height: AppSpacing.sm),
            _buildSettingsItem(
              context,
              icon: Icons.info_outline_rounded,
              iconColor: AppColors.violetGlow,
              title: AppStrings.about,
              subtitle: AppStrings.aboutDesc,
              trailing: const ConvoBadge(
                label: 'v${AppConstants.appVersion}',
                variant: ConvoBadgeVariant.subtle,
              ),
              onTap: () => _showAboutModal(context),
            ),
            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xs),
      child: Text(
        title,
        style: AppTypography.labelMedium.copyWith(
          color: context.convoColors.textTertiary,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildThemeSelectorCard(
    BuildContext context,
    WidgetRef ref,
    ThemeMode currentMode,
  ) {
    return ConvoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: context.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: AppRadius.borderSm,
                ),
                child: Icon(
                  Icons.palette_outlined,
                  color: context.colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.appearance,
                      style: AppTypography.titleMedium.copyWith(
                        color: context.convoColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      AppStrings.appearanceDesc,
                      style: AppTypography.bodySmall.copyWith(
                        color: context.convoColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment<ThemeMode>(
                value: ThemeMode.system,
                label: Text('System'),
                icon: Icon(Icons.brightness_auto_rounded, size: 16),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.light,
                label: Text('Light'),
                icon: Icon(Icons.light_mode_rounded, size: 16),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.dark,
                label: Text('Dark'),
                icon: Icon(Icons.dark_mode_rounded, size: 16),
              ),
            ],
            selected: {currentMode},
            onSelectionChanged: (newSelection) {
              ref
                  .read(themeModeProvider.notifier)
                  .setThemeMode(newSelection.first);
            },
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: context.colorScheme.primary,
              selectedForegroundColor: Colors.white,
              backgroundColor: context.convoColors.surfaceSubtle,
              foregroundColor: context.convoColors.textSecondary,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
              side: BorderSide(color: context.convoColors.cardBorder),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return ConvoCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: AppRadius.borderSm,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.titleMedium.copyWith(
                    color: context.convoColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.bodySmall.copyWith(
                    color: context.convoColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null)
            trailing
          else
            Icon(
              Icons.chevron_right_rounded,
              color: context.convoColors.textTertiary,
              size: 20,
            ),
        ],
      ),
    );
  }

  void _showPlaceholderModal(
    BuildContext context, {
    required String title,
    required String description,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.convoColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: AppTypography.headlineMedium.copyWith(
                      color: context.convoColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  const ConvoBadge(
                    label: AppStrings.comingSoon,
                    variant: ConvoBadgeVariant.primary,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                description,
                style: AppTypography.bodyMedium.copyWith(
                  color: context.convoColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.borderMd,
                  ),
                ),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAboutModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.convoColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderXl),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: AppColors.meshGradient,
                borderRadius: AppRadius.borderSm,
              ),
              child: const Icon(
                Icons.all_inclusive_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              AppConstants.appName,
              style: AppTypography.titleLarge.copyWith(
                color: context.convoColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppConstants.appTagline,
              style: AppTypography.titleMedium.copyWith(
                color: context.convoColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Version: ${AppConstants.appVersion} (${AppConstants.appBuildNumber})\n'
              'Protocol: ${AppConstants.meshProtocolVersion}\n\n'
              'CONVO is built for high-resilience, offline-capable peer communications '
              'with modern typography, encryption, and zero server lock-in.',
              style: AppTypography.bodySmall.copyWith(
                color: context.convoColors.textSecondary,
                height: 1.45,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyModeCard(BuildContext context, WidgetRef ref) {
    final nearbyState = ref.watch(nearbyControllerProvider);
    final isEnabled = nearbyState.isEnabled;

    String subtitleText;
    if (!isEnabled) {
      subtitleText = 'Turn on to discover & message people offline';
    } else if (nearbyState.hasConnectedPeers) {
      subtitleText =
          'Connected to ${nearbyState.connectedDevices.length} peer(s)';
    } else if (nearbyState.isSearching) {
      subtitleText = 'Searching for nearby CONVO peers...';
    } else {
      subtitleText = 'Nearby active';
    }

    return ConvoCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isEnabled
                  ? AppColors.accentPurple.withValues(alpha: 0.16)
                  : context.convoColors.cardBorder,
              borderRadius: AppRadius.borderSm,
            ),
            child: Icon(
              Icons.radar_rounded,
              color: isEnabled
                  ? AppColors.accentPurple
                  : context.convoColors.textTertiary,
              size: 22,
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
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitleText,
                  style: AppTypography.bodySmall.copyWith(
                    color: isEnabled
                        ? AppColors.accentPurple
                        : context.convoColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: isEnabled,
            activeTrackColor: AppColors.accentPurple,
            onChanged: (val) async {
              if (val) {
                final user = ref.read(currentUserProfileProvider).asData?.value;
                if (user == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please log in first to use Nearby.'),
                    ),
                  );
                  return;
                }
                final ok = await ref
                    .read(nearbyControllerProvider.notifier)
                    .enableNearby(user);
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Bluetooth / Nearby permissions are required for offline mode.',
                      ),
                    ),
                  );
                }
              } else {
                await ref
                    .read(nearbyControllerProvider.notifier)
                    .disableNearby();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineQueueCard(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(offlineQueueStreamProvider).asData?.value ?? [];

    return ConvoCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.blueGlow.withValues(alpha: 0.12),
              borderRadius: AppRadius.borderSm,
            ),
            child: const Icon(
              Icons.cloud_sync_outlined,
              color: AppColors.blueGlow,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Smart Offline Queue',
                  style: AppTypography.titleMedium.copyWith(
                    color: context.convoColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  queue.isEmpty
                      ? 'Queue empty • All messages synced'
                      : '${queue.length} message(s) waiting to sync',
                  style: AppTypography.bodySmall.copyWith(
                    color: context.convoColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (queue.isNotEmpty)
            TextButton(
              onPressed: () => _showClearQueueDialog(context, ref),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Clear'),
            ),
        ],
      ),
    );
  }

  void _showNearbyPrivacyModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.convoColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.shield_rounded,
                    color: AppColors.accentPurple,
                    size: 26,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Nearby Privacy & Safety',
                    style: AppTypography.headlineMedium.copyWith(
                      color: context.convoColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '• Opt-In Discovery: Your device is NEVER discoverable until you explicitly toggle Nearby Mode on.\n'
                '• Anonymous Handshake: Only temporary session identifiers and your display name are broadcasted.\n'
                '• No Private Exposure: Email addresses, phone numbers, and cloud profiles are NEVER shared over the local mesh.\n'
                '• Smart Sync: When internet connectivity returns, unsynced messages are idempotently stored to Firebase without duplicating.\n'
                '• Strict Permission Control: Bluetooth and local device permissions are requested only when enabling Nearby.',
                style: AppTypography.bodySmall.copyWith(
                  color: context.convoColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: AppColors.accentPurple,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.borderMd,
                  ),
                ),
                child: const Text('Understood'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showClearQueueDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: context.convoColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderXl),
        title: Text(
          'Clear Offline Queue?',
          style: AppTypography.titleLarge.copyWith(
            color: context.convoColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'This will permanently delete any pending messages stored locally that have not yet synced with Firebase or nearby peers.',
          style: AppTypography.bodyMedium.copyWith(
            color: context.convoColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              final queueStorage = ref.read(offlineQueueStorageServiceProvider);
              await queueStorage.clearQueue();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Offline queue cleared.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Clear Queue'),
          ),
        ],
      ),
    );
  }
}
