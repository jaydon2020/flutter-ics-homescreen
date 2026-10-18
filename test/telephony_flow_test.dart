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
  void load(List<PhoneContact> contacts) =>
      state = state.copyWith(contacts: contacts);
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

  @override
  Future<void> setMicrophoneVolume(String address, int volume) async {
    if (commandGate != null) await commandGate!.future;
  }

  @override
  Future<void> activateTransport(String address) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Unexpected telephony operation: ${invocation.memberName}',
  );
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
      (container.read(phoneDataProvider.notifier) as _ContactsNotifier).load([
        const PhoneContact(id: '1', name: 'Aisha', numbers: ['+60 12345']),
      ]);
      expect(state().name, 'Aisha');
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
