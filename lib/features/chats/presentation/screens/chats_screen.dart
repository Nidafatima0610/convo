import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/convo_app_bar.dart';
import '../../../../core/widgets/convo_avatar.dart';
import '../../../../core/widgets/convo_badge.dart';
import '../../../../core/widgets/convo_empty_state.dart';
import '../../../auth/domain/models/convo_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/models/conversation_model.dart';
import '../providers/chat_providers.dart';
import '../widgets/user_search_modal.dart';

class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({super.key});

  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends ConsumerState<ChatsScreen> {
  int _selectedFilterIndex = 0;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _filters = const ['All', 'Unread', 'Groups', 'Mesh'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onNewChatPressed() {
    UserSearchModal.show(context);
  }

  void _openConversation(ConversationModel conversation, String currentUserId) {
    final otherId = conversation.otherParticipantId(currentUserId);
    final otherDetails = conversation.participantDetails[otherId];

    final otherUser = ConvoUser(
      uid: otherId,
      name: otherDetails?['name'] as String? ?? 'CONVO User',
      email: otherDetails?['email'] as String? ?? '',
      photoUrl: otherDetails?['photoUrl'] as String?,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    context.push('/chat/${conversation.id}', extra: otherUser);
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId =
        ref.watch(authStateChangesProvider).asData?.value?.uid ?? '';
    final conversationsAsync = ref.watch(userConversationsProvider);

    return Scaffold(
      appBar: ConvoAppBar(
        showBrand: true,
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close_rounded : Icons.search_rounded,
              color: context.convoColors.textPrimary,
            ),
            tooltip: AppStrings.search,
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) _searchController.clear();
              });
            },
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: context.colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_rounded,
                color: context.colorScheme.primary,
                size: 20,
              ),
            ),
            tooltip: AppStrings.newChat,
            onPressed: _onNewChatPressed,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_isSearching) _buildSearchBar(),
            _buildFilterChips(),
            Expanded(
              child: conversationsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.error,
                          size: 44,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Error loading conversations',
                          style: AppTypography.titleMedium.copyWith(
                            color: context.convoColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          error.toString(),
                          textAlign: TextAlign.center,
                          style: AppTypography.bodySmall.copyWith(
                            color: context.convoColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        FilledButton.tonal(
                          onPressed: () =>
                              ref.refresh(userConversationsProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (conversations) {
                  return _buildConversationList(
                    context,
                    conversations,
                    currentUserId,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'chats_new_chat_fab',
        onPressed: _onNewChatPressed,
        icon: const Icon(Icons.edit_outlined, size: 20),
        label: const Text(AppStrings.newChat),
        backgroundColor: context.colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: AppStrings.searchChatsHint,
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                    });
                  },
                )
              : null,
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: _filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final isSelected = _selectedFilterIndex == index;
          final title = _filters[index];

          return ChoiceChip(
            label: Text(title),
            selected: isSelected,
            onSelected: (selected) {
              if (selected) {
                setState(() => _selectedFilterIndex = index);
              }
            },
            showCheckmark: false,
            labelStyle: AppTypography.labelMedium.copyWith(
              color: isSelected
                  ? Colors.white
                  : context.convoColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
            backgroundColor: context.convoColors.surfaceSubtle,
            selectedColor: index == 3
                ? AppColors.accent
                : context.colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.borderPill,
              side: BorderSide(
                color: isSelected
                    ? Colors.transparent
                    : context.convoColors.cardBorder,
                width: 0.8,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildConversationList(
    BuildContext context,
    List<ConversationModel> conversations,
    String currentUserId,
  ) {
    // 1. Filter by query
    var filtered = conversations;
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((conv) {
        final name = conv.otherParticipantName(currentUserId).toLowerCase();
        final lastMsg = conv.lastMessage.toLowerCase();
        return name.contains(query) || lastMsg.contains(query);
      }).toList();
    }

    // 2. Filter by tab chip
    if (_selectedFilterIndex == 1) {
      // Unread only
      filtered = filtered
          .where((conv) => conv.unreadCountFor(currentUserId) > 0)
          .toList();
    } else if (_selectedFilterIndex == 2) {
      // Groups placeholder (0 for now)
      filtered = [];
    } else if (_selectedFilterIndex == 3) {
      // Mesh placeholder (0 for now)
      filtered = [];
    }

    if (filtered.isEmpty) {
      if (_searchController.text.isNotEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 48,
                color: context.convoColors.textTertiary,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'No conversations found',
                style: AppTypography.titleMedium.copyWith(
                  color: context.convoColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Try searching for another name or keyword',
                style: AppTypography.bodySmall.copyWith(
                  color: context.convoColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      }

      if (_selectedFilterIndex == 1) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.mark_chat_read_rounded,
                size: 48,
                color: context.colorScheme.primary.withValues(alpha: 0.7),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'No Unread Messages',
                style: AppTypography.titleMedium.copyWith(
                  color: context.convoColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'You are all caught up on all your conversations!',
                style: AppTypography.bodySmall.copyWith(
                  color: context.convoColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      }

      // Default high-polish empty state
      return ConvoEmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: AppStrings.chatsEmptyTitle,
        subtitle: AppStrings.chatsEmptySubtitle,
        actionLabel: AppStrings.newChat,
        actionIcon: Icons.add_comment_rounded,
        badge: const ConvoBadge(
          label: 'ENCRYPTED MESSAGING',
          variant: ConvoBadgeVariant.primary,
          icon: Icons.lock_outline_rounded,
        ),
        onActionPressed: _onNewChatPressed,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => Divider(
        color: context.convoColors.cardBorder,
        height: 1,
        indent: 72,
        endIndent: AppSpacing.lg,
      ),
      itemBuilder: (context, index) {
        final conversation = filtered[index];
        final otherId = conversation.otherParticipantId(currentUserId);
        final otherName = conversation.otherParticipantName(currentUserId);
        final unreadCount = conversation.unreadCountFor(currentUserId);
        final isLastFromMe = conversation.lastMessageSenderId == currentUserId;

        // Watch live presence of other user
        final otherUserPresence = ref
            .watch(userPresenceProvider(otherId))
            .asData
            ?.value;
        final isOnline = otherUserPresence?.isOnline ?? false;

        final initials = otherName.isNotEmpty
            ? (otherName.length >= 2
                  ? otherName.substring(0, 2).toUpperCase()
                  : otherName[0].toUpperCase())
            : 'CO';

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 4,
          ),
          onTap: () => _openConversation(conversation, currentUserId),
          leading: ConvoAvatar(
            initials: initials,
            size: 52,
            status: isOnline
                ? ConvoAvatarStatus.online
                : ConvoAvatarStatus.offline,
          ),
          title: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        otherName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleMedium.copyWith(
                          color: context.convoColors.textPrimary,
                          fontWeight: unreadCount > 0
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                    if (conversation.hasMood &&
                        conversation.moodEmoji != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        conversation.moodEmoji!,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                DateFormatter.formatConversationTime(
                  conversation.lastMessageAt,
                ),
                style: AppTypography.labelSmall.copyWith(
                  color: unreadCount > 0
                      ? context.colorScheme.primary
                      : context.convoColors.textTertiary,
                  fontWeight: unreadCount > 0
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ],
          ),
          subtitle: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    if (conversation.lastMessage == 'Photo') ...[
                      Icon(
                        Icons.photo_camera_rounded,
                        size: 14,
                        color: unreadCount > 0
                            ? context.colorScheme.primary
                            : context.convoColors.textTertiary,
                      ),
                      const SizedBox(width: 4),
                    ] else if (conversation.lastMessage == 'Video') ...[
                      Icon(
                        Icons.videocam_rounded,
                        size: 14,
                        color: unreadCount > 0
                            ? context.colorScheme.primary
                            : context.convoColors.textTertiary,
                      ),
                      const SizedBox(width: 4),
                    ] else if (conversation.lastMessage == 'Voice message') ...[
                      Icon(
                        Icons.mic_rounded,
                        size: 14,
                        color: unreadCount > 0
                            ? context.colorScheme.primary
                            : context.convoColors.textTertiary,
                      ),
                      const SizedBox(width: 4),
                    ] else if (conversation.lastMessage.contains(
                      'Sticker',
                    )) ...[
                      const Text('🎨 ', style: TextStyle(fontSize: 11)),
                    ] else if (conversation.lastMessage.startsWith('🎲')) ...[
                      const Text('🎲 ', style: TextStyle(fontSize: 11)),
                    ] else if (conversation.lastMessage.startsWith('⏳')) ...[
                      const Text('⏳ ', style: TextStyle(fontSize: 11)),
                    ],
                    Expanded(
                      child: Text(
                        conversation.lastMessage.isEmpty
                            ? 'Started a new conversation'
                            : (isLastFromMe
                                  ? 'You: ${conversation.lastMessage}'
                                  : conversation.lastMessage),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: unreadCount > 0
                              ? context.convoColors.textPrimary
                              : context.convoColors.textSecondary,
                          fontWeight: unreadCount > 0
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (unreadCount > 0) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: context.colorScheme.primary,
                    borderRadius: AppRadius.borderPill,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: AppTypography.labelSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
