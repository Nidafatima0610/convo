import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../services/calling/call_signaling_service.dart';
import '../../../../services/calling/webrtc_service.dart';
import '../../../auth/domain/models/convo_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/models/call_model.dart';

final callSignalingServiceProvider = Provider<CallSignalingService>((ref) {
  return CallSignalingService();
});

/// Stream of incoming ringing calls for the currently authenticated user.
final incomingCallStreamProvider = StreamProvider.autoDispose<CallModel?>((
  ref,
) {
  final authUser = ref.watch(authStateChangesProvider).asData?.value;
  if (authUser == null) return const Stream.empty();

  final signaling = ref.watch(callSignalingServiceProvider);
  return signaling.listenToIncomingCalls(authUser.uid);
});

/// Stream of all call history for the currently authenticated user.
final callHistoryProvider = StreamProvider.autoDispose<List<CallModel>>((ref) {
  final authUser = ref.watch(authStateChangesProvider).asData?.value;
  if (authUser == null) return const Stream.empty();

  final signaling = ref.watch(callSignalingServiceProvider);
  return signaling.listenToCallHistory(authUser.uid);
});

enum CallConnectionState {
  idle,
  ringing,
  connecting,
  connected,
  reconnecting,
  ended,
  failed,
}

class ActiveCallState {
  const ActiveCallState({
    this.call,
    this.webrtc,
    this.isCaller = false,
    this.connectionState = CallConnectionState.idle,
    this.isMicMuted = false,
    this.isCameraOff = false,
    this.isSpeakerOn = false,
    this.elapsedDuration = Duration.zero,
    this.errorMessage,
  });

  final CallModel? call;
  final WebRtcService? webrtc;
  final bool isCaller;
  final CallConnectionState connectionState;
  final bool isMicMuted;
  final bool isCameraOff;
  final bool isSpeakerOn;
  final Duration elapsedDuration;
  final String? errorMessage;

  bool get isInCall =>
      call != null && connectionState != CallConnectionState.idle;
  bool get isConnected => connectionState == CallConnectionState.connected;
  bool get isRinging => connectionState == CallConnectionState.ringing;
  bool get isVideo => call?.isVideo ?? false;
  bool get isVoice => call?.isVoice ?? true;

  ActiveCallState copyWith({
    CallModel? call,
    WebRtcService? webrtc,
    bool? isCaller,
    CallConnectionState? connectionState,
    bool? isMicMuted,
    bool? isCameraOff,
    bool? isSpeakerOn,
    Duration? elapsedDuration,
    String? errorMessage,
  }) {
    return ActiveCallState(
      call: call ?? this.call,
      webrtc: webrtc ?? this.webrtc,
      isCaller: isCaller ?? this.isCaller,
      connectionState: connectionState ?? this.connectionState,
      isMicMuted: isMicMuted ?? this.isMicMuted,
      isCameraOff: isCameraOff ?? this.isCameraOff,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      elapsedDuration: elapsedDuration ?? this.elapsedDuration,
      errorMessage: errorMessage,
    );
  }
}

class ActiveCallNotifier extends Notifier<ActiveCallState> {
  StreamSubscription<CallModel?>? _callSub;
  StreamSubscription<List<Map<String, dynamic>>>? _candidatesSub;
  Timer? _durationTimer;
  Timer? _ringingTimeoutTimer;
  final Set<String> _processedCandidates = {};

  @override
  ActiveCallState build() {
    ref.onDispose(() {
      _cleanUpInternal();
    });
    return const ActiveCallState();
  }

  CallSignalingService get _signaling => ref.read(callSignalingServiceProvider);

  /// Checks and requests necessary permissions for voice/video calls.
  Future<bool> checkAndRequestPermissions({required bool isVideo}) async {
    try {
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        state = state.copyWith(
          errorMessage: 'Microphone permission is required for calls.',
        );
        return false;
      }

      if (isVideo) {
        final cameraStatus = await Permission.camera.request();
        if (!cameraStatus.isGranted) {
          state = state.copyWith(
            errorMessage: 'Camera permission is required for video calls.',
          );
          return false;
        }
      }

      return true;
    } catch (e) {
      debugPrint('Permission request error: $e');
      return true; // Fallback gracefully if permission handler encounters platform limitations
    }
  }

  /// Initiates an outgoing call session.
  Future<bool> startCall({
    required ConvoUser caller,
    required ConvoUser receiver,
    required CallType type,
  }) async {
    final hasPermissions = await checkAndRequestPermissions(
      isVideo: type == CallType.video,
    );
    if (!hasPermissions) return false;

    // Reset previous session
    await _cleanUpInternal();

    final webrtc = WebRtcService();
    final callId =
        '${caller.uid}_${receiver.uid}_${DateTime.now().millisecondsSinceEpoch}';

    final initialCall = CallModel(
      callId: callId,
      callerId: caller.uid,
      callerName: caller.name,
      callerPhoto: caller.photoUrl,
      receiverId: receiver.uid,
      receiverName: receiver.name,
      receiverPhoto: receiver.photoUrl,
      type: type,
      status: CallStatus.ringing,
      participants: [caller.uid, receiver.uid],
      createdAt: DateTime.now(),
    );

    state = ActiveCallState(
      call: initialCall,
      webrtc: webrtc,
      isCaller: true,
      connectionState: CallConnectionState.ringing,
      isSpeakerOn: type == CallType.video,
    );

    try {
      // 1. Open User Media
      await webrtc.openUserMedia(isVideo: type == CallType.video);

      // 2. Initialize Peer Connection
      await webrtc.createPeerConnectionInstance();

      // Hook candidate sending
      webrtc.onIceCandidate = (candidate) {
        _signaling.addCallerCandidate(callId, candidate);
      };

      // Hook connection state
      webrtc.onConnectionStateChange = (connState) {
        _handlePeerConnectionStateChange(connState);
      };

      // 3. Create WebRTC Offer
      final offer = await webrtc.createOffer();
      if (offer == null) {
        state = state.copyWith(
          connectionState: CallConnectionState.failed,
          errorMessage: 'Could not generate call offer.',
        );
        return false;
      }

      // 4. Save call in Firestore
      await _signaling.initiateCall(call: initialCall, offer: offer);

      // 5. Listen to Call document for answer or rejection
      _callSub = _signaling.listenToCall(callId).listen((callUpdate) async {
        if (callUpdate == null) return;
        state = state.copyWith(call: callUpdate);

        if (callUpdate.status == CallStatus.accepted &&
            callUpdate.answer != null) {
          _ringingTimeoutTimer?.cancel();
          await webrtc.setRemoteAnswer(callUpdate.answer!);
        } else if (callUpdate.status == CallStatus.rejected) {
          state = state.copyWith(
            connectionState: CallConnectionState.ended,
            errorMessage: 'Call declined',
          );
          _scheduleAutoClose();
        } else if (callUpdate.status == CallStatus.missed) {
          state = state.copyWith(
            connectionState: CallConnectionState.ended,
            errorMessage: 'No answer',
          );
          _scheduleAutoClose();
        } else if (callUpdate.status == CallStatus.ended) {
          state = state.copyWith(connectionState: CallConnectionState.ended);
          _scheduleAutoClose();
        }
      });

      // 6. Listen to receiver ICE candidates
      _candidatesSub = _signaling.listenToReceiverCandidates(callId).listen((
        candidates,
      ) {
        for (final candidateMap in candidates) {
          final candStr = candidateMap['candidate']?.toString() ?? '';
          if (candStr.isNotEmpty && !_processedCandidates.contains(candStr)) {
            _processedCandidates.add(candStr);
            webrtc.addCandidate(candidateMap);
          }
        }
      });

      // 7. Ringing timeout (45 seconds)
      _ringingTimeoutTimer = Timer(const Duration(seconds: 45), () {
        if (state.connectionState == CallConnectionState.ringing) {
          _signaling.markCallAsMissed(callId);
          state = state.copyWith(
            connectionState: CallConnectionState.ended,
            errorMessage: 'No answer',
          );
          _scheduleAutoClose();
        }
      });

      return true;
    } catch (e) {
      debugPrint('Error starting call: $e');
      state = state.copyWith(
        connectionState: CallConnectionState.failed,
        errorMessage: 'Call initialization failed: $e',
      );
      return false;
    }
  }

  /// Accepts an incoming call session.
  Future<bool> acceptCall(CallModel incomingCall) async {
    final hasPermissions = await checkAndRequestPermissions(
      isVideo: incomingCall.isVideo,
    );
    if (!hasPermissions) {
      await rejectCall(incomingCall.callId);
      return false;
    }

    await _cleanUpInternal();

    final webrtc = WebRtcService();
    state = ActiveCallState(
      call: incomingCall,
      webrtc: webrtc,
      isCaller: false,
      connectionState: CallConnectionState.connecting,
      isSpeakerOn: incomingCall.isVideo,
    );

    try {
      // 1. Open User Media
      await webrtc.openUserMedia(isVideo: incomingCall.isVideo);

      // 2. Setup Peer Connection
      await webrtc.createPeerConnectionInstance();

      // Hook candidate sending
      webrtc.onIceCandidate = (candidate) {
        _signaling.addReceiverCandidate(incomingCall.callId, candidate);
      };

      webrtc.onConnectionStateChange = (connState) {
        _handlePeerConnectionStateChange(connState);
      };

      // 3. Create Answer from remote Offer
      final offerMap = incomingCall.offer;
      if (offerMap == null) {
        state = state.copyWith(
          connectionState: CallConnectionState.failed,
          errorMessage: 'Invalid call session offer.',
        );
        return false;
      }

      final answer = await webrtc.createAnswer(offerMap);
      if (answer == null) {
        state = state.copyWith(
          connectionState: CallConnectionState.failed,
          errorMessage: 'Could not generate answer.',
        );
        return false;
      }

      // 4. Update Firestore with Accepted status and Answer
      await _signaling.acceptCall(callId: incomingCall.callId, answer: answer);

      // 5. Listen to caller ICE candidates
      _candidatesSub = _signaling
          .listenToCallerCandidates(incomingCall.callId)
          .listen((candidates) {
            for (final candidateMap in candidates) {
              final candStr = candidateMap['candidate']?.toString() ?? '';
              if (candStr.isNotEmpty &&
                  !_processedCandidates.contains(candStr)) {
                _processedCandidates.add(candStr);
                webrtc.addCandidate(candidateMap);
              }
            }
          });

      // 6. Listen to Call document for updates
      _callSub = _signaling.listenToCall(incomingCall.callId).listen((
        callUpdate,
      ) {
        if (callUpdate == null) return;
        state = state.copyWith(call: callUpdate);

        if (callUpdate.status == CallStatus.ended) {
          state = state.copyWith(connectionState: CallConnectionState.ended);
          _scheduleAutoClose();
        }
      });

      return true;
    } catch (e) {
      debugPrint('Error accepting call: $e');
      state = state.copyWith(
        connectionState: CallConnectionState.failed,
        errorMessage: 'Failed to accept call: $e',
      );
      return false;
    }
  }

  /// Rejects an incoming call session.
  Future<void> rejectCall(String callId) async {
    await _signaling.rejectCall(callId);
    await endCall();
  }

  /// Ends the active call and performs cleanup.
  Future<void> endCall() async {
    final callId = state.call?.callId;
    final durationSeconds = state.elapsedDuration.inSeconds;

    if (callId != null && callId.isNotEmpty) {
      await _signaling.endCall(callId, durationSeconds: durationSeconds);
    }

    state = state.copyWith(connectionState: CallConnectionState.ended);
    await _cleanUpInternal();
    state = const ActiveCallState();
  }

  void toggleMicrophone() {
    final newMute = !state.isMicMuted;
    state.webrtc?.toggleMicrophone(isMuted: newMute);
    state = state.copyWith(isMicMuted: newMute);
  }

  void toggleCamera() {
    final newCameraOff = !state.isCameraOff;
    state.webrtc?.toggleCamera(isCameraOff: newCameraOff);
    state = state.copyWith(isCameraOff: newCameraOff);
  }

  Future<void> switchCamera() async {
    await state.webrtc?.switchCamera();
  }

  void toggleSpeaker() {
    final newSpeaker = !state.isSpeakerOn;
    state.webrtc?.toggleSpeaker(speakerOn: newSpeaker);
    state = state.copyWith(isSpeakerOn: newSpeaker);
  }

  void _handlePeerConnectionStateChange(RTCPeerConnectionState connState) {
    switch (connState) {
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        state = state.copyWith(connectionState: CallConnectionState.connected);
        _startDurationTimer();
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
        state = state.copyWith(connectionState: CallConnectionState.connecting);
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        state = state.copyWith(
          connectionState: CallConnectionState.reconnecting,
        );
        break;
      case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
        state = state.copyWith(connectionState: CallConnectionState.ended);
        _scheduleAutoClose();
        break;
      default:
        break;
    }
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      state = state.copyWith(elapsedDuration: Duration(seconds: timer.tick));
    });
  }

  void _scheduleAutoClose() {
    Timer(const Duration(seconds: 2), () {
      if (state.connectionState == CallConnectionState.ended) {
        _cleanUpInternal();
        state = const ActiveCallState();
      }
    });
  }

  Future<void> _cleanUpInternal() async {
    _durationTimer?.cancel();
    _durationTimer = null;
    _ringingTimeoutTimer?.cancel();
    _ringingTimeoutTimer = null;
    await _callSub?.cancel();
    _callSub = null;
    await _candidatesSub?.cancel();
    _candidatesSub = null;
    _processedCandidates.clear();

    await state.webrtc?.cleanUp();
  }
}

final activeCallControllerProvider =
    NotifierProvider<ActiveCallNotifier, ActiveCallState>(
      ActiveCallNotifier.new,
    );
