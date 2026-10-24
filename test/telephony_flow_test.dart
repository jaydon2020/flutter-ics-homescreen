import 'dart:async';

import 'package:flutter_ics_homescreen/data/data_providers/bluetooth_notifier.dart';
import 'package:flutter_ics_homescreen/data/data_providers/call_notifier.dart';
import 'package:flutter_ics_homescreen/data/data_providers/phone_data_notifier.dart';
import 'package:flutter_ics_homescreen/data/models/call_state.dart';
import 'package:flutter_ics_homescreen/data/models/phone_models.dart';
import 'package:flutter_ics_homescreen/data/services/telephony_backend.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipewire_telephony_native/pipewire_telephony_native.dart';

import 'phone_test_support.dart';

class _ContactsNotifier extends PhoneDataNotifier {
  @override
  PhoneDataState build() => const PhoneDataState();
  void load(String address, List<PhoneContact> contacts) =>
      state = state.copyWith(contacts: contacts, contactsAddress: address);
}

class _Telephony implements TelephonyBackend {
  _Telephony(String address)
    : current = TelephonySnapshot(
        clientState: PipeWireTelephonyClientState.ready,
        gatewayAddress: address,
      );
  final controller = StreamController<TelephonySnapshot>.broadcast(sync: true);
  @override
  TelephonySnapshot current;
  bool closed = false;
  int connects = 0;
  Completer<void>? connectGate;
  Completer<void>? commandGate;
  @override
  Stream<TelephonySnapshot> get snapshots => controller.stream;
  @override
  Future<void> connect() async {
    connects++;
    if (connectGate != null) await connectGate!.future;
  }

  @override
  Future<void> refresh() async => emit(current);
  void emit(TelephonySnapshot snapshot) {
    current = snapshot;
    controller.add(snapshot);
  }

  @override
  Future<void> close() async {
    closed = true;
    await controller.close();
  }

  final operations = <List<Object>>[];
  Object? commandError;
  Future<void> record(String method, List<Object> args) async {
    operations.add([method, ...args]);
    if (commandGate != null) await commandGate!.future;
    if (commandError != null) throw commandError!;
  }

  @override
  Future<void> dial(String address, String number) =>
      record('dial', [address, number]);
  @override
  Future<void> answer(String callId) => record('answer', [callId]);
  @override
  Future<void> hangup(String callId) => record('hangup', [callId]);
  @override
  Future<void> hangupAll(String address) => record('hangupAll', [address]);
  @override
  Future<void> sendTones(String address, String tones) =>
      record('sendTones', [address, tones]);
  @override
  Future<void> swapCalls(String address) => record('swapCalls', [address]);
  @override
  Future<void> releaseAndAnswer(String address) =>
      record('releaseAndAnswer', [address]);
  @override
  Future<void> releaseAndSwap(String address) =>
      record('releaseAndSwap', [address]);
  @override
  Future<void> holdAndAnswer(String address) =>
      record('holdAndAnswer', [address]);
  @override
  Future<void> createMultiparty(String address) =>
      record('createMultiparty', [address]);
  @override
  Future<void> setSpeakerVolume(String address, int volume) =>
      record('setSpeakerVolume', [address, volume]);
  @override
  Future<void> setMicrophoneVolume(String address, int volume) =>
      record('setMicrophoneVolume', [address, volume]);
  @override
  Future<void> activateTransport(String address) =>
      record('activateTransport', [address]);
  @override
  Future<void> setRejectSco(String address, bool value) =>
      record('setRejectSco', [address, value]);
}

void main() {
  late ProviderContainer container;
  late List<_Telephony> backends;
  late List<String> selectedAddresses;
  late List<_Telephony> opened;
  CallState state() => container.read(callStateProvider);
  void publish(String? address) =>
      (container.read(bluetoothProvider.notifier) as TestBluetoothNotifier)
          .publish(
            BluetoothState(devices: address == null ? [] : [phone(address)]),
          );

  setUp(() {
    backends = [];
    selectedAddresses = [];
    opened = [];
    container = ProviderContainer(
      overrides: [
        bluetoothProvider.overrideWith(TestBluetoothNotifier.new),
        phoneDataProvider.overrideWith(_ContactsNotifier.new),
        telephonyBackendFactoryProvider.overrideWithValue((address) {
          selectedAddresses.add(address);
          final backend = backends.removeAt(0);
          opened.add(backend);
          return backend;
        }),
      ],
    );
    container.read(callStateProvider);
  });
  tearDown(() async {
    container.dispose();
    await waitUntil(() => opened.every((backend) => backend.closed));
  });

  Future<_Telephony> connect() async {
    final backend = _Telephony('AA:BB');
    backends.add(backend);
    publish('AA:BB');
    await waitUntil(() => state().connected);
    return backend;
  }

  TelephonyCallInfo call(String id, PipeWireCallState status) =>
      TelephonyCallInfo(
        id: id,
        number: '123',
        name: '',
        state: status,
        multiparty: false,
      );
  void calls(_Telephony backend, List<TelephonyCallInfo> calls) => backend.emit(
    TelephonySnapshot(
      clientState: PipeWireTelephonyClientState.ready,
      gatewayAddress: 'AA:BB',
      calls: calls,
    ),
  );

  test(
    'all commands forward the selected gateway, call and arguments',
    () async {
      final backend = await connect();
      final notifier = container.read(callStateProvider.notifier);
      await notifier.startCall('456');
      calls(backend, [call('incoming', PipeWireCallState.incoming)]);
      await notifier.acceptCall();
      await notifier.rejectCall();
      await notifier.endCall();
      await notifier.hangupAll();
      await notifier.sendTones('12#');
      await notifier.setSpeakerVolume(99);
      await notifier.setMicrophoneVolume(-1);
      await notifier.activateTransport();
      await notifier.setRejectSco(true);
      calls(backend, [
        call('active', PipeWireCallState.active),
        call('waiting', PipeWireCallState.waiting),
      ]);
      await notifier.holdAndAnswer();
      await notifier.releaseAndAnswer();
      calls(backend, [
        call('active', PipeWireCallState.active),
        call('held', PipeWireCallState.held),
      ]);
      await notifier.swapCalls();
      await notifier.releaseAndSwap();
      await notifier.createMultiparty();
      expect(
        backend.operations,
        containsAllInOrder([
          ['dial', 'AA:BB', '456'],
          ['answer', 'incoming'],
          ['hangup', 'incoming'],
          ['hangup', 'incoming'],
          ['hangupAll', 'AA:BB'],
          ['sendTones', 'AA:BB', '12#'],
          ['setSpeakerVolume', 'AA:BB', 15],
          ['setMicrophoneVolume', 'AA:BB', 0],
          ['activateTransport', 'AA:BB'],
          ['setRejectSco', 'AA:BB', true],
          ['holdAndAnswer', 'AA:BB'],
          ['releaseAndAnswer', 'AA:BB'],
          ['swapCalls', 'AA:BB'],
          ['releaseAndSwap', 'AA:BB'],
          ['createMultiparty', 'AA:BB'],
        ]),
      );
    },
  );

  test('single call cannot invoke multi-call operations', () async {
    final backend = await connect();
    calls(backend, [call('one', PipeWireCallState.active)]);
    backend.operations.clear();
    final notifier = container.read(callStateProvider.notifier);
    await notifier.swapCalls();
    await notifier.releaseAndSwap();
    await notifier.createMultiparty();
    await notifier.holdAndAnswer();
    await notifier.releaseAndAnswer();
    expect(backend.operations, isEmpty);
  });

  test(
    'snapshot cannot unlock a pending command or allow duplicate taps',
    () async {
      final backend = await connect();
      backend.commandGate = Completer<void>();
      final notifier = container.read(callStateProvider.notifier);
      final pending = notifier.startCall('123');
      backend.emit(backend.current);
      expect(state().busy, isTrue);
      await notifier.startCall('123');
      await notifier.toggleMute();
      expect(backend.operations, [
        ['dial', 'AA:BB', '123'],
      ]);
      backend.commandGate!.complete();
      await pending;
      expect(state().busy, isFalse);
    },
  );

  for (final command in <String, Future<void> Function(CallStateNotifier)>{
    'dial': (n) => n.startCall('123'),
    'answer': (n) => n.acceptCall(),
    'hangup': (n) => n.endCall(),
    'hangupAll': (n) => n.hangupAll(),
    'tones': (n) => n.sendTones('#'),
    'swap': (n) => n.swapCalls(),
    'releaseAndSwap': (n) => n.releaseAndSwap(),
    'releaseAndAnswer': (n) => n.releaseAndAnswer(),
    'holdAndAnswer': (n) => n.holdAndAnswer(),
    'merge': (n) => n.createMultiparty(),
    'speaker': (n) => n.setSpeakerVolume(8),
    'microphone': (n) => n.toggleMute(),
    'activate': (n) => n.activateTransport(),
    'rejectSco': (n) => n.setRejectSco(true),
  }.entries) {
    test('${command.key} reports failure and unlocks controls', () async {
      final backend = await connect();
      calls(backend, [
        if (command.key != 'answer') ...[
          call('active', PipeWireCallState.active),
          call('held', PipeWireCallState.held),
        ],
        call('waiting', PipeWireCallState.waiting),
      ]);
      backend.commandError = StateError('command failed');
      await command.value(container.read(callStateProvider.notifier));
      expect(state().error, contains('command failed'));
      expect(state().busy, isFalse);
      expect(state().isMuted, isFalse);
    });
  }

  test(
    'removed transport and gateway fields clear instead of retaining values',
    () async {
      final backend = await connect();
      backend.emit(
        const TelephonySnapshot(
          clientState: PipeWireTelephonyClientState.ready,
          gatewayAddress: 'AA:BB',
          speakerVolume: 9,
          microphoneVolume: 7,
          transportState: PipeWireTransportState.active,
          codec: 2,
          rejectSco: true,
        ),
      );
      expect(state().codec, 2);
      backend.emit(
        const TelephonySnapshot(
          clientState: PipeWireTelephonyClientState.ready,
          gatewayAddress: 'AA:BB',
        ),
      );
      expect(state().codec, isNull);
      expect(state().transportState, isNull);
      expect(state().rejectSco, isNull);
      expect(state().speakerVolume, isNull);
      expect(state().microphoneVolume, isNull);
      backend.emit(
        const TelephonySnapshot(
          clientState: PipeWireTelephonyClientState.ready,
        ),
      );
      expect(state().gatewayAddress, isNull);
    },
  );

  for (final action in ['answer', 'hangup']) {
    test('$action ignores duplicate taps until completion', () async {
      final backend = await connect();
      calls(backend, [call('one', PipeWireCallState.incoming)]);
      backend.commandGate = Completer<void>();
      final notifier = container.read(callStateProvider.notifier);
      final command = action == 'answer'
          ? notifier.acceptCall
          : notifier.endCall;
      final pending = command();
      backend.emit(backend.current);
      await command();
      expect(state().busy, isTrue);
      expect(backend.operations, [
        [action, 'one'],
      ]);
      backend.commandGate!.complete();
      await pending;
      expect(state().busy, isFalse);
    });
  }

  test('mute and unmute restore the last nonzero microphone gain', () async {
    final backend = await connect();
    backend.emit(
      const TelephonySnapshot(
        clientState: PipeWireTelephonyClientState.ready,
        gatewayAddress: 'AA:BB',
        microphoneVolume: 11,
      ),
    );
    final notifier = container.read(callStateProvider.notifier);
    await notifier.toggleMute();
    expect(state().isMuted, isTrue);
    await notifier.toggleMute();
    expect(state().isMuted, isFalse);
    expect(backend.operations, [
      ['setMicrophoneVolume', 'AA:BB', 0],
      ['setMicrophoneVolume', 'AA:BB', 11],
    ]);
  });

  testWidgets('duration resets when the primary call identity changes', (
    tester,
  ) async {
    // Pump virtual time only after the asynchronous provider connection.
    late _Telephony backend;
    await tester.runAsync(() async {
      backend = await connect();
    });
    calls(backend, [call('one', PipeWireCallState.active)]);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1100)),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(state().duration.inSeconds, greaterThanOrEqualTo(1));
    calls(backend, [call('two', PipeWireCallState.active)]);
    expect(state().activeCallId, 'two');
    expect(state().duration, Duration.zero);
    publish(null);
    await tester.runAsync(() => waitUntil(() => backend.closed));
  });

  test(
    'retry after service closure binds a fresh backend and accepts commands',
    () async {
      final first = await connect();
      await first.controller.close();
      final second = _Telephony('AA:BB');
      backends.add(second);
      final notifier = container.read(callStateProvider.notifier);
      await notifier.retry();
      await notifier.startCall('456');
      expect(state().connected, isTrue);
      expect(second.operations, [
        ['dial', 'AA:BB', '456'],
      ]);
    },
  );

  test(
    'connects once per Bluetooth link and binds the selected phone address',
    () async {
      final backend = _Telephony('AA:BB');
      backends.add(backend);
      publish('AA:BB');
      publish('AA:BB');
      await waitUntil(() => state().connected);
      expect(selectedAddresses, ['AA:BB']);
      expect(backend.connects, 1);
      publish(null);
      await waitUntil(() => backend.closed);
      expect(state().connected, isFalse);
    },
  );

  test(
    'ignores a different phone gateway and clears calls when service ends',
    () async {
      final backend = _Telephony('AA:BB');
      backends.add(backend);
      publish('AA:BB');
      await waitUntil(() => state().connected);
      const call = TelephonyCallInfo(
        id: '/call/1',
        number: '+6012345',
        name: '',
        state: PipeWireCallState.incoming,
        multiparty: false,
      );
      backend.emit(
        const TelephonySnapshot(
          clientState: PipeWireTelephonyClientState.ready,
          gatewayAddress: 'CC:DD',
          calls: [call],
        ),
      );
      expect(state().connected, isFalse);
      expect(state().hasCall, isFalse);
      backend.emit(
        const TelephonySnapshot(
          clientState: PipeWireTelephonyClientState.ready,
          gatewayAddress: 'AA:BB',
          calls: [call],
        ),
      );
      expect(state().hasCall, isTrue);
      await backend.controller.close();
      expect(state().connected, isFalse);
      expect(state().hasCall, isFalse);
      expect(state().error, contains('disconnected'));
    },
  );

  test(
    'caller name updates when the cached phonebook becomes available',
    () async {
      final backend = _Telephony('AA:BB');
      backends.add(backend);
      publish('AA:BB');
      await waitUntil(() => state().connected);
      backend.emit(
        const TelephonySnapshot(
          clientState: PipeWireTelephonyClientState.ready,
          gatewayAddress: 'AA:BB',
          calls: [
            TelephonyCallInfo(
              id: '/call/1',
              number: '+6012345',
              name: '',
              state: PipeWireCallState.incoming,
              multiparty: false,
            ),
          ],
        ),
      );
      expect(state().name, '+6012345');
      (container.read(phoneDataProvider.notifier) as _ContactsNotifier).load(
        'AA:BB',
        [
          const PhoneContact(id: '1', name: 'Aisha', numbers: ['+60 12345']),
        ],
      );
      expect(state().name, 'Aisha');
    },
  );

  test('outgoing call keeps the selected contact name while dialing', () async {
    final backend = _Telephony('AA:BB');
    backends.add(backend);
    publish('AA:BB');
    await waitUntil(() => state().connected);
    await container
        .read(callStateProvider.notifier)
        .startCall('+6012345', name: 'Aisha');
    backend.emit(
      const TelephonySnapshot(
        clientState: PipeWireTelephonyClientState.ready,
        gatewayAddress: 'AA:BB',
        calls: [
          TelephonyCallInfo(
            id: '/call/outgoing',
            number: '+6012345',
            name: '',
            state: PipeWireCallState.dialing,
            multiparty: false,
          ),
        ],
      ),
    );
    expect(state().name, 'Aisha');
    expect(state().participants.single.name, 'Aisha');
    backend.emit(
      const TelephonySnapshot(
        clientState: PipeWireTelephonyClientState.ready,
        gatewayAddress: 'AA:BB',
        calls: [
          TelephonyCallInfo(
            id: '/call/outgoing',
            number: '+6012345',
            name: '',
            state: PipeWireCallState.active,
            multiparty: false,
          ),
        ],
      ),
    );
    expect(state().name, 'Aisha');
  });

  test(
    'caller names only come from the connected phone contact owner',
    () async {
      final backend = _Telephony('CC:DD');
      backends.add(backend);
      publish('CC:DD');
      await waitUntil(() => state().connected);
      final contacts =
          container.read(phoneDataProvider.notifier) as _ContactsNotifier;
      contacts.load('AA:BB', [
        const PhoneContact(
          id: '1',
          name: 'Aisha on phone A',
          numbers: ['+6012345'],
        ),
      ]);
      backend.emit(
        const TelephonySnapshot(
          clientState: PipeWireTelephonyClientState.ready,
          gatewayAddress: 'CC:DD',
          calls: [
            TelephonyCallInfo(
              id: '/call/1',
              number: '+6012345',
              name: '',
              state: PipeWireCallState.incoming,
              multiparty: false,
            ),
          ],
        ),
      );
      expect(state().name, '+6012345');
      contacts.load('CC:DD', [
        const PhoneContact(
          id: '1',
          name: 'Daniel on phone B',
          numbers: ['+6012345'],
        ),
      ]);
      expect(state().name, 'Daniel on phone B');
    },
  );

  test(
    'late connection and snapshots cannot restore the previous phone',
    () async {
      final first = _Telephony('AA:BB')..connectGate = Completer<void>();
      final second = _Telephony('CC:DD');
      backends.addAll([first, second]);
      publish('AA:BB');
      await waitUntil(() => first.connects == 1);
      publish('CC:DD');
      first.emit(
        const TelephonySnapshot(
          clientState: PipeWireTelephonyClientState.ready,
          gatewayAddress: 'AA:BB',
          calls: [
            TelephonyCallInfo(
              id: '/call/old',
              number: '123',
              name: 'Old phone',
              state: PipeWireCallState.incoming,
              multiparty: false,
            ),
          ],
        ),
      );
      expect(state().hasCall, isFalse);
      first.connectGate!.complete();
      await waitUntil(() => state().connected);
      expect(state().deviceAddress, 'CC:DD');
      expect(first.closed, isTrue);
      expect(state().participants, isEmpty);
    },
  );

  test('late mute completion cannot change the next phone state', () async {
    final first = _Telephony('AA:BB')..commandGate = Completer<void>();
    final second = _Telephony('CC:DD');
    backends.addAll([first, second]);
    publish('AA:BB');
    await waitUntil(() => state().connected);
    final mute = container.read(callStateProvider.notifier).toggleMute();
    publish('CC:DD');
    await waitUntil(
      () => state().deviceAddress == 'CC:DD' && state().connected,
    );
    first.commandGate!.complete();
    await mute;
    expect(state().isMuted, isFalse);
    expect(state().error, isNull);
  });
}
