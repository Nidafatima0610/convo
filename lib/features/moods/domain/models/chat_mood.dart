import 'package:flutter/material.dart';

enum ChatMoodType {
  love,
  funny,
  emotional,
  angry,
  celebration,
  chill,
  custom;

  static ChatMoodType fromString(String? val) {
    switch (val) {
      case 'love':
        return ChatMoodType.love;
      case 'funny':
        return ChatMoodType.funny;
      case 'emotional':
        return ChatMoodType.emotional;
      case 'angry':
        return ChatMoodType.angry;
      case 'celebration':
        return ChatMoodType.celebration;
      case 'chill':
        return ChatMoodType.chill;
      case 'custom':
        return ChatMoodType.custom;
      default:
        return ChatMoodType.chill;
    }
  }

  String toValue() => name;
}

class ChatMood {
  const ChatMood({
    required this.type,
    required this.emoji,
    required this.label,
    required this.colorHex,
    this.customText,
    this.setByUserId,
    this.setByName,
    required this.setAt,
  });

  final ChatMoodType type;
  final String emoji;
  final String label;
  final String colorHex;
  final String? customText;
  final String? setByUserId;
  final String? setByName;
  final DateTime setAt;

  Color get color {
    try {
      final hex = colorHex.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF5B4DFF);
    }
  }

  static const List<ChatMoodPreset> presets = [
    ChatMoodPreset(
      type: ChatMoodType.love,
      emoji: '❤️',
      label: 'Love',
      colorHex: 'FF4B72',
      tagline: 'Romantic, warm & sweet feelings',
    ),
    ChatMoodPreset(
      type: ChatMoodType.funny,
      emoji: '😂',
      label: 'Funny',
      colorHex: 'FFB020',
      tagline: 'Laughs, jokes & meme territory',
    ),
    ChatMoodPreset(
      type: ChatMoodType.emotional,
      emoji: '🥹',
      label: 'Emotional',
      colorHex: '8B5CF6',
      tagline: 'Deep talks, support & heart-to-hearts',
    ),
    ChatMoodPreset(
      type: ChatMoodType.angry,
      emoji: '😡',
      label: 'Venting',
      colorHex: 'EF4444',
      tagline: 'Spilling tea, ranting & blowing off steam',
    ),
    ChatMoodPreset(
      type: ChatMoodType.celebration,
      emoji: '🎉',
      label: 'Celebration',
      colorHex: '10B981',
      tagline: 'Good news, milestones & party time',
    ),
    ChatMoodPreset(
      type: ChatMoodType.chill,
      emoji: '😎',
      label: 'Chill',
      colorHex: '06B6D4',
      tagline: 'Casual banter & relaxing vibes',
    ),
    ChatMoodPreset(
      type: ChatMoodType.custom,
      emoji: '✨',
      label: 'Custom Vibe',
      colorHex: '5B4DFF',
      tagline: 'Craft your own unique chat atmosphere',
    ),
  ];

  Map<String, dynamic> toMap() {
    return {
      'type': type.toValue(),
      'emoji': emoji,
      'label': label,
      'colorHex': colorHex,
      'customText': customText,
      'setByUserId': setByUserId,
      'setByName': setByName,
      'setAt': setAt.toIso8601String(),
    };
  }

  factory ChatMood.fromMap(Map<String, dynamic> map) {
    return ChatMood(
      type: ChatMoodType.fromString(map['type'] as String?),
      emoji: map['emoji'] as String? ?? '✨',
      label: map['label'] as String? ?? 'Chill',
      colorHex: map['colorHex'] as String? ?? '5B4DFF',
      customText: map['customText'] as String?,
      setByUserId: map['setByUserId'] as String?,
      setByName: map['setByName'] as String?,
      setAt: DateTime.tryParse(map['setAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class ChatMoodPreset {
  const ChatMoodPreset({
    required this.type,
    required this.emoji,
    required this.label,
    required this.colorHex,
    required this.tagline,
  });

  final ChatMoodType type;
  final String emoji;
  final String label;
  final String colorHex;
  final String tagline;
}
