import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/convo_avatar.dart';
import '../../../auth/domain/models/convo_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/models/conversation_model.dart';
import '../../domain/models/message_model.dart';
import '../providers/chat_providers.dart';

class ForwardMessageSheet extends ConsumerStatefulWidget {
  const ForwardMessageSheet({super.key, required this.message});

  final MessageModel message;

  static Future<void> show(BuildContext context, MessageModel message) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ForwardMessageSheet(message: message),
    );
  }

  @override
  ConsumerState<ForwardMessageSheet> createState() =>
      _ForwardMessageSheetState();
}

class _ForwardMessageSheetState extends ConsumerState<ForwardMessageSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  final Set<String> _sendingIds = {};
  final Map<String, ConversationModel> _selectedConversations = {};
  final Map<String, ConvoUser> _selectedUsers = {};
  bool _isBulkSending = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int get _totalSelected =>
      _selectedConversations.length + _selectedUsers.length;

  void _toggleConversationSelection(ConversationModel conv) {
    setState(() {
      if (_selectedConversations.containsKey(conv.id)) {
        _selectedConversations.remove(conv.id);
      } else {
        _selectedConversations[conv.id] = conv;
      }
    });
  }

  void _toggleUserSelection(ConvoUser user) {
    setState(() {
      if (_selectedUsers.containsKey(user.uid)) {
        _selectedUsers.remove(user.uid);
      } else {
        _selectedUsers[user.uid] = user;
      }
    });
  }

  Future<void> _forwardToConversation(ConversationModel target) async {
    if (_sendingIds.contains(target.id)) return;
    setState(() => _sendingIds.add(target.id));

    try {
      final currentUserId =
          ref.read(authStateChangesProvider).asData?.value?.uid ?? '';
      final isTargetGroup = target.isGroup;
      final receiverId = isTargetGroup
          ? 'group'
          : target.otherParticipantId(currentUserId);
      final recipientIds = isTargetGroup ? target.participants : [receiverId];

      final success = await _performSend(
        targetConversationId: target.id,
        receiverId: receiverId,
        recipientIds: recipientIds,
      );

      if (mounted && success) {
        Navigator.of(context).pop();
        final targetName = isTargetGroup
            ? (target.name ?? 'Group')
            : target.otherParticipantName(currentUserId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Message forwarded to $targetName'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to forward: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sendingIds.remove(target.id));
      }
    }
  }

  Future<void> _forwardToUser(ConvoUser user) async {
    if (_sendingIds.contains(user.uid)) return;
    setState(() => _sendingIds.add(user.uid));

    try {
      final currentUserProfile =
          ref.read(currentUserProfileProvider).asData?.value;
      final authUser = ref.read(authStateChangesProvider).asData?.value;
      final currentUser = currentUserProfile ??
          ConvoUser(
            uid: authUser?.uid ?? '',
            name: authUser?.displayName ?? 'CONVO User',
            email: authUser?.email ?? '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

      final chatService = ref.read(chatServiceProvider);
      final conversation = await chatService.getOrCreateConversation(
        currentUser: currentUser,
        otherUser: user,
      );

      final success = await _performSend(
        targetConversationId: conversation.id,
        receiverId: user.uid,
        recipientIds: [user.uid],
      );

      if (mounted && success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Message forwarded to ${user.name}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to forward: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sendingIds.remove(user.uid));
      }
    }
  }

  Future<void> _forwardToAllSelected() async {
    if (_totalSelected == 0 || _isBulkSending) return;
    setState(() => _isBulkSending = true);

    int successCount = 0;
    final currentUserId =
        ref.read(authStateChangesProvider).asData?.value?.uid ?? '';
    final currentUserProfile =
        ref.read(currentUserProfileProvider).asData?.value;
    final authUser = ref.read(authStateChangesProvider).asData?.value;
    final currentUser = currentUserProfile ??
        ConvoUser(
          uid: authUser?.uid ?? '',
          name: authUser?.displayName ?? 'CONVO User',
          email: authUser?.email ?? '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

    try {
      // 1. Send to all selected conversations
      for (final conv in _selectedConversations.values) {
        final isGroup = conv.isGroup;
        final receiverId =
            isGroup ? 'group' : conv.otherParticipantId(currentUserId);
        final recipientIds = isGroup ? conv.participants : [receiverId];

        final ok = await _performSend(
          targetConversationId: conv.id,
          receiverId: receiverId,
          recipientIds: recipientIds,
        );
        if (ok) successCount++;
      }

      // 2. Send to all selected direct users
      final chatService = ref.read(chatServiceProvider);
      for (final user in _selectedUsers.values) {
        final conv = await chatService.getOrCreateConversation(
          currentUser: currentUser,
          otherUser: user,
        );
        final ok = await _performSend(
          targetConversationId: conv.id,
          receiverId: user.uid,
          recipientIds: [user.uid],
        );
        if (ok) successCount++;
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Forwarded message to $successCount chat${successCount > 1 ? 's' : ''}',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during forward: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isBulkSending = false);
      }
    }
  }

  Future<bool> _performSend({
    required String targetConversationId,
    required String receiverId,
    required List<String> recipientIds,
  }) async {
    final controller = ref.read(chatControllerProvider.notifier);
    final msg = widget.message;
    final originalSenderName = msg.senderName ?? 'User';

    if (msg.isMedia && msg.mediaUrl != null && msg.mediaUrl!.isNotEmpty) {
      return await controller.sendMediaMessage(
        conversationId: targetConversationId,
        receiverId: receiverId,
        recipientIds: recipientIds,
        type: msg.type,
        mediaUrl: msg.mediaUrl!,
        text: msg.text,
        fileName: msg.fileName,
        fileSize: msg.fileSize,
        durationMs: msg.durationMs,
        thumbnailUrl: msg.thumbnailUrl,
        metadata: msg.metadata,
        isForwarded: true,
        forwardedFrom: originalSenderName,
      );
    } else {
      return await controller.sendMessage(
        conversationId: targetConversationId,
        receiverId: receiverId,
        recipientIds: recipientIds,
        text: msg.text.isNotEmpty ? msg.text : 'Forwarded message',
        type: msg.type,
        metadata: msg.metadata,
        isForwarded: true,
        forwardedFrom: originalSenderName,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId =
        ref.watch(authStateChangesProvider).asData?.value?.uid ?? '';
    final conversationsAsync = ref.watch(userConversationsProvider);
    final searchedUsersAsync = ref.watch(searchedUsersProvider(_query));

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: BoxDecoration(
        color: context.convoColors.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: context.convoColors.cardBorder, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: AppSpacing.sm),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.convoColors.cardBorder,
                borderRadius: AppRadius.borderPill,
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Forward Message',
                      style: AppTypography.titleLarge.copyWith(
                        color: context.convoColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (widget.message.text.isNotEmpty)
                      Text(
                        widget.message.isMedia
                            ? '[${widget.message.type.toUpperCase()}] ${widget.message.text}'
                            : widget.message.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: context.convoColors.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Search input
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search chats or contacts...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
              onChanged: (val) => setState(() => _query = val.trim()),
            ),
          ),

          const SizedBox(height: AppSpacing.xs),

          // Content list
          Expanded(
            child: conversationsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text(
                  'Error loading chats: $err',
                  style: TextStyle(color: context.convoColors.textSecondary),
                ),
              ),
              data: (conversations) {
                final filteredConvs = conversations.where((c) {
                  if (_query.isEmpty) return true;
                  final name = c.isGroup
                      ? (c.name ?? 'Group').toLowerCase()
                      : c.otherParticipantName(currentUserId).toLowerCase();
                  return name.contains(_query.toLowerCase());
                }).toList();

                return ListView(
                  children: [
                    if (filteredConvs.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.sm,
                          AppSpacing.lg,
                          AppSpacing.xs,
                        ),
                        child: Text(
                          'RECENT CHATS',
                          style: AppTypography.labelSmall.copyWith(
                            color: context.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      ...filteredConvs.map((conv) {
                        final isSending = _sendingIds.contains(conv.id);
                        final isSelected =
                            _selectedConversations.containsKey(conv.id);
                        final displayName = conv.isGroup
                            ? (conv.name ?? 'Group')
                            : conv.otherParticipantName(currentUserId);
                        final initials = displayName.isNotEmpty
                            ? (displayName.length >= 2
                                  ? displayName.substring(0, 2).toUpperCase()
                                  : displayName[0].toUpperCase())
                            : (conv.isGroup ? 'GP' : 'CO');

                        return ListTile(
                          onTap: () => _toggleConversationSelection(conv),
                          leading: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              ConvoAvatar(
                                initials: initials,
                                photoUrl: conv.isGroup
                                    ? conv.photoUrl
                                    : conv.otherParticipantPhoto(currentUserId),
                                size: 42,
                              ),
                              if (isSelected)
                                Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: context.colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                            ],
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.titleMedium.copyWith(
                                    color: context.convoColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (conv.isGroup) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.colorScheme.primary
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'GROUP',
                                    style: TextStyle(
                                      color: context.colorScheme.primary,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            conv.isGroup
                                ? '${conv.participants.length} members'
                                : (conv.lastMessage.isNotEmpty
                                      ? conv.lastMessage
                                      : 'Tap to select'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySmall.copyWith(
                              color: context.convoColors.textSecondary,
                            ),
                          ),
                          trailing: FilledButton.tonal(
                            onPressed: isSending
                                ? null
                                : () => _forwardToConversation(conv),
                            child: isSending
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Send'),
                          ),
                        );
                      }),
                    ],

                    // Contacts section if search query active
                    if (_query.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.md,
                          AppSpacing.lg,
                          AppSpacing.xs,
                        ),
                        child: Text(
                          'CONTACTS',
                          style: AppTypography.labelSmall.copyWith(
                            color: context.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      searchedUsersAsync.when(
                        loading: () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(AppSpacing.md),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        error: (err, _) => Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Text('Error: $err'),
                        ),
                        data: (users) {
                          if (users.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              child: Center(
                                child: Text(
                                  'No contacts found matching "$_query"',
                                  style: TextStyle(
                                    color: context.convoColors.textSecondary,
                                  ),
                                ),
                              ),
                            );
                          }

                          return Column(
                            children: users.map((user) {
                              final isSending =
                                  _sendingIds.contains(user.uid);
                              final isSelected =
                                  _selectedUsers.containsKey(user.uid);

                              return ListTile(
                                onTap: () => _toggleUserSelection(user),
                                leading: Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    ConvoAvatar(
                                      initials: user.initials,
                                      photoUrl: user.photoUrl,
                                      size: 40,
                                    ),
                                    if (isSelected)
                                      Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: context.colorScheme.primary,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.check_rounded,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                  ],
                                ),
                                title: Text(
                                  user.name,
                                  style: AppTypography.titleMedium.copyWith(
                                    color: context.convoColors.textPrimary,
                                  ),
                                ),
                                subtitle: Text(
                                  user.email,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: context.convoColors.textSecondary,
                                  ),
                                ),
                                trailing: FilledButton.tonal(
                                  onPressed: isSending
                                      ? null
                                      : () => _forwardToUser(user),
                                  child: isSending
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('Send'),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ],
                );
              },
            ),
          ),

          // Bottom Multi-forward action bar
          if (_totalSelected > 0)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: context.convoColors.surfaceSubtle,
                border: Border(
                  top: BorderSide(
                    color: context.convoColors.cardBorder,
                    width: 1,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$_totalSelected chat${_totalSelected > 1 ? 's' : ''} selected',
                      style: AppTypography.titleMedium.copyWith(
                        color: context.convoColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _isBulkSending ? null : _forwardToAllSelected,
                      icon: _isBulkSending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        _isBulkSending ? 'Sending...' : 'Send ($_totalSelected)',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: context.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.sm,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
