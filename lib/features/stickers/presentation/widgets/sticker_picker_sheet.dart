import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/extensions.dart';
import '../../domain/models/sticker_model.dart';
import '../providers/sticker_providers.dart';
import '../screens/sticker_studio_screen.dart';

class StickerPickerSheet extends ConsumerStatefulWidget {
  const StickerPickerSheet({
    super.key,
    required this.conversationId,
    required this.onStickerSelected,
    this.onOpenStudio,
  });

  final String conversationId;
  final ValueChanged<StickerModel> onStickerSelected;
  final VoidCallback? onOpenStudio;

  static Future<void> show(
    BuildContext context, {
    required String conversationId,
    required ValueChanged<StickerModel> onStickerSelected,
    VoidCallback? onOpenStudio,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StickerPickerSheet(
        conversationId: conversationId,
        onStickerSelected: onStickerSelected,
        onOpenStudio: onOpenStudio,
      ),
    );
  }

  @override
  ConsumerState<StickerPickerSheet> createState() => _StickerPickerSheetState();
}

class _StickerPickerSheetState extends ConsumerState<StickerPickerSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openStudio() {
    Navigator.of(context).pop();
    if (widget.onOpenStudio != null) {
      widget.onOpenStudio!();
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => StickerStudioScreen(
            conversationId: widget.conversationId,
            onStickerCreatedAndSelected: (sticker) {
              widget.onStickerSelected(sticker);
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final myStickersAsync = ref.watch(myStickersStreamProvider);
    final recentStickersAsync = ref.watch(recentStickersStreamProvider);
    final starterStickers = ref.watch(starterStickersProvider);

    return Container(
      height: 380,
      decoration: BoxDecoration(
        color: context.convoColors.cardBackground,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle & top bar
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: context.convoColors.cardBorder,
              borderRadius: AppRadius.borderPill,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: context.colorScheme.primary,
                    unselectedLabelColor: context.convoColors.textTertiary,
                    indicatorColor: context.colorScheme.primary,
                    indicatorSize: TabBarIndicatorSize.label,
                    tabs: const [
                      Tab(text: 'Official Packs'),
                      Tab(text: 'My Stickers'),
                      Tab(text: 'Recent'),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  icon: const Icon(Icons.add_rounded, size: 20),
                  tooltip: 'Create Sticker',
                  onPressed: _openStudio,
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. Official Packs
                _buildStickerGrid(starterStickers),

                // 2. My Stickers
                myStickersAsync.when(
                  data: (stickers) => stickers.isEmpty
                      ? _buildEmptyState(
                          icon: Icons.palette_outlined,
                          title: 'No custom stickers yet',
                          subtitle: 'Tap + to craft your first sticker in Sticker Studio!',
                        )
                      : _buildStickerGrid(stickers),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => _buildEmptyState(
                    icon: Icons.error_outline,
                    title: 'Error loading stickers',
                    subtitle: 'Please try again later.',
                  ),
                ),

                // 3. Recent Stickers
                recentStickersAsync.when(
                  data: (stickers) => stickers.isEmpty
                      ? _buildEmptyState(
                          icon: Icons.history_rounded,
                          title: 'No recent stickers',
                          subtitle: 'Send stickers to see them here!',
                        )
                      : _buildStickerGrid(stickers),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => _buildEmptyState(
                    icon: Icons.error_outline,
                    title: 'Error loading recents',
                    subtitle: 'Please try again later.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: context.convoColors.textTertiary),
            const SizedBox(height: AppSpacing.sm),
            Text(
              title,
              style: AppTypography.titleMedium.copyWith(
                color: context.convoColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: context.convoColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickerGrid(List<StickerModel> stickers) {
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.0,
      ),
      itemCount: stickers.length,
      itemBuilder: (context, index) {
        final sticker = stickers[index];
        return InkWell(
          onTap: () {
            ref.read(stickerStorageServiceProvider).markStickerUsed(sticker);
            Navigator.of(context).pop();
            widget.onStickerSelected(sticker);
          },
          borderRadius: AppRadius.borderMd,
          child: Container(
            decoration: BoxDecoration(
              color: context.convoColors.surfaceSubtle,
              borderRadius: AppRadius.borderMd,
              border: Border.all(color: context.convoColors.cardBorder),
            ),
            padding: const EdgeInsets.all(6),
            alignment: Alignment.center,
            child: _buildStickerThumbnail(sticker),
          ),
        );
      },
    );
  }

  Widget _buildStickerThumbnail(StickerModel sticker) {
    if (sticker.imagePath.startsWith('emoji:')) {
      final parts = sticker.imagePath.split(':');
      final emoji = parts.length > 1 ? parts[1] : sticker.emoji;
      final label = parts.length > 2 ? parts[2] : '';

      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          if (label.isNotEmpty)
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
            ),
        ],
      );
    } else if (sticker.imagePath.startsWith('custom:')) {
      final parts = sticker.imagePath.split(':');
      final emoji = parts.length > 1 ? parts[1] : sticker.emoji;
      final label = parts.length > 2 ? parts[2] : '';

      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          if (label.isNotEmpty)
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700),
            ),
        ],
      );
    } else if (File(sticker.imagePath).existsSync()) {
      return ClipRRect(
        borderRadius: AppRadius.borderSm,
        child: Image.file(File(sticker.imagePath), fit: BoxFit.cover),
      );
    }

    return Text(sticker.emoji, style: const TextStyle(fontSize: 32));
  }
}
