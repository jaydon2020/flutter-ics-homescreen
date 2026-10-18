import 'dart:async';

import 'package:flutter_ics_homescreen/data/data_providers/bluetooth_notifier.dart';
import 'package:flutter_ics_homescreen/data/data_providers/phone_data_notifier.dart';
import 'package:flutter_ics_homescreen/data/models/call_state.dart';
import 'package:flutter_ics_homescreen/data/models/phone_models.dart';
import 'package:flutter_ics_homescreen/data/services/telephony_backend.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pipewire_telephony_native/pipewire_telephony_native.dart';

final telephonyBackendFactoryProvider =
    Provider<TelephonyBackend Function(String)>(
      (ref) => NativeTelephonyBackend.new,
    );

class CallStateNotifier extends Notifier<CallState> {
  TelephonyBackend? _backend;
  StreamSubscription<TelephonySnapshot>? _subscription;
  Timer? _durationTimer;
  DateTime? _activeSince;
  int _savedMicrophoneVolume = 8;
  int _savedSpeakerVolume = 8;
  int _generation = 0;
  bool _disposed = false;
  String? _requestedAddress;
  Future<void> _lifecycle = Future.value();

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  @override
  CallState build() {
    ref.onDispose(() {
      _disposed = true;
      ++_generation;
      unawaited(_lifecycle.then((_) => _disposeBackend()));
    });
    ref.listen(bluetoothProvider, (previous, next) => _syncBluetooth(next));
    ref.listen(phoneDataProvider.select((phone) => phone.contacts), (_, __) {
      final backend = _backend;
      if (!_disposed && backend != null) _applySnapshot(backend.current);
    });
    Future.microtask(() {
      if (!_disposed) _syncBluetooth(ref.read(bluetoothProvider));
    });
    return const CallState.initial();
  }

  void _syncBluetooth(BluetoothState bluetooth) {
    if (_disposed) return;
    final device = bluetooth.devices
        .where(
          (item) =>
              item.connected &&
              bluetoothDeviceIsSupported(item) &&
              bluetooth.busyAddress != item.address,
        )
        .firstOrNull;
    if (device == null) {
      if (_requestedAddress != null) unawaited(_disconnect());
    } else if (device.address != _requestedAddress) {
      unawaited(_connect(device.address));
    }
  }

  Future<void> _connect(String address) async {
    final generation = ++_generation;
    _requestedAddress = address;
    state = const CallState.initial().copyWith(
      deviceAddress: address,
      busy: true,
    );
    final task = _lifecycle.then((_) async {
      await _disposeBackend();
      if (!_isCurrent(generation)) return;
      try {
        final backend = ref.read(telephonyBackendFactoryProvider)(address);
        _backend = backend;
        _subscription = backend.snapshots.listen(
          (snapshot) {
            if (_isCurrent(generation)) _applySnapshot(snapshot);
          },
          onError: (Object error) {
            if (_isCurrent(generation)) _operationFailed(error);
          },
          onDone: () {
            if (_isCurrent(generation)) {
              state = const CallState.initial().copyWith(
                deviceAddress: address,
                error: 'Telephony service disconnected',
              );
            }
          },
        );
        await backend.connect().timeout(const Duration(seconds: 12));
        if (!_isCurrent(generation)) return;
        await backend.refresh();
        if (_isCurrent(generation)) _applySnapshot(backend.current);
      } catch (error) {
        if (_isCurrent(generation)) {
          await _disposeBackend();
          if (_isCurrent(generation)) _operationFailed(error);
        }
      }
    });
    _lifecycle = task.then((_) {}, onError: (Object _, StackTrace __) {});
    await task;
  }

  Future<void> retry() async {
    final address = state.deviceAddress;
    if (address != null) await _connect(address);
  }

  Future<void> refresh() async {
    if (_backend == null) return;
    await _run((backend, _) => backend.refresh());
  }

  Future<void> _disconnect() async {
    ++_generation;
    _requestedAddress = null;
    state = const CallState.initial();
    final task = _lifecycle.then((_) => _disposeBackend());
    _lifecycle = task.then((_) {}, onError: (Object _, StackTrace __) {});
    await task;
  }

  Future<void> _disposeBackend() async {
    _durationTimer?.cancel();
    _durationTimer = null;
    _activeSince = null;
    final subscription = _subscription;
    final backend = _backend;
    _subscription = null;
    _backend = null;
    await subscription?.cancel();
    try {
      await backend?.close();
    } catch (_) {}
  }

  void _applySnapshot(TelephonySnapshot snapshot) {
    final address = state.deviceAddress;
    final matchingGateway =
        snapshot.gatewayAddress != null &&
        address != null &&
        _normalizeAddress(snapshot.gatewayAddress!) ==
            _normalizeAddress(address);
    final connected =
        snapshot.clientState == PipeWireTelephonyClientState.ready &&
        snapshot.gatewayAddress != null &&
        matchingGateway;
    final gatewayError =
        snapshot.clientState == PipeWireTelephonyClientState.ready &&
            !matchingGateway &&
            address != null
        ? 'Bluetooth is connected, but hands-free calling is unavailable. Reconnect the phone in Bluetooth settings.'
        : null;
    final calls = snapshot.calls
        .where(
          (call) => connected && call.state != PipeWireCallState.disconnected,
        )
        .toList();
    final primary = _primaryCall(calls);
    final nextStatus = primary == null
        ? CallStatus.idle
        : _mapStatus(primary.state);
    if (nextStatus == CallStatus.active && state.status != CallStatus.active) {
      _activeSince = DateTime.now();
      _startDurationTimer();
      if (address != null) {
        final generation = _generation;
        unawaited(
          _backend?.activateTransport(address).catchError((Object error) {
            if (_isCurrent(generation)) _operationFailed(error);
          }),
        );
      }
    } else if (nextStatus != CallStatus.active &&
        nextStatus != CallStatus.held) {
      _durationTimer?.cancel();
      if (primary == null) _activeSince = null;
    }
    final participants = calls
        .map(
          (call) => CallParticipant(
            id: call.id,
            name: _displayName(call),
            number: call.number,
            status: _mapStatus(call.state),
            multiparty: call.multiparty,
          ),
        )
        .toList(growable: false);
    state = state.copyWith(
      status: nextStatus,
      name: primary == null ? '' : _displayName(primary),
      number: primary?.number ?? '',
      duration: primary == null ? Duration.zero : state.duration,
      isHeld: nextStatus == CallStatus.held,
      connected: connected,
      busy: false,
      gatewayAddress: snapshot.gatewayAddress,
      activeCallId: primary?.id,
      speakerVolume: snapshot.speakerVolume,
      microphoneVolume: snapshot.microphoneVolume,
      transportState: snapshot.transportState?.name,
      codec: snapshot.codec,
      rejectSco: snapshot.rejectSco,
      participants: participants,
      error: snapshot.error?.toString() ?? gatewayError,
      clearCall: primary == null,
      clearError: snapshot.error == null && gatewayError == null,
    );
    if ((snapshot.microphoneVolume ?? 0) > 0) {
      _savedMicrophoneVolume = snapshot.microphoneVolume!;
    }
    if ((snapshot.speakerVolume ?? 0) > 0) {
      _savedSpeakerVolume = snapshot.speakerVolume!;
    }
  }

  TelephonyCallInfo? _primaryCall(List<TelephonyCallInfo> calls) {
    if (calls.isEmpty) return null;
    for (final desired in [
      PipeWireCallState.incoming,
      PipeWireCallState.waiting,
      PipeWireCallState.active,
      PipeWireCallState.dialing,
      PipeWireCallState.alerting,
      PipeWireCallState.held,
    ]) {
      final found = calls.where((call) => call.state == desired).firstOrNull;
      if (found != null) return found;
    }
    return calls.first;
  }

  String _displayName(TelephonyCallInfo call) {
    if (call.name.trim().isNotEmpty) return call.name;
    final normalized = normalizePhoneNumber(call.number);
    final contact = ref
        .read(phoneDataProvider)
        .contacts
        .where(
          (item) => item.numbers.any(
            (number) => normalizePhoneNumber(number) == normalized,
          ),
        )
        .firstOrNull;
    return contact?.name ??
        (call.number.isEmpty ? 'Unknown caller' : call.number);
  }

  Future<void> startCall(String number, {String? name}) =>
      _run((backend, address) => backend.dial(address, number));
  Future<void> acceptCall() async {
    final id = _incomingCallId;
    if (id != null) await _run((backend, _) => backend.answer(id));
  }

  Future<void> rejectCall() => endCall();
  Future<void> endCall() async {
    final id = state.activeCallId;
    if (id != null) {
      await _run((backend, _) => backend.hangup(id));
    } else {
      await hangupAll();
    }
  }

  Future<void> hangupAll() =>
      _run((backend, address) => backend.hangupAll(address));
  Future<void> sendTones(String tones) =>
      _run((backend, address) => backend.sendTones(address, tones));
  Future<void> swapCalls() =>
      _run((backend, address) => backend.swapCalls(address));
  Future<void> releaseAndAnswer() =>
      _run((backend, address) => backend.releaseAndAnswer(address));
  Future<void> releaseAndSwap() =>
      _run((backend, address) => backend.releaseAndSwap(address));
  Future<void> holdAndAnswer() =>
      _run((backend, address) => backend.holdAndAnswer(address));
  Future<void> createMultiparty() =>
      _run((backend, address) => backend.createMultiparty(address));
  Future<void> setSpeakerVolume(int volume) => _run(
    (backend, address) =>
        backend.setSpeakerVolume(address, volume.clamp(0, 15)),
  );
  Future<void> setMicrophoneVolume(int volume) => _run(
    (backend, address) =>
        backend.setMicrophoneVolume(address, volume.clamp(0, 15)),
  );
  Future<void> activateTransport() =>
      _run((backend, address) => backend.activateTransport(address));
  Future<void> setRejectSco(bool reject) =>
      _run((backend, address) => backend.setRejectSco(address, reject));

  Future<void> toggleMute() async {
    final generation = _generation;
    final muted = !state.isMuted;
    await setMicrophoneVolume(muted ? 0 : _savedMicrophoneVolume);
    if (_isCurrent(generation) && state.error == null) {
      state = state.copyWith(isMuted: muted);
    }
  }

  Future<void> toggleSpeaker() async {
    final generation = _generation;
    final enabled = !state.isSpeaker;
    await setSpeakerVolume(enabled ? _savedSpeakerVolume : 0);
    if (_isCurrent(generation) && state.error == null) {
      state = state.copyWith(isSpeaker: enabled);
    }
  }

  Future<void> toggleHold() async {
    await swapCalls();
  }

  String? get _incomingCallId => state.participants
      .where((call) => call.status == CallStatus.incoming)
      .map((call) => call.id)
      .firstOrNull;

  Future<void> _run(
    Future<void> Function(TelephonyBackend, String) action,
  ) async {
    final backend = _backend;
    final address = state.deviceAddress;
    if (backend == null || address == null || !state.connected) {
      _operationFailed('Phone telephony is not connected');
      return;
    }
    final generation = _generation;
    state = state.copyWith(busy: true, clearError: true);
    try {
      await action(backend, address);
      if (_isCurrent(generation)) state = state.copyWith(busy: false);
    } catch (error) {
      if (_isCurrent(generation)) _operationFailed(error);
    }
  }

  void _operationFailed(Object error) {
    state = state.copyWith(
      busy: false,
      error: error.toString().replaceFirst(
        RegExp(r'^\w+(?:Exception|Error):\s*'),
        '',
      ),
    );
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed) return;
      final since = _activeSince;
      if (since != null &&
          (state.status == CallStatus.active ||
              state.status == CallStatus.held)) {
        state = state.copyWith(duration: DateTime.now().difference(since));
      }
    });
  }
}

CallStatus _mapStatus(PipeWireCallState status) => switch (status) {
  PipeWireCallState.active => CallStatus.active,
  PipeWireCallState.held => CallStatus.held,
  PipeWireCallState.dialing || PipeWireCallState.alerting => CallStatus.dialing,
  PipeWireCallState.incoming ||
  PipeWireCallState.waiting => CallStatus.incoming,
  PipeWireCallState.disconnected => CallStatus.ended,
  PipeWireCallState.unknown => CallStatus.idle,
};

String _normalizeAddress(String value) =>
    value.replaceAll(':', '').toLowerCase();

final callStateProvider = NotifierProvider<CallStateNotifier, CallState>(
  CallStateNotifier.new,
);
