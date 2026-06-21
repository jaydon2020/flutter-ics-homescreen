import 'dart:async';

import 'package:bluez_native_comms/bluez_native_comms.dart';
import 'package:flutter_ics_homescreen/export.dart';

class BluetoothPowerNotifier extends AsyncNotifier<BluetoothPowerState> {
  BlueZClient? _client;
  BlueZAdapter? _adapter;
  StreamSubscription<BlueZDevice>? _deviceAddedSub;
  StreamSubscription<BlueZDevice>? _deviceRemovedSub;
  Timer? _scanTimeoutTimer;
  final Map<String, BluetoothDeviceInfo> _devices = {};
  final Map<String, BlueZDevice> _bluezDevices = {};
  final Map<String, StreamSubscription<List<String>>> _deviceChangedSubs = {};

  @override
  Future<BluetoothPowerState> build() async {
    ref.onDispose(() {
      _adapter?.stopDiscovery();
      _scanTimeoutTimer?.cancel();
      _deviceAddedSub?.cancel();
      _deviceRemovedSub?.cancel();
      for (final subscription in _deviceChangedSubs.values) {
        subscription.cancel();
      }
      _client?.close();
      _deviceAddedSub = null;
      _deviceRemovedSub = null;
      _client = null;
      _adapter = null;
      _devices.clear();
      _bluezDevices.clear();
      _deviceChangedSubs.clear();
    });

    if (!Platform.isLinux) {
      return const BluetoothPowerState(
        isPowered: false,
        error: 'Bluetooth controls are only available on Linux.',
      );
    }

    return _connect();
  }

  Future<BluetoothPowerState> _connect() async {
    try {
      final client = BlueZClient();
      await client.connect();
      _client = client;

      final adapters = client.adapters;
      if (adapters.isEmpty) {
        _syncSignal(false);
        return const BluetoothPowerState(
          isPowered: false,
          error: 'No Bluetooth adapter found.',
        );
      }

      final adapter = adapters.first;
      _adapter = adapter;
      _seedDevices(client.devices);
      _listenForDevices(client);
      _syncSignal(adapter.powered);

      return BluetoothPowerState(
        isPowered: adapter.powered,
        isScanning: adapter.discovering,
        adapterName: _adapterDisplayName(adapter),
        devices: _sortedDevices(),
      );
    } catch (error) {
      _syncSignal(false);
      return BluetoothPowerState(
        isPowered: false,
        error: error.toString(),
      );
    }
  }

  Future<void> setPowered(bool enabled) async {
    final previous = state.valueOrNull ?? const BluetoothPowerState.initial();
    state = AsyncData(previous.copyWith(isChanging: true, clearError: true));

    try {
      final adapter = _adapter ?? await _resolveAdapter();
      await adapter.setPowered(enabled);

      final updated = previous.copyWith(
        isPowered: enabled,
        isChanging: false,
        isScanning: enabled ? previous.isScanning : false,
        adapterName: _adapterDisplayName(adapter),
        devices: enabled ? previous.devices : const [],
        clearError: true,
      );
      if (!enabled) {
        _devices.clear();
        _bluezDevices.clear();
        _scanTimeoutTimer?.cancel();
      }
      _syncSignal(enabled);
      state = AsyncData(updated);
    } catch (error, stackTrace) {
      _syncSignal(previous.isPowered);
      state = AsyncData(previous.copyWith(
        isChanging: false,
        error: error.toString(),
      ));
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'bluetooth_notifier',
        context: ErrorDescription('while changing Bluetooth power state'),
      ));
    }
  }

  Future<void> startScan() async {
    final previous = state.valueOrNull ?? const BluetoothPowerState.initial();
    state = AsyncData(previous.copyWith(clearError: true));

    try {
      final adapter = _adapter ?? await _resolveAdapter();
      if (!adapter.powered) {
        await adapter.setPowered(true);
        _syncSignal(true);
      }

      _seedDevices(_client?.devices ?? const []);
      await adapter.startDiscovery();
      _scheduleScanTimeout();

      state = AsyncData(previous.copyWith(
        isPowered: true,
        isScanning: true,
        adapterName: _adapterDisplayName(adapter),
        devices: _sortedDevices(),
        clearError: true,
      ));
    } catch (error, stackTrace) {
      state = AsyncData(previous.copyWith(
        isScanning: false,
        error: error.toString(),
      ));
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'bluetooth_notifier',
        context: ErrorDescription('while starting Bluetooth discovery'),
      ));
    }
  }

  Future<void> stopScan() async {
    final previous = state.valueOrNull ?? const BluetoothPowerState.initial();

    try {
      final adapter = _adapter ?? await _resolveAdapter();
      await adapter.stopDiscovery();
      _scanTimeoutTimer?.cancel();
      state = AsyncData(previous.copyWith(
        isScanning: false,
        adapterName: _adapterDisplayName(adapter),
        devices: _sortedDevices(),
        clearError: true,
      ));
    } catch (error, stackTrace) {
      state = AsyncData(previous.copyWith(
        isScanning: false,
        error: error.toString(),
      ));
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'bluetooth_notifier',
        context: ErrorDescription('while stopping Bluetooth discovery'),
      ));
    }
  }

  Future<void> toggleScan() async {
    if (state.valueOrNull?.isScanning ?? false) {
      await stopScan();
    } else {
      await startScan();
    }
  }

  void _scheduleScanTimeout() {
    _scanTimeoutTimer?.cancel();
    _scanTimeoutTimer = Timer(const Duration(minutes: 1), () {
      stopScan();
    });
  }

  void clearError() {
    final current = state.valueOrNull;
    if (current == null) {
      state = const AsyncData(BluetoothPowerState.initial());
      return;
    }
    state = AsyncData(current.copyWith(clearError: true));
  }

  Future<void> renameAdapter(String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return;
    }

    final previous = state.valueOrNull ?? const BluetoothPowerState.initial();
    state = AsyncData(previous.copyWith(isChanging: true, clearError: true));

    try {
      final adapter = _adapter ?? await _resolveAdapter();
      final result = await Process.run('busctl', [
        'set-property',
        'org.bluez',
        adapter.objectPath,
        'org.bluez.Adapter1',
        'Alias',
        's',
        trimmedName,
      ]);

      if (result.exitCode != 0) {
        final message = result.stderr.toString().trim();
        throw StateError(
            message.isEmpty ? 'Unable to rename Bluetooth device.' : message);
      }

      final current = state.valueOrNull ?? previous;
      state = AsyncData(current.copyWith(
        isChanging: false,
        adapterName: trimmedName,
        clearError: true,
      ));
    } catch (error, stackTrace) {
      final current = state.valueOrNull ?? previous;
      state = AsyncData(current.copyWith(
        isChanging: false,
        error: error.toString(),
      ));
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'bluetooth_notifier',
        context: ErrorDescription('while renaming Bluetooth adapter'),
      ));
    }
  }

  Future<void> connectDevice(String deviceId) async {
    await _updateDeviceConnection(deviceId, connect: true);
  }

  Future<void> disconnectDevice(String deviceId) async {
    await _updateDeviceConnection(deviceId, connect: false);
  }

  Future<void> pairDevice(String deviceId) async {
    await _runDeviceOperation(
      deviceId,
      context: 'while pairing Bluetooth device',
      operation: (device) => device.pair(),
    );
  }

  Future<void> cancelPairing(String deviceId) async {
    await _runDeviceOperation(
      deviceId,
      context: 'while cancelling Bluetooth pairing',
      operation: (device) => device.cancelPairing(),
    );
  }

  Future<void> waitForServicesResolved(String deviceId) async {
    await _runDeviceOperation(
      deviceId,
      context: 'while resolving Bluetooth services',
      operation: (device) => device.waitForServicesResolved(),
    );
  }

  Future<void> setDeviceTrusted(String deviceId, bool trusted) async {
    await _setDeviceProperty(deviceId, 'Trusted', 'b', trusted.toString());
  }

  Future<void> setDeviceBlocked(String deviceId, bool blocked) async {
    await _setDeviceProperty(deviceId, 'Blocked', 'b', blocked.toString());
  }

  Future<void> renameDevice(String deviceId, String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return;
    }
    await _setDeviceProperty(deviceId, 'Alias', 's', trimmedName);
  }

  Future<void> forgetDevice(String deviceId) async {
    final previous = state.valueOrNull ?? const BluetoothPowerState.initial();
    try {
      final adapter = _adapter ?? await _resolveAdapter();
      await adapter.removeDevice(deviceId);
      _devices.remove(deviceId);
      _bluezDevices.remove(deviceId);
      _deviceChangedSubs.remove(deviceId)?.cancel();
      _publishDeviceList();
    } catch (error, stackTrace) {
      state = AsyncData(previous.copyWith(
        error: error.toString(),
      ));
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'bluetooth_notifier',
        context: ErrorDescription('while forgetting Bluetooth device'),
      ));
    }
  }

  Future<void> _updateDeviceConnection(
    String deviceId, {
    required bool connect,
  }) async {
    final previous = state.valueOrNull ?? const BluetoothPowerState.initial();
    state = AsyncData(previous.copyWith(
      busyDeviceId: deviceId,
      clearError: true,
    ));

    try {
      final device = _bluezDevices[deviceId];
      if (device == null) {
        throw StateError('Bluetooth device is no longer available.');
      }

      if (connect) {
        if (_adapter?.discovering ?? previous.isScanning) {
          await _adapter?.stopDiscovery();
        }
        await device.connect();
      } else {
        await device.disconnect();
      }

      _upsertDevice(device);
      final current = state.valueOrNull ?? previous;
      state = AsyncData(current.copyWith(
        isScanning: connect ? false : current.isScanning,
        devices: _sortedDevices(),
        clearBusyDevice: true,
        clearError: true,
      ));
    } catch (error, stackTrace) {
      final current = state.valueOrNull ?? previous;
      state = AsyncData(current.copyWith(
        clearBusyDevice: true,
        error: error.toString(),
      ));
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'bluetooth_notifier',
        context: ErrorDescription(connect
            ? 'while connecting Bluetooth device'
            : 'while disconnecting Bluetooth device'),
      ));
    }
  }

  Future<void> _runDeviceOperation(
    String deviceId, {
    required String context,
    required Future<void> Function(BlueZDevice device) operation,
  }) async {
    final previous = state.valueOrNull ?? const BluetoothPowerState.initial();
    state = AsyncData(previous.copyWith(
      busyDeviceId: deviceId,
      clearError: true,
    ));

    try {
      final device = _bluezDevices[deviceId];
      if (device == null) {
        throw StateError('Bluetooth device is no longer available.');
      }

      await operation(device);
      _upsertDevice(device);
      final current = state.valueOrNull ?? previous;
      state = AsyncData(current.copyWith(
        devices: _sortedDevices(),
        clearBusyDevice: true,
        clearError: true,
      ));
    } catch (error, stackTrace) {
      final current = state.valueOrNull ?? previous;
      state = AsyncData(current.copyWith(
        clearBusyDevice: true,
        error: error.toString(),
      ));
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'bluetooth_notifier',
        context: ErrorDescription(context),
      ));
    }
  }

  Future<void> _setDeviceProperty(
    String deviceId,
    String property,
    String signature,
    String value,
  ) async {
    final previous = state.valueOrNull ?? const BluetoothPowerState.initial();
    state = AsyncData(previous.copyWith(
      busyDeviceId: deviceId,
      clearError: true,
    ));

    try {
      final device = _bluezDevices[deviceId];
      if (device == null) {
        throw StateError('Bluetooth device is no longer available.');
      }

      final result = await Process.run('busctl', [
        'set-property',
        'org.bluez',
        device.objectPath,
        'org.bluez.Device1',
        property,
        signature,
        value,
      ]);

      if (result.exitCode != 0) {
        final message = result.stderr.toString().trim();
        throw StateError(message.isEmpty
            ? 'Unable to update Bluetooth device property.'
            : message);
      }

      final current = state.valueOrNull ?? previous;
      state = AsyncData(current.copyWith(
        clearBusyDevice: true,
        clearError: true,
      ));
    } catch (error, stackTrace) {
      final current = state.valueOrNull ?? previous;
      state = AsyncData(current.copyWith(
        clearBusyDevice: true,
        error: error.toString(),
      ));
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'bluetooth_notifier',
        context: ErrorDescription('while updating Bluetooth device property'),
      ));
    }
  }

  Future<BlueZAdapter> _resolveAdapter() async {
    if (_adapter != null) {
      return _adapter!;
    }

    final currentState = await _connect();
    state = AsyncData(currentState);

    final adapter = _adapter;
    if (adapter == null) {
      throw StateError(currentState.error ?? 'No Bluetooth adapter found.');
    }
    return adapter;
  }

  void _listenForDevices(BlueZClient client) {
    _deviceAddedSub ??= client.deviceAdded.listen(_upsertDevice);
    _deviceRemovedSub ??= client.deviceRemoved.listen((device) {
      _devices.remove(device.objectPath);
      _bluezDevices.remove(device.objectPath);
      _deviceChangedSubs.remove(device.objectPath)?.cancel();
      _publishDeviceList();
    });
  }

  void _seedDevices(List<BlueZDevice> devices) {
    for (final device in devices) {
      _storeDevice(device);
    }
  }

  void _upsertDevice(BlueZDevice device) {
    _storeDevice(device);
    _publishDeviceList();
  }

  void _storeDevice(BlueZDevice device) {
    _bluezDevices[device.objectPath] = device;
    _devices[device.objectPath] = _deviceInfoFrom(device);
    _deviceChangedSubs[device.objectPath] ??=
        device.propertiesChanged.listen((_) {
      _devices[device.objectPath] = _deviceInfoFrom(device);
      _publishDeviceList();
    });
  }

  void _publishDeviceList() {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    state = AsyncData(current.copyWith(devices: _sortedDevices()));
  }

  List<BluetoothDeviceInfo> _sortedDevices() {
    final devices = _devices.values.toList()
      ..sort((a, b) {
        if (a.connected && !b.connected) {
          return -1;
        }
        if (!a.connected && b.connected) {
          return 1;
        }
        final rssiCompare = b.rssi.compareTo(a.rssi);
        if (rssiCompare != 0) {
          return rssiCompare;
        }
        return a.name.compareTo(b.name);
      });
    return List.unmodifiable(devices);
  }

  BluetoothDeviceInfo _deviceInfoFrom(BlueZDevice device) {
    return BluetoothDeviceInfo(
      id: device.objectPath,
      name: device.alias.isNotEmpty
          ? device.alias
          : device.name.isNotEmpty
              ? device.name
              : device.address,
      alias: device.alias,
      address: device.address,
      addressType: device.addressType,
      rssi: device.rssi,
      txPower: device.txPower,
      appearance: device.appearance,
      deviceClass: device.deviceClass,
      paired: device.paired,
      trusted: device.trusted,
      blocked: device.blocked,
      connected: device.connected,
      servicesResolved: device.servicesResolved,
      uuids: device.uuids.map((uuid) => uuid.toString()).toList(),
    );
  }

  String _adapterDisplayName(BlueZAdapter adapter) {
    return adapter.alias.trim().isNotEmpty ? adapter.alias : adapter.name;
  }

  void _syncSignal(bool isPowered) {
    ref.read(signalsProvider.notifier).setBluetooth(isPowered);
  }
}
