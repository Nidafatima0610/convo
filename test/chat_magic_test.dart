import 'package:flutter_test/flutter_test.dart';
import 'package:convo/features/stickers/domain/models/sticker_model.dart';
import 'package:convo/features/stickers/data/sticker_storage_service.dart';
import 'package:convo/features/moods/domain/models/chat_mood.dart';
import 'package:convo/features/games/domain/models/game_model.dart';
import 'package:convo/features/capsules/domain/models/capsule_model.dart';
import 'package:convo/features/chats/domain/models/message_model.dart';
import 'package:convo/services/entitlements/entitlement_service.dart';

void main() {
  group('Chat Magic - Sticker Studio & Storage', () {
    test('StickerModel serializes and deserializes properly', () {
      final sticker = StickerModel(
        id: 'stk_001',
        creatorId: 'user_123',
        name: 'Vibes Only',
        imagePath: 'custom:✨:Vibes:0:0',
        createdAt: DateTime(2026, 1, 1),
        packId: 'pack_vibes',
        packName: 'Vibe Pack',
      );

      final map = sticker.toMap();
      final restored = StickerModel.fromMap(map);

      expect(restored.id, 'stk_001');
      expect(restored.creatorId, 'user_123');
      expect(restored.name, 'Vibes Only');
      expect(restored.packId, 'pack_vibes');
    });

    test('StickerStorageService provides starter stickers', () {
      final storage = StickerStorageService();
      final starters = storage.starterPacks;
      expect(starters.isNotEmpty, isTrue);
      expect(starters.any((s) => s.packId == 'pack_convo_official'), isTrue);
    });
  });

  group('Chat Magic - Chat Moods', () {
    test('ChatMood provides all 7 required moods with distinct emojis', () {
      expect(ChatMood.presets.length, 7);
      final emojis = ChatMood.presets.map((p) => p.emoji).toList();
      expect(emojis, contains('❤️'));
      expect(emojis, contains('😂'));
      expect(emojis, contains('🥹'));
      expect(emojis, contains('😡'));
      expect(emojis, contains('🎉'));
      expect(emojis, contains('😎'));
      expect(emojis, contains('✨'));
    });

    test('ChatMoodType maps to and from string safely', () {
      final love = ChatMoodType.fromString('love');
      expect(love, ChatMoodType.love);

      final unknown = ChatMoodType.fromString('nonexistent');
      expect(unknown, ChatMoodType.chill);
    });
  });

  group('Chat Magic - Chat Games', () {
    test('GameModel handles answers from multiple users correctly', () {
      final game = GameModel(
        id: 'game_001',
        gameType: GameType.wouldYouRather,
        title: 'Superpower Dilemma',
        question: 'Fly or Read Minds?',
        options: ['Fly', 'Read Minds'],
        creatorId: 'user_a',
        creatorName: 'Alice',
      );

      expect(game.isAnsweredBy('user_a'), isFalse);
      expect(game.isAnsweredBy('user_b'), isFalse);

      final updatedA = game.copyWith(
        answers: {...game.answers, 'user_a': 'Fly'},
      );
      expect(updatedA.isAnsweredBy('user_a'), isTrue);
      expect(updatedA.answerOf('user_a'), 'Fly');

      final updatedB = updatedA.copyWith(
        answers: {...updatedA.answers, 'user_b': 'Read Minds'},
      );
      expect(updatedB.isAnsweredBy('user_b'), isTrue);
      expect(updatedB.answerOf('user_b'), 'Read Minds');
      expect(updatedB.answers.length, 2);
    });

    test('GameModel preset templates exist for all game types', () {
      final templates = GameModel.getPresetTemplates();
      expect(templates.isNotEmpty, isTrue);
      for (final type in GameType.values) {
        expect(templates.any((t) => t.gameType == type), isTrue);
      }
    });
  });

  group('Chat Magic - Message Capsule', () {
    test('Capsule calculates status and countdown string correctly', () {
      final now = DateTime.now();
      final futureTime = now.add(const Duration(hours: 2, minutes: 30));

      final capsule = CapsuleModel(
        id: 'cap_001',
        conversationId: 'conv_123',
        senderId: 'user_a',
        senderName: 'Alice',
        receiverId: 'user_b',
        receiverName: 'Bob',
        message: 'Happy Birthday in advance!',
        createdAt: now,
        unlockAt: futureTime,
        status: CapsuleStatus.locked,
      );

      expect(capsule.isLocked, isTrue);
      expect(capsule.isUnlocked, isFalse);
      expect(capsule.countdownString.contains('remaining'), isTrue);

      final readyCapsule = capsule.copyWith(
        unlockAt: now.subtract(const Duration(seconds: 10)),
      );
      expect(readyCapsule.isUnlocked, isTrue);
      expect(readyCapsule.countdownString, 'Ready to open!');
    });
  });

  group('Chat Magic - Secret / Disappearing Chat', () {
    test('MessageModel detects expired status for secret messages', () {
      final now = DateTime.now();

      final nonSecretMsg = MessageModel(
        id: 'msg_001',
        conversationId: 'conv_123',
        senderId: 'user_a',
        receiverId: 'user_b',
        text: 'Normal message',
        createdAt: now,
      );
      expect(nonSecretMsg.isExpired, isFalse);
      expect(nonSecretMsg.isSecret, isFalse);

      final activeSecretMsg = MessageModel(
        id: 'msg_002',
        conversationId: 'conv_123',
        senderId: 'user_a',
        receiverId: 'user_b',
        text: 'Self destruct in 5 min',
        createdAt: now,
        expiresAt: now.add(const Duration(minutes: 5)),
        isSecret: true,
      );
      expect(activeSecretMsg.isSecret, isTrue);
      expect(activeSecretMsg.isExpired, isFalse);

      final expiredSecretMsg = MessageModel(
        id: 'msg_003',
        conversationId: 'conv_123',
        senderId: 'user_a',
        receiverId: 'user_b',
        text: 'Gone message',
        createdAt: now.subtract(const Duration(minutes: 10)),
        expiresAt: now.subtract(const Duration(minutes: 5)),
        isSecret: true,
      );
      expect(expiredSecretMsg.isSecret, isTrue);
      expect(expiredSecretMsg.isExpired, isTrue);
    });
  });

  group('Chat Magic - Premium Entitlements Layer', () {
    test('Free tier allows basic chat magic features without paywall', () {
      final freeService = EntitlementService(currentTier: EntitlementTier.free);
      expect(freeService.limits.maxCustomStickers, 25);
      expect(freeService.limits.maxActiveCapsules, 10);
      expect(freeService.limits.allowCustomMoods, isTrue);
      expect(freeService.limits.allowAdvancedReactions, isTrue);
      expect(freeService.limits.allowedVoiceEffects, contains('echo'));
    });

    test('EntitlementService cleanly distinguishes Pro limits', () {
      final proService = EntitlementService(currentTier: EntitlementTier.pro);
      expect(proService.limits.maxActiveCapsules, 50);
      expect(proService.limits.maxCustomStickers, 200);
      expect(proService.currentTier.isProOrAbove, isTrue);
    });
  });
}
