import 'dart:async';

import 'package:pipewire_telephony_native/pipewire_telephony_native.dart';

class TelephonyCallInfo {
  const TelephonyCallInfo({
    required this.id,
    required this.number,
    required this.name,
    required this.state,
    required this.multiparty,
  });

  final String id;
  final String number;
  final String name;
  final PipeWireCallState state;
  final bool multiparty;
}

class TelephonySnapshot {
  const TelephonySnapshot({
    required this.clientState,
    this.gatewayAddress,
    this.speakerVolume,
    this.microphoneVolume,
    this.transportState,
    this.codec,
    this.rejectSco,
    this.calls = const [],
    this.error,
  });

  final PipeWireTelephonyClientState clientState;
  final String? gatewayAddress;
  final int? speakerVolume;
  final int? microphoneVolume;
  final PipeWireTransportState? transportState;
  final int? codec;
  final bool? rejectSco;
  final List<TelephonyCallInfo> calls;
  final Object? error;
}

abstract interface class TelephonyBackend {
  Stream<TelephonySnapshot> get snapshots;
  TelephonySnapshot get current;

  Future<void> connect();
  Future<void> close();
  Future<void> refresh();
  Future<void> dial(String address, String number);
  Future<void> answer(String callId);
  Future<void> hangup(String callId);
  Future<void> hangupAll(String address);
  Future<void> sendTones(String address, String tones);
  Future<void> swapCalls(String address);
  Future<void> releaseAndAnswer(String address);
  Future<void> releaseAndSwap(String address);
  Future<void> holdAndAnswer(String address);
  Future<void> createMultiparty(String address);
  Future<void> setSpeakerVolume(String address, int volume);
  Future<void> setMicrophoneVolume(String address, int volume);
  Future<void> activateTransport(String address);
  Future<void> setRejectSco(String address, bool value);
}

class NativeTelephonyBackend implements TelephonyBackend {
  NativeTelephonyBackend(
    this.address, {
    PipeWireBus bus = PipeWireBus.automatic,
  }) : _client = PipeWireTelephonyClient(bus: bus);

  final PipeWireTelephonyClient _client;
  final String address;
  final _controller = StreamController<TelephonySnapshot>.broadcast(sync: true);
  final _subscriptions = <StreamSubscription<Object?>>[];
  TelephonySnapshot _current = const TelephonySnapshot(
    clientState: PipeWireTelephonyClientState.idle,
  );
  bool _closed = false;

  @override
  Stream<TelephonySnapshot> get snapshots => _controller.stream;

  @override
  TelephonySnapshot get current => _current;

  @override
  Future<void> connect() async {
    _subscriptions.add(_client.stateChanged.listen((_) => _emit()));
    _subscriptions.add(_client.gatewayAdded.listen((_) => _emit()));
    _subscriptions.add(_client.gatewayRemoved.listen((_) => _emit()));
    _subscriptions.add(_client.gatewayChanged.listen((_) => _emit()));
    _subscriptions.add(_client.callAdded.listen((_) => _emit()));
    _subscriptions.add(_client.callRemoved.listen((_) => _emit()));
    _subscriptions.add(_client.callChanged.listen((_) => _emit()));
    try {
      await _client.connect();
      _emit();
    } catch (error) {
      _emit(error);
      rethrow;
    }
  }

  void _emit([Object? error]) {
    if (_closed) return;
    final gateway = _client.gateways
        .where(
          (gateway) =>
              (gateway.address ?? '').replaceAll(':', '').toLowerCase() ==
              address.replaceAll(':', '').toLowerCase(),
        )
        .firstOrNull;
    final transport = gateway?.transport;
    _current = TelephonySnapshot(
      clientState: _client.state,
      gatewayAddress: gateway?.address,
      speakerVolume: gateway?.speakerVolume,
      microphoneVolume: gateway?.microphoneVolume,
      transportState: transport?.state,
      codec: transport?.codec,
      rejectSco: transport?.rejectSco,
      calls: _client.calls
          .where((call) => call.isValid && identical(call.gateway, gateway))
          .map(
            (call) => TelephonyCallInfo(
              id: call.objectPath,
              number: call.lineIdentification ?? call.incomingLine ?? '',
              name: call.name ?? '',
              state: call.state ?? PipeWireCallState.unknown,
              multiparty: call.multiparty ?? false,
            ),
          )
          .toList(growable: false),
      error: error ?? _client.lastError,
    );
    _controller.add(_current);
  }

  PipeWireAudioGateway _gateway(String address) {
    final normalized = address.replaceAll(':', '').toLowerCase();
    return _client.gateways.firstWhere(
      (gateway) =>
          (gateway.address ?? '').replaceAll(':', '').toLowerCase() ==
          normalized,
      orElse: () =>
          throw StateError('No telephony gateway is available for $address'),
    );
  }

  PipeWireCall _call(String id) => _client.calls.firstWhere(
    (call) => call.objectPath == id && call.isValid,
    orElse: () => throw StateError('Call is no longer available'),
  );

  @override
  Future<void> refresh() => _client.refresh();

  @override
  Future<void> dial(String address, String number) =>
      _gateway(address).dial(number);

  @override
  Future<void> answer(String callId) => _call(callId).answer();

  @override
  Future<void> hangup(String callId) => _call(callId).hangup();

  @override
  Future<void> hangupAll(String address) => _gateway(address).hangupAll();

  @override
  Future<void> sendTones(String address, String tones) =>
      _gateway(address).sendTones(tones);

  @override
  Future<void> swapCalls(String address) => _gateway(address).swapCalls();

  @override
  Future<void> releaseAndAnswer(String address) =>
      _gateway(address).releaseAndAnswer();

  @override
  Future<void> releaseAndSwap(String address) =>
      _gateway(address).releaseAndSwap();

  @override
  Future<void> holdAndAnswer(String address) =>
      _gateway(address).holdAndAnswer();

  @override
  Future<void> createMultiparty(String address) =>
      _gateway(address).createMultiparty();

  @override
  Future<void> setSpeakerVolume(String address, int volume) =>
      _gateway(address).setSpeakerVolume(volume);

  @override
  Future<void> setMicrophoneVolume(String address, int volume) =>
      _gateway(address).setMicrophoneVolume(volume);

  @override
  Future<void> activateTransport(String address) async {
    final transport = _gateway(address).transport;
    if (transport == null) throw StateError('SCO transport is unavailable');
    await transport.activate();
  }

  @override
  Future<void> setRejectSco(String address, bool value) async {
    final transport = _gateway(address).transport;
    if (transport == null) throw StateError('SCO transport is unavailable');
    await transport.setRejectSco(value);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _client.close();
    await _controller.close();
  }
}
