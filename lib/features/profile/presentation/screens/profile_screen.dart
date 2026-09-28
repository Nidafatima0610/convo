import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/convo_app_bar.dart';
import '../../../../core/widgets/convo_avatar.dart';
import '../../../../core/widgets/convo_badge.dart';
import '../../../../core/widgets/convo_button.dart';
import '../../../../core/widgets/convo_card.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _onEditProfile(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Edit profile and avatar customization coming soon!',
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
      ),
    );
  }

  void _onShareQr(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Local mesh peer QR code sharing coming soon!'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
      ),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(currentUserProfileProvider).asData?.value;
    final authUser = ref.watch(authStateChangesProvider).asData?.value;

    final displayName =
        userProfile?.name ??
        authUser?.displayName ??
        AppStrings.defaultUserDisplayName;
    final email =
        userProfile?.email ?? authUser?.email ?? AppStrings.defaultUserHandle;
    final initials =
        userProfile?.initials ??
        (displayName.isNotEmpty ? displayName[0].toUpperCase() : 'CO');

    return Scaffold(
      appBar: ConvoAppBar(
        title: AppStrings.profileTitle,
        subtitle: AppStrings.profileSubtitle,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: AppStrings.settings,
            onPressed: () => context.push('/profile/settings'),
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
            children: [
              const SizedBox(height: AppSpacing.sm),
              // Avatar with camera edit badge
              ConvoAvatar(
                initials: initials,
                size: 92,
                status: ConvoAvatarStatus.meshActive,
                showEditBadge: true,
                onTap: () => _onEditProfile(context),
              ),
              const SizedBox(height: AppSpacing.md),

              // Name from authenticated Firestore profile
              Text(
                displayName,
                style: AppTypography.headlineLarge.copyWith(
                  color: context.convoColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),

              // Email from authenticated user
              Text(
                email,
                style: AppTypography.bodyMedium.copyWith(
                  color: context.convoColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Offline Mesh Status Chip
              const ConvoBadge(
                label: 'OFFLINE MESH READY',
                variant: ConvoBadgeVariant.accent,
                icon: Icons.wifi_tethering_rounded,
              ),

              const SizedBox(height: AppSpacing.lg),

              // Quick action buttons
              Row(
                children: [
                  Expanded(
                    child: ConvoButton(
                      label: AppStrings.editProfile,
                      icon: Icons.edit_outlined,
                      variant: ConvoButtonVariant.outline,
                      height: 44,
                      onPressed: () => _onEditProfile(context),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ConvoButton(
                      label: AppStrings.shareProfile,
                      icon: Icons.qr_code_rounded,
                      variant: ConvoButtonVariant.tonal,
                      height: 44,
                      onPressed: () => _onShareQr(context),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xl),

              // Mesh Identity Card
              ConvoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.12),
                            borderRadius: AppRadius.borderSm,
                          ),
                          child: const Icon(
                            Icons.fingerprint_rounded,
                            color: AppColors.accent,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Local Mesh Address',
                                style: AppTypography.titleMedium.copyWith(
                                  color: context.convoColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                AppStrings.defaultMeshAddress,
                                style: AppTypography.bodySmall.copyWith(
                                  color: context.convoColors.textSecondary,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          tooltip: 'Copy Mesh Address',
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Mesh address copied to clipboard!',
                                ),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: AppRadius.borderMd,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Settings Entry Tile
              ConvoCard(
                onTap: () => context.push('/profile/settings'),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: context.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: AppRadius.borderSm,
                      ),
                      child: Icon(
                        Icons.settings_outlined,
                        color: context.colorScheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.settings,
                            style: AppTypography.titleMedium.copyWith(
                              color: context.convoColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Appearance, notifications, privacy & security',
                            style: AppTypography.bodySmall.copyWith(
                              color: context.convoColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: context.convoColors.textTertiary,
                      size: 22,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // Logout Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showLogoutConfirmation(context, ref),
                  icon: const Icon(
                    Icons.logout_rounded,
                    size: 18,
                    color: AppColors.error,
                  ),
                  label: Text(
                    'Sign Out',
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: AppColors.error.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.borderMd,
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
