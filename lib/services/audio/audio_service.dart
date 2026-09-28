import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class AudioService {
  AudioService() {
    _recorder = AudioRecorder();
    _player = AudioPlayer();
  }

  late final AudioRecorder _recorder;
  late final AudioPlayer _player;

  DateTime? _recordingStartTime;

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  Duration get recordingDuration {
    if (_recordingStartTime == null) return Duration.zero;
    return DateTime.now().difference(_recordingStartTime!);
  }

  /// Checks if microphone permission is granted.
  Future<bool> hasPermission() async {
    try {
      return await _recorder.hasPermission();
    } catch (e) {
      debugPrint('Error checking audio permission: $e');
      return false;
    }
  }

  /// Starts recording a voice message.
  Future<bool> startRecording() async {
    try {
      final hasPerm = await hasPermission();
      if (!hasPerm) return false;

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${tempDir.path}/convo_voice_$timestamp.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: filePath,
      );

      _recordingStartTime = DateTime.now();
      _isRecording = true;
      return true;
    } catch (e) {
      debugPrint('Error starting voice recording: $e');
      _isRecording = false;
      return false;
    }
  }

  /// Stops recording and returns the recorded file path along with the duration in milliseconds.
  Future<({String? path, int durationMs})> stopRecording() async {
    if (!_isRecording) return (path: null, durationMs: 0);

    try {
      final path = await _recorder.stop();
      final duration = recordingDuration.inMilliseconds;

      _isRecording = false;
      _recordingStartTime = null;

      return (path: path, durationMs: duration);
    } catch (e) {
      debugPrint('Error stopping voice recording: $e');
      _isRecording = false;
      _recordingStartTime = null;
      return (path: null, durationMs: 0);
    }
  }

  /// Cancels recording and deletes the temporary file.
  Future<void> cancelRecording() async {
    if (!_isRecording) return;

    try {
      final path = await _recorder.stop();
      _isRecording = false;
      _recordingStartTime = null;

      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      debugPrint('Error canceling voice recording: $e');
      _isRecording = false;
    }
  }

  Stream<PlayerState> get playerStateStream => _player.onPlayerStateChanged;
  bool isPlaying(String? url) => _player.state == PlayerState.playing;

  /// Plays a remote or local audio URL with state notifications and playback rate.
  Future<void> playAudio(
    String url, {
    VoidCallback? onComplete,
    ValueChanged<Duration>? onPositionChanged,
    ValueChanged<Duration>? onDurationChanged,
    double playbackRate = 1.0,
  }) async {
    try {
      await _player.stop();

      if (onComplete != null) {
        _player.onPlayerComplete.listen((_) => onComplete());
      }
      if (onPositionChanged != null) {
        _player.onPositionChanged.listen(onPositionChanged);
      }
      if (onDurationChanged != null) {
        _player.onDurationChanged.listen(onDurationChanged);
      }

      final source = url.startsWith('http')
          ? UrlSource(url)
          : DeviceFileSource(url);

      await _player.play(source);
      if (playbackRate != 1.0) {
        await _player.setPlaybackRate(playbackRate);
      }
    } catch (e) {
      debugPrint('Error playing audio: $e');
      onComplete?.call();
    }
  }

  Future<void> play(String url, {double playbackRate = 1.0}) =>
      playAudio(url, playbackRate: playbackRate);

  /// Pauses the current audio playback.
  Future<void> pauseAudio() async {
    try {
      await _player.pause();
    } catch (e) {
      debugPrint('Error pausing audio: $e');
    }
  }

  Future<void> pause() => pauseAudio();

  /// Resumes audio playback.
  Future<void> resumeAudio() async {
    try {
      await _player.resume();
    } catch (e) {
      debugPrint('Error resuming audio: $e');
    }
  }

  /// Stops audio playback.
  Future<void> stopAudio() async {
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('Error stopping audio: $e');
    }
  }

  Future<void> stop() => stopAudio();

  void dispose() {
    _recorder.dispose();
    _player.dispose();
  }
}
