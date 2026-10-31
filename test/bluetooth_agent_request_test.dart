import 'dart:io';

import 'package:bluez_native/bluez_native.dart';
import 'package:flutter_ics_homescreen/data/data_providers/bluetooth_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('interactive native pairing requests need a response', () {
    const request = BlueZAgentRequest(
      requestId: 1,
      requestType: AgentRequestType.requestPasskey,
      devicePath: '/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF',
    );

    expect(request.needsResponse, isTrue);
  });

  test('display-only pairing events do not wait for a response', () {
    const request = BlueZAgentRequest(
      requestId: 2,
      requestType: AgentRequestType.displayPasskey,
      devicePath: '/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF',
      passkey: 123456,
    );

    expect(request.needsResponse, isFalse);
  });

  test('rfkill unblock reports command failures', () async {
    await expectLater(
      unblockBluetoothRfkill(
        run: (executable, arguments) async {
          expect(executable, 'rfkill');
          expect(arguments, ['unblock', 'bluetooth']);
          return ProcessResult(1, 1, '', 'Operation not permitted');
        },
      ),
      throwsA(
        isA<ProcessException>()
            .having((error) => error.errorCode, 'exit code', 1)
            .having(
              (error) => error.message,
              'message',
              'Operation not permitted',
            ),
      ),
    );
  });
}
