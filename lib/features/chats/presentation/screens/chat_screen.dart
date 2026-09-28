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
import '../providers/chat_providers.dart';
import '../widgets/chat_magic_sheet.dart';
import '../widgets/convo_emoji_picker.dart';
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

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);

    // Mark conversation as read on screen entry
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(chatControllerProvider.notifier)
          .markAsRead(widget.conversationId);
    });
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _textController.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus && _showEmojiPicker) {
      setState(() => _showEmojiPicker = false);
    }
  }

  void _onTextChanged() {
    final canSend = _textController.text.trim().isNotEmpty;
    if (canSend != _canSend) {
      setState(() => _canSend = canSend);
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

    await ref
        .read(chatControllerProvider.notifier)
        .sendMessage(
          conversationId: widget.conversationId,
          receiverId: receiverId,
          text: text,
          replyToMessageId: replyingMessage?.id,
          replyToSnippet: replyingMessage?.text,
          replyToSenderName: replyingMessage?.senderId == receiverId
              ? receiverName
              : 'You',
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
    final mediaService = ref.read(mediaServiceProvider);

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
              receiverId: otherUserId,
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
              onCapsuleCreated: (capsule) => _sendCapsule(capsule, otherUserId),
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

    await ref
        .read(chatControllerProvider.notifier)
        .sendMessage(
          conversationId: widget.conversationId,
          receiverId: otherUserId,
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

    await ref
        .read(chatControllerProvider.notifier)
        .sendMessage(
          conversationId: widget.conversationId,
          receiverId: otherUserId,
          text: '🎲 ${game.title}: ${game.question}',
          type: 'game',
          metadata: {'game': game.toMap()},
          expiresAt: expiresAt,
          isSecret: isSecret,
        );
    _scrollToBottom();
  }

  Future<void> _sendCapsule(CapsuleModel capsule, String otherUserId) async {
    await ref
        .read(chatControllerProvider.notifier)
        .sendMessage(
          conversationId: widget.conversationId,
          receiverId: otherUserId,
          text: '⏳ Capsule: ${capsule.message}',
          type: 'capsule',
          metadata: {'capsule': capsule.toMap()},
        );
    _scrollToBottom();
  }

  // --- Image & Video Media Sharing ---

  void _showAttachmentOptions(String otherUserId) {
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
                      _pickAndSendImage(ImageSource.gallery, otherUserId);
                    },
                  ),
                  _AttachmentOptionTile(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    color: AppColors.accent,
                    onTap: () {
                      Navigator.of(modalContext).pop();
                      _pickAndSendImage(ImageSource.camera, otherUserId);
                    },
                  ),
                  _AttachmentOptionTile(
                    icon: Icons.videocam_rounded,
                    label: 'Video',
                    color: AppColors.blueGlow,
                    onTap: () {
                      Navigator.of(modalContext).pop();
                      _pickAndSendVideo(otherUserId);
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

  Future<void> _pickAndSendImage(ImageSource source, String otherUserId) async {
    final mediaService = ref.read(mediaServiceProvider);
    final file = await mediaService.pickImage(source: source);
    if (file == null) return;

    final currentUserId =
        ref.read(authStateChangesProvider).asData?.value?.uid ?? '';

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
              receiverId: otherUserId,
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

  Future<void> _pickAndSendVideo(String otherUserId) async {
    final mediaService = ref.read(mediaServiceProvider);
    final file = await mediaService.pickVideo();
    if (file == null) return;

    final currentUserId =
        ref.read(authStateChangesProvider).asData?.value?.uid ?? '';

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
              receiverId: otherUserId,
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
    final conversationsAsync = ref.watch(userConversationsProvider);
    final conversationList = conversationsAsync.asData?.value ?? [];
    final conversation =
        conversationList
            .where((c) => c.id == widget.conversationId)
            .firstOrNull ??
        ConversationModel(
          id: widget.conversationId,
          participants: widget.otherUser != null
              ? [currentUserId, widget.otherUser!.uid]
              : [],
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

    final otherUserId =
        widget.otherUser?.uid ?? conversation.otherParticipantId(currentUserId);
    final otherUserName =
        widget.otherUser?.name ??
        conversation.otherParticipantName(currentUserId);

    final otherUserObj =
        widget.otherUser ??
        ConvoUser(
          uid: otherUserId,
          name: otherUserName,
          email: conversation.otherParticipantEmail(currentUserId),
          photoUrl: conversation.otherParticipantPhoto(currentUserId),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

    // Live presence stream of other user
    final otherUserLive = ref
        .watch(userPresenceProvider(otherUserId))
        .asData
        ?.value;
    final isOnline =
        otherUserLive?.isOnline ?? widget.otherUser?.isOnline ?? false;

    // Check if other user is directly connected via CONVO Nearby Offline
    final nearbyService = ref.watch(nearbyServiceProvider);
    final isNearbyConnected = nearbyService.isConnectedToUser(otherUserId);

    final messagesAsync = ref.watch(
      conversationCombinedMessagesProvider(widget.conversationId),
    );
    final replyingMessage = ref.watch(replyingMessageProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: InkWell(
          onTap: () => _openChatDetails(otherUserObj),
          borderRadius: AppRadius.borderMd,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(
              children: [
                ConvoAvatar(
                  initials: otherUserName.isNotEmpty
                      ? (otherUserName.length >= 2
                            ? otherUserName.substring(0, 2).toUpperCase()
                            : otherUserName[0].toUpperCase())
                      : 'CO',
                  size: 38,
                  status: isNearbyConnected
                      ? ConvoAvatarStatus.online
                      : (isOnline
                            ? ConvoAvatarStatus.online
                            : ConvoAvatarStatus.offline),
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
                              style: AppTypography.titleMedium.copyWith(
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
                                    ? ChatMood.fromMap(conversation.mood!)
                                    : null,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: context.colorScheme.primary.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  conversation.moodEmoji!,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isNearbyConnected
                                  ? AppColors.accentPurple
                                  : (isOnline
                                        ? AppColors.success
                                        : Colors.grey),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isNearbyConnected
                                ? 'Nearby Peer'
                                : (isOnline ? 'Active now' : 'Offline'),
                            style: AppTypography.labelSmall.copyWith(
                              color: isNearbyConnected
                                  ? AppColors.accentPurple
                                  : (isOnline
                                        ? AppColors.success
                                        : context.convoColors.textTertiary),
                              fontSize: 11,
                              fontWeight: isNearbyConnected
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
            icon: const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.primary,
            ),
            tooltip: 'Chat Magic',
            onPressed: () =>
                _openChatMagic(otherUserId, otherUserName, conversation),
          ),
          IconButton(
            icon: const Icon(Icons.phone_outlined),
            tooltip: 'Voice Call',
            onPressed: () => _startCall(otherUserObj, isVideo: false),
          ),
          IconButton(
            icon: const Icon(Icons.videocam_outlined),
            tooltip: 'Video Call',
            onPressed: () => _startCall(otherUserObj, isVideo: true),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Conversation Info',
            onPressed: () => _openChatDetails(otherUserObj),
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
                              'Say Hello!',
                              style: AppTypography.headlineMedium.copyWith(
                                color: context.convoColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'No messages in this encrypted conversation yet.\nSend text, photos, videos or voice messages to start chatting with $otherUserName.',
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

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMe = message.senderId == currentUserId;

                      final bool showDateHeader;
                      if (index == messages.length - 1) {
                        showDateHeader = true;
                      } else {
                        final previousMessage = messages[index + 1];
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
                                  .deleteMessage(
                                    conversationId: widget.conversationId,
                                    messageId: message.id,
                                  );
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
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
                                : 'Replying to $otherUserName',
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

            // Voice Effect Preview Bar OR Voice Recording Bar OR Normal Composer
            if (_recordedVoicePath != null)
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
            onPressed: () => _showAttachmentOptions(otherUserId),
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
