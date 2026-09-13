import 'package:flutter_ics_homescreen/export.dart';

enum CallStatus {
  idle,
  dialing,
  incoming,
  active,
  held,
  ended,
}

@immutable
class CallState {
  final CallStatus status;
  final String name;
  final String number;
  final Duration duration;
  final bool isMuted;
  final bool isSpeaker;
  final bool isHeld;

  const CallState({
    required this.status,
    required this.name,
    required this.number,
    required this.duration,
    required this.isMuted,
    required this.isSpeaker,
    required this.isHeld,
  });

  const CallState.initial()
      : status = CallStatus.idle,
        name = '',
        number = '',
        duration = Duration.zero,
        isMuted = false,
        isSpeaker = false,
        isHeld = false;

  CallState copyWith({
    CallStatus? status,
    String? name,
    String? number,
    Duration? duration,
    bool? isMuted,
    bool? isSpeaker,
    bool? isHeld,
  }) {
    return CallState(
      status: status ?? this.status,
      name: name ?? this.name,
      number: number ?? this.number,
      duration: duration ?? this.duration,
      isMuted: isMuted ?? this.isMuted,
      isSpeaker: isSpeaker ?? this.isSpeaker,
      isHeld: isHeld ?? this.isHeld,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is CallState &&
        other.status == status &&
        other.name == name &&
        other.number == number &&
        other.duration == duration &&
        other.isMuted == isMuted &&
        other.isSpeaker == isSpeaker &&
        other.isHeld == isHeld;
  }

  @override
  int get hashCode {
    return status.hashCode ^
        name.hashCode ^
        number.hashCode ^
        duration.hashCode ^
        isMuted.hashCode ^
        isSpeaker.hashCode ^
        isHeld.hashCode;
  }
}
