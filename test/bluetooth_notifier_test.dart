import 'dart:async';

import 'package:bluez_native/bluez_native.dart';
import 'package:flutter_ics_homescreen/data/data_providers/bluetooth_notifier.dart';
import 'package:flutter_ics_homescreen/data/data_providers/signal_notifier.dart';
import 'package:flutter_ics_homescreen/data/models/connections_signals.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pairing limit is reached at ten devices', () {
    expect(bluetoothPairingLimitReached(9), isFalse);
    expect(bluetoothPairingLimitReached(10), isTrue);
  });

  test('media profile filter accepts only supported profile UUIDs', () {
    expect(
      bluetoothSupportsMediaProfile([
        '0000110A-0000-1000-8000-00805F9B34FB',
      ]),
      isTrue,
    );
    expect(
      bluetoothSupportsMediaProfile([
        '0000180d-0000-1000-8000-00805f9b34fb',
      ]),
      isFalse,
    );
  });

  test('Bluetooth signal ignores duplicate connection values', () async {
    final notifier = SignalNotifier(const Signals.initial());
    final values = <bool>[];
    final subscription = notifier.stream.listen(
      (state) => values.add(state.isBluetoothConnected),
    );

    notifier.setBluetoothConnected(false);
    notifier.setBluetoothConnected(true);
    notifier.setBluetoothConnected(true);
    await Future<void>.delayed(Duration.zero);

    expect(values, [true]);
    await subscription.cancel();
    notifier.dispose();
  });

  test('Bluetooth provider initializes once and disposes its client', () async {
    final client = _FakeBlueZClient();
    final container = ProviderContainer(
      overrides: [
        blueZClientFactoryProvider.overrideWithValue(() => client),
      ],
    );

    container.read(bluetoothProvider);
    container.read(bluetoothProvider);
    await container.read(bluetoothProvider.notifier).ensureInitialized();

    expect(client.connectCalls, 1);
    expect(container.read(bluetoothProvider).nativeAvailable, isTrue);

    container.dispose();
    expect(client.closed, isTrue);
  });
}

class _FakeBlueZClient extends BlueZClient {
  int connectCalls = 0;
  bool closed = false;

  @override
  List<BlueZAdapter> get adapters => const [];

  @override
  List<BlueZDevice> get devices => const [];

  @override
  Stream<BlueZDevice> get deviceAdded => const Stream.empty();

  @override
  Stream<BlueZDevice> get deviceRemoved => const Stream.empty();

  @override
  Stream<BlueZDevice> get deviceChanged => const Stream.empty();

  @override
  Stream<BlueZAdapter> get adapterChanged => const Stream.empty();

  @override
  Stream<BlueZAgentRequest> get agentRequest => const Stream.empty();

  @override
  Future<void> connect() async => connectCalls++;

  @override
  void registerAgent() {}

  @override
  void unregisterAgent() {}

  @override
  Future<void> close() async => closed = true;
}
