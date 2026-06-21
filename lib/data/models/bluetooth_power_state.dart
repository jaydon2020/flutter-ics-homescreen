import 'package:flutter_ics_homescreen/export.dart';

@immutable
class BluetoothDeviceInfo {
  final String id;
  final String name;
  final String alias;
  final String address;
  final String addressType;
  final int rssi;
  final int txPower;
  final int appearance;
  final int deviceClass;
  final bool paired;
  final bool trusted;
  final bool blocked;
  final bool connected;
  final bool servicesResolved;
  final List<String> uuids;

  const BluetoothDeviceInfo({
    required this.id,
    required this.name,
    this.alias = '',
    required this.address,
    this.addressType = '',
    required this.rssi,
    this.txPower = 0,
    this.appearance = 0,
    this.deviceClass = 0,
    required this.paired,
    this.trusted = false,
    this.blocked = false,
    required this.connected,
    this.servicesResolved = false,
    this.uuids = const [],
  });

  bool get isSavedOnly => paired && !connected && rssi == 0;
}

@immutable
class BluetoothPowerState {
  final bool isPowered;
  final bool isChanging;
  final bool isScanning;
  final String? adapterName;
  final List<BluetoothDeviceInfo> devices;
  final String? busyDeviceId;
  final String? error;

  const BluetoothPowerState({
    required this.isPowered,
    this.isChanging = false,
    this.isScanning = false,
    this.adapterName,
    this.devices = const [],
    this.busyDeviceId,
    this.error,
  });

  const BluetoothPowerState.initial()
      : isPowered = false,
        isChanging = false,
        isScanning = false,
        adapterName = null,
        devices = const [],
        busyDeviceId = null,
        error = null;

  BluetoothPowerState copyWith({
    bool? isPowered,
    bool? isChanging,
    bool? isScanning,
    String? adapterName,
    List<BluetoothDeviceInfo>? devices,
    String? busyDeviceId,
    String? error,
    bool clearBusyDevice = false,
    bool clearError = false,
  }) {
    return BluetoothPowerState(
      isPowered: isPowered ?? this.isPowered,
      isChanging: isChanging ?? this.isChanging,
      isScanning: isScanning ?? this.isScanning,
      adapterName: adapterName ?? this.adapterName,
      devices: devices ?? this.devices,
      busyDeviceId: clearBusyDevice ? null : busyDeviceId ?? this.busyDeviceId,
      error: clearError ? null : error ?? this.error,
    );
  }
}
