import 'package:flutter_riverpod/flutter_riverpod.dart';

enum EntitlementTier {
  free,
  pro,
  creator;

  bool get isProOrAbove =>
      this == EntitlementTier.pro || this == EntitlementTier.creator;
  bool get isCreator => this == EntitlementTier.creator;
}

class EntitlementLimits {
  const EntitlementLimits({
    required this.maxCustomStickers,
    required this.maxActiveCapsules,
    required this.allowedVoiceEffects,
    required this.allowCustomMoods,
    required this.allowAdvancedReactions,
  });

  final int maxCustomStickers;
  final int maxActiveCapsules;
  final List<String> allowedVoiceEffects;
  final bool allowCustomMoods;
  final bool allowAdvancedReactions;

  static const free = EntitlementLimits(
    maxCustomStickers: 25,
    maxActiveCapsules: 10,
    allowedVoiceEffects: ['normal', 'robot', 'deep', 'funny', 'echo'],
    allowCustomMoods: true,
    allowAdvancedReactions: true,
  );

  static const pro = EntitlementLimits(
    maxCustomStickers: 200,
    maxActiveCapsules: 50,
    allowedVoiceEffects: [
      'normal',
      'robot',
      'deep',
      'funny',
      'echo',
      'fast',
      'whisper',
      'chipmunk',
    ],
    allowCustomMoods: true,
    allowAdvancedReactions: true,
  );
}

class EntitlementService {
  EntitlementService({this.currentTier = EntitlementTier.free});

  final EntitlementTier currentTier;

  EntitlementLimits get limits {
    switch (currentTier) {
      case EntitlementTier.creator:
      case EntitlementTier.pro:
        return EntitlementLimits.pro;
      case EntitlementTier.free:
        return EntitlementLimits.free;
    }
  }

  bool canCreateSticker(int currentStickerCount) =>
      currentStickerCount < limits.maxCustomStickers;

  bool canCreateCapsule(int currentCapsuleCount) =>
      currentCapsuleCount < limits.maxActiveCapsules;

  bool isVoiceEffectAllowed(String effectId) =>
      limits.allowedVoiceEffects.contains(effectId.toLowerCase());
}

final entitlementServiceProvider = Provider<EntitlementService>((ref) {
  return EntitlementService(currentTier: EntitlementTier.free);
});
