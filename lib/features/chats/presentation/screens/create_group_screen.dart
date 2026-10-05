import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/convo_app_bar.dart';
import '../../../../core/widgets/convo_avatar.dart';
import '../../../../core/widgets/convo_card.dart';
import '../../../auth/domain/models/convo_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/chat_providers.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  final List<ConvoUser> _selectedMembers = [];
  String _searchQuery = '';
  File? _pickedImageFile;
  bool _isCreating = false;
  double _uploadProgress = 0.0;
  String _statusText = '';

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleMemberSelection(ConvoUser user) {
    setState(() {
      final index = _selectedMembers.indexWhere((m) => m.uid == user.uid);
      if (index >= 0) {
        _selectedMembers.removeAt(index);
      } else {
        _selectedMembers.add(user);
      }
    });
  }

  Future<void> _showPhotoPickerSheet() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.convoColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.lg,
            horizontal: AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: context.convoColors.cardBorder,
                  borderRadius: AppRadius.borderPill,
                ),
              ),
              Text(
                'Group Photo',
                style: AppTypography.titleMedium.copyWith(
                  color: context.convoColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: context.colorScheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.camera_alt_rounded,
                    color: context.colorScheme.primary,
                  ),
                ),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.of(bottomSheetContext).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.accentPurple.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.photo_library_rounded,
                    color: AppColors.accentPurple,
                  ),
                ),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.of(bottomSheetContext).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (_pickedImageFile != null)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.error,
                    ),
                  ),
                  title: const Text(
                    'Remove Photo',
                    style: TextStyle(color: AppColors.error),
                  ),
                  onTap: () {
                    Navigator.of(bottomSheetContext).pop();
                    setState(() => _pickedImageFile = null);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final mediaService = ref.read(mediaServiceProvider);
    final file = await mediaService.pickProfileImage(source: source);
    if (file != null) {
      setState(() => _pickedImageFile = File(file.path));
    }
  }

  Future<void> _handleCreateGroup() async {
    final groupName = _nameController.text.trim();
    if (groupName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a group name'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }


    final currentUserId =
        ref.read(authStateChangesProvider).asData?.value?.uid ?? '';

    setState(() {
      _isCreating = true;
      _statusText = 'Creating group...';
    });

    try {
      String? photoUrl;

      // Upload group photo if picked
      if (_pickedImageFile != null) {
        setState(() => _statusText = 'Uploading group photo...');
        final mediaService = ref.read(mediaServiceProvider);
        final tempGroupId = 'grp_${DateTime.now().millisecondsSinceEpoch}';
        photoUrl = await mediaService.uploadGroupPicture(
          filePath: _pickedImageFile!.path,
          groupId: tempGroupId,
          uploaderId: currentUserId,
          onProgress: (p) => setState(() => _uploadProgress = p),
        );
      }

      setState(() => _statusText = 'Finalizing group...');
      final group = await ref
          .read(chatControllerProvider.notifier)
          .createGroup(
            name: groupName,
            initialMembers: _selectedMembers,
            photoUrl: photoUrl,
            description: _descriptionController.text.trim().isNotEmpty
                ? _descriptionController.text.trim()
                : null,
          );

      if (group != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Group "$groupName" created successfully!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Replace current screen with group chat
        context.pushReplacement('/chat/${group.id}');
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create group. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating group: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchedUsersAsync = ref.watch(searchedUsersProvider(_searchQuery));

    return Scaffold(
      appBar: ConvoAppBar(
        title: 'New Group',
        actions: [
          if (!_isCreating)
            TextButton(
              onPressed: _selectedMembers.isNotEmpty ? _handleCreateGroup : null,
              child: Text(
                'Create',
                style: AppTypography.labelLarge.copyWith(
                  color: _selectedMembers.isNotEmpty
                      ? context.colorScheme.primary
                      : context.convoColors.textSecondary.withValues(alpha: 0.4),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
      body: _isCreating
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      _statusText,
                      style: AppTypography.titleMedium.copyWith(
                        color: context.convoColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_uploadProgress > 0 && _uploadProgress < 1.0) ...[
                      const SizedBox(height: AppSpacing.md),
                      ClipRRect(
                        borderRadius: AppRadius.borderPill,
                        child: LinearProgressIndicator(
                          value: _uploadProgress,
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          : CustomScrollView(
              slivers: [
                // Top Group Info Card (DP, Name, Description)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: ConvoCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: _showPhotoPickerSheet,
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                if (_pickedImageFile != null)
                                  CircleAvatar(
                                    radius: 44,
                                    backgroundImage:
                                        FileImage(_pickedImageFile!),
                                  )
                                else
                                  Container(
                                    width: 88,
                                    height: 88,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [
                                          context.colorScheme.primary,
                                          AppColors.accentPurple,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.group_rounded,
                                        size: 44,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: context.colorScheme.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color:
                                          context.convoColors.cardBackground,
                                      width: 2.5,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Add Group Photo',
                            style: AppTypography.labelSmall.copyWith(
                              color: context.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextField(
                            controller: _nameController,
                            maxLength: 50,
                            decoration: const InputDecoration(
                              labelText: 'Group Name *',
                              hintText: 'Enter group subject or name...',
                              prefixIcon: Icon(Icons.group_outlined, size: 20),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          TextField(
                            controller: _descriptionController,
                            maxLength: 150,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Description (optional)',
                              hintText: 'What is this group about?',
                              prefixIcon:
                                  Icon(Icons.info_outline_rounded, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Selected Members horizontal chip scroll
                if (_selectedMembers.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'SELECTED MEMBERS (${_selectedMembers.length})',
                                style: AppTypography.labelSmall.copyWith(
                                  color: context.colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              TextButton(
                                onPressed: () =>
                                    setState(() => _selectedMembers.clear()),
                                child: const Text('Clear All'),
                              ),
                            ],
                          ),
                          SizedBox(
                            height: 60,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _selectedMembers.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: AppSpacing.xs),
                              itemBuilder: (context, index) {
                                final member = _selectedMembers[index];
                                return Chip(
                                  avatar: ConvoAvatar(
                                    initials: member.initials,
                                    photoUrl: member.photoUrl,
                                    size: 26,
                                  ),
                                  label: Text(
                                    member.name,
                                    style: AppTypography.labelMedium.copyWith(
                                      color: context.convoColors.textPrimary,
                                    ),
                                  ),
                                  deleteIcon: const Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                  ),
                                  onDeleted: () =>
                                      _toggleMemberSelection(member),
                                  backgroundColor: context
                                      .colorScheme.primary
                                      .withValues(alpha: 0.1),
                                  side: BorderSide(
                                    color: context.colorScheme.primary
                                        .withValues(alpha: 0.3),
                                  ),
                                );
                              },
                            ),
                          ),
                          const Divider(),
                        ],
                      ),
                    ),
                  ),

                // Search input for contacts
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.xs,
                      AppSpacing.md,
                      AppSpacing.xs,
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search contacts to add...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                ),

                // Contact list with checkboxes
                searchedUsersAsync.when(
                  loading: () => const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (err, _) => SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(
                        'Error loading contacts: $err',
                        style: TextStyle(
                          color: context.convoColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  data: (users) {
                    if (users.isEmpty) {
                      return SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.xl),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.person_search_rounded,
                                  size: 48,
                                  color: context.convoColors.textSecondary
                                      .withValues(alpha: 0.4),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  _searchQuery.isEmpty
                                      ? 'No registered contacts found.'
                                      : 'No contacts matching "$_searchQuery"',
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: context.convoColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final user = users[index];
                          final isSelected = _selectedMembers
                              .any((m) => m.uid == user.uid);

                          return ListTile(
                            leading: ConvoAvatar(
                              initials: user.initials,
                              photoUrl: user.photoUrl,
                              size: 42,
                            ),
                            title: Text(
                              user.name,
                              style: AppTypography.titleMedium.copyWith(
                                color: context.convoColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              user.effectiveBio.isNotEmpty
                                  ? user.effectiveBio
                                  : user.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodySmall.copyWith(
                                color: context.convoColors.textSecondary,
                              ),
                            ),
                            trailing: Checkbox(
                              value: isSelected,
                              activeColor: context.colorScheme.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              onChanged: (_) => _toggleMemberSelection(user),
                            ),
                            onTap: () => _toggleMemberSelection(user),
                          );
                        },
                        childCount: users.length,
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }
}
