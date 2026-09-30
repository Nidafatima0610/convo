import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/convo_avatar.dart';
import '../../../auth/domain/models/convo_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../calls/domain/models/call_model.dart';
import '../../../calls/presentation/providers/call_providers.dart';
import '../../../capsules/domain/models/capsule_model.dart';
import '../../../capsules/presentation/widgets/create_capsule_dialog.dart';
import '../../../games/domain/models/game_model.dart';
import '../../../games/presentation/widgets/game_launcher_sheet.dart';
import '../../../moods/domain/models/chat_mood.dart';
import '../../../moods/presentation/widgets/chat_mood_sheet.dart';
import '../../../nearby/presentation/providers/nearby_providers.dart';
import '../../../secret_chat/presentation/widgets/secret_chat_dialog.dart';
import '../../../stickers/domain/models/sticker_model.dart';
import '../../../stickers/presentation/widgets/sticker_picker_sheet.dart';
import '../../../voice_effects/domain/models/voice_effect.dart';
import '../../../voice_effects/presentation/widgets/voice_effect_preview_bar.dart';
import '../../domain/models/conversation_model.dart';
import '../../domain/models/message_model.dart';
import '../../../../services/notifications/notification_service.dart';
import '../../../profile/domain/privacy_helper.dart';
import '../providers/chat_providers.dart';
import '../widgets/chat_magic_sheet.dart';
import '../widgets/convo_emoji_picker.dart';
import '../widgets/forward_message_sheet.dart';
import '../../../../services/local_storage/chat_preferences_service.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId, this.otherUser});

  final String conversationId;
  final ConvoUser? otherUser;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  bool _canSend = false;
  bool _showEmojiPicker = false;
  bool _isRecording = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  String? _recordedVoicePath;
  int _recordedVoiceDuration = 0;

  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _uploadStatusText = 'Uploading media...';

  // Multi-selection state
  bool _isSelectionMode = false;
  final Set<String> _selectedMessageIds = {};
  final Map<String, MessageModel> _selectedMessages = {};

  // In-chat search state
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Typing debounce timer
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    NotificationService.activeConversationId = widget.conversationId;
    _textController.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
    _scrollController.addListener(_onScroll);

    // Mark conversation as read on screen entry
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(chatControllerProvider.notifier)
          .markAsRead(widget.conversationId);
    });
  }

  @override
  void dispose() {
    if (NotificationService.activeConversationId == widget.conversationId) {
      NotificationService.activeConversationId = null;
    }
    _recordingTimer?.cancel();
    _typingTimer?.cancel();
    _textController.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _scrollController.removeListener(_onScroll);
    _textController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    // When user scrolls towards older messages (top of reverse ListView), fetch next page
    if (currentScroll >= maxScroll - 250) {
      ref
          .read(conversationPaginatedMessagesProvider(widget.conversationId).notifier)
          .loadMore();
    }
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus && _showEmojiPicker) {
      setState(() => _showEmojiPicker = false);
    }
  }

  void _sendTypingStatus(bool isTyping) {
    if (!mounted) return;
    final currentUserId = ref.read(authStateChangesProvider).asData?.value?.uid;
    if (currentUserId == null || currentUserId.isEmpty) return;
    ref.read(chatControllerProvider.notifier).setTypingStatus(
      conversationId: widget.conversationId,
      isTyping: isTyping,
    );
  }

  void _onTextChanged() {
    final canSend = _textController.text.trim().isNotEmpty;
    if (canSend != _canSend) {
      setState(() => _canSend = canSend);
    }

    if (_textController.text.trim().isNotEmpty) {
      _sendTypingStatus(true);
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 3), () {
        _sendTypingStatus(false);
      });
    } else {
      _sendTypingStatus(false);
    }
  }

  void _toggleMessageSelection(MessageModel message) {
    setState(() {
      if (_selectedMessageIds.contains(message.id)) {
        _selectedMessageIds.remove(message.id);
        _selectedMessages.remove(message.id);
        if (_selectedMessageIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedMessageIds.add(message.id);
        _selectedMessages[message.id] = message;
      }
    });
  }

  void _startSelectionWith(MessageModel message) {
    setState(() {
      _isSelectionMode = true;
      _selectedMessageIds.add(message.id);
      _selectedMessages[message.id] = message;
    });
  }

  void _clearSelection() {
    setState(() {
      _isSelectionMode = false;
      _selectedMessageIds.clear();
      _selectedMessages.clear();
    });
  }

  void _copySelectedMessages() {
    final textList = _selectedMessages.values
        .where((m) => !m.isMedia && m.text.isNotEmpty && !m.isDeleted)
        .map((m) => m.text)
        .toList();
    if (textList.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: textList.join('\n\n')));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${textList.length} message(s) copied to clipboard'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
    _clearSelection();
  }

  Future<void> _starSelectedMessages() async {
    final prefs = ref.read(chatPreferencesServiceProvider);
    for (final m in _selectedMessages.values) {
      if (!m.isDeleted) {
        await prefs.toggleStarMessage(m);
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Starred messages updated'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
    _clearSelection();
  }

  void _deleteSelectedMessages(String currentUserId) {
    final selectedList = _selectedMessages.values.toList();
    final allMine = selectedList.every((m) => m.senderId == currentUserId);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: context.convoColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderXl),
        title: Text(
          'Delete ${selectedList.length} Messages?',
          style: AppTypography.titleLarge.copyWith(
            color: context.convoColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          allMine
              ? 'Choose whether to delete these messages for yourself or for everyone.'
              : 'These messages will be removed from your chat on this device.',
          style: AppTypography.bodyMedium.copyWith(
            color: context.convoColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              for (final m in selectedList) {
                await ref
                    .read(chatControllerProvider.notifier)
                    .deleteMessageForMe(
                      conversationId: widget.conversationId,
                      messageId: m.id,
                    );
              }
              _clearSelection();
            },
            child: const Text('Delete for me'),
          ),
          if (allMine)
            FilledButton(
              onPressed: () async {
                Navigator.of(dialogCtx).pop();
                for (final m in selectedList) {
                  await ref
                      .read(chatControllerProvider.notifier)
                      .deleteMessageForEveryone(
                        conversationId: widget.conversationId,
                        messageId: m.id,
                      );
                }
                _clearSelection();
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete for everyone'),
            ),
        ],
      ),
    );
  }

  Future<void> _toggleStarMessage(MessageModel message) async {
    final prefs = ref.read(chatPreferencesServiceProvider);
    await prefs.toggleStarMessage(message);
  }

  void _jumpToMessage(String messageId, List<MessageModel> messages) {
    final index = messages.indexWhere((m) => m.id == messageId);
    if (index != -1 && _scrollController.hasClients) {
      final targetOffset = (index * 72.0).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      ref
          .read(
            conversationPaginatedMessagesProvider(
              widget.conversationId,
            ).notifier,
          )
          .loadMore();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loading older messages...'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  DateTime? _calculateExpiresAt(ConversationModel? conversation) {
    if (conversation?.isDisappearingActive == true) {
      return DateTime.now().add(
        Duration(seconds: conversation!.disappearingDuration!),
      );
    }
    return null;
  }

  Future<void> _handleSendMessage(
    String receiverId,
    String receiverName,
    ConversationModel? conversation,
  ) async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final replyingMessage = ref.read(replyingMessageProvider);

    _textController.clear();
    setState(() => _canSend = false);

    final expiresAt = _calculateExpiresAt(conversation);
    final currentUser = ref.read(currentUserProfileProvider).asData?.value;
    final currentConv = ref
            .read(singleConversationProvider(widget.conversationId))
            .asData
            ?.value ??
        conversation;
    final isGroup = currentConv?.isGroup == true;
    final recipientIds = isGroup
        ? currentConv!.participants
        : (receiverId.isNotEmpty ? [receiverId] : <String>[]);

    await ref
        .read(chatControllerProvider.notifier)
        .sendMessage(
          conversationId: widget.conversationId,
          receiverId: isGroup ? 'group' : receiverId,
          recipientIds: recipientIds,
          senderName: currentUser?.name,
          senderPhotoUrl: currentUser?.photoUrl,
          text: text,
          replyToMessageId: replyingMessage?.id,
          replyToSnippet: replyingMessage?.text,
          replyToSenderName: replyingMessage?.senderName ??
              (replyingMessage?.senderId == receiverId ? receiverName : 'You'),
          expiresAt: expiresAt,
          isSecret: expiresAt != null,
        );

    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuad,
      );
    }
  }

  void _toggleEmojiPicker() {
    if (_showEmojiPicker) {
      setState(() => _showEmojiPicker = false);
      _focusNode.requestFocus();
    } else {
      _focusNode.unfocus();
      setState(() => _showEmojiPicker = true);
    }
  }

  // --- Voice Message Recording & Effects ---

  Future<void> _startVoiceRecording() async {
    final audioService = ref.read(audioServiceProvider);
    final hasPerm = await audioService.hasPermission();

    if (!hasPerm) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Microphone permission is required to record voice messages.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final success = await audioService.startRecording();
    if (success) {
      HapticFeedback.heavyImpact();
      setState(() {
        _isRecording = true;
        _recordingSeconds = 0;
        _recordedVoicePath = null;
        _recordedVoiceDuration = 0;
      });

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() => _recordingSeconds++);
        }
      });
    }
  }

  Future<void> _cancelVoiceRecording() async {
    _recordingTimer?.cancel();
    final audioService = ref.read(audioServiceProvider);
    await audioService.cancelRecording();

    if (mounted) {
      setState(() {
        _isRecording = false;
        _recordingSeconds = 0;
        _recordedVoicePath = null;
        _recordedVoiceDuration = 0;
      });
    }
  }

  Future<void> _finishVoiceRecording() async {
    _recordingTimer?.cancel();
    final audioService = ref.read(audioServiceProvider);
    final result = await audioService.stopRecording();

    setState(() {
      _isRecording = false;
      _recordingSeconds = 0;
    });

    if (result.path == null || result.durationMs < 600) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recording was too short'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 1),
          ),
        );
      }
      return;
    }

    setState(() {
      _recordedVoicePath = result.path;
      _recordedVoiceDuration = (result.durationMs / 1000).ceil();
    });
  }

  Future<void> _uploadAndSendVoiceMessage(
    String path,
    String otherUserId,
    VoiceEffectPreset effect,
    ConversationModel? conversation,
  ) async {
    final currentUserId =
        ref.read(authStateChangesProvider).asData?.value?.uid ?? '';
    final currentUser = ref.read(currentUserProfileProvider).asData?.value;
    final mediaService = ref.read(mediaServiceProvider);
    final isGroup = conversation?.isGroup == true;

    setState(() {
      _isUploading = true;
      _uploadStatusText = 'Sending voice message (${effect.name})...';
      _uploadProgress = 0.0;
    });

    final expiresAt = _calculateExpiresAt(conversation);

    try {
      final downloadUrl = await mediaService.uploadChatMedia(
        filePath: path,
        senderId: currentUserId,
        conversationId: widget.conversationId,
        category: 'voice',
        fileName: 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
        mimeType: 'audio/m4a',
        onProgress: (p) => setState(() => _uploadProgress = p),
      );

      if (downloadUrl != null) {
        await ref
            .read(chatControllerProvider.notifier)
            .sendMediaMessage(
              conversationId: widget.conversationId,
              receiverId: isGroup ? 'group' : otherUserId,
              recipientIds: isGroup ? conversation!.participants : [otherUserId],
              senderName: currentUser?.name,
              senderPhotoUrl: currentUser?.photoUrl,
              type: 'voice',
              mediaUrl: downloadUrl,
              durationMs: _recordedVoiceDuration * 1000,
              metadata: {'effect': effect.name},
              expiresAt: expiresAt,
              isSecret: expiresAt != null,
            );
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload voice message: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  // --- Chat Magic Hub & Senders ---

  void _openChatMagic(
    String otherUserId,
    String otherUserName,
    ConversationModel? conversation,
  ) {
    ChatMagicSheet.show(
      context,
      currentMoodLabel: conversation?.hasMood == true
          ? '${conversation!.moodEmoji} ${conversation.moodLabel}'
          : null,
      isSecretActive: conversation?.isDisappearingActive ?? false,
      onActionSelected: (action) {
        switch (action) {
          case ChatMagicAction.stickers:
            StickerPickerSheet.show(
              context,
              conversationId: widget.conversationId,
              onStickerSelected: (sticker) =>
                  _sendSticker(sticker, otherUserId, conversation),
              onOpenStudio: () => context.push(AppRoutes.stickerStudio),
            );
            break;
          case ChatMagicAction.mood:
            ChatMoodSheet.show(
              context,
              conversationId: widget.conversationId,
              currentMood: conversation?.mood != null
                  ? ChatMood.fromMap(conversation!.mood!)
                  : null,
            );
            break;
          case ChatMagicAction.games:
            GameLauncherSheet.show(
              context,
              conversationId: widget.conversationId,
              onGameSelected: (game) =>
                  _sendGame(game, otherUserId, conversation),
            );
            break;
          case ChatMagicAction.voiceEffects:
            _startVoiceRecording();
            break;
          case ChatMagicAction.reactions:
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Long press any message bubble to trigger animated reactions: ❤️ 😂 👍 😮 😢 🔥 🎉',
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
            break;
          case ChatMagicAction.capsule:
            CreateCapsuleDialog.show(
              context,
              conversationId: widget.conversationId,
              receiverId: otherUserId,
              receiverName: otherUserName,
              onCapsuleCreated: (capsule) =>
                  _sendCapsule(capsule, otherUserId, conversation),
            );
            break;
          case ChatMagicAction.secretChat:
            if (conversation != null) {
              SecretChatDialog.show(context, conversation);
            }
            break;
        }
      },
    );
  }

  Future<void> _sendSticker(
    StickerModel sticker,
    String otherUserId,
    ConversationModel? conversation,
  ) async {
    final expiresAt = _calculateExpiresAt(conversation);
    final isSecret = expiresAt != null;
    final currentUser = ref.read(currentUserProfileProvider).asData?.value;
    final isGroup = conversation?.isGroup == true;

    await ref
        .read(chatControllerProvider.notifier)
        .sendMessage(
          conversationId: widget.conversationId,
          receiverId: isGroup ? 'group' : otherUserId,
          recipientIds: isGroup ? conversation!.participants : [otherUserId],
          senderName: currentUser?.name,
          senderPhotoUrl: currentUser?.photoUrl,
          text: '${sticker.emoji} Sticker',
          type: 'sticker',
          metadata: {'sticker': sticker.toMap()},
          expiresAt: expiresAt,
          isSecret: isSecret,
        );
    _scrollToBottom();
  }

  Future<void> _sendGame(
    GameModel game,
    String otherUserId,
    ConversationModel? conversation,
  ) async {
    final expiresAt = _calculateExpiresAt(conversation);
    final isSecret = expiresAt != null;
    final currentUser = ref.read(currentUserProfileProvider).asData?.value;
    final isGroup = conversation?.isGroup == true;

    await ref
        .read(chatControllerProvider.notifier)
        .sendMessage(
          conversationId: widget.conversationId,
          receiverId: isGroup ? 'group' : otherUserId,
          recipientIds: isGroup ? conversation!.participants : [otherUserId],
          senderName: currentUser?.name,
          senderPhotoUrl: currentUser?.photoUrl,
          text: '🎲 ${game.title}: ${game.question}',
          type: 'game',
          metadata: {'game': game.toMap()},
          expiresAt: expiresAt,
          isSecret: isSecret,
        );
    _scrollToBottom();
  }

  Future<void> _sendCapsule(
    CapsuleModel capsule,
    String otherUserId,
    ConversationModel? conversation,
  ) async {
    final currentUser = ref.read(currentUserProfileProvider).asData?.value;
    final isGroup = conversation?.isGroup == true;

    await ref
        .read(chatControllerProvider.notifier)
        .sendMessage(
          conversationId: widget.conversationId,
          receiverId: isGroup ? 'group' : otherUserId,
          recipientIds: isGroup ? conversation!.participants : [otherUserId],
          senderName: currentUser?.name,
          senderPhotoUrl: currentUser?.photoUrl,
          text: '⏳ Capsule: ${capsule.message}',
          type: 'capsule',
          metadata: {'capsule': capsule.toMap()},
        );
    _scrollToBottom();
  }

  // --- Image & Video Media Sharing ---

  void _showAttachmentOptions(
    String otherUserId,
    ConversationModel? conversation,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: context.convoColors.cardBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(color: context.convoColors.cardBorder, width: 1),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.convoColors.cardBorder,
                  borderRadius: AppRadius.borderPill,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _AttachmentOptionTile(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    color: AppColors.primary,
                    onTap: () {
                      Navigator.of(modalContext).pop();
                      _pickAndSendImage(
                        ImageSource.gallery,
                        otherUserId,
                        conversation,
                      );
                    },
                  ),
                  _AttachmentOptionTile(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    color: AppColors.accent,
                    onTap: () {
                      Navigator.of(modalContext).pop();
                      _pickAndSendImage(
                        ImageSource.camera,
                        otherUserId,
                        conversation,
                      );
                    },
                  ),
                  _AttachmentOptionTile(
                    icon: Icons.videocam_rounded,
                    label: 'Video',
                    color: AppColors.blueGlow,
                    onTap: () {
                      Navigator.of(modalContext).pop();
                      _pickAndSendVideo(otherUserId, conversation);
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndSendImage(
    ImageSource source,
    String otherUserId,
    ConversationModel? conversation,
  ) async {
    final mediaService = ref.read(mediaServiceProvider);
    final file = await mediaService.pickImage(source: source);
    if (file == null) return;

    final currentUserId =
        ref.read(authStateChangesProvider).asData?.value?.uid ?? '';
    final currentUser = ref.read(currentUserProfileProvider).asData?.value;
    final isGroup = conversation?.isGroup == true;

    setState(() {
      _isUploading = true;
      _uploadStatusText = 'Uploading photo...';
      _uploadProgress = 0.0;
    });

    try {
      final downloadUrl = await mediaService.uploadChatMedia(
        filePath: file.path,
        senderId: currentUserId,
        conversationId: widget.conversationId,
        category: 'images',
        fileName: file.name,
        mimeType: 'image/jpeg',
        onProgress: (p) => setState(() => _uploadProgress = p),
      );

      if (downloadUrl != null) {
        await ref
            .read(chatControllerProvider.notifier)
            .sendMediaMessage(
              conversationId: widget.conversationId,
              receiverId: isGroup ? 'group' : otherUserId,
              recipientIds: isGroup ? conversation!.participants : [otherUserId],
              senderName: currentUser?.name,
              senderPhotoUrl: currentUser?.photoUrl,
              type: 'image',
              mediaUrl: downloadUrl,
              fileName: file.name,
            );
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to upload photo: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _pickAndSendVideo(
    String otherUserId,
    ConversationModel? conversation,
  ) async {
    final mediaService = ref.read(mediaServiceProvider);
    final file = await mediaService.pickVideo();
    if (file == null) return;

    final currentUserId =
        ref.read(authStateChangesProvider).asData?.value?.uid ?? '';
    final currentUser = ref.read(currentUserProfileProvider).asData?.value;
    final isGroup = conversation?.isGroup == true;

    setState(() {
      _isUploading = true;
      _uploadStatusText = 'Uploading video...';
      _uploadProgress = 0.0;
    });

    try {
      final downloadUrl = await mediaService.uploadChatMedia(
        filePath: file.path,
        senderId: currentUserId,
        conversationId: widget.conversationId,
        category: 'videos',
        fileName: file.name,
        mimeType: 'video/mp4',
        onProgress: (p) => setState(() => _uploadProgress = p),
      );

      if (downloadUrl != null) {
        await ref
            .read(chatControllerProvider.notifier)
            .sendMediaMessage(
              conversationId: widget.conversationId,
              receiverId: isGroup ? 'group' : otherUserId,
              recipientIds: isGroup ? conversation!.participants : [otherUserId],
              senderName: currentUser?.name,
              senderPhotoUrl: currentUser?.photoUrl,
              type: 'video',
              mediaUrl: downloadUrl,
              fileName: file.name,
            );
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to upload video: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _openChatDetails(ConvoUser otherUser) {
    context.push('/chat/${widget.conversationId}/details', extra: otherUser);
  }

  Future<void> _startCall(ConvoUser otherUser, {required bool isVideo}) async {
    final currentUser = ref.read(currentUserProfileProvider).asData?.value;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to make calls')),
      );
      return;
    }

    final success = await ref
        .read(activeCallControllerProvider.notifier)
        .startCall(
          caller: currentUser,
          receiver: otherUser,
          type: isVideo ? CallType.video : CallType.voice,
        );

    if (success && mounted) {
      context.push('/call/active');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId =
        ref.watch(authStateChangesProvider).asData?.value?.uid ?? '';
    final singleConvAsync =
        ref.watch(singleConversationProvider(widget.conversationId));
    final conversationsAsync = ref.watch(userConversationsProvider);
    final conversationList = conversationsAsync.asData?.value ?? [];
    final resolvedConv = singleConvAsync.asData?.value ??
        conversationList
            .where((c) => c.id == widget.conversationId)
            .firstOrNull;

    if (widget.otherUser == null && resolvedConv == null) {
      if (singleConvAsync.isLoading || conversationsAsync.isLoading) {
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.pop(),
            ),
            title: const Text('Loading chat...'),
          ),
          body: const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }
    }

    final conversation = resolvedConv ??
        ConversationModel(
          id: widget.conversationId,
          type: widget.otherUser != null ? 'direct' : 'group',
          participants: widget.otherUser != null
              ? [currentUserId, widget.otherUser!.uid]
              : [currentUserId],
          participantDetails: widget.otherUser != null
              ? {
                  widget.otherUser!.uid: {
                    'name': widget.otherUser!.name,
                    'email': widget.otherUser!.email,
                    'photoUrl': widget.otherUser!.photoUrl,
                  },
                }
              : {},
          lastMessageAt: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

    final isGroup = conversation.isGroup;

    final otherUserId =
        widget.otherUser?.uid ??
        (isGroup ? '' : conversation.otherParticipantId(currentUserId));
    final otherUserName =
        widget.otherUser?.name ??
        (isGroup
            ? (conversation.name ?? 'Group')
            : conversation.otherParticipantName(currentUserId));

    final otherUserObj =
        widget.otherUser ??
        ConvoUser(
          uid: otherUserId,
          name: otherUserName,
          email: isGroup ? '' : conversation.otherParticipantEmail(currentUserId),
          photoUrl: isGroup
              ? conversation.photoUrl
              : conversation.otherParticipantPhoto(currentUserId),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

    // Live presence stream of other user (only for 1-to-1 chats)
    final otherUserLive = isGroup
        ? null
        : ref.watch(userPresenceProvider(otherUserId)).asData?.value;
    final isOnline =
        otherUserLive?.isOnline ?? widget.otherUser?.isOnline ?? false;

    final currentUserProfile =
        ref.watch(currentUserProfileProvider).asData?.value;
    final isBlockedByMe =
        !isGroup && (currentUserProfile?.isUserBlocked(otherUserId) ?? false);
    final targetUserObj = otherUserLive ?? otherUserObj;

    final canSeePhoto = isGroup ||
        PrivacyHelper.canViewPhoto(
          targetUser: targetUserObj,
          viewerUserId: currentUserId,
          hasConversation: true,
        );
    final canSeeOnline = !isGroup &&
        PrivacyHelper.canViewOnline(
          targetUser: targetUserObj,
          viewerUserId: currentUserId,
          hasConversation: true,
        );
    final canSeeLastSeen = !isGroup &&
        PrivacyHelper.canViewLastSeen(
          targetUser: targetUserObj,
          viewerUserId: currentUserId,
          hasConversation: true,
        );

    // Check if other user is directly connected via CONVO Nearby Offline
    final nearbyService = ref.watch(nearbyServiceProvider);
    final isNearbyConnected =
        !isGroup && nearbyService.isConnectedToUser(otherUserId);

    final messagesAsync = ref.watch(
      conversationCombinedMessagesProvider(widget.conversationId),
    );
    final paginatedState = ref.watch(
      conversationPaginatedMessagesProvider(widget.conversationId),
    );
    final replyingMessage = ref.watch(replyingMessageProvider);

    final typingUsers = ref.watch(
      conversationTypingUsersProvider(widget.conversationId),
    );
    final starredItems = ref.watch(starredMessagesProvider);
    final starredMessageIds = starredItems.map((s) => s.messageId).toSet();

    return Scaffold(
      appBar: _isSelectionMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: _clearSelection,
              ),
              title: Text(
                '${_selectedMessageIds.length} selected',
                style: AppTypography.titleMedium.copyWith(
                  color: context.convoColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.copy_rounded),
                  tooltip: 'Copy',
                  onPressed: _copySelectedMessages,
                ),
                IconButton(
                  icon: const Icon(Icons.star_outline_rounded),
                  tooltip: 'Star',
                  onPressed: _starSelectedMessages,
                ),
                IconButton(
                  icon: const Icon(Icons.forward_rounded),
                  tooltip: 'Forward',
                  onPressed: () {
                    final firstMsg = _selectedMessages.values.firstOrNull;
                    if (firstMsg != null) {
                      ForwardMessageSheet.show(context, firstMsg);
                    }
                    _clearSelection();
                  },
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.error,
                  ),
                  tooltip: 'Delete',
                  onPressed: () => _deleteSelectedMessages(currentUserId),
                ),
              ],
            )
          : _isSearching
              ? AppBar(
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () {
                      setState(() {
                        _isSearching = false;
                        _searchQuery = '';
                        _searchController.clear();
                      });
                    },
                  ),
                  title: TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: AppTypography.bodyLarge.copyWith(
                      color: context.convoColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search in conversation...',
                      hintStyle: TextStyle(
                        color: context.convoColors.textTertiary,
                      ),
                      border: InputBorder.none,
                    ),
                    onChanged: (val) {
                      setState(() => _searchQuery = val.trim());
                    },
                  ),
                  actions: [
                    if (_searchQuery.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _searchController.clear();
                          });
                        },
                      ),
                  ],
                )
              : AppBar(
                  titleSpacing: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => context.pop(),
                  ),
                  title: InkWell(
                    onTap: () {
                      if (isGroup) {
                        context.push(
                          '/chat/${widget.conversationId}/group_info',
                        );
                      } else {
                        _openChatDetails(otherUserObj);
                      }
                    },
                    borderRadius: AppRadius.borderMd,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 2,
                      ),
                      child: Row(
                        children: [
                          ConvoAvatar(
                            initials: isGroup
                                ? (conversation.name?.isNotEmpty == true
                                      ? (conversation.name!.length >= 2
                                            ? conversation.name!
                                                  .substring(0, 2)
                                                  .toUpperCase()
                                            : conversation.name![0]
                                                  .toUpperCase())
                                      : 'GP')
                                : (otherUserName.isNotEmpty
                                      ? (otherUserName.length >= 2
                                            ? otherUserName
                                                  .substring(0, 2)
                                                  .toUpperCase()
                                            : otherUserName[0].toUpperCase())
                                      : 'CO'),
                            photoUrl: isGroup
                                ? conversation.photoUrl
                                : (canSeePhoto ? targetUserObj.photoUrl : null),
                            size: 38,
                            status: isGroup
                                ? ConvoAvatarStatus.none
                                : (isNearbyConnected
                                      ? ConvoAvatarStatus.online
                                      : (canSeeOnline && isOnline
                                            ? ConvoAvatarStatus.online
                                            : ConvoAvatarStatus.offline)),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        otherUserName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style:
                                            AppTypography.titleMedium.copyWith(
                                          color: context.convoColors.textPrimary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    if (conversation.hasMood &&
                                        conversation.moodEmoji != null) ...[
                                      const SizedBox(width: 4),
                                      InkWell(
                                        onTap: () => ChatMoodSheet.show(
                                          context,
                                          conversationId: widget.conversationId,
                                          currentMood: conversation.mood != null
                                              ? ChatMood.fromMap(
                                                  conversation.mood!,
                                                )
                                              : null,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: context.colorScheme.primary
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            conversation.moodEmoji!,
                                            style:
                                                const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (typingUsers.isNotEmpty)
                                  Text(
                                    '${typingUsers.join(', ')} typing...',
                                    style: AppTypography.labelSmall.copyWith(
                                      color: context.colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FontStyle.italic,
                                      fontSize: 11,
                                    ),
                                  )
                                else if (isGroup)
                                  Text(
                                    '${conversation.participants.length} members',
                                    style: AppTypography.labelSmall.copyWith(
                                      color: context.convoColors.textTertiary,
                                      fontSize: 11,
                                    ),
                                  )
                                else
                                  Row(
                                    children: [
                                      Container(
                                        width: 7,
                                        height: 7,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isBlockedByMe
                                              ? AppColors.error
                                              : (isNearbyConnected
                                                    ? AppColors.accentPurple
                                                    : (canSeeOnline && isOnline
                                                          ? AppColors.success
                                                          : Colors.grey)),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isBlockedByMe
                                            ? 'Blocked'
                                            : (isNearbyConnected
                                                  ? 'Nearby Peer'
                                                  : (canSeeOnline && isOnline
                                                        ? 'Active now'
                                                        : (canSeeLastSeen &&
                                                                targetUserObj
                                                                        .lastSeen !=
                                                                    null
                                                            ? 'Last seen ${DateFormatter.formatTimeAgo(targetUserObj.lastSeen!)}'
                                                            : 'Offline'))),
                                        style:
                                            AppTypography.labelSmall.copyWith(
                                          color: isBlockedByMe
                                              ? AppColors.error
                                              : (isNearbyConnected
                                                    ? AppColors.accentPurple
                                                    : (canSeeOnline && isOnline
                                                          ? AppColors.success
                                                          : context
                                                              .convoColors
                                                              .textTertiary)),
                                          fontSize: 11,
                                          fontWeight:
                                              isNearbyConnected || isBlockedByMe
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.search_rounded),
                      tooltip: 'Search in Conversation',
                      onPressed: () => setState(() => _isSearching = true),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.auto_awesome_rounded,
                        color: AppColors.primary,
                      ),
                      tooltip: 'Chat Magic',
                      onPressed: () => _openChatMagic(
                        otherUserId,
                        otherUserName,
                        conversation,
                      ),
                    ),
                    if (!isGroup) ...[
                      IconButton(
                        icon: const Icon(Icons.phone_outlined),
                        tooltip: 'Voice Call',
                        onPressed: () =>
                            _startCall(otherUserObj, isVideo: false),
                      ),
                      IconButton(
                        icon: const Icon(Icons.videocam_outlined),
                        tooltip: 'Video Call',
                        onPressed: () =>
                            _startCall(otherUserObj, isVideo: true),
                      ),
                    ],
                    IconButton(
                      icon: const Icon(Icons.info_outline_rounded),
                      tooltip: isGroup ? 'Group Info' : 'Conversation Info',
                      onPressed: () {
                        if (isGroup) {
                          context.push(
                            '/chat/${widget.conversationId}/group_info',
                          );
                        } else {
                          _openChatDetails(otherUserObj);
                        }
                      },
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded),
                      onSelected: (value) async {
                        if (value == 'search') {
                          setState(() => _isSearching = true);
                        } else if (value == 'gallery') {
                          context.push(
                            '/chat/${widget.conversationId}/gallery',
                          );
                        } else if (value == 'starred') {
                          context.push('/starred_messages');
                        } else if (value == 'group_info') {
                          context.push(
                            '/chat/${widget.conversationId}/group_info',
                          );
                        } else if (value == 'toggle_mute') {
                          final isMuted =
                              conversation.isMutedFor(currentUserId);
                          await ref
                              .read(chatControllerProvider.notifier)
                              .toggleGroupMute(
                                conversationId: widget.conversationId,
                                mute: !isMuted,
                              );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isMuted
                                      ? 'Group notifications unmuted'
                                      : 'Group notifications muted',
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } else if (value == 'toggle_block') {
                          final messenger = ScaffoldMessenger.of(context);
                          if (isBlockedByMe) {
                            await ref
                                .read(profileControllerProvider.notifier)
                                .unblockUser(otherUserId);
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Contact unblocked.'),
                              ),
                            );
                          } else {
                            await ref
                                .read(profileControllerProvider.notifier)
                                .blockUser(otherUserId);
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Contact blocked.'),
                              ),
                            );
                          }
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'search',
                          child: Row(
                            children: [
                              Icon(Icons.search_rounded, size: 20),
                              SizedBox(width: 8),
                              Text('Search'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'gallery',
                          child: Row(
                            children: [
                              Icon(Icons.perm_media_outlined, size: 20),
                              SizedBox(width: 8),
                              Text('Media, Links & Files'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'starred',
                          child: Row(
                            children: [
                              Icon(Icons.star_outline_rounded, size: 20),
                              SizedBox(width: 8),
                              Text('Starred Messages'),
                            ],
                          ),
                        ),
                        if (isGroup) ...[
                          const PopupMenuItem(
                            value: 'group_info',
                            child: Row(
                              children: [
                                Icon(Icons.info_outline_rounded, size: 20),
                                SizedBox(width: 8),
                                Text('Group Info'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'toggle_mute',
                            child: Row(
                              children: [
                                Icon(
                                  conversation.isMutedFor(currentUserId)
                                      ? Icons.notifications_active_rounded
                                      : Icons.notifications_off_rounded,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  conversation.isMutedFor(currentUserId)
                                      ? 'Unmute Notifications'
                                      : 'Mute Notifications',
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          PopupMenuItem(
                            value: 'toggle_block',
                            child: Row(
                              children: [
                                Icon(
                                  isBlockedByMe
                                      ? Icons.check_circle_outline_rounded
                                      : Icons.block_rounded,
                                  color: isBlockedByMe
                                      ? AppColors.primary
                                      : AppColors.error,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isBlockedByMe
                                      ? 'Unblock Contact'
                                      : 'Block Contact',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
      body: SafeArea(
        child: Column(
          children: [
            // Secret / Disappearing Chat banner
            if (conversation.isDisappearingActive)
              InkWell(
                onTap: () => SecretChatDialog.show(context, conversation),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        size: 13,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Secret Chat Active: ${conversation.disappearingDuration}s • Auto-destruct',
                        style: AppTypography.bodySmall.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Nearby Offline direct connection banner
            if (isNearbyConnected)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accentPurple.withValues(alpha: 0.12),
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.accentPurple.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accentPurple,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.radar_rounded,
                      size: 14,
                      color: AppColors.accentPurple,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Nearby Offline • Connected directly',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.accentPurple,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),

            // Upload progress banner
            if (_isUploading)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: 6,
                ),
                color: context.colorScheme.primary.withValues(alpha: 0.12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        value: _uploadProgress > 0 ? _uploadProgress : null,
                        strokeWidth: 2,
                        color: context.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        _uploadStatusText,
                        style: AppTypography.labelSmall.copyWith(
                          color: context.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_uploadProgress > 0)
                      Text(
                        '${(_uploadProgress * 100).toInt()}%',
                        style: AppTypography.labelSmall.copyWith(
                          color: context.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),

            // Messages List Area
            Expanded(
              child: messagesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.error,
                          size: 36,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Error loading messages',
                          style: AppTypography.titleMedium.copyWith(
                            color: context.convoColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          err.toString(),
                          textAlign: TextAlign.center,
                          style: AppTypography.bodySmall.copyWith(
                            color: context.convoColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (messages) {
                  final displayedMessages = _searchQuery.isEmpty
                      ? messages
                      : messages
                          .where((m) =>
                              m.text
                                  .toLowerCase()
                                  .contains(_searchQuery.toLowerCase()) ||
                              (m.senderName
                                      ?.toLowerCase()
                                      .contains(_searchQuery.toLowerCase()) ??
                                  false))
                          .toList();

                  if (messages.isEmpty) {
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
                                color: context.colorScheme.primary.withValues(
                                  alpha: 0.12,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.waving_hand_rounded,
                                color: context.colorScheme.primary,
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              isGroup ? 'Welcome!' : 'Say Hello!',
                              style: AppTypography.headlineMedium.copyWith(
                                color: context.convoColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              isGroup
                                  ? 'No messages in this group yet.\nSend photos, voice messages, or text to start chatting with the group!'
                                  : 'No messages in this encrypted conversation yet.\nSend text, photos, videos or voice messages to start chatting with $otherUserName.',
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

                  if (_searchQuery.isNotEmpty && displayedMessages.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 48,
                              color: context.convoColors.textTertiary,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'No matching messages',
                              style: AppTypography.titleMedium.copyWith(
                                color: context.convoColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'No results found for "$_searchQuery"',
                              style: AppTypography.bodySmall.copyWith(
                                color: context.convoColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final bool showLoadingMore = paginatedState.isLoadingMore;
                  final bool showRetry =
                      paginatedState.error != null && paginatedState.hasMore;
                  final int extraCount =
                      (showLoadingMore || showRetry) ? 1 : 0;

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    itemCount: displayedMessages.length + extraCount,
                    itemBuilder: (context, index) {
                      if (index == displayedMessages.length) {
                        if (showLoadingMore) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: AppSpacing.md,
                            ),
                            child: Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          );
                        }
                        if (showRetry) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.sm,
                            ),
                            child: Center(
                              child: TextButton.icon(
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  size: 16,
                                ),
                                label: const Text(
                                  'Tap to retry loading older messages',
                                  style: TextStyle(fontSize: 12),
                                ),
                                onPressed: () {
                                  ref
                                      .read(
                                        conversationPaginatedMessagesProvider(
                                          widget.conversationId,
                                        ).notifier,
                                      )
                                      .loadMore();
                                },
                              ),
                            ),
                          );
                        }
                      }

                      final message = displayedMessages[index];
                      final isMe = message.senderId == currentUserId;
                      final showSenderName =
                          isGroup &&
                          !isMe &&
                          (index == displayedMessages.length - 1 ||
                              displayedMessages[index + 1].senderId !=
                                  message.senderId);

                      final bool showDateHeader;
                      if (index == displayedMessages.length - 1) {
                        showDateHeader = true;
                      } else {
                        final previousMessage = displayedMessages[index + 1];
                        showDateHeader =
                            message.createdAt.day !=
                                previousMessage.createdAt.day ||
                            message.createdAt.month !=
                                previousMessage.createdAt.month ||
                            message.createdAt.year !=
                                previousMessage.createdAt.year;
                      }

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (showDateHeader)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.convoColors.surfaceSubtle,
                                    borderRadius: AppRadius.borderPill,
                                  ),
                                  child: Text(
                                    DateFormatter.formatChatDateDivider(
                                      message.createdAt,
                                    ),
                                    style: AppTypography.labelSmall.copyWith(
                                      color: context.convoColors.textTertiary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          MessageBubble(
                            message: message,
                            isMe: isMe,
                            currentUserId: currentUserId,
                            showSenderName: showSenderName,
                            isStarred: starredMessageIds.contains(message.id),
                            isSelected:
                                _selectedMessageIds.contains(message.id),
                            isSelectionMode: _isSelectionMode,
                            onToggleSelect: () =>
                                _toggleMessageSelection(message),
                            onSelectMessage: () =>
                                _startSelectionWith(message),
                            onToggleStar: () => _toggleStarMessage(message),
                            onReplyTap: (replyId) =>
                                _jumpToMessage(replyId, messages),
                            onDeleteForMe: () => ref
                                .read(chatControllerProvider.notifier)
                                .deleteMessageForMe(
                                  conversationId: widget.conversationId,
                                  messageId: message.id,
                                ),
                            onDeleteForEveryone: isMe
                                ? () => ref
                                    .read(chatControllerProvider.notifier)
                                    .deleteMessageForEveryone(
                                      conversationId: widget.conversationId,
                                      messageId: message.id,
                                    )
                                : null,
                            onReply: () {
                              ref
                                  .read(replyingMessageProvider.notifier)
                                  .setMessage(message);
                            },
                            onReact: (emoji) {
                              ref
                                  .read(chatControllerProvider.notifier)
                                  .toggleReaction(
                                    conversationId: widget.conversationId,
                                    messageId: message.id,
                                    emoji: emoji,
                                  );
                            },
                            onDelete: () {
                              ref
                                  .read(chatControllerProvider.notifier)
                                  .deleteMessageForMe(
                                    conversationId: widget.conversationId,
                                    messageId: message.id,
                                  );
                            },
                            onForward: () =>
                                ForwardMessageSheet.show(context, message),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),

            // Floating Typing Indicator Pill
            if (typingUsers.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: 4,
                ),
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.convoColors.surfaceSubtle,
                    borderRadius: AppRadius.borderPill,
                    border: Border.all(
                      color: context.convoColors.cardBorder,
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${typingUsers.join(', ')} typing...',
                        style: AppTypography.labelSmall.copyWith(
                          color: context.colorScheme.primary,
                          fontStyle: FontStyle.italic,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Replying Quote Banner
            if (replyingMessage != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xs,
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
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 32,
                      decoration: BoxDecoration(
                        color: context.colorScheme.primary,
                        borderRadius: AppRadius.borderPill,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            replyingMessage.senderId == currentUserId
                                ? 'Replying to Yourself'
                                : 'Replying to ${replyingMessage.senderName ?? otherUserName}',
                            style: AppTypography.labelSmall.copyWith(
                              color: context.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            replyingMessage.isMedia
                                ? '[${replyingMessage.type.toUpperCase()}]'
                                : replyingMessage.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySmall.copyWith(
                              color: context.convoColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        ref.read(replyingMessageProvider.notifier).clear();
                      },
                    ),
                  ],
                ),
              ),

            // Blocked Banner OR Voice Effect Preview Bar OR Voice Recording Bar OR Normal Composer
            if (isBlockedByMe)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                color: context.convoColors.surfaceSubtle,
                child: Row(
                  children: [
                    const Icon(
                      Icons.block_rounded,
                      color: AppColors.error,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'You have blocked this contact.',
                        style: AppTypography.bodySmall.copyWith(
                          color: context.convoColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        await ref
                            .read(profileControllerProvider.notifier)
                            .unblockUser(otherUserId);
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Contact unblocked.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: const Text('Unblock'),
                    ),
                  ],
                ),
              )
            else if (_recordedVoicePath != null)
              VoiceEffectPreviewBar(
                filePath: _recordedVoicePath!,
                durationSeconds: _recordedVoiceDuration,
                onDiscard: () {
                  setState(() {
                    _recordedVoicePath = null;
                    _recordedVoiceDuration = 0;
                  });
                },
                onSend: (path, effect) async {
                  await _uploadAndSendVoiceMessage(
                    path,
                    otherUserId,
                    effect,
                    conversation,
                  );
                  setState(() {
                    _recordedVoicePath = null;
                    _recordedVoiceDuration = 0;
                  });
                },
              )
            else if (_isRecording)
              _buildRecordingBar(otherUserId)
            else
              _buildNormalComposer(otherUserId, otherUserName, conversation),

            // Emoji Picker Drawer
            if (_showEmojiPicker)
              ConvoEmojiPicker(
                onEmojiSelected: (emoji) {
                  _textController.text = '${_textController.text}$emoji';
                  _textController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _textController.text.length),
                  );
                },
                onBackspace: () {
                  final text = _textController.text;
                  if (text.isNotEmpty) {
                    _textController.text = text.characters.skipLast(1).string;
                    _textController.selection = TextSelection.fromPosition(
                      TextPosition(offset: _textController.text.length),
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingBar(String otherUserId) {
    final minutes = (_recordingSeconds ~/ 60).toString();
    final seconds = (_recordingSeconds % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.convoColors.cardBackground,
        border: Border(
          top: BorderSide(color: context.convoColors.cardBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Blinking red recording indicator
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: AppColors.error,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          Text(
            '$minutes:$seconds',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.error,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          const Expanded(
            child: Text(
              'Recording voice message...',
              style: TextStyle(fontSize: 12),
            ),
          ),

          // Cancel Recording button
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.error,
            ),
            tooltip: 'Cancel',
            onPressed: _cancelVoiceRecording,
          ),

          // Review with Effects button
          Container(
            decoration: BoxDecoration(
              gradient: AppColors.meshGradient,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 20,
              ),
              tooltip: 'Review with Voice Effects',
              onPressed: _finishVoiceRecording,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNormalComposer(
    String otherUserId,
    String otherUserName,
    ConversationModel conversation,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: context.convoColors.cardBackground,
        border: Border(
          top: BorderSide(color: context.convoColors.cardBorder, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Emoji Button
          IconButton(
            icon: Icon(
              _showEmojiPicker
                  ? Icons.keyboard_rounded
                  : Icons.sentiment_satisfied_alt_rounded,
              color: _showEmojiPicker
                  ? context.colorScheme.primary
                  : context.convoColors.textTertiary,
              size: 24,
            ),
            tooltip: 'Emoji',
            onPressed: _toggleEmojiPicker,
          ),

          // Attachment Button
          IconButton(
            icon: Icon(
              Icons.attach_file_rounded,
              color: context.colorScheme.primary,
              size: 24,
            ),
            tooltip: 'Add attachment',
            onPressed: () =>
                _showAttachmentOptions(otherUserId, conversation),
          ),

          // Chat Magic Hub Button
          IconButton(
            icon: const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.primary,
              size: 24,
            ),
            tooltip: 'Chat Magic',
            onPressed: () =>
                _openChatMagic(otherUserId, otherUserName, conversation),
          ),

          // Text Input Field
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: context.convoColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: context.convoColors.cardBorder,
                  width: 1,
                ),
              ),
              child: TextField(
                focusNode: _focusNode,
                controller: _textController,
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Message...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                  isDense: true,
                ),
              ),
            ),
          ),

          const SizedBox(width: AppSpacing.xs),

          // Send Button (when text entered) OR Microphone (when empty)
          if (_canSend)
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                gradient: AppColors.meshGradient,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.send_rounded,
                  size: 20,
                  color: Colors.white,
                ),
                onPressed: () => _handleSendMessage(
                  otherUserId,
                  otherUserName,
                  conversation,
                ),
              ),
            )
          else
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: context.colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  Icons.mic_rounded,
                  size: 22,
                  color: context.colorScheme.primary,
                ),
                tooltip: 'Hold or tap to record voice message',
                onPressed: _startVoiceRecording,
              ),
            ),
        ],
      ),
    );
  }
}

class _AttachmentOptionTile extends StatelessWidget {
  const _AttachmentOptionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.borderMd,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: AppTypography.labelMedium.copyWith(
                color: context.convoColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
