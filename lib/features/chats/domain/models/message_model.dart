import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    required this.text,
    this.type = 'text',
    this.mediaUrl,
    this.thumbnailUrl,
    this.fileName,
    this.fileSize,
    this.durationMs,
    this.uploadStatus = 'success',
    required this.createdAt,
    this.isRead = false,
    this.readAt,
    this.replyToMessageId,
    this.replyToSnippet,
    this.replyToSenderName,
    this.reactions = const {},
    this.isDeleted = false,
    this.deletedAt,
    this.offlineOrigin = false,
    this.metadata,
    this.expiresAt,
    this.isSecret = false,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String receiverId;
  final String text;
  final String type;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final String? fileName;
  final int? fileSize;
  final int? durationMs;
  final String? uploadStatus; // 'uploading', 'success', 'failed'
  final DateTime createdAt;
  final bool isRead;
  final DateTime? readAt;
  final String? replyToMessageId;
  final String? replyToSnippet;
  final String? replyToSenderName;

  /// Maps userId -> emoji string (e.g., {'uid123': '❤️'})
  final Map<String, String> reactions;
  final bool isDeleted;
  final DateTime? deletedAt;
  final bool offlineOrigin;
  final Map<String, dynamic>? metadata;
  final DateTime? expiresAt;
  final bool isSecret;

  /// Type checks
  bool get isText => type == 'text';
  bool get isImage => type == 'image';
  bool get isVideo => type == 'video';
  bool get isVoice => type == 'voice';
  bool get isFile => type == 'file';
  bool get isSticker => type == 'sticker';
  bool get isGame => type == 'game';
  bool get isCapsule => type == 'capsule';
  bool get isMedia => isImage || isVideo || isVoice || isFile;
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  /// Returns true if this message is a reply to another message
  bool get isReply => replyToMessageId != null && replyToMessageId!.isNotEmpty;

  /// Counts the frequencies of each reaction emoji, e.g. {'❤️': 2, '👍': 1}
  Map<String, int> get reactionCounts {
    final counts = <String, int>{};
    for (final emoji in reactions.values) {
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }
    return counts;
  }

  /// Returns the emoji the given user reacted with, if any
  String? reactionOfUser(String userId) => reactions[userId];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'type': type,
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      if (fileName != null) 'fileName': fileName,
      if (fileSize != null) 'fileSize': fileSize,
      if (durationMs != null) 'durationMs': durationMs,
      if (uploadStatus != null) 'uploadStatus': uploadStatus,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
      if (readAt != null) 'readAt': Timestamp.fromDate(readAt!),
      if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
      if (replyToSnippet != null) 'replyToSnippet': replyToSnippet,
      if (replyToSenderName != null) 'replyToSenderName': replyToSenderName,
      'reactions': reactions,
      'isDeleted': isDeleted,
      if (deletedAt != null) 'deletedAt': Timestamp.fromDate(deletedAt!),
      'offlineOrigin': offlineOrigin,
      if (metadata != null) 'metadata': metadata,
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
      'isSecret': isSecret,
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      } else if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      return DateTime.now();
    }

    final rawReactions = map['reactions'];
    final reactions = <String, String>{};
    if (rawReactions is Map) {
      rawReactions.forEach((key, value) {
        reactions[key.toString()] = value.toString();
      });
    }

    return MessageModel(
      id: docId ?? map['id'] as String? ?? '',
      conversationId: map['conversationId'] as String? ?? '',
      senderId: map['senderId'] as String? ?? '',
      receiverId: map['receiverId'] as String? ?? '',
      text: map['text'] as String? ?? '',
      type: map['type'] as String? ?? 'text',
      mediaUrl: map['mediaUrl'] as String?,
      thumbnailUrl: map['thumbnailUrl'] as String?,
      fileName: map['fileName'] as String?,
      fileSize: map['fileSize'] as int?,
      durationMs: map['durationMs'] as int?,
      uploadStatus: map['uploadStatus'] as String? ?? 'success',
      createdAt: parseDate(map['createdAt']),
      isRead: map['isRead'] as bool? ?? false,
      readAt: map['readAt'] != null ? parseDate(map['readAt']) : null,
      replyToMessageId: map['replyToMessageId'] as String?,
      replyToSnippet: map['replyToSnippet'] as String?,
      replyToSenderName: map['replyToSenderName'] as String?,
      reactions: reactions,
      isDeleted: map['isDeleted'] as bool? ?? false,
      deletedAt: map['deletedAt'] != null ? parseDate(map['deletedAt']) : null,
      offlineOrigin: map['offlineOrigin'] as bool? ?? false,
      metadata: map['metadata'] is Map
          ? Map<String, dynamic>.from(map['metadata'] as Map)
          : null,
      expiresAt: map['expiresAt'] != null ? parseDate(map['expiresAt']) : null,
      isSecret: map['isSecret'] as bool? ?? false,
    );
  }

  factory MessageModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return MessageModel.fromMap(doc.data() ?? {}, docId: doc.id);
  }

  MessageModel copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? receiverId,
    String? text,
    String? type,
    String? mediaUrl,
    String? thumbnailUrl,
    String? fileName,
    int? fileSize,
    int? durationMs,
    String? uploadStatus,
    DateTime? createdAt,
    bool? isRead,
    DateTime? readAt,
    String? replyToMessageId,
    String? replyToSnippet,
    String? replyToSenderName,
    Map<String, String>? reactions,
    bool? isDeleted,
    DateTime? deletedAt,
    bool? offlineOrigin,
    Map<String, dynamic>? metadata,
    DateTime? expiresAt,
    bool? isSecret,
  }) {
    return MessageModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      text: text ?? this.text,
      type: type ?? this.type,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      durationMs: durationMs ?? this.durationMs,
      uploadStatus: uploadStatus ?? this.uploadStatus,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToSnippet: replyToSnippet ?? this.replyToSnippet,
      replyToSenderName: replyToSenderName ?? this.replyToSenderName,
      reactions: reactions ?? this.reactions,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      offlineOrigin: offlineOrigin ?? this.offlineOrigin,
      metadata: metadata ?? this.metadata,
      expiresAt: expiresAt ?? this.expiresAt,
      isSecret: isSecret ?? this.isSecret,
    );
  }
}
