import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

typedef OnIceCandidateCallback = void Function(RTCIceCandidate candidate);
typedef OnConnectionStateCallback = void Function(RTCPeerConnectionState state);
typedef OnStreamCallback = void Function(MediaStream stream);

class WebRtcService {
  WebRtcService();

  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  RTCVideoRenderer get localRenderer => _localRenderer;
  RTCVideoRenderer get remoteRenderer => _remoteRenderer;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;

  OnIceCandidateCallback? onIceCandidate;
  OnConnectionStateCallback? onConnectionStateChange;
  OnStreamCallback? onRemoteStream;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  static const Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
    ],
    'sdpSemantics': 'unified-plan',
  };

  /// Initializes the video renderers for local and remote streams.
  Future<void> initializeRenderers() async {
    if (_isInitialized) return;
    try {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing WebRTC renderers: $e');
    }
  }

  /// Obtains the local camera/microphone media stream.
  Future<MediaStream?> openUserMedia({required bool isVideo}) async {
    await initializeRenderers();

    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': isVideo
          ? {
              'mandatory': {
                'minWidth': '640',
                'minHeight': '480',
                'minFrameRate': '30',
              },
              'facingMode': 'user',
              'optional': [],
            }
          : false,
    };

    try {
      final stream = await navigator.mediaDevices.getUserMedia(
        mediaConstraints,
      );
      _localStream = stream;
      _localRenderer.srcObject = _localStream;
      return stream;
    } catch (e) {
      debugPrint('Error accessing user media: $e');
      return null;
    }
  }

  /// Creates and configures the RTCPeerConnection.
  Future<bool> createPeerConnectionInstance() async {
    try {
      _peerConnection = await createPeerConnection(_iceServers);

      // Handle ICE Candidates generated locally
      _peerConnection!.onIceCandidate = (candidate) {
        if (candidate.candidate != null && candidate.candidate!.isNotEmpty) {
          onIceCandidate?.call(candidate);
        }
      };

      // Handle connection state changes
      _peerConnection!.onConnectionState = (state) {
        debugPrint('WebRTC Connection state changed: $state');
        onConnectionStateChange?.call(state);
      };

      // Handle remote media track reception
      _peerConnection!.onTrack = (event) {
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];
          _remoteRenderer.srcObject = _remoteStream;
          onRemoteStream?.call(_remoteStream!);
        }
      };

      // Add local media tracks to the peer connection
      if (_localStream != null) {
        for (final track in _localStream!.getTracks()) {
          await _peerConnection!.addTrack(track, _localStream!);
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error creating peer connection: $e');
      return false;
    }
  }

  /// Generates a WebRTC offer for outgoing calls.
  Future<RTCSessionDescription?> createOffer() async {
    if (_peerConnection == null) return null;

    try {
      final offer = await _peerConnection!.createOffer({
        'offerToReceiveAudio': 1,
        'offerToReceiveVideo': 1,
      });
      await _peerConnection!.setLocalDescription(offer);
      return offer;
    } catch (e) {
      debugPrint('Error creating WebRTC offer: $e');
      return null;
    }
  }

  /// Sets the remote offer and generates an answer for incoming calls.
  Future<RTCSessionDescription?> createAnswer(
    Map<String, dynamic> offerMap,
  ) async {
    if (_peerConnection == null) return null;

    try {
      final remoteOffer = RTCSessionDescription(
        offerMap['sdp'] as String? ?? '',
        offerMap['type'] as String? ?? 'offer',
      );
      await _peerConnection!.setRemoteDescription(remoteOffer);

      final answer = await _peerConnection!.createAnswer({
        'offerToReceiveAudio': 1,
        'offerToReceiveVideo': 1,
      });
      await _peerConnection!.setLocalDescription(answer);
      return answer;
    } catch (e) {
      debugPrint('Error creating WebRTC answer: $e');
      return null;
    }
  }

  /// Sets the remote answer received from the callee.
  Future<void> setRemoteAnswer(Map<String, dynamic> answerMap) async {
    if (_peerConnection == null) return;

    try {
      final remoteAnswer = RTCSessionDescription(
        answerMap['sdp'] as String? ?? '',
        answerMap['type'] as String? ?? 'answer',
      );
      await _peerConnection!.setRemoteDescription(remoteAnswer);
    } catch (e) {
      debugPrint('Error setting remote answer: $e');
    }
  }

  /// Adds a remote ICE Candidate to the peer connection.
  Future<void> addCandidate(Map<String, dynamic> candidateMap) async {
    if (_peerConnection == null) return;

    try {
      final candidate = RTCIceCandidate(
        candidateMap['candidate'] as String?,
        candidateMap['sdpMid'] as String?,
        candidateMap['sdpMLineIndex'] as int?,
      );
      await _peerConnection!.addCandidate(candidate);
    } catch (e) {
      debugPrint('Error adding remote ICE candidate: $e');
    }
  }

  /// Toggles microphone audio track mute.
  void toggleMicrophone({required bool isMuted}) {
    if (_localStream == null) return;
    for (final track in _localStream!.getAudioTracks()) {
      track.enabled = !isMuted;
    }
  }

  /// Toggles camera video track enablement.
  void toggleCamera({required bool isCameraOff}) {
    if (_localStream == null) return;
    for (final track in _localStream!.getVideoTracks()) {
      track.enabled = !isCameraOff;
    }
  }

  /// Switches camera between front and rear lenses.
  Future<void> switchCamera() async {
    if (_localStream == null) return;
    final videoTracks = _localStream!.getVideoTracks();
    if (videoTracks.isNotEmpty) {
      try {
        await Helper.switchCamera(videoTracks.first);
      } catch (e) {
        debugPrint('Error switching camera: $e');
      }
    }
  }

  /// Toggles between speakerphone and ear piece.
  void toggleSpeaker({required bool speakerOn}) {
    try {
      _localStream?.getAudioTracks().forEach((track) {
        track.enableSpeakerphone(speakerOn);
      });
    } catch (e) {
      debugPrint('Notice setting speakerphone: $e');
    }
  }

  /// Comprehensive cleanup and resource release.
  Future<void> cleanUp() async {
    try {
      // 1. Stop and dispose local tracks
      if (_localStream != null) {
        for (final track in _localStream!.getTracks()) {
          try {
            await track.stop();
          } catch (_) {}
        }
        try {
          await _localStream!.dispose();
        } catch (_) {}
        _localStream = null;
      }

      // 2. Clear remote stream
      if (_remoteStream != null) {
        try {
          await _remoteStream!.dispose();
        } catch (_) {}
        _remoteStream = null;
      }

      // 3. Close peer connection
      if (_peerConnection != null) {
        try {
          await _peerConnection!.close();
          await _peerConnection!.dispose();
        } catch (_) {}
        _peerConnection = null;
      }

      // 4. Detach and dispose renderers
      try {
        _localRenderer.srcObject = null;
        await _localRenderer.dispose();
      } catch (_) {}

      try {
        _remoteRenderer.srcObject = null;
        await _remoteRenderer.dispose();
      } catch (_) {}

      _isInitialized = false;
    } catch (e) {
      debugPrint('Error during WebRTC cleanup: $e');
    }
  }
}
