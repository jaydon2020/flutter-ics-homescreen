import 'package:flutter_ics_homescreen/export.dart';

class SignalNotifier extends StateNotifier<Signals> {
  SignalNotifier(super.state);

  void startListen() {}

  void setBluetooth(bool isConnected) {
    state = state.copyWith(isBluetoothConnected: isConnected);
  }

  void toggleBluetooth() {
    state = state.copyWith(isBluetoothConnected: !state.isBluetoothConnected);
  }

  void toggleWifi() {
    state = state.copyWith(isWifiConnected: !state.isWifiConnected);
  }
}
