import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/convo_app_bar.dart';
import '../../../../core/widgets/convo_avatar.dart';
import '../../../../core/widgets/convo_badge.dart';
import '../../../../core/widgets/convo_card.dart';
import '../../../../core/widgets/convo_setting_tile.dart';
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
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          children: [
            // 1. Profile Section
            _buildProfileHeaderCard(context, ref),
            const SizedBox(height: AppSpacing.lg),

            // 2. Appearance Section
            const ConvoSettingSectionHeader(title: 'APPEARANCE'),
            const SizedBox(height: AppSpacing.xs),
            _buildThemeSelectorCard(context, ref, themeMode),
            const SizedBox(height: AppSpacing.lg),

            // 3. Chat Settings Section
            const ConvoSettingSectionHeader(title: 'CHATS & MESSAGING'),
            const SizedBox(height: AppSpacing.xs),
            ConvoCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ConvoSettingTile(
                    icon: Icons.chat_bubble_outline_rounded,
                    iconColor: AppColors.primary,
                    title: AppStrings.chatSettings,
                    subtitle: AppStrings.chatSettingsDesc,
                    onTap: () => _showChatSettingsModal(context, ref),
                  ),
                  Divider(
                    height: 1,
                    indent: 56,
                    color: context.convoColors.cardBorder.withValues(alpha: 0.5),
                  ),
                  ConvoSettingTile(
                    icon: Icons.star_rounded,
                    iconColor: AppColors.amberGlow,
                    title: 'Saved Messages',
                    subtitle: 'Access bookmarked messages & media',
                    onTap: () => context.push(AppRoutes.starredMessages),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // 4. Secret Chat Section
            const ConvoSettingSectionHeader(title: 'SECRET & DISAPPEARING CHATS'),
            const SizedBox(height: AppSpacing.xs),
            ConvoCard(
              padding: EdgeInsets.zero,
              child: ConvoSettingTile(
                icon: Icons.timer_outlined,
                iconColor: AppColors.coralGlow,
                title: AppStrings.secretChat,
                subtitle: AppStrings.secretChatDesc,
                onTap: () => _showSecretChatSettingsModal(context),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // 5. Notifications Section
            const ConvoSettingSectionHeader(title: 'NOTIFICATIONS'),
            const SizedBox(height: AppSpacing.xs),
            ConvoCard(
              padding: EdgeInsets.zero,
              child: ConvoSettingTile(
                icon: Icons.notifications_none_rounded,
                iconColor: AppColors.blueGlow,
                title: AppStrings.notifications,
                subtitle: AppStrings.notificationsDesc,
                onTap: () => _showNotificationSettings(context, ref),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // 6. Privacy Section
            const ConvoSettingSectionHeader(title: 'PRIVACY & SECURITY'),
            const SizedBox(height: AppSpacing.xs),
            ConvoCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ConvoSettingTile(
                    icon: Icons.lock_outline_rounded,
                    iconColor: AppColors.accent,
                    title: AppStrings.privacy,
                    subtitle: AppStrings.privacyDesc,
                    onTap: () => _showPrivacySettings(context, ref),
                  ),
                  Divider(
                    height: 1,
                    indent: 56,
                    color: context.convoColors.cardBorder.withValues(alpha: 0.5),
                  ),
                  ConvoSettingTile(
                    icon: Icons.block_rounded,
                    iconColor: AppColors.error,
                    title: 'Blocked Contacts',
                    subtitle: 'Manage blocked users and unblock',
                    onTap: () => _showBlockedContactsModal(context, ref),
                  ),
                  Divider(
                    height: 1,
                    indent: 56,
                    color: context.convoColors.cardBorder.withValues(alpha: 0.5),
                  ),
                  ConvoSettingTile(
                    icon: Icons.security_rounded,
                    iconColor: AppColors.amberGlow,
                    title: AppStrings.security,
                    subtitle: AppStrings.securityDesc,
                    onTap: () => _showPlaceholderModal(
                      context,
                      title: AppStrings.security,
                      description:
                          'Setup biometric app lock, local encrypted key backups, and zero-knowledge session pins.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Nearby Offline Mesh
            const ConvoSettingSectionHeader(title: 'NEARBY & OFFLINE MESH'),
            const SizedBox(height: AppSpacing.xs),
            _buildNearbyModeCard(context, ref),
            const SizedBox(height: AppSpacing.sm),
            ConvoCard(
              padding: EdgeInsets.zero,
              child: ConvoSettingTile(
                icon: Icons.shield_outlined,
                iconColor: AppColors.accentPurple,
                title: 'Nearby Privacy & Consent',
                subtitle: 'Opt-in discovery • Session tokens • Zero leaks',
                onTap: () => _showNearbyPrivacyModal(context),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildOfflineQueueCard(context, ref),
            const SizedBox(height: AppSpacing.lg),

            // 7. About CONVO Section
            const ConvoSettingSectionHeader(title: 'ABOUT & SYSTEM'),
            const SizedBox(height: AppSpacing.xs),
            ConvoCard(
              padding: EdgeInsets.zero,
              child: ConvoSettingTile(
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
            ),
            const SizedBox(height: AppSpacing.xl),

            // Sign Out Action
            ConvoCard(
              padding: EdgeInsets.zero,
              child: ConvoSettingTile(
                icon: Icons.logout_rounded,
                isDestructive: true,
                title: 'Sign Out',
                subtitle: 'Disconnect active sessions on this device',
                onTap: () => _showLogoutConfirmation(context, ref),
              ),
            ),
            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeaderCard(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProfileProvider).asData?.value;
    final displayName = user?.name ?? 'Alex Rivera';
    final email = user?.email ?? '@alex.convo';
    final initials = user?.initials ??
        (displayName.isNotEmpty ? displayName[0].toUpperCase() : 'CO');

    return ConvoCard(
      onTap: () => context.push(AppRoutes.profile),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.brandGradient,
            ),
            child: ConvoAvatar(
              initials: initials,
              photoUrl: user?.photoUrl,
              size: 54,
              status: ConvoAvatarStatus.online,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleLarge.copyWith(
                          color: context.convoColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: AppRadius.borderPill,
                      ),
                      child: Text(
                        'ONLINE',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.accent,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: context.convoColors.textSecondary,
                  ),
                ),
                if (user?.effectiveBio != null &&
                    user!.effectiveBio.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    user.effectiveBio,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSmall.copyWith(
                      color: context.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(
            Icons.chevron_right_rounded,
            color: context.convoColors.textTertiary,
            size: 22,
          ),
        ],
      ),
    );
  }

  void _showChatSettingsModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.convoColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              AppStrings.chatSettings,
                              style: AppTypography.titleLarge.copyWith(
                                color: context.convoColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(sheetContext).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Customize chat behavior, input preferences, and media download settings.',
                      style: AppTypography.bodySmall.copyWith(
                        color: context.convoColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Enter is Send',
                        style: AppTypography.titleMedium.copyWith(
                          color: context.convoColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Enter key sends message on keyboard',
                        style: AppTypography.bodySmall.copyWith(
                          color: context.convoColors.textSecondary,
                        ),
                      ),
                      value: true,
                      onChanged: (val) {},
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Auto-Download on Wi-Fi',
                        style: AppTypography.titleMedium.copyWith(
                          color: context.convoColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Automatically download photos and voice notes',
                        style: AppTypography.bodySmall.copyWith(
                          color: context.convoColors.textSecondary,
                        ),
                      ),
                      value: true,
                      onChanged: (val) {},
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Save to Gallery',
                        style: AppTypography.titleMedium.copyWith(
                          color: context.convoColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Save received media to device photos',
                        style: AppTypography.bodySmall.copyWith(
                          color: context.convoColors.textSecondary,
                        ),
                      ),
                      value: false,
                      onChanged: (val) {},
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Clear Local Chat Cache',
                        style: AppTypography.titleMedium.copyWith(
                          color: context.convoColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Clears cached media files without deleting messages',
                        style: AppTypography.bodySmall.copyWith(
                          color: context.convoColors.textSecondary,
                        ),
                      ),
                      trailing: const Text(
                        '12.4 MB',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Chat cache cleared successfully.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSecretChatSettingsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.convoColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (sheetContext) {
        String selectedTimer = 'off';

        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.timer_outlined,
                              color: AppColors.coralGlow,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              AppStrings.secretChat,
                              style: AppTypography.titleLarge.copyWith(
                                color: context.convoColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(sheetContext).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Secret chats use end-to-end device keys and self-destructing messages that leave no cloud trace.',
                      style: AppTypography.bodySmall.copyWith(
                        color: context.convoColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Default Disappearing Message Timer',
                      style: AppTypography.labelMedium.copyWith(
                        color: context.convoColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'off', label: Text('Off')),
                        ButtonSegment(value: '30s', label: Text('30s')),
                        ButtonSegment(value: '5m', label: Text('5m')),
                        ButtonSegment(value: '1h', label: Text('1h')),
                        ButtonSegment(value: '24h', label: Text('24h')),
                      ],
                      selected: {selectedTimer},
                      onSelectionChanged: (newSelection) {
                        setModalState(() {
                          selectedTimer = newSelection.first;
                        });
                      },
                      style: SegmentedButton.styleFrom(
                        selectedBackgroundColor: AppColors.coralGlow,
                        selectedForegroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Screenshot Detection Alerts',
                        style: AppTypography.titleMedium.copyWith(
                          color: context.convoColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Send alert in conversation if recipient captures screen',
                        style: AppTypography.bodySmall.copyWith(
                          color: context.convoColors.textSecondary,
                        ),
                      ),
                      value: true,
                      onChanged: (val) {},
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.coralGlow.withValues(alpha: 0.1),
                        borderRadius: AppRadius.borderMd,
                        border: Border.all(
                          color: AppColors.coralGlow.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.security_rounded,
                            color: AppColors.coralGlow,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'CONVO Secret Chats use zero-knowledge ephemeral keys. Messages cannot be forwarded or recovered once deleted.',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.coralGlow,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showLogoutConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.convoColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderXl),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: AppColors.error),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Sign Out',
              style: AppTypography.titleLarge.copyWith(
                color: context.convoColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to sign out of CONVO? Your local offline mesh sessions will be disconnected.',
          style: AppTypography.bodyMedium.copyWith(
            color: context.convoColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await ref.read(authControllerProvider.notifier).signOut();
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
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

  void _showNotificationSettings(BuildContext context, WidgetRef ref) {
    final user = ref.read(currentUserProfileProvider).asData?.value;
    if (user == null) return;

    final currentSettings =
        Map<String, dynamic>.from(user.notificationSettings);

    showModalBottomSheet(
      context: context,
      backgroundColor: context.convoColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isEnabled = (currentSettings['enabled'] as bool?) ?? true;
            final isPreview = (currentSettings['preview'] as bool?) ?? true;
            final isSound = (currentSettings['sound'] as bool?) ?? true;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.notifications_active_outlined,
                              color: AppColors.blueGlow,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'Notification Settings',
                              style: AppTypography.titleLarge.copyWith(
                                color: context.convoColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(sheetContext).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Manage FCM message alerts, preview visibility, and notification sounds.',
                      style: AppTypography.bodySmall.copyWith(
                        color: context.convoColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Push Notifications',
                        style: AppTypography.titleMedium.copyWith(
                          color: context.convoColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Receive background and foreground message alerts',
                        style: AppTypography.bodySmall.copyWith(
                          color: context.convoColors.textSecondary,
                        ),
                      ),
                      value: isEnabled,
                      onChanged: (val) async {
                        setModalState(() {
                          currentSettings['enabled'] = val;
                        });
                        await ref
                            .read(profileControllerProvider.notifier)
                            .updateNotificationSettings(currentSettings);
                      },
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Message Previews',
                        style: AppTypography.titleMedium.copyWith(
                          color: context.convoColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Show sender name and message preview in notifications',
                        style: AppTypography.bodySmall.copyWith(
                          color: context.convoColors.textSecondary,
                        ),
                      ),
                      value: isPreview,
                      onChanged: !isEnabled
                          ? null
                          : (val) async {
                              setModalState(() {
                                currentSettings['preview'] = val;
                              });
                              await ref
                                  .read(profileControllerProvider.notifier)
                                  .updateNotificationSettings(currentSettings);
                            },
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Sound & Vibration',
                        style: AppTypography.titleMedium.copyWith(
                          color: context.convoColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Alert when new message is received',
                        style: AppTypography.bodySmall.copyWith(
                          color: context.convoColors.textSecondary,
                        ),
                      ),
                      value: isSound,
                      onChanged: !isEnabled
                          ? null
                          : (val) async {
                              setModalState(() {
                                currentSettings['sound'] = val;
                              });
                              await ref
                                  .read(profileControllerProvider.notifier)
                                  .updateNotificationSettings(currentSettings);
                            },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showPrivacySettings(BuildContext context, WidgetRef ref) {
    final user = ref.read(currentUserProfileProvider).asData?.value;
    if (user == null) return;

    final currentSettings = Map<String, dynamic>.from(user.privacySettings);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.convoColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Widget buildPrivacySelector(String title, String key, String desc) {
              final val = (currentSettings[key] as String?) ?? 'everyone';
              return Column(
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
                    desc,
                    style: AppTypography.bodySmall.copyWith(
                      color: context.convoColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'everyone', label: Text('Everyone')),
                      ButtonSegment(value: 'contacts', label: Text('Chats')),
                      ButtonSegment(value: 'nobody', label: Text('Nobody')),
                    ],
                    selected: {val},
                    onSelectionChanged: (newSelection) async {
                      setModalState(() {
                        currentSettings[key] = newSelection.first;
                      });
                      await ref
                          .read(profileControllerProvider.notifier)
                          .updatePrivacySettings(currentSettings);
                    },
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: context.colorScheme.primary,
                      selectedForegroundColor: Colors.white,
                      backgroundColor: context.convoColors.surfaceSubtle,
                      foregroundColor: context.convoColors.textSecondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.borderMd,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              );
            }

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.lock_outline_rounded,
                              color: AppColors.accent,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'Privacy Controls',
                              style: AppTypography.headlineMedium.copyWith(
                                color: context.convoColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(sheetContext).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Control who can view your sensitive profile details and presence.',
                      style: AppTypography.bodySmall.copyWith(
                        color: context.convoColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    buildPrivacySelector(
                      'Last Seen',
                      'lastSeen',
                      'Who can see when you were last online',
                    ),
                    buildPrivacySelector(
                      'Online Status',
                      'online',
                      'Who can see your real-time active status',
                    ),
                    buildPrivacySelector(
                      'Profile Photo',
                      'photo',
                      'Who can view your display picture',
                    ),
                    buildPrivacySelector(
                      'About / Bio',
                      'bio',
                      'Who can view your about snippet',
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showBlockedContactsModal(BuildContext context, WidgetRef ref) {
    final user = ref.read(currentUserProfileProvider).asData?.value;
    if (user == null) return;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: context.convoColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderXl),
        title: Row(
          children: [
            const Icon(Icons.block_rounded, color: AppColors.error),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Blocked Contacts',
              style: AppTypography.titleLarge.copyWith(
                color: context.convoColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: user.blockedUsers.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text(
                    'You have not blocked any contacts.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: context.convoColors.textSecondary,
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: user.blockedUsers.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final blockedUid = user.blockedUsers[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'User: ${blockedUid.length > 8 ? blockedUid.substring(0, 8) : blockedUid}...',
                        style: AppTypography.bodyMedium.copyWith(
                          color: context.convoColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: TextButton(
                        onPressed: () async {
                          await ref
                              .read(profileControllerProvider.notifier)
                              .unblockUser(blockedUid);
                          if (dialogCtx.mounted) {
                            Navigator.of(dialogCtx).pop();
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Contact unblocked.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        child: const Text('Unblock'),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Close'),
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
