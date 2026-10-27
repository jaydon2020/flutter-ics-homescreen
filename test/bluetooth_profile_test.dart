import 'package:dbus/dbus.dart';
import 'package:flutter_ics_homescreen/data/data_providers/bluetooth_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingBus implements DBusClient {
  String? destination;
  DBusObjectPath? path;
  String? interface;
  String? method;
  List<DBusValue> values = const [];
  String? errorName;

  @override
  Future<DBusMethodSuccessResponse> callMethod({
    String? destination,
    required DBusObjectPath path,
    String? interface,
    required String name,
    Iterable<DBusValue> values = const [],
    DBusSignature? replySignature,
    bool noReplyExpected = false,
    bool noAutoStart = false,
    bool allowInteractiveAuthorization = false,
  }) async {
    this.destination = destination;
    this.path = path;
    this.interface = interface;
    method = name;
    this.values = values.toList();
    if (errorName case final name?) {
      throw DBusMethodResponseException(DBusMethodErrorResponse(name));
    }
    return DBusMethodSuccessResponse();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'ConnectProfile targets the selected BlueZ device and HFP UUID',
    () async {
      final bus = _RecordingBus();

      await connectBlueZProfile(
        bus,
        '/org/bluez/hci0/dev_AA_BB',
        bluetoothHfpAudioGatewayUuid,
      );

      expect(bus.destination, 'org.bluez');
      expect(bus.path?.value, '/org/bluez/hci0/dev_AA_BB');
      expect(bus.interface, 'org.bluez.Device1');
      expect(bus.method, 'ConnectProfile');
      expect(bus.values.single, const DBusString(bluetoothHfpAudioGatewayUuid));
    },
  );

  test('an already connected HFP profile is successful', () async {
    final bus = _RecordingBus()..errorName = 'org.bluez.Error.AlreadyConnected';

    await expectLater(
      connectBlueZProfile(bus, '/device', bluetoothHfpAudioGatewayUuid),
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
