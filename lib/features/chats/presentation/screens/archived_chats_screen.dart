import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/convo_app_bar.dart';
import '../../../../core/widgets/convo_avatar.dart';
import '../../../auth/domain/models/convo_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/chat_providers.dart';
import '../../../../services/local_storage/chat_preferences_service.dart';

class ArchivedChatsScreen extends ConsumerWidget {
  const ArchivedChatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(userConversationsProvider);
    final archivedIds = ref.watch(archivedChatIdsProvider);
    final currentUserId =
        ref.watch(authStateChangesProvider).asData?.value?.uid ?? '';

    return Scaffold(
      appBar: ConvoAppBar(
        title: 'Archived Chats',
        actions: [
          if (archivedIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: Center(
                child: Text(
                  '${archivedIds.length}',
                  style: AppTypography.labelSmall.copyWith(
                    color: context.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: conversationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text(
            'Failed to load archived chats: $err',
            style: TextStyle(color: context.convoColors.textSecondary),
          ),
        ),
        data: (allConversations) {
          final archivedList = allConversations
              .where((c) => archivedIds.contains(c.id))
              .toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

          if (archivedList.isEmpty) {
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
                      child: Icon(
                        Icons.archive_outlined,
                        size: 32,
                        color: context.convoColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'No Archived Chats',
                      style: AppTypography.titleMedium.copyWith(
                        color: context.convoColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Archived chats will stay hidden from your main chat list until you unarchive them or receive a new message.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySmall.copyWith(
                        color: context.convoColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: archivedList.length,
            separatorBuilder: (_, _) => Divider(
              indent: 72,
              height: 1,
              color: context.convoColors.cardBorder,
            ),
            itemBuilder: (context, index) {
              final conversation = archivedList[index];
              final isGroup = conversation.isGroup;
              final name = isGroup
                  ? (conversation.name ?? 'Group')
                  : conversation.otherParticipantName(currentUserId);
              final photo = isGroup
                  ? conversation.photoUrl
                  : conversation.otherParticipantPhoto(currentUserId);
              final initials = name.isNotEmpty
                  ? (name.length >= 2
                        ? name.substring(0, 2).toUpperCase()
                        : name[0].toUpperCase())
                  : (isGroup ? 'GP' : 'CO');

              return Dismissible(
                key: Key('archived_${conversation.id}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: context.colorScheme.primary,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: AppSpacing.lg),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.unarchive_rounded, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Unarchive',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                onDismissed: (_) {
                  ref
                      .read(chatPreferencesServiceProvider)
                      .toggleArchiveChat(conversation.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Unarchived $name'),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: ListTile(
                  onTap: () {
                    ConvoUser? otherUser;
                    if (!isGroup) {
                      final otherId =
                          conversation.otherParticipantId(currentUserId);
                      otherUser = ConvoUser(
                        uid: otherId,
                        name: conversation.otherParticipantName(currentUserId),
                        email: '',
                        photoUrl: conversation.otherParticipantPhoto(
                          currentUserId,
                        ),
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      );
                    }
                    context.push(
                      '/chat/${conversation.id}',
                      extra: otherUser,
                    );
                  },
                  leading: ConvoAvatar(
                    initials: initials,
                    photoUrl: photo,
                    size: 48,
                  ),
                  title: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleMedium.copyWith(
                      color: context.convoColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    conversation.lastMessage.isNotEmpty
                        ? conversation.lastMessage
                        : 'No messages',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: context.convoColors.textSecondary,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormatter.formatConversationTime(conversation.updatedAt),
                        style: AppTypography.labelSmall.copyWith(
                          color: context.convoColors.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.unarchive_outlined, size: 20),
                        tooltip: 'Unarchive',
                        onPressed: () {
                          ref
                              .read(chatPreferencesServiceProvider)
                              .toggleArchiveChat(conversation.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Unarchived $name'),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
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
      ),
    );
  }
}
