import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/convo_app_bar.dart';
import '../../../../core/widgets/convo_card.dart';
import '../providers/chat_providers.dart';
import '../widgets/image_viewer_screen.dart';

class ChatMediaGalleryScreen extends ConsumerWidget {
  const ChatMediaGalleryScreen({super.key, required this.conversationId});

  final String conversationId;

  static final RegExp _urlRegex = RegExp(
    r'(https?:\/\/[^\s]+)',
    caseSensitive: false,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(
      conversationCombinedMessagesProvider(conversationId),
    );

    return messagesAsync.when(
      loading: () => Scaffold(
        appBar: const ConvoAppBar(title: 'Media, Links & Files'),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: const ConvoAppBar(title: 'Media, Links & Files'),
        body: Center(
          child: Text(
            'Failed to load media: $err',
            style: TextStyle(color: context.convoColors.textSecondary),
          ),
        ),
      ),
      data: (messages) {
        final photos = messages
            .where((m) => m.isImage && !m.isDeleted && m.mediaUrl != null)
            .toList();
        final videos = messages
            .where((m) => m.isVideo && !m.isDeleted && m.mediaUrl != null)
            .toList();
        final files = messages
            .where((m) => (m.isFile || m.type == 'document') && !m.isDeleted && m.mediaUrl != null)
            .toList();
        final links = messages.where((m) {
          if (m.isDeleted || m.text.isEmpty) return false;
          return _urlRegex.hasMatch(m.text);
        }).toList();

        return DefaultTabController(
          length: 4,
          child: Scaffold(
            appBar: ConvoAppBar(
              title: 'Media, Links & Files',
              bottom: TabBar(
                isScrollable: false,
                labelColor: context.colorScheme.primary,
                unselectedLabelColor: context.convoColors.textTertiary,
                indicatorColor: context.colorScheme.primary,
                indicatorWeight: 3,
                labelStyle: AppTypography.labelSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
                tabs: [
                  Tab(text: 'Photos (${photos.length})'),
                  Tab(text: 'Videos (${videos.length})'),
                  Tab(text: 'Files (${files.length})'),
                  Tab(text: 'Links (${links.length})'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                // 1. Photos Tab
                _buildPhotosTab(context, photos),

                // 2. Videos Tab
                _buildVideosTab(context, videos),

                // 3. Files Tab
                _buildFilesTab(context, files),

                // 4. Links Tab
                _buildLinksTab(context, links),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPhotosTab(BuildContext context, List<dynamic> photos) {
    if (photos.isEmpty) {
      return _buildEmptyState(
        context,
        icon: Icons.photo_library_outlined,
        title: 'No Photos Shared',
        subtitle: 'Photos sent in this conversation will appear here.',
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.xs),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 3,
        mainAxisSpacing: 3,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final message = photos[index];
        final url = message.mediaUrl as String;

        return GestureDetector(
          onTap: () {
            ImageViewerScreen.show(
              context,
              imageUrl: url,
              title: message.senderName != null ? 'Photo from ${message.senderName}' : 'Photo',
              timestamp: message.createdAt,
            );
          },
          child: Hero(
            tag: 'gallery_$url',
            child: Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: context.convoColors.surfaceSubtle,
                  child: const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              },
              errorBuilder: (_, _, _) => Container(
                color: context.convoColors.surfaceSubtle,
                child: const Icon(Icons.broken_image_rounded, size: 28),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideosTab(BuildContext context, List<dynamic> videos) {
    if (videos.isEmpty) {
      return _buildEmptyState(
        context,
        icon: Icons.videocam_outlined,
        title: 'No Videos Shared',
        subtitle: 'Videos sent in this conversation will appear here.',
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.sm),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.1,
      ),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final message = videos[index];
        final durationSec = (message.durationMs != null ? message.durationMs / 1000 : 0).round();

        return ConvoCard(
          padding: EdgeInsets.zero,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (message.thumbnailUrl != null)
                Image.network(message.thumbnailUrl, fit: BoxFit.cover)
              else
                Container(
                  color: Colors.black87,
                  child: const Icon(
                    Icons.movie_creation_outlined,
                    color: Colors.white38,
                    size: 36,
                  ),
                ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (durationSec > 0)
                      Text(
                        '${durationSec ~/ 60}:${(durationSec % 60).toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    Text(
                      DateFormatter.formatTime(message.createdAt),
                      style: const TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilesTab(BuildContext context, List<dynamic> files) {
    if (files.isEmpty) {
      return _buildEmptyState(
        context,
        icon: Icons.insert_drive_file_outlined,
        title: 'No Files Shared',
        subtitle: 'Documents and files sent here will be listed in this section.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final message = files[index];
        final fileName = message.fileName ?? 'Document';
        final fileSize = message.fileSize != null
            ? '${(message.fileSize / 1024).toStringAsFixed(1)} KB'
            : '';

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: ConvoCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.accentPurple.withValues(alpha: 0.12),
                    borderRadius: AppRadius.borderMd,
                  ),
                  child: const Icon(
                    Icons.insert_drive_file_rounded,
                    color: AppColors.accentPurple,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleMedium.copyWith(
                          color: context.convoColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$fileSize • ${DateFormatter.formatTimeAgo(message.createdAt)}',
                        style: AppTypography.labelSmall.copyWith(
                          color: context.convoColors.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 20),
                  tooltip: 'Copy File URL',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: message.mediaUrl!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('File link copied to clipboard'),
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
  }

  Widget _buildLinksTab(BuildContext context, List<dynamic> linkMessages) {
    if (linkMessages.isEmpty) {
      return _buildEmptyState(
        context,
        icon: Icons.link_rounded,
        title: 'No Links Shared',
        subtitle: 'URLs and links sent in this chat will appear here.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: linkMessages.length,
      itemBuilder: (context, index) {
        final message = linkMessages[index];
        final match = _urlRegex.firstMatch(message.text);
        final url = match?.group(0) ?? message.text;

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: ConvoCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: AppRadius.borderMd,
                  ),
                  child: Icon(
                    Icons.link_rounded,
                    color: context.colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleMedium.copyWith(
                          color: context.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Shared by ${message.senderName ?? 'User'} • ${DateFormatter.formatTimeAgo(message.createdAt)}',
                        style: AppTypography.labelSmall.copyWith(
                          color: context.convoColors.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 20),
                  tooltip: 'Copy Link',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: url));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Link copied to clipboard'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 1),
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
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: context.convoColors.surfaceSubtle,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: context.convoColors.textTertiary),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: AppTypography.titleMedium.copyWith(
                color: context.convoColors.textPrimary,
                fontWeight: FontWeight.w700,
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
}
