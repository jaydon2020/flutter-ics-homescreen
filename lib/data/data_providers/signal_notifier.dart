import 'package:flutter_ics_homescreen/export.dart';

class SignalNotifier extends StateNotifier<Signals> {
  SignalNotifier(super.state);

  void setBluetoothConnected(bool isConnected) {
    if (state.isBluetoothConnected == isConnected) return;
    state = state.copyWith(isBluetoothConnected: isConnected);
  }

  void toggleWifi() {
    state = state.copyWith(isWifiConnected: !state.isWifiConnected);
  }
}
