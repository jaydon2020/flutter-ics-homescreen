import 'dart:async';
import 'package:flutter_ics_homescreen/export.dart';

class CallStateNotifier extends Notifier<CallState> {
  Timer? _timer;
  Timer? _transitionTimer;

  @override
  CallState build() {
    ref.onDispose(() {
      _timer?.cancel();
      _transitionTimer?.cancel();
    });
    return const CallState.initial();
  }

  void startCall(String number, {String? name}) {
    _timer?.cancel();
    _transitionTimer?.cancel();
    final displayName = (name != null && name.isNotEmpty) ? name : 'Calling...';

    state = CallState(
      status: CallStatus.dialing,
      name: displayName,
      number: number,
      duration: Duration.zero,
      isMuted: false,
      isSpeaker: false,
      isHeld: false,
    );

    // Simulate connected call after 2 seconds
    _transitionTimer = Timer(const Duration(seconds: 2), () {
      if (state.status == CallStatus.dialing) {
        state = state.copyWith(
          status: CallStatus.active,
          name: (name != null && name.isNotEmpty) ? name : 'Connected Call',
        );
        _startTimer();
      }
    });
  }

  void receiveIncomingCall(String name, String number) {
    _timer?.cancel();
    _transitionTimer?.cancel();

    state = CallState(
      status: CallStatus.incoming,
      name: name.isEmpty ? 'Unknown Caller' : name,
      number: number.isEmpty ? '+1 (555) 019-2834' : number,
      duration: Duration.zero,
      isMuted: false,
      isSpeaker: false,
      isHeld: false,
    );
  }

  void acceptCall() {
    _transitionTimer?.cancel();
    state = state.copyWith(
      status: CallStatus.active,
      duration: Duration.zero,
    );
    _startTimer();
  }

  void rejectCall() {
    _timer?.cancel();
    _transitionTimer?.cancel();
    state = state.copyWith(status: CallStatus.ended);

    _transitionTimer = Timer(const Duration(seconds: 1), () {
      state = const CallState.initial();
    });
  }

  void endCall() {
    _timer?.cancel();
    _transitionTimer?.cancel();
    state = state.copyWith(status: CallStatus.ended);

    _transitionTimer = Timer(const Duration(seconds: 1), () {
      state = const CallState.initial();
    });
  }

  void toggleMute() {
    if (state.status == CallStatus.active || state.status == CallStatus.held) {
      state = state.copyWith(isMuted: !state.isMuted);
    }
  }

  void toggleSpeaker() {
    if (state.status == CallStatus.active || state.status == CallStatus.held) {
      state = state.copyWith(isSpeaker: !state.isSpeaker);
    }
  }

  void toggleHold() {
    if (state.status == CallStatus.active) {
      state = state.copyWith(status: CallStatus.held, isHeld: true);
      _timer?.cancel();
    } else if (state.status == CallStatus.held) {
      state = state.copyWith(status: CallStatus.active, isHeld: false);
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.status == CallStatus.active) {
        state = state.copyWith(
          duration: Duration(seconds: state.duration.inSeconds + 1),
        );
      }
    });
  }
}

final callStateProvider =
    NotifierProvider<CallStateNotifier, CallState>(CallStateNotifier.new);
