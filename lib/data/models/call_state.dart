import 'package:flutter/foundation.dart';

enum CallStatus { idle, dialing, incoming, active, held, ended }

@immutable
class CallParticipant {
  const CallParticipant({
    required this.id,
    required this.name,
    required this.number,
    required this.status,
    this.multiparty = false,
  });
  final String id;
  final String name;
  final String number;
  final CallStatus status;
  final bool multiparty;
}

@immutable
class CallState {
  static const _unchanged = Object();
  const CallState({
    required this.status,
    required this.name,
    required this.number,
    required this.duration,
    required this.isMuted,
    required this.isSpeaker,
    required this.isHeld,
    this.connected = false,
    this.busy = false,
    this.deviceAddress,
    this.gatewayAddress,
    this.activeCallId,
    this.speakerVolume,
    this.microphoneVolume,
    this.transportState,
    this.codec,
    this.rejectSco,
    this.participants = const [],
    this.error,
  });

  const CallState.initial()
    : status = CallStatus.idle,
      name = '',
      number = '',
      duration = Duration.zero,
      isMuted = false,
      isSpeaker = false,
      isHeld = false,
      connected = false,
      busy = false,
      deviceAddress = null,
      gatewayAddress = null,
      activeCallId = null,
      speakerVolume = null,
      microphoneVolume = null,
      transportState = null,
      codec = null,
      rejectSco = null,
      participants = const [],
      error = null;

  final CallStatus status;
  final String name;
  final String number;
  final Duration duration;
  final bool isMuted;
  final bool isSpeaker;
  final bool isHeld;
  final bool connected;
  final bool busy;
  final String? deviceAddress;
  final String? gatewayAddress;
  final String? activeCallId;
  final int? speakerVolume;
  final int? microphoneVolume;
  final String? transportState;
  final int? codec;
  final bool? rejectSco;
  final List<CallParticipant> participants;
  final String? error;

  bool get hasCall => status != CallStatus.idle && status != CallStatus.ended;

  bool get hasWaitingCall =>
      participants.any((c) => c.status == CallStatus.incoming) &&
      participants.any(
        (c) => c.status == CallStatus.active || c.status == CallStatus.held,
      );
  bool get canSwap =>
      participants.any((c) => c.status == CallStatus.active) &&
      participants.any((c) => c.status == CallStatus.held);
  bool get canMerge => canSwap && !participants.any((c) => c.multiparty);

  CallState copyWith({
    CallStatus? status,
    String? name,
    String? number,
    Duration? duration,
    bool? isMuted,
    bool? isSpeaker,
    bool? isHeld,
    bool? connected,
    bool? busy,
    String? deviceAddress,
    Object? gatewayAddress = _unchanged,
    Object? activeCallId = _unchanged,
    Object? speakerVolume = _unchanged,
    Object? microphoneVolume = _unchanged,
    Object? transportState = _unchanged,
    Object? codec = _unchanged,
    Object? rejectSco = _unchanged,
    List<CallParticipant>? participants,
    String? error,
    bool clearCall = false,
    bool clearError = false,
  }) => CallState(
    status: status ?? this.status,
    name: clearCall ? '' : name ?? this.name,
    number: clearCall ? '' : number ?? this.number,
    duration: clearCall ? Duration.zero : duration ?? this.duration,
    isMuted: clearCall ? false : isMuted ?? this.isMuted,
    isSpeaker: clearCall ? false : isSpeaker ?? this.isSpeaker,
    isHeld: clearCall ? false : isHeld ?? this.isHeld,
    connected: connected ?? this.connected,
    busy: busy ?? this.busy,
    deviceAddress: deviceAddress ?? this.deviceAddress,
    gatewayAddress: identical(gatewayAddress, _unchanged)
        ? this.gatewayAddress
        : gatewayAddress as String?,
    activeCallId: clearCall
        ? null
        : identical(activeCallId, _unchanged)
        ? this.activeCallId
        : activeCallId as String?,
    speakerVolume: identical(speakerVolume, _unchanged)
        ? this.speakerVolume
        : speakerVolume as int?,
    microphoneVolume: identical(microphoneVolume, _unchanged)
        ? this.microphoneVolume
        : microphoneVolume as int?,
    transportState: identical(transportState, _unchanged)
        ? this.transportState
        : transportState as String?,
    codec: identical(codec, _unchanged) ? this.codec : codec as int?,
    rejectSco: identical(rejectSco, _unchanged)
        ? this.rejectSco
        : rejectSco as bool?,
    participants: clearCall ? const [] : participants ?? this.participants,
    error: clearError ? null : error ?? this.error,
  );
}
