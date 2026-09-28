import 'package:flutter/material.dart';

enum VoiceEffectType {
  normal,
  robot,
  deep,
  funny,
  echo;

  static VoiceEffectType fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'robot':
        return VoiceEffectType.robot;
      case 'deep':
        return VoiceEffectType.deep;
      case 'funny':
        return VoiceEffectType.funny;
      case 'echo':
        return VoiceEffectType.echo;
      case 'normal':
      default:
        return VoiceEffectType.normal;
    }
  }

  String toValue() => name;
}

class VoiceEffectPreset {
  const VoiceEffectPreset({
    required this.type,
    required this.name,
    required this.icon,
    required this.playbackSpeed,
    required this.pitchShiftSemitones,
    required this.description,
  });

  final VoiceEffectType type;
  final String name;
  final IconData icon;
  final double playbackSpeed;
  final int pitchShiftSemitones;
  final String description;

  static const List<VoiceEffectPreset> presets = [
    VoiceEffectPreset(
      type: VoiceEffectType.normal,
      name: 'Original',
      icon: Icons.mic_none_rounded,
      playbackSpeed: 1.0,
      pitchShiftSemitones: 0,
      description: 'Crystal clear unaltered voice audio',
    ),
    VoiceEffectPreset(
      type: VoiceEffectType.robot,
      name: 'Robot',
      icon: Icons.smart_toy_rounded,
      playbackSpeed: 1.05,
      pitchShiftSemitones: 2,
      description: 'Monotone futuristic modulation simulation',
    ),
    VoiceEffectPreset(
      type: VoiceEffectType.deep,
      name: 'Deep Voice',
      icon: Icons.graphic_eq_rounded,
      playbackSpeed: 0.85,
      pitchShiftSemitones: -4,
      description: 'Authoritative deep resonance pitch',
    ),
    VoiceEffectPreset(
      type: VoiceEffectType.funny,
      name: 'Funny / Chipmunk',
      icon: Icons.sentiment_very_satisfied_rounded,
      playbackSpeed: 1.35,
      pitchShiftSemitones: 6,
      description: 'High-pitch playful fast tempo',
    ),
    VoiceEffectPreset(
      type: VoiceEffectType.echo,
      name: 'Echo Chamber',
      icon: Icons.surround_sound_rounded,
      playbackSpeed: 0.95,
      pitchShiftSemitones: 0,
      description: 'Cathedral reverb & spatial reflections',
    ),
  ];
}
