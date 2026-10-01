import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/convo_app_bar.dart';
import '../../../../core/widgets/convo_avatar.dart';
import '../../../../core/widgets/convo_card.dart';
import '../../../../services/local_storage/chat_preferences_service.dart';
import '../widgets/image_viewer_screen.dart';

class StarredMessagesScreen extends ConsumerStatefulWidget {
  const StarredMessagesScreen({super.key, this.conversationId});

  final String? conversationId;

  @override
  ConsumerState<StarredMessagesScreen> createState() =>
      _StarredMessagesScreenState();
}

class _StarredMessagesScreenState extends ConsumerState<StarredMessagesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'all'; // all, text, photo, video, voice, file

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final starredItems = ref.watch(starredMessagesProvider);

    final filteredItems = starredItems.where((item) {
      if (widget.conversationId != null &&
          item.conversationId != widget.conversationId) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final matchesText =
            item.text.toLowerCase().contains(_searchQuery.toLowerCase());
        final matchesSender =
            item.senderName.toLowerCase().contains(_searchQuery.toLowerCase());
        if (!matchesText && !matchesSender) return false;
      }

      if (_selectedFilter == 'text') return !item.isMedia;
      if (_selectedFilter == 'photo') return item.isImage;
      if (_selectedFilter == 'video') return item.isVideo;
      if (_selectedFilter == 'voice') return item.isVoice;
      if (_selectedFilter == 'file') return item.isFile;

      return true;
    }).toList();

    return Scaffold(
      appBar: ConvoAppBar(
        title: widget.conversationId != null
            ? 'Starred Messages'
            : 'Saved Messages',
        actions: [
          if (filteredItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Center(
                child: Text(
                  '${filteredItems.length}',
                  style: AppTypography.labelSmall.copyWith(
                    color: context.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search saved messages...',
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
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
            ),
          ),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: [
                _buildFilterChip('all', 'All (${starredItems.length})'),
                _buildFilterChip(
                  'text',
                  'Text (${starredItems.where((m) => !m.isMedia).length})',
                ),
                _buildFilterChip(
                  'photo',
                  'Photos (${starredItems.where((m) => m.isImage).length})',
                ),
                _buildFilterChip(
                  'video',
                  'Videos (${starredItems.where((m) => m.isVideo).length})',
                ),
                _buildFilterChip(
                  'voice',
                  'Voice (${starredItems.where((m) => m.isVoice).length})',
                ),
                _buildFilterChip(
                  'file',
                  'Files (${starredItems.where((m) => m.isFile).length})',
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xs),

          // Main list
          Expanded(
            child: filteredItems.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.star_rounded,
                              size: 36,
                              color: Colors.amber,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            _searchQuery.isNotEmpty || _selectedFilter != 'all'
                                ? 'No matching saved messages'
                                : 'No Starred Messages',
                            style: AppTypography.titleMedium.copyWith(
                              color: context.convoColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _searchQuery.isNotEmpty || _selectedFilter != 'all'
                                ? 'Try adjusting your search or filter.'
                                : 'Long press any message in a conversation to save it here for quick reference.',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodySmall.copyWith(
                              color: context.convoColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      return _StarredItemCard(
                        item: item,
                        onUnstar: () => ref
                            .read(starredMessagesProvider.notifier)
                            .unstar(item.messageId),
                        onTap: () {
                          if (item.conversationId.isNotEmpty) {
                            context.push('/chat/${item.conversationId}');
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected
              ? Colors.white
              : context.convoColors.textSecondary,
        ),
        backgroundColor: context.convoColors.surfaceSubtle,
        selectedColor: context.colorScheme.primary,
        checkmarkColor: Colors.white,
        showCheckmark: false,
        onSelected: (_) => setState(() => _selectedFilter = key),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.borderPill,
          side: BorderSide(
            color: isSelected
                ? context.colorScheme.primary
                : context.convoColors.cardBorder,
            width: 0.8,
          ),
        ),
      ),
    );
  }
}

class _StarredItemCard extends StatelessWidget {
  const _StarredItemCard({
    required this.item,
    required this.onUnstar,
    required this.onTap,
  });

  final StarredMessageItem item;
  final VoidCallback onUnstar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ConvoCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.borderMd,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top header row: Sender + Date + Unstar Button
              Row(
                children: [
                  ConvoAvatar(
                    initials: item.senderName.isNotEmpty
                        ? (item.senderName.length >= 2
                              ? item.senderName.substring(0, 2).toUpperCase()
                              : item.senderName[0].toUpperCase())
                        : 'CO',
                    size: 28,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.senderName,
                          style: AppTypography.titleMedium.copyWith(
                            color: context.convoColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          DateFormatter.formatTimeAgo(item.createdAt),
                          style: AppTypography.labelSmall.copyWith(
                            color: context.convoColors.textTertiary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.star_rounded,
                      color: Colors.amber,
                      size: 22,
                    ),
                    tooltip: 'Unstar',
                    onPressed: onUnstar,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),

              // Content Preview
              if (item.isImage && item.mediaUrl != null) ...[
                ClipRRect(
                  borderRadius: AppRadius.borderSm,
                  child: GestureDetector(
                    onTap: () => ImageViewerScreen.show(
                      context,
                      imageUrl: item.mediaUrl!,
                      title: 'Starred Photo',
                      timestamp: item.createdAt,
                    ),
                    child: Image.network(
                      item.mediaUrl!,
                      width: double.infinity,
                      height: 160,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        height: 80,
                        color: Colors.black12,
                        child: const Center(
                          child: Icon(Icons.broken_image_rounded),
                        ),
                      ),
                    ),
                  ),
                ),
                if (item.text.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.text,
                    style: AppTypography.bodyMedium.copyWith(
                      color: context.convoColors.textPrimary,
                    ),
                  ),
                ],
              ] else if (item.isVideo) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: context.convoColors.surfaceSubtle,
                    borderRadius: AppRadius.borderSm,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.videocam_rounded, color: AppColors.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          item.text.isNotEmpty ? item.text : 'Video message',
                          style: AppTypography.bodyMedium.copyWith(
                            color: context.convoColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (item.isVoice) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: context.convoColors.surfaceSubtle,
                    borderRadius: AppRadius.borderSm,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.mic_rounded, color: AppColors.accent),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Voice message',
                        style: AppTypography.bodyMedium.copyWith(
                          color: context.convoColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (item.isFile) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: context.convoColors.surfaceSubtle,
                    borderRadius: AppRadius.borderSm,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.insert_drive_file_rounded,
                        color: AppColors.accentPurple,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          item.fileName ?? 'Shared File',
                          style: AppTypography.bodyMedium.copyWith(
                            color: context.convoColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Text(
                  item.text,
                  style: AppTypography.bodyMedium.copyWith(
                    color: context.convoColors.textPrimary,
                    height: 1.35,
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.xs),

              // Bottom row: "Go to chat" button & copy
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                    label: const Text(
                      'Go to chat',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  if (item.text.isNotEmpty && !item.isMedia)
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      tooltip: 'Copy text',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: item.text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Copied to clipboard'),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
