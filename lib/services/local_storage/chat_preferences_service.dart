import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/chats/domain/models/message_model.dart';

class StarredMessageItem {
  const StarredMessageItem({
    required this.messageId,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.type,
    this.mediaUrl,
    this.thumbnailUrl,
    this.fileName,
    required this.createdAt,
    this.conversationName,
  });

  final String messageId;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String text;
  final String type;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final String? fileName;
  final DateTime createdAt;
  final String? conversationName;

  bool get isMedia => type == 'image' || type == 'video' || type == 'voice' || type == 'file';
  bool get isImage => type == 'image';
  bool get isVideo => type == 'video';
  bool get isVoice => type == 'voice';
  bool get isFile => type == 'file';

  Map<String, dynamic> toMap() => {
        'messageId': messageId,
        'conversationId': conversationId,
        'senderId': senderId,
        'senderName': senderName,
        'text': text,
        'type': type,
        'mediaUrl': mediaUrl,
        'thumbnailUrl': thumbnailUrl,
        'fileName': fileName,
        'createdAt': createdAt.toIso8601String(),
        'conversationName': conversationName,
      };

  factory StarredMessageItem.fromMap(Map<String, dynamic> map) => StarredMessageItem(
        messageId: map['messageId'] as String? ?? '',
        conversationId: map['conversationId'] as String? ?? '',
        senderId: map['senderId'] as String? ?? '',
        senderName: map['senderName'] as String? ?? 'CONVO User',
        text: map['text'] as String? ?? '',
        type: map['type'] as String? ?? 'text',
        mediaUrl: map['mediaUrl'] as String?,
        thumbnailUrl: map['thumbnailUrl'] as String?,
        fileName: map['fileName'] as String?,
        createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
        conversationName: map['conversationName'] as String?,
      );

  factory StarredMessageItem.fromMessage(MessageModel message, {String? conversationName}) =>
      StarredMessageItem(
        messageId: message.id,
        conversationId: message.conversationId,
        senderId: message.senderId,
        senderName: message.senderName ?? 'CONVO User',
        text: message.text,
        type: message.type,
        mediaUrl: message.mediaUrl,
        thumbnailUrl: message.thumbnailUrl,
        fileName: message.fileName,
        createdAt: message.createdAt,
        conversationName: conversationName,
      );
}

class ChatPreferencesService {
  ChatPreferencesService([this._prefs]);

  final SharedPreferences? _prefs;

  static const String _keyPinnedChats = 'convo_pinned_chats';
  static const String _keyArchivedChats = 'convo_archived_chats';
  static const String _keyStarredMessages = 'convo_starred_messages';
  static const String _keyDeletedForMe = 'convo_deleted_for_me';

  // --- Pinned Chats ---
  Set<String> getPinnedChatIds() {
    if (_prefs == null) return {};
    final list = _prefs.getStringList(_keyPinnedChats) ?? [];
    return list.toSet();
  }

  Future<void> togglePinChat(String conversationId) async {
    if (_prefs == null) return;
    final set = getPinnedChatIds();
    if (set.contains(conversationId)) {
      set.remove(conversationId);
    } else {
      set.add(conversationId);
    }
    await _prefs.setStringList(_keyPinnedChats, set.toList());
  }

  Future<void> unpinChat(String conversationId) async {
    if (_prefs == null) return;
    final set = getPinnedChatIds();
    set.remove(conversationId);
    await _prefs.setStringList(_keyPinnedChats, set.toList());
  }

  bool isChatPinned(String conversationId) {
    return getPinnedChatIds().contains(conversationId);
  }

  // --- Archived Chats ---
  Set<String> getArchivedChatIds() {
    if (_prefs == null) return {};
    final list = _prefs.getStringList(_keyArchivedChats) ?? [];
    return list.toSet();
  }

  Future<void> toggleArchiveChat(String conversationId) async {
    if (_prefs == null) return;
    final set = getArchivedChatIds();
    if (set.contains(conversationId)) {
      set.remove(conversationId);
    } else {
      set.add(conversationId);
    }
    await _prefs.setStringList(_keyArchivedChats, set.toList());
  }

  Future<void> unarchiveChat(String conversationId) async {
    if (_prefs == null) return;
    final set = getArchivedChatIds();
    set.remove(conversationId);
    await _prefs.setStringList(_keyArchivedChats, set.toList());
  }

  bool isChatArchived(String conversationId) {
    return getArchivedChatIds().contains(conversationId);
  }

  // --- Deleted / Hidden Chats (UI-Level deletion) ---
  static const String _keyDeletedChats = 'convo_deleted_chats';

  Set<String> getDeletedChatIds() {
    if (_prefs == null) return {};
    final list = _prefs.getStringList(_keyDeletedChats) ?? [];
    return list.toSet();
  }

  Future<void> deleteChat(String conversationId) async {
    if (_prefs == null) return;
    final set = getDeletedChatIds();
    set.add(conversationId);
    await _prefs.setStringList(_keyDeletedChats, set.toList());
  }

  Future<void> restoreChat(String conversationId) async {
    if (_prefs == null) return;
    final set = getDeletedChatIds();
    set.remove(conversationId);
    await _prefs.setStringList(_keyDeletedChats, set.toList());
  }

  // --- Starred Messages ---
  List<StarredMessageItem> getStarredMessages() {
    if (_prefs == null) return [];
    final raw = _prefs.getStringList(_keyStarredMessages) ?? [];
    return raw.map((jsonStr) {
      try {
        final decoded = jsonDecode(jsonStr);
        return StarredMessageItem.fromMap(Map<String, dynamic>.from(decoded as Map));
      } catch (_) {
        return null;
      }
    }).whereType<StarredMessageItem>().toList();
  }

  bool isMessageStarred(String messageId) {
    return getStarredMessages().any((m) => m.messageId == messageId);
  }

  Future<bool> toggleStarMessage(MessageModel message, {String? conversationName}) async {
    if (_prefs == null) return false;
    final current = getStarredMessages();
    final index = current.indexWhere((m) => m.messageId == message.id);
    bool isNowStarred = false;

    if (index >= 0) {
      current.removeAt(index);
      isNowStarred = false;
    } else {
      current.add(StarredMessageItem.fromMessage(message, conversationName: conversationName));
      isNowStarred = true;
    }

    final rawList = current.map((m) => jsonEncode(m.toMap())).toList();
    await _prefs.setStringList(_keyStarredMessages, rawList);
    return isNowStarred;
  }

  Future<void> unstarMessage(String messageId) async {
    if (_prefs == null) return;
    final current = getStarredMessages();
    current.removeWhere((m) => m.messageId == messageId);
    final rawList = current.map((m) => jsonEncode(m.toMap())).toList();
    await _prefs.setStringList(_keyStarredMessages, rawList);
  }

  // --- Deleted For Me Messages ---
  Set<String> getDeletedForMeMessageIds() {
    if (_prefs == null) return {};
    final list = _prefs.getStringList(_keyDeletedForMe) ?? [];
    return list.toSet();
  }

  Future<void> markMessageDeletedForMe(String messageId) async {
    if (_prefs == null) return;
    final set = getDeletedForMeMessageIds();
    set.add(messageId);
    await _prefs.setStringList(_keyDeletedForMe, set.toList());
  }

  bool isMessageDeletedForMe(String messageId) {
    return getDeletedForMeMessageIds().contains(messageId);
  }
}

SharedPreferences? _globalPrefs;

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  if (_globalPrefs != null) return _globalPrefs!;
  throw UnimplementedError('Initialize sharedPreferencesProvider in main');
});

void setGlobalSharedPreferences(SharedPreferences prefs) {
  _globalPrefs = prefs;
}

final chatPreferencesServiceProvider = Provider<ChatPreferencesService>((ref) {
  try {
    final prefs = ref.watch(sharedPreferencesProvider);
    return ChatPreferencesService(prefs);
  } catch (_) {
    return ChatPreferencesService(null);
  }
});

final pinnedChatIdsProvider =
    NotifierProvider<PinnedChatIdsNotifier, Set<String>>(PinnedChatIdsNotifier.new);

class PinnedChatIdsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    final service = ref.watch(chatPreferencesServiceProvider);
    return service.getPinnedChatIds();
  }

  Future<void> togglePin(String conversationId) async {
    final service = ref.read(chatPreferencesServiceProvider);
    await service.togglePinChat(conversationId);
    state = service.getPinnedChatIds();
  }

  Future<void> unpin(String conversationId) async {
    final service = ref.read(chatPreferencesServiceProvider);
    await service.unpinChat(conversationId);
    state = service.getPinnedChatIds();
  }
}

final archivedChatIdsProvider =
    NotifierProvider<ArchivedChatIdsNotifier, Set<String>>(ArchivedChatIdsNotifier.new);

class ArchivedChatIdsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    final service = ref.watch(chatPreferencesServiceProvider);
    return service.getArchivedChatIds();
  }

  Future<void> toggleArchive(String conversationId) async {
    final service = ref.read(chatPreferencesServiceProvider);
    await service.toggleArchiveChat(conversationId);
    state = service.getArchivedChatIds();
  }

  Future<void> unarchive(String conversationId) async {
    final service = ref.read(chatPreferencesServiceProvider);
    await service.unarchiveChat(conversationId);
    state = service.getArchivedChatIds();
  }
}

final deletedChatIdsProvider =
    NotifierProvider<DeletedChatIdsNotifier, Set<String>>(DeletedChatIdsNotifier.new);

class DeletedChatIdsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    final service = ref.watch(chatPreferencesServiceProvider);
    return service.getDeletedChatIds();
  }

  Future<void> deleteChat(String conversationId) async {
    final service = ref.read(chatPreferencesServiceProvider);
    await service.deleteChat(conversationId);
    state = service.getDeletedChatIds();
  }

  Future<void> restoreChat(String conversationId) async {
    final service = ref.read(chatPreferencesServiceProvider);
    await service.restoreChat(conversationId);
    state = service.getDeletedChatIds();
  }
}

final starredMessagesProvider =
    NotifierProvider<StarredMessagesNotifier, List<StarredMessageItem>>(StarredMessagesNotifier.new);

class StarredMessagesNotifier extends Notifier<List<StarredMessageItem>> {
  @override
  List<StarredMessageItem> build() {
    final service = ref.watch(chatPreferencesServiceProvider);
    return service.getStarredMessages();
  }

  Future<bool> toggleStar(MessageModel message, {String? conversationName}) async {
    final service = ref.read(chatPreferencesServiceProvider);
    final result = await service.toggleStarMessage(message, conversationName: conversationName);
    state = service.getStarredMessages();
    return result;
  }

  Future<void> unstar(String messageId) async {
    final service = ref.read(chatPreferencesServiceProvider);
    await service.unstarMessage(messageId);
    state = service.getStarredMessages();
  }
}
