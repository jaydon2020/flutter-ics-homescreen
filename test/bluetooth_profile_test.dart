import 'dart:async';

import 'package:bluez_native/bluez_native.dart';
import 'package:flutter_ics_homescreen/data/data_providers/bluetooth_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

class _ProfileDevice implements BlueZDevice {
  _ProfileDevice({
    required List<String> uuids,
    this.failProfiles = const {},
    this.alreadyConnectedProfiles = const {},
  }) : _uuids = uuids.map(BlueZUUID.new).toList();

  final List<BlueZUUID> _uuids;
  final Set<String> failProfiles;
  final Set<String> alreadyConnectedProfiles;
  final connectedProfiles = <String>[];
  final _properties = StreamController<List<String>>.broadcast();
  bool generalConnectCalled = false;
  @override
  bool connected = false;

  @override
  List<BlueZUUID> get uuids => _uuids;

  @override
  Stream<List<String>> get propertiesChanged => _properties.stream;

  @override
  Future<void> connect() async {
    generalConnectCalled = true;
    connected = true;
    _properties.add(const ['Connected']);
  }

  @override
  Future<void> connectProfile(BlueZUUID uuid) async {
    connectedProfiles.add(uuid.value);
    if (alreadyConnectedProfiles.contains(uuid.value)) {
      throw const BlueZOperationException(
        'Already connected',
        name: 'org.bluez.Error.AlreadyConnected',
      );
    }
    if (failProfiles.contains(uuid.value)) {
      throw const BlueZOperationException(
        'Profile unavailable',
        name: 'org.bluez.Error.NotAvailable',
      );
    }
    connected = true;
    _properties.add(const ['Connected']);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Unexpected Bluetooth operation: ${invocation.memberName}',
  );
}

void main() {
  test('connects a media profile without requiring HFP', () async {
    final device = _ProfileDevice(
      uuids: [bluetoothA2dpSourceUuid, bluetoothHfpAudioGatewayUuid],
    );

    await connectBlueZDeviceWithoutRequiredHfp(device);

    expect(device.connected, isTrue);
    expect(device.generalConnectCalled, isFalse);
    expect(device.connectedProfiles, [bluetoothA2dpSourceUuid]);
  });

  test('tries AVRCP when A2DP is unavailable', () async {
    final device = _ProfileDevice(
      uuids: [bluetoothA2dpSourceUuid, bluetoothAvrcpUuid],
      failProfiles: {bluetoothA2dpSourceUuid},
    );

    await connectBlueZDeviceWithoutRequiredHfp(device);

    expect(device.connected, isTrue);
    expect(device.connectedProfiles, [
      bluetoothA2dpSourceUuid,
      bluetoothAvrcpUuid,
    ]);
  });

  test(
    'falls back to the general connection without a media profile',
    () async {
      final device = _ProfileDevice(uuids: [bluetoothHfpAudioGatewayUuid]);

      await connectBlueZDeviceWithoutRequiredHfp(device);

      expect(device.connected, isTrue);
      expect(device.generalConnectCalled, isTrue);
    },
  );

  test('an already connected profile is successful', () async {
    final device = _ProfileDevice(
      uuids: [bluetoothHfpAudioGatewayUuid],
      alreadyConnectedProfiles: {bluetoothHfpAudioGatewayUuid},
    );

    await expectLater(
      connectBlueZProfile(device, bluetoothHfpAudioGatewayUuid),
      completes,
    );
  });

  test('hands-free UUID matching is case insensitive', () {
    expect(
      bluetoothSupportsHandsFreeProfile([
        bluetoothHfpAudioGatewayUuid.toUpperCase(),
      ]),
      isTrue,
    );
    expect(bluetoothSupportsHandsFreeProfile(const []), isFalse);
  });
}
