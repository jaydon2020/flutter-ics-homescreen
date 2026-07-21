import 'dart:async';

import 'package:bluez_native/bluez_native.dart';
import 'package:flutter_ics_homescreen/export.dart';

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

enum BluetoothOperation { connecting, disconnecting, removing, switching }

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class BluetoothState {
  const BluetoothState({
    this.devices = const [],
    this.powered = false,
    this.changingPower = false,
    this.scanning = false,
    this.pairable = false,
    this.discoverable = false,
    this.scanTimedOut = false,
    this.busyAddress,
    this.operation,
    this.pairingRequest,
    this.error,
  });

  final List<BlueZDevice> devices;
  final bool powered;
  final bool changingPower;
  final bool scanning;

  /// True only while the Scan for New Device page is open.
  final bool pairable;

  /// True only while the Scan for New Device page is open.
  final bool discoverable;

  /// True when the 2-minute scan timeout fires; drives the Refresh button.
  final bool scanTimedOut;

  final String? busyAddress;
  final BluetoothOperation? operation;
  final BlueZAgentRequest? pairingRequest;
  final String? error;

  // Derived lists ─────────────────────────────────────────────────────────────

  /// Paired devices sorted: connected first, then alphabetically.
  List<BlueZDevice> get pairedDevices => devices.where((d) => d.paired).toList()
    ..sort((a, b) {
      if (a.connected != b.connected) return a.connected ? -1 : 1;
      return bluetoothDeviceName(a).compareTo(bluetoothDeviceName(b));
    });

  /// Unpaired discovered devices sorted by RSSI (strongest first).
  List<BlueZDevice> get unpairedDevices =>
      devices.where((d) => !d.paired).toList()
        ..sort((a, b) => b.rssi.compareTo(a.rssi));

  // copyWith ──────────────────────────────────────────────────────────────────

  BluetoothState copyWith({
    List<BlueZDevice>? devices,
    bool? powered,
    bool? changingPower,
    bool? scanning,
    bool? pairable,
    bool? discoverable,
    bool? scanTimedOut,
    String? busyAddress,
    BluetoothOperation? operation,
    bool clearBusyAddress = false,
    BlueZAgentRequest? pairingRequest,
    bool clearPairingRequest = false,
    String? error,
    bool clearError = false,
  }) {
    return BluetoothState(
      devices: devices ?? this.devices,
      powered: powered ?? this.powered,
      changingPower: changingPower ?? this.changingPower,
      scanning: scanning ?? this.scanning,
      pairable: pairable ?? this.pairable,
      discoverable: discoverable ?? this.discoverable,
      scanTimedOut: scanTimedOut ?? this.scanTimedOut,
      busyAddress: clearBusyAddress ? null : busyAddress ?? this.busyAddress,
      operation: clearBusyAddress ? null : operation ?? this.operation,
      pairingRequest:
          clearPairingRequest ? null : pairingRequest ?? this.pairingRequest,
      error: clearError ? null : error ?? this.error,
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String bluetoothDeviceName(BlueZDevice device) {
  if (device.alias.isNotEmpty) return device.alias;
  if (device.name.isNotEmpty) return device.name;
  return device.address;
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class BluetoothNotifier extends StateNotifier<BluetoothState> {
  BluetoothNotifier(this.ref) : super(const BluetoothState()) {
    unawaited(ensureInitialized());
  }

  final Ref ref;
  final BlueZClient _client = BlueZClient();
  final Map<String, BlueZDevice> _devices = {};
  final Set<String> _connectedAddresses = {};

  Future<void>? _initialization;
  StreamSubscription<BlueZDevice>? _deviceAddedSub;
  StreamSubscription<BlueZDevice>? _deviceRemovedSub;
  StreamSubscription<BlueZDevice>? _deviceChangedSub;
  StreamSubscription<BlueZAdapter>? _adapterChangedSub;
  StreamSubscription<BlueZAgentRequest>? _agentRequestSub;
  Timer? _scanTimer;
  bool _agentRegistered = false;

  BlueZAdapter? get _adapter =>
      _client.adapters.isEmpty ? null : _client.adapters.first;

  /// True when the Bluetooth page (paired list) or Scan page is in the
  /// foreground. Connections initiated externally are rejected when false.
  bool get _isOnBluetoothPage {
    final s = ref.read(appProvider);
    return s == AppState.bluetooth || s == AppState.bluetoothScan;
  }

  Future<void> ensureInitialized() =>
      _initialization ??= _initializeBluetooth();

  // ── Initialisation ─────────────────────────────────────────────────────────

  Future<void> _initializeBluetooth() async {
    try {
      await _client.connect();

      // The BlueZ agent is registered at startup to handle authorizeService for
      // incoming connections. Unsolicited pairing requests are rejected unless
      // we are in scan mode or explicitly connecting to a device.
      _client.registerAgent();
      _agentRegistered = true;
      _agentRequestSub = _client.agentRequest.listen(_handleAgentRequest);

      _deviceAddedSub = _client.deviceAdded.listen((device) {
        _devices[device.address] = device;
        _trackConnectionChange(device);
        _publishDevices();
      });
      _deviceRemovedSub = _client.deviceRemoved.listen((device) {
        _devices.remove(device.address);
        _connectedAddresses.remove(device.address);
        _publishDevices();
      });
      _deviceChangedSub = _client.deviceChanged.listen((device) {
        _devices[device.address] = device;
        _trackConnectionChange(device);
        _publishDevices();
      });
      _adapterChangedSub = _client.adapterChanged.listen((adapter) {
        state = state.copyWith(
          powered: adapter.powered,
          scanning: adapter.powered && adapter.discovering,
          pairable: adapter.pairable,
          discoverable: adapter.discoverable,
          clearBusyAddress: !adapter.powered,
          clearPairingRequest: !adapter.powered,
        );
      });

      for (final device in _client.devices) {
        _devices[device.address] = device;
        if (device.connected) _connectedAddresses.add(device.address);
      }

      state = state.copyWith(powered: _adapter?.powered ?? false);
      _publishDevices();
      unawaited(_enforceInitialSingleConnection());
    } catch (e) {
      state = state.copyWith(error: 'Bluetooth is unavailable: $e');
    }
  }

  // ── Agent request handling ─────────────────────────────────────────────────

  void _handleAgentRequest(BlueZAgentRequest request) {
    final device = _deviceForPath(request.devicePath);
    final isBusyDevice = device != null && state.busyAddress == device.address;

    switch (request.requestType) {
      case AgentRequestType.authorizeService:
        if (device == null) {
          _client.agentRespond(request.requestId, accepted: false);
          return;
        }
        if (isBusyDevice) {
          _client.agentRespond(request.requestId, accepted: true);
          return;
        }
        if (!_isOnBluetoothPage) {
          // Device connected from outside AGL (e.g. from the phone's BT
          // settings) while the BT page is not open — reject the service.
          print(
              'Bluetooth: Rejecting external service auth for ${device.address} (not on BT page)');
          _client.agentRespond(request.requestId, accepted: false);
          return;
        }
        if (_connectedDeviceExcept(device) != null) {
          state = state.copyWith(pairingRequest: request);
          return;
        }
        _client.agentRespond(request.requestId, accepted: device.paired);
      case AgentRequestType.cancel:
      case AgentRequestType.release:
        print(
            'Bluetooth: Agent request cancelled by BlueZ (type: ${request.requestType}) for ${device?.address}');
        state = state.copyWith(clearPairingRequest: true);
        unawaited(_cleanupFailedPairing(device, isAgentCancel: true));
        // Restart discovery so the scan page doesn't get stuck.
        unawaited(_startDiscovery());
        return;
      default:
        if (!state.scanning && !isBusyDevice) {
          print(
              'Bluetooth: Rejecting unsolicited pairing request for ${device?.address}');
          _client.agentRespond(request.requestId, accepted: false);
          unawaited(_cleanupFailedPairing(device, cancelPairing: false));
          state = state.copyWith(clearPairingRequest: true);
          return;
        }
        state = state.copyWith(pairingRequest: request);
    }
  }

  // ── Connection tracking ────────────────────────────────────────────────────

  void _trackConnectionChange(BlueZDevice device) {
    final wasConnected = _connectedAddresses.contains(device.address);
    if (device.connected) {
      _connectedAddresses.add(device.address);
    } else {
      _connectedAddresses.remove(device.address);
    }

    if (device.connected &&
        !wasConnected &&
        state.pairingRequest == null &&
        state.busyAddress != device.address) {
      if (!_isOnBluetoothPage) {
        // Connection was not initiated from AGL's BT page — disconnect it
        // silently rather than showing a switch dialog or allowing it.
        print(
            'Bluetooth: Disconnecting external connection from ${device.address} (not on BT page)');
        unawaited(device.disconnect());
        _connectedAddresses.remove(device.address);
        _publishDevices();
        return;
      }
      if (_connectedDeviceExcept(device) != null) {
        unawaited(_stageIncomingDeviceSwitch(device));
      }
    }
  }

  Future<void> _enforceInitialSingleConnection() async {
    final connected = _devices.values.where((d) => d.connected).toList();
    if (connected.length < 2 || state.pairingRequest != null) return;
    await _stageIncomingDeviceSwitch(connected.last);
  }

  Future<void> _stageIncomingDeviceSwitch(BlueZDevice incoming) async {
    if (_connectedDeviceExcept(incoming) == null ||
        state.pairingRequest != null) {
      return;
    }
    state = state.copyWith(
      pairingRequest: BlueZAgentRequest(
        requestId: -2,
        requestType: AgentRequestType.requestAuthorization,
        devicePath: incoming.objectPath,
      ),
    );
    try {
      await incoming.disconnect();
      _connectedAddresses.remove(incoming.address);
      _publishDevices();
    } catch (e) {
      state = state.copyWith(
        error: 'Unable to hold ${bluetoothDeviceName(incoming)} connection: $e',
      );
    }
  }

  // ── Adapter power ──────────────────────────────────────────────────────────

  Future<void> setPowered(bool powered) async {
    await ensureInitialized();
    final adapter = _adapter;
    if (adapter == null || state.changingPower || state.powered == powered) {
      return;
    }
    state = state.copyWith(changingPower: true, clearError: true);
    try {
      if (powered) await _unblockRfkill();
      if (!powered) await _stopDiscovery();
      await adapter.setPowered(powered);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      state = state.copyWith(
        powered: adapter.powered,
        scanning: powered && adapter.discovering,
        clearBusyAddress: !powered,
        clearPairingRequest: !powered,
      );
    } catch (e) {
      state = state.copyWith(
        powered: adapter.powered,
        error: 'Unable to turn Bluetooth ${powered ? 'on' : 'off'}: $e',
      );
    } finally {
      state = state.copyWith(changingPower: false);
    }
  }

  Future<void> _unblockRfkill() async {
    try {
      await Process.run('rfkill', const ['unblock', 'bluetooth']);
    } on ProcessException {
      // Proceed — bluez_native also attempts rfkill internally.
    }
  }

  // ── Scan mode lifecycle ────────────────────────────────────────────────────

  /// Opens scan mode by starting discovery and its two-minute UI timeout.
  ///
  /// The agent remains registered for the notifier's whole lifetime. This
  /// method does not change the adapter's Pairable or Discoverable properties.
  ///
  /// Safe to call while scan mode is already active (idempotent).
  Future<void> enterScanMode() async {
    await ensureInitialized();
    if (_adapter == null) return;

    state = state.copyWith(scanTimedOut: false, clearError: true);

    await _startDiscovery();
  }

  /// Closes scan mode by stopping discovery and dismissing any pending request.
  /// The registered agent remains active so app-level policy can reject or
  /// disconnect external requests while the Bluetooth pages are not open.
  ///
  /// [timedOut] is `true` only when called from the 2-minute scan timer;
  /// `false` when the page is closed normally.
  Future<void> exitScanMode({bool timedOut = false}) async {
    _scanTimer?.cancel();
    _scanTimer = null;

    await _stopDiscovery();

    state = state.copyWith(clearPairingRequest: true, scanTimedOut: timedOut);
  }

  Future<void> _startDiscovery() async {
    final adapter = _adapter;
    if (adapter == null || state.scanning) return;
    try {
      if (!adapter.powered) {
        await setPowered(true);
        if (!state.powered) return;
      }
      await adapter.startDiscovery();
      state = state.copyWith(scanning: true);
      _scanTimer?.cancel();
      _scanTimer = Timer(
        const Duration(minutes: 2),
        () => unawaited(exitScanMode(timedOut: true)),
      );
    } catch (e) {
      state = state.copyWith(
        scanning: false,
        error: 'Unable to scan for Bluetooth devices: $e',
      );
    }
  }

  Future<void> _stopDiscovery() async {
    _scanTimer?.cancel();
    final adapter = _adapter;
    try {
      if (adapter?.discovering ?? false) await adapter?.stopDiscovery();
    } catch (_) {
      // BlueZ may already have stopped discovery.
    }
    state = state.copyWith(scanning: false);
  }

  // ── Device actions ─────────────────────────────────────────────────────────

  Future<bool> pairAndConnect(BlueZDevice device) async {
    if (state.busyAddress != null) return false;
    state = state.copyWith(
      busyAddress: device.address,
      operation: BluetoothOperation.connecting,
      clearError: true,
    );
    try {
      await _stopDiscovery();
      if (!device.paired) await device.pair();
      if (!device.trusted) await device.setTrust(true);

      // If another device is already connected, ask user before switching.
      // The device is now paired — the switch dialog only needs to handle
      // disconnect-old + connect-new.
      if (_connectedDeviceExcept(device) != null) {
        _devices[device.address] = device;
        _publishDevices();
        state = state.copyWith(clearBusyAddress: true);
        state = state.copyWith(
          pairingRequest: BlueZAgentRequest(
            requestId: -1,
            requestType: AgentRequestType.requestAuthorization,
            devicePath: device.objectPath,
          ),
        );
        return false;
      }

      if (!device.connected) await device.connect();
      _connectedAddresses.add(device.address);
      _devices[device.address] = device;
      _publishDevices();
      return true;
    } catch (e) {
      print('Bluetooth: pairAndConnect failed for ${device.address}: $e');
      state = state.copyWith(
        error: 'Unable to connect to ${bluetoothDeviceName(device)}: $e',
        clearPairingRequest: true,
      );
      await _cleanupFailedPairing(device, isAgentCancel: false);
      // Restart discovery so the scan page recovers its 2-minute timer
      // and device list instead of sitting idle with no timeout/rescan.
      await _startDiscovery();
      return false;
    } finally {
      state = state.copyWith(clearBusyAddress: true);
    }
  }

  Future<void> disconnect(BlueZDevice device) async {
    if (state.busyAddress != null) return;
    state = state.copyWith(
      busyAddress: device.address,
      operation: BluetoothOperation.disconnecting,
      clearError: true,
    );
    try {
      await device.disconnect();
      _publishDevices();
    } catch (e) {
      state = state.copyWith(
        error: 'Unable to disconnect ${bluetoothDeviceName(device)}: $e',
      );
    } finally {
      state = state.copyWith(clearBusyAddress: true);
    }
  }

  Future<void> removeDevice(BlueZDevice device) async {
    if (state.busyAddress != null) return;
    state = state.copyWith(
      busyAddress: device.address,
      operation: BluetoothOperation.removing,
      clearError: true,
    );
    try {
      if (device.connected) await device.disconnect();
      await _adapter?.removeDevice(device.objectPath);
      _devices.remove(device.address);
      _publishDevices();
    } catch (e) {
      state = state.copyWith(
        error: 'Unable to remove ${bluetoothDeviceName(device)}: $e',
      );
    } finally {
      state = state.copyWith(clearBusyAddress: true);
    }
  }

  // ── Pairing responses ──────────────────────────────────────────────────────

  Future<void> respondToPairing({
    required bool accepted,
    String? response,
  }) async {
    final request = state.pairingRequest;
    if (request == null) return;

    if (request.requestId < 0) {
      state = state.copyWith(clearPairingRequest: true);
      if (!accepted && request.requestId == -1) {
        await enterScanMode();
      }
      return;
    }

    final device = _deviceForPath(request.devicePath);
    print(
        'Bluetooth: respondToPairing for ${device?.address}, accepted: $accepted');

    switch (request.requestType) {
      case AgentRequestType.displayPinCode:
      case AgentRequestType.displayPasskey:
        if (!accepted) {
          await _cleanupFailedPairing(device, isAgentCancel: false);
          await _startDiscovery();
        }
      default:
        _client.agentRespond(
          request.requestId,
          accepted: accepted,
          response: response,
        );
        if (!accepted) {
          await _cleanupFailedPairing(device, cancelPairing: false);
          await _startDiscovery();
        }
    }
    state = state.copyWith(clearPairingRequest: true);
  }

  Future<void> switchToPairingDevice() async {
    final request = state.pairingRequest;
    if (request == null) return;

    final target = _deviceForPath(request.devicePath);
    if (state.busyAddress != null && state.busyAddress != target?.address) {
      return;
    }
    final current = _connectedDeviceExcept(target);
    if (target == null || current == null) {
      await respondToPairing(accepted: target != null);
      return;
    }

    state = state.copyWith(
      busyAddress: target.address,
      operation: BluetoothOperation.switching,
      clearError: true,
    );
    var requestAccepted = request.requestId < 0;
    try {
      await current.disconnect();
      if (request.requestId >= 0) {
        _client.agentRespond(request.requestId);
        requestAccepted = true;
      }
      state = state.copyWith(clearPairingRequest: true);

      if (!target.paired) {
        if (request.requestId >= 0) {
          await _waitForDeviceState(
            target,
            (d) => d.paired,
            timeout: const Duration(seconds: 3),
          );
        }
        if (!target.paired) await target.pair();
      }
      if (!target.trusted) await target.setTrust(true);

      if (!target.connected) {
        await _waitForDeviceState(
          target,
          (d) => d.connected,
          timeout: const Duration(milliseconds: 500),
        );
        if (!target.connected) await target.connect();
      }
      _publishDevices();
      ref.read(appProvider.notifier).updateNested(AppState.bluetooth);
    } catch (e) {
      print(
          'Bluetooth: switchToPairingDevice failed for ${target.address}: $e');
      if (!requestAccepted && request.requestId >= 0) {
        _client.agentRespond(request.requestId, accepted: false);
        state = state.copyWith(clearPairingRequest: true);
        await _cleanupFailedPairing(target, cancelPairing: false);
      } else {
        await _cleanupFailedPairing(target, isAgentCancel: false);
      }
      if (!current.connected) {
        try {
          await current.connect();
        } catch (rollbackError) {
          print(
              'Bluetooth: Best-effort rollback to ${current.address} failed: $rollbackError');
        }
      }
      state = state.copyWith(
        error: 'Unable to switch to ${bluetoothDeviceName(target)}: $e',
      );
      _publishDevices();
    } finally {
      state = state.copyWith(clearBusyAddress: true);
    }
  }

  // ── Pairing request helpers (used by BluetoothPairingRequest widget) ───────

  BlueZDevice? deviceForPairingRequest(BlueZAgentRequest request) =>
      _deviceForPath(request.devicePath);

  BlueZDevice? deviceToDisconnectForPairingRequest(BlueZAgentRequest request) {
    if (request.requestType != AgentRequestType.requestAuthorization &&
        request.requestType != AgentRequestType.authorizeService) {
      return null;
    }
    return _connectedDeviceExcept(_deviceForPath(request.devicePath));
  }

  // ── Error ──────────────────────────────────────────────────────────────────

  void clearError() => state = state.copyWith(clearError: true);

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<void> _cleanupFailedPairing(
    BlueZDevice? device, {
    bool isAgentCancel = false,
    bool cancelPairing = true,
  }) async {
    if (device == null) return;

    if (!isAgentCancel && cancelPairing) {
      try {
        await device.cancelPairing();
      } catch (e) {
        print('Bluetooth: cancelPairing() failed for ${device.address}: $e');
      }
    }

    if (device.connected) {
      try {
        await device.disconnect();
      } catch (e) {
        print('Bluetooth: disconnect() failed for ${device.address}: $e');
      }
    }
  }

  Future<void> _waitForDeviceState(
    BlueZDevice device,
    bool Function(BlueZDevice) test, {
    required Duration timeout,
  }) async {
    if (test(device)) return;
    try {
      await device.propertiesChanged
          .where((_) => test(device))
          .first
          .timeout(timeout);
    } on TimeoutException {
      // Caller decides whether to fall back to an explicit call.
    }
  }

  BlueZDevice? _connectedDeviceExcept(BlueZDevice? device) {
    for (final candidate in _devices.values) {
      if (candidate.connected && candidate.address != device?.address) {
        return candidate;
      }
    }
    return null;
  }

  BlueZDevice? _deviceForPath(String objectPath) {
    for (final device in _devices.values) {
      if (device.objectPath == objectPath) return device;
    }
    return null;
  }

  void _publishDevices() {
    state = state.copyWith(devices: List.unmodifiable(_devices.values));
    ref
        .read(signalsProvider.notifier)
        .toggleBluetooth(_devices.values.any((d) => d.connected));
  }

  // ── Dispose ────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _scanTimer?.cancel();
    if (state.scanning) unawaited(_adapter?.stopDiscovery());
    _agentRequestSub?.cancel();
    _deviceAddedSub?.cancel();
    _deviceRemovedSub?.cancel();
    _deviceChangedSub?.cancel();
    _adapterChangedSub?.cancel();
    if (_agentRegistered) _client.unregisterAgent();
    unawaited(_client.close());
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final bluetoothProvider =
    StateNotifierProvider<BluetoothNotifier, BluetoothState>(
  BluetoothNotifier.new,
);
