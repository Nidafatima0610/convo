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
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/models/sticker_model.dart';
import '../providers/sticker_providers.dart';

class StickerStudioScreen extends ConsumerStatefulWidget {
  const StickerStudioScreen({
    super.key,
    this.conversationId,
    this.onStickerCreatedAndSelected,
  });

  final String? conversationId;
  final void Function(StickerModel sticker)? onStickerCreatedAndSelected;

  @override
  ConsumerState<StickerStudioScreen> createState() =>
      _StickerStudioScreenState();
}

class _StickerStudioScreenState extends ConsumerState<StickerStudioScreen> {
  final ImagePicker _picker = ImagePicker();
  String? _pickedImagePath;
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _stickerNameController = TextEditingController();

  String _selectedEmoji = '✨';
  int _selectedColorIndex = 0;
  int _selectedShapeIndex = 0;
  bool _isSaving = false;

  final List<List<Color>> _colorPalettes = [
    [const Color(0xFF5B4DFF), const Color(0xFF7E3AF2)], // CONVO Violet
    [const Color(0xFFFF5376), const Color(0xFFFF9F43)], // Coral Sunset
    [const Color(0xFF00D2B4), const Color(0xFF06B6D4)], // Cyan Wave
    [const Color(0xFF10B981), const Color(0xFF059669)], // Emerald
    [const Color(0xFF1E293B), const Color(0xFF0F172A)], // Slate Dark
    [const Color(0xFFF59E0B), const Color(0xFFD97706)], // Amber Gold
  ];

  final List<String> _quickEmojis = [
    '✨',
    '🔥',
    '💜',
    '😂',
    '💀',
    '🚀',
    '😎',
    '🎉',
    '🥺',
    '💯',
    '👋',
    '👀',
  ];

  @override
  void initState() {
    super.initState();
    _stickerNameController.text = 'My Vibe';
    _textController.text = 'Stay Real';
  }

  @override
  void dispose() {
    _textController.dispose();
    _stickerNameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _pickedImagePath = picked.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not access image: $e')));
      }
    }
  }

  Future<void> _saveAndSendSticker() async {
    final stickerText = _textController.text.trim();
    final stickerName = _stickerNameController.text.trim().isEmpty
        ? 'Sticker'
        : _stickerNameController.text.trim();

    final user = ref.read(currentUserProfileProvider).asData?.value;
    final userId = user?.uid ?? 'anon_creator';

    setState(() => _isSaving = true);

    try {
      // Encode sticker layout payload
      // If photo picked, use file path; otherwise encode emoji & text badge
      final imagePayload = _pickedImagePath != null
          ? _pickedImagePath!
          : 'custom:$_selectedEmoji:$stickerText:$_selectedColorIndex:$_selectedShapeIndex';

      final newSticker = StickerModel(
        id: 'stk_${DateTime.now().millisecondsSinceEpoch}',
        creatorId: userId,
        name: stickerName,
        imagePath: imagePayload,
        packId: 'pack_my_stickers',
        packName: 'My Stickers',
        emoji: _selectedEmoji,
        createdAt: DateTime.now(),
        isBuiltIn: false,
      );

      final storage = ref.read(stickerStorageServiceProvider);
      await storage.saveCustomSticker(newSticker);
      await storage.markStickerUsed(newSticker);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sticker saved to My Stickers!'),
            behavior: SnackBarBehavior.floating,
          ),
        );

        if (widget.onStickerCreatedAndSelected != null) {
          widget.onStickerCreatedAndSelected!(newSticker);
        }

        context.pop(newSticker);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save sticker: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = _colorPalettes[_selectedColorIndex];

    return Scaffold(
      appBar: ConvoAppBar(
        title: 'Sticker Studio',
        subtitle: 'Craft personalized chat stickers',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _saveAndSendSticker,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded, size: 20),
            label: Text(
              widget.conversationId != null ? 'Send' : 'Save',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
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
              // Live Interactive Sticker Preview Card
              _buildLivePreview(palette),

              const SizedBox(height: AppSpacing.xl),

              // Image Source Options
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Gallery'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.borderMd,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined, size: 18),
                      label: const Text('Camera'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.borderMd,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (_pickedImagePath != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.error,
                      ),
                      tooltip: 'Remove photo',
                      onPressed: () => setState(() => _pickedImagePath = null),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: AppSpacing.xl),

              // Sticker Text Customizer
              TextField(
                controller: _textController,
                maxLength: 24,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Sticker Caption / Slogan',
                  prefixIcon: const Icon(Icons.text_fields_rounded),
                  border: OutlineInputBorder(borderRadius: AppRadius.borderMd),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              // Color Gradient Palette Selector
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'BACKGROUND PALETTE',
                  style: AppTypography.labelMedium.copyWith(
                    color: context.convoColors.textTertiary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _colorPalettes.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final pal = _colorPalettes[index];
                    final isSelected = _selectedColorIndex == index;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColorIndex = index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: pal,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? Colors.white
                                : Colors.transparent,
                            width: isSelected ? 3 : 0,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: pal.first.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 20,
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ),

              // Sticker Shape Selector
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'STICKER SHAPE',
                  style: AppTypography.labelMedium.copyWith(
                    color: context.convoColors.textTertiary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  _buildShapeOption(0, 'Rounded', Icons.crop_square_rounded),
                  const SizedBox(width: AppSpacing.sm),
                  _buildShapeOption(1, 'Circle', Icons.circle_outlined),
                  const SizedBox(width: AppSpacing.sm),
                  _buildShapeOption(2, 'Crisp', Icons.crop_square_sharp),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              // Quick Emoji Badges
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'BADGE EMOJI',
                  style: AppTypography.labelMedium.copyWith(
                    color: context.convoColors.textTertiary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _quickEmojis.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final emoji = _quickEmojis[index];
                    final isSelected = _selectedEmoji == emoji;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedEmoji = emoji),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? context.colorScheme.primary.withValues(
                                  alpha: 0.16,
                                )
                              : context.convoColors.surfaceSubtle,
                          borderRadius: AppRadius.borderSm,
                          border: Border.all(
                            color: isSelected
                                ? context.colorScheme.primary
                                : context.convoColors.cardBorder,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // Sticker Name
              TextField(
                controller: _stickerNameController,
                maxLength: 20,
                decoration: InputDecoration(
                  labelText: 'Sticker Name (for your collection)',
                  prefixIcon: const Icon(Icons.bookmark_border_rounded),
                  border: OutlineInputBorder(borderRadius: AppRadius.borderMd),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Action button
              FilledButton.icon(
                onPressed: _isSaving ? null : _saveAndSendSticker,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: Text(
                  widget.conversationId != null
                      ? 'Send Sticker in Chat'
                      : 'Save to My Stickers',
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.borderMd,
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLivePreview(List<Color> palette) {
    BorderRadius borderRadius;
    switch (_selectedShapeIndex) {
      case 1:
        borderRadius = BorderRadius.circular(100);
        break;
      case 2:
        borderRadius = BorderRadius.circular(8);
        break;
      case 0:
      default:
        borderRadius = BorderRadius.circular(24);
        break;
    }

    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: palette,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: palette.first.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // If picked image is available
          if (_pickedImagePath != null)
            ClipRRect(
              borderRadius: borderRadius,
              child: Image.file(
                File(_pickedImagePath!),
                width: 200,
                height: 200,
                fit: BoxFit.cover,
              ),
            ),

          // Foreground Content
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_selectedEmoji, style: const TextStyle(fontSize: 48)),
                const SizedBox(height: 6),
                if (_textController.text.trim().isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: AppRadius.borderSm,
                    ),
                    child: Text(
                      _textController.text.trim(),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShapeOption(int index, String label, IconData icon) {
    final isSelected = _selectedShapeIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedShapeIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? context.colorScheme.primary.withValues(alpha: 0.12)
                : context.convoColors.surfaceSubtle,
            borderRadius: AppRadius.borderSm,
            border: Border.all(
              color: isSelected
                  ? context.colorScheme.primary
                  : context.convoColors.cardBorder,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? context.colorScheme.primary
                    : context.convoColors.textSecondary,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? context.colorScheme.primary
                      : context.convoColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
