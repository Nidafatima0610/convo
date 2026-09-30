import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/routes/app_routes.dart';
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
import '../../../auth/domain/models/convo_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../chats/presentation/providers/chat_providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isUploadingDp = false;

  Future<void> _showAvatarOptions(ConvoUser? user) async {
    if (_isUploadingDp) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: context.convoColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (bottomSheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: context.convoColors.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'Profile Picture',
                  style: AppTypography.titleLarge.copyWith(
                    color: context.convoColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: context.colorScheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      color: context.colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Take Photo',
                    style: AppTypography.bodyMedium.copyWith(
                      color: context.convoColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Use device camera',
                    style: AppTypography.bodySmall.copyWith(
                      color: context.convoColors.textSecondary,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(bottomSheetCtx).pop();
                    _pickAndUploadDp(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.accentPurple.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.photo_library_rounded,
                      color: AppColors.accentPurple,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Choose from Gallery',
                    style: AppTypography.bodyMedium.copyWith(
                      color: context.convoColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Select existing picture',
                    style: AppTypography.bodySmall.copyWith(
                      color: context.convoColors.textSecondary,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(bottomSheetCtx).pop();
                    _pickAndUploadDp(ImageSource.gallery);
                  },
                ),
                if (user?.photoUrl != null && user!.photoUrl!.isNotEmpty)
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.error,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'Remove Photo',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () async {
                      Navigator.of(bottomSheetCtx).pop();
                      await _removeDp();
                    },
                  ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadDp(ImageSource source) async {
    try {
      final mediaService = ref.read(mediaServiceProvider);
      final picked = await mediaService.pickProfileImage(source: source);
      if (picked == null) return; // User cancelled picker

      setState(() => _isUploadingDp = true);

      final downloadUrl = await ref
          .read(profileControllerProvider.notifier)
          .uploadProfilePicture(picked.path);

      if (mounted) {
        if (downloadUrl != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Profile picture updated successfully.'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Failed to upload profile picture. Please try again.',
              ),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating photo: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingDp = false);
      }
    }
  }

  Future<void> _removeDp() async {
    setState(() => _isUploadingDp = true);
    final ok =
        await ref.read(profileControllerProvider.notifier).removeProfilePicture();
    if (mounted) {
      setState(() => _isUploadingDp = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Profile picture removed.'
                : 'Failed to remove picture. Try again.',
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
        ),
      );
    }
  }

  void _showEditProfileModal(ConvoUser? user) {
    final nameController = TextEditingController(text: user?.name ?? '');
    final bioController = TextEditingController(text: user?.effectiveBio ?? '');

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
            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                top: AppSpacing.lg,
                bottom:
                    MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Edit Profile',
                        style: AppTypography.titleLarge.copyWith(
                          color: context.convoColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(sheetContext).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Display Name',
                    style: AppTypography.labelMedium.copyWith(
                      color: context.convoColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  TextField(
                    controller: nameController,
                    maxLength: 35,
                    decoration: InputDecoration(
                      hintText: 'Enter your name',
                      counterText: '',
                      filled: true,
                      fillColor: context.convoColors.surfaceSubtle,
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.borderMd,
                        borderSide:
                            BorderSide(color: context.convoColors.cardBorder),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Bio / About',
                    style: AppTypography.labelMedium.copyWith(
                      color: context.convoColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  TextField(
                    controller: bioController,
                    maxLines: 3,
                    maxLength: 140,
                    decoration: InputDecoration(
                      hintText: 'Share a little bit about yourself...',
                      filled: true,
                      fillColor: context.convoColors.surfaceSubtle,
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.borderMd,
                        borderSide:
                            BorderSide(color: context.convoColors.cardBorder),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: () async {
                        final newName = nameController.text.trim();
                        final newBio = bioController.text.trim();
                        if (newName.isEmpty) return;

                        Navigator.of(sheetContext).pop();

                        final okName = await ref
                            .read(profileControllerProvider.notifier)
                            .updateDisplayName(newName);
                        final okBio = await ref
                            .read(profileControllerProvider.notifier)
                            .updateBio(newBio);

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                okName && okBio
                                    ? 'Profile updated successfully.'
                                    : 'Some updates could not be saved.',
                              ),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: AppRadius.borderMd,
                              ),
                            ),
                          );
                        }
                      },
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.borderMd,
                        ),
                      ),
                      child: const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showPrivacySettingsModal(ConvoUser? user) {
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
                      'Choose who can view your sensitive profile details and presence.',
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
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.block_rounded,
                          color: AppColors.error,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        'Blocked Contacts',
                        style: AppTypography.titleMedium.copyWith(
                          color: context.convoColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${user.blockedUsers.length} contact(s) blocked',
                        style: AppTypography.bodySmall.copyWith(
                          color: context.convoColors.textSecondary,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                      ),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _showBlockedUsersDialog(user);
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

  void _showNotificationSettingsModal(ConvoUser? user) {
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
            final isEnabled =
                (currentSettings['enabled'] as bool?) ?? true;
            final isPreview =
                (currentSettings['preview'] as bool?) ?? true;
            final isSound =
                (currentSettings['sound'] as bool?) ?? true;

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
                      'Manage FCM message alerts and preview options.',
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
                        'Receive alerts for new incoming messages',
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
                        'Show sender name and message content in notification',
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
                        'Play default notification ringtone',
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

  void _showBlockedUsersDialog(ConvoUser user) {
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
                                content: Text('User unblocked.'),
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

  void _onShareQr(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Local mesh peer QR code sharing coming soon!'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
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
  Widget build(BuildContext context) {
    final userProfile = ref.watch(currentUserProfileProvider).asData?.value;
    final authUser = ref.watch(authStateChangesProvider).asData?.value;

    final displayName =
        userProfile?.name ??
        authUser?.displayName ??
        AppStrings.defaultUserDisplayName;
    final email =
        userProfile?.email ?? authUser?.email ?? AppStrings.defaultUserHandle;
    final bio = userProfile?.effectiveBio ?? 'Hey there! I am using CONVO.';
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

              // DP Avatar with interactive camera badge & upload spinner
              ConvoAvatar(
                initials: initials,
                photoUrl: userProfile?.photoUrl,
                size: 96,
                status: ConvoAvatarStatus.meshActive,
                showEditBadge: true,
                isLoading: _isUploadingDp,
                onTap: () => _showAvatarOptions(userProfile),
              ),
              const SizedBox(height: AppSpacing.md),

              // Display Name
              Text(
                displayName,
                textAlign: TextAlign.center,
                style: AppTypography.headlineLarge.copyWith(
                  color: context.convoColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),

              // Bio
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Text(
                  bio,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium.copyWith(
                    color: context.convoColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 4),

              // Email
              Text(
                email,
                style: AppTypography.bodySmall.copyWith(
                  color: context.convoColors.textTertiary,
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
                      onPressed: () => _showEditProfileModal(userProfile),
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

              // Privacy Controls Tile
              ConvoCard(
                onTap: () => _showPrivacySettingsModal(userProfile),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.12),
                        borderRadius: AppRadius.borderSm,
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        color: AppColors.accent,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Privacy & Presence',
                            style: AppTypography.titleMedium.copyWith(
                              color: context.convoColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Last seen, online status, DP visibility & blocks',
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

              const SizedBox(height: AppSpacing.md),

              // Notification Settings Tile
              ConvoCard(
                onTap: () => _showNotificationSettingsModal(userProfile),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.blueGlow.withValues(alpha: 0.12),
                        borderRadius: AppRadius.borderSm,
                      ),
                      child: const Icon(
                        Icons.notifications_none_rounded,
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
                            'Push Notifications',
                            style: AppTypography.titleMedium.copyWith(
                              color: context.convoColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'FCM message alerts, previews & sounds',
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

              const SizedBox(height: AppSpacing.md),

              // Saved / Starred Messages Tile
              ConvoCard(
                onTap: () => context.push(AppRoutes.starredMessages),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: AppRadius.borderSm,
                      ),
                      child: const Icon(
                        Icons.star_rounded,
                        color: AppColors.accent,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Saved Messages',
                            style: AppTypography.titleMedium.copyWith(
                              color: context.convoColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'View bookmarked and starred chat messages',
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

              const SizedBox(height: AppSpacing.md),

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
                            'Appearance, nearby privacy & system',
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
                  onPressed: () => _showLogoutConfirmation(context),
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
