import 'package:flutter_ics_homescreen/export.dart';

class SignalNotifier extends StateNotifier<Signals> {
  SignalNotifier(super.state);

  void startListen() {}

  void toggleBluetooth([bool? isConnected]) {
    state = state.copyWith(
      isBluetoothConnected: isConnected ?? !state.isBluetoothConnected,
    );
  }

  void toggleWifi() {
    state = state.copyWith(isWifiConnected: !state.isWifiConnected);
  }
}
