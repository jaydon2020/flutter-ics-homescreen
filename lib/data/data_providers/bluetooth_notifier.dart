import 'dart:async';

import 'package:bluez_native/bluez_native.dart';
import 'package:flutter_ics_homescreen/export.dart';

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

enum BluetoothOperation { connecting, disconnecting, removing }

const maxPairedBluetoothDevices = 10;

const bluetoothDiscoveryProfileUuids = <String>[
  '0000110a-0000-1000-8000-00805f9b34fb', // A2DP source
  '0000110e-0000-1000-8000-00805f9b34fb', // AVRCP
  '0000111f-0000-1000-8000-00805f9b34fb', // HFP audio gateway
];

bool bluetoothPairingLimitReached(int pairedDeviceCount) =>
    pairedDeviceCount >= maxPairedBluetoothDevices;

bool bluetoothSupportsMediaProfile(Iterable<String> uuids) => uuids.any(
      (uuid) => bluetoothDiscoveryProfileUuids.contains(uuid.toLowerCase()),
    );

bool bluetoothDeviceSupportsMediaProfile(BlueZDevice device) =>
    bluetoothSupportsMediaProfile(device.uuids.map((uuid) => uuid.value));

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class BluetoothState {
  const BluetoothState({
    this.devices = const [],
    this.powered = false,
    this.changingPower = false,
    this.scanning = false,
    this.scanTimedOut = false,
    this.nativeAvailable,
    this.busyAddress,
    this.operation,
    this.pairingRequest,
  });

  final List<BlueZDevice> devices;
  final bool powered;
  final bool changingPower;
  final bool scanning;

  /// True when the 2-minute scan timeout fires; drives the Refresh button.
  final bool scanTimedOut;

  /// `null` while BlueZ is initializing, then whether the native backend works.
  final bool? nativeAvailable;

  final String? busyAddress;
  final BluetoothOperation? operation;
  final BlueZAgentRequest? pairingRequest;

  bool get pairingLimitReached =>
      bluetoothPairingLimitReached(devices.where((d) => d.paired).length);

  // copyWith ──────────────────────────────────────────────────────────────────

  BluetoothState copyWith({
    List<BlueZDevice>? devices,
    bool? powered,
    bool? changingPower,
    bool? scanning,
    bool? scanTimedOut,
    bool? nativeAvailable,
    String? busyAddress,
    BluetoothOperation? operation,
    bool clearBusyAddress = false,
    BlueZAgentRequest? pairingRequest,
    bool clearPairingRequest = false,
  }) {
    return BluetoothState(
      devices: devices ?? this.devices,
      powered: powered ?? this.powered,
      changingPower: changingPower ?? this.changingPower,
      scanning: scanning ?? this.scanning,
      scanTimedOut: scanTimedOut ?? this.scanTimedOut,
      nativeAvailable: nativeAvailable ?? this.nativeAvailable,
      busyAddress: clearBusyAddress ? null : busyAddress ?? this.busyAddress,
      operation: clearBusyAddress ? null : operation ?? this.operation,
      pairingRequest:
          clearPairingRequest ? null : pairingRequest ?? this.pairingRequest,
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

class BluetoothNotifier extends Notifier<BluetoothState> {
  @override
  BluetoothState build() {
    _client = ref.watch(blueZClientFactoryProvider)();
    ref.onDispose(_disposeResources);
    ref.listen<AppState>(appProvider, (previous, next) {
      if (next == AppState.bluetooth || next == AppState.bluetoothScan) {
        _publishDevices();
      }
    });
    unawaited(ensureInitialized());
    return const BluetoothState();
  }

  late final BlueZClient _client;
  final Map<String, BlueZDevice> _devices = {};
  final Set<String> _connectedAddresses = {};
  final Set<String> _intentionalDisconnects = {};

  Future<void>? _initialization;
  StreamSubscription<BlueZDevice>? _deviceAddedSub;
  StreamSubscription<BlueZDevice>? _deviceRemovedSub;
  StreamSubscription<BlueZDevice>? _deviceChangedSub;
  StreamSubscription<BlueZAdapter>? _adapterChangedSub;
  StreamSubscription<BlueZAgentRequest>? _agentRequestSub;
  Timer? _scanTimer;
  bool _agentRegistered = false;
  bool _disposed = false;

  BlueZAdapter? get _adapter =>
      _client.adapters.isEmpty ? null : _client.adapters.first;

  /// True when the Bluetooth page (paired list) or Scan page is in the
  /// foreground. Connections initiated externally are rejected when false.
  bool get _isOnBluetoothPage {
    final s = ref.read(appProvider);
    return s == AppState.bluetooth || s == AppState.bluetoothScan;
  }

  bool get _isOnScanPage => ref.read(appProvider) == AppState.bluetoothScan;

  Future<void> ensureInitialized() =>
      _initialization ??= _initializeBluetooth();

  void _updateState(BluetoothState Function(BluetoothState state) update) {
    if (_disposed) return;
    state = update(state);
  }

  // ── Initialisation ─────────────────────────────────────────────────────────

  Future<void> _initializeBluetooth() async {
    try {
      await _client.connect();
      if (_disposed) {
        await _client.close();
        return;
      }

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
        final connected = _connectedDeviceExcept(device);
        if (device.paired && connected != null) {
          unawaited(_updateDeviceBlocks(connected));
        }
      });
      _deviceRemovedSub = _client.deviceRemoved.listen((device) {
        _devices.remove(device.address);
        final wasConnected = _connectedAddresses.remove(device.address);
        _publishDevices();
        if (wasConnected && state.busyAddress == null) {
          unawaited(_updateDeviceBlocks(null));
        }
      });
      _deviceChangedSub = _client.deviceChanged.listen((device) {
        _devices[device.address] = device;
        _trackConnectionChange(device);
        _publishDevices();
      });
      _adapterChangedSub = _client.adapterChanged.listen((adapter) {
        if (!adapter.powered) {
          _scanTimer?.cancel();
          _scanTimer = null;
        }
        _updateState(
          (state) => state.copyWith(
            powered: adapter.powered,
            scanning: adapter.powered && adapter.discovering && state.scanning,
            clearBusyAddress: !adapter.powered,
            clearPairingRequest: !adapter.powered,
          ),
        );
      });

      for (final device in _client.devices) {
        _devices[device.address] = device;
        if (device.connected) _connectedAddresses.add(device.address);
      }

      _updateState(
        (state) => state.copyWith(
          powered: _adapter?.powered ?? false,
          nativeAvailable: true,
        ),
      );
      _publishDevices();
      unawaited(_enforceInitialConnectionPolicy());
    } catch (e) {
      _reportError('Bluetooth is unavailable: $e');
      _updateState((state) => state.copyWith(nativeAvailable: false));
    }
  }

  // ── Agent request handling ─────────────────────────────────────────────────

  void _handleAgentRequest(BlueZAgentRequest request) {
    if (_disposed) return;
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
          debugPrint(
            'Bluetooth: Rejecting external service auth for ${device.address} (not on BT page)',
          );
          _client.agentRespond(request.requestId, accepted: false);
          return;
        }
        _client.agentRespond(
          request.requestId,
          accepted: device.paired && _connectedDeviceExcept(device) == null,
        );
      case AgentRequestType.cancel:
      case AgentRequestType.release:
        debugPrint(
          'Bluetooth: Agent request cancelled by BlueZ (type: ${request.requestType}) for ${device?.address}',
        );
        _updateState((state) => state.copyWith(clearPairingRequest: true));
        unawaited(_cleanupFailedPairing(device, isAgentCancel: true));
        // Restart discovery so the scan page doesn't get stuck.
        unawaited(_startDiscovery());
        return;
      default:
        if (!state.scanning && !isBusyDevice) {
          debugPrint(
            'Bluetooth: Rejecting unsolicited pairing request for ${device?.address}',
          );
          _client.agentRespond(request.requestId, accepted: false);
          unawaited(_cleanupFailedPairing(device, cancelPairing: false));
          _updateState((state) => state.copyWith(clearPairingRequest: true));
          return;
        }
        _updateState((state) => state.copyWith(pairingRequest: request));
    }
  }

  // ── Connection tracking ────────────────────────────────────────────────────

  void _trackConnectionChange(BlueZDevice device) {
    if (_disposed) return;
    final wasConnected = _connectedAddresses.contains(device.address);
    final wasIntentional =
        !device.connected && _intentionalDisconnects.remove(device.address);
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
        debugPrint(
          'Bluetooth: Disconnecting external connection from ${device.address} (not on BT page)',
        );
        unawaited(_rejectExternalConnection(device));
        return;
      }
      final current = _connectedDeviceExcept(device);
      if (current != null) {
        unawaited(_rejectExternalConnection(device));
      } else {
        unawaited(_updateDeviceBlocks(device));
      }
    } else if (!device.connected &&
        wasConnected &&
        state.busyAddress == null &&
        !wasIntentional) {
      unawaited(_updateDeviceBlocks(null));
    }
  }

  Future<void> _enforceInitialConnectionPolicy() async {
    final connected = _devices.values.where((d) => d.connected).toList();
    try {
      if (connected.isEmpty) {
        await _unblockAllDevices();
        return;
      }

      final active = connected.first;
      for (final device in connected.skip(1)) {
        await _disconnectDevice(device);
      }
      await _applyDeviceBlocks(active);
      _publishDevices();
    } catch (e) {
      _reportError('Unable to enforce the connection policy: $e');
    }
  }

  Future<void> _rejectExternalConnection(BlueZDevice device) async {
    try {
      await _disconnectDevice(device);
      final connected = _devices.values.where((d) => d.connected).firstOrNull;
      if (connected == null) {
        await _unblockAllDevices();
      } else {
        await _applyDeviceBlocks(connected);
      }
      _publishDevices();
    } catch (e) {
      _reportError('Unable to reject ${bluetoothDeviceName(device)}: $e');
    }
  }

  // ── Adapter power ──────────────────────────────────────────────────────────

  Future<void> setPowered(bool powered) async {
    await ensureInitialized();
    if (_disposed) return;
    final adapter = _adapter;
    if (adapter == null || state.changingPower || state.powered == powered) {
      return;
    }
    _updateState((state) => state.copyWith(changingPower: true));
    try {
      if (!powered) await _stopDiscovery();
      await adapter.setPowered(powered);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      _updateState(
        (state) => state.copyWith(
          powered: adapter.powered,
          scanning: powered && adapter.discovering && state.scanning,
          clearBusyAddress: !powered,
          clearPairingRequest: !powered,
        ),
      );
    } catch (e) {
      _reportError('Unable to turn Bluetooth ${powered ? 'on' : 'off'}: $e');
      _updateState((state) => state.copyWith(powered: adapter.powered));
    } finally {
      _updateState((state) => state.copyWith(changingPower: false));
    }
  }

  // ── Scan mode lifecycle ────────────────────────────────────────────────────

  /// Opens scan mode and starts device discovery.
  ///
  /// Safe to call while scan mode is already active (idempotent).
  Future<void> enterScanMode() async {
    await ensureInitialized();
    if (_disposed) return;
    if (_adapter == null) return;
    if (state.pairingLimitReached) {
      _reportError('Forget a paired device before scanning for a new one.');
      return;
    }

    _updateState((state) => state.copyWith(scanTimedOut: false));

    await _startDiscovery();
  }

  /// Closes scan mode, stops discovery, and clears the pairing prompt.
  ///
  /// [timedOut] is `true` only when called from the 2-minute scan timer;
  /// `false` when the page is closed normally.
  Future<void> exitScanMode({bool timedOut = false}) async {
    _scanTimer?.cancel();
    _scanTimer = null;

    await _stopDiscovery();

    _updateState(
      (state) => state.copyWith(
        clearPairingRequest: true,
        scanTimedOut: timedOut,
      ),
    );
  }

  Future<void> _startDiscovery() async {
    if (_disposed) return;
    final adapter = _adapter;
    if (adapter == null || state.scanning || !_isOnScanPage) return;
    try {
      if (!adapter.powered) {
        await setPowered(true);
        if (_disposed || !state.powered) return;
      }
      await adapter.setDiscoveryFilter(
        transport: BlueZDiscoveryTransport.bredr,
        uuids: bluetoothDiscoveryProfileUuids,
      );
      await adapter.startDiscovery();
      _updateState((state) => state.copyWith(scanning: true));
      _scanTimer?.cancel();
      _scanTimer = Timer(
        const Duration(minutes: 2),
        () => unawaited(exitScanMode(timedOut: true)),
      );
    } catch (e) {
      _reportError('Unable to scan for devices: $e');
      _updateState((state) => state.copyWith(scanning: false));
    }
  }

  Future<void> _stopDiscovery() async {
    _scanTimer?.cancel();
    _scanTimer = null;
    final adapter = _adapter;
    try {
      if (adapter?.discovering ?? false) await adapter?.stopDiscovery();
    } catch (_) {
      // BlueZ may already have stopped discovery.
    }
    if (_disposed) return;
    _updateState((state) => state.copyWith(scanning: false));
  }

  // ── Device actions ─────────────────────────────────────────────────────────

  Future<bool> pairAndConnect(BlueZDevice device) async {
    if (state.busyAddress != null) return false;
    if (!device.paired && !bluetoothDeviceSupportsMediaProfile(device)) {
      _reportError(
        '${bluetoothDeviceName(device)} does not provide a supported phone or '
        'media profile.',
      );
      return false;
    }
    if (!device.paired && state.pairingLimitReached) {
      _reportError('Forget a paired device before pairing a new one.');
      return false;
    }
    final current = _connectedDeviceExcept(device);
    var leftScanPage = false;
    _updateState(
      (state) => state.copyWith(
        busyAddress: device.address,
        operation: BluetoothOperation.connecting,
      ),
    );
    try {
      await _setDeviceBlocked(device, false);
      if (!device.trusted) await device.setTrust(true);
      if (!device.paired) await device.pair();

      _devices[device.address] = device;
      _publishDevices();

      if (ref.read(appProvider) == AppState.bluetoothScan) {
        await exitScanMode();
        ref.read(appProvider.notifier).updateNested(AppState.bluetooth);
        leftScanPage = true;
      }

      // Pairing may establish a temporary connection. Reset it so every
      // successful pairing follows the same explicit connection sequence.
      if (device.connected) await _disconnectDevice(device);
      if (current?.connected ?? false) await _disconnectDevice(current!);
      if (!device.connected) await device.connect();
      if (!device.connected) {
        throw StateError('the connection did not complete');
      }
      _connectedAddresses.add(device.address);
      await _applyDeviceBlocks(device);
      _publishDevices();
      return true;
    } catch (e) {
      _reportError('Unable to connect to ${bluetoothDeviceName(device)}: $e');
      _updateState((state) => state.copyWith(clearPairingRequest: true));
      await _cleanupFailedPairing(device, isAgentCancel: false);
      if (current != null && !current.connected) {
        try {
          await _setDeviceBlocked(current, false);
          await current.connect();
          if (current.connected) await _applyDeviceBlocks(current);
        } catch (rollbackError) {
          debugPrint(
            'Bluetooth: Best-effort rollback to ${current.address} failed: '
            '$rollbackError',
          );
        }
      }
      if (!_devices.values.any((d) => d.connected)) {
        try {
          await _unblockAllDevices();
        } catch (unblockError) {
          debugPrint('Bluetooth: Unable to unblock devices: $unblockError');
        }
      }
      if (!leftScanPage) await _startDiscovery();
      return false;
    } finally {
      _updateState((state) => state.copyWith(clearBusyAddress: true));
    }
  }

  Future<void> disconnect(BlueZDevice device) async {
    if (state.busyAddress != null || !device.connected) return;
    _updateState(
      (state) => state.copyWith(
        busyAddress: device.address,
        operation: BluetoothOperation.disconnecting,
      ),
    );
    try {
      await _disconnectDevice(device);
      await _unblockAllDevices();
      _publishDevices();
    } catch (e) {
      _reportError('Unable to disconnect ${bluetoothDeviceName(device)}: $e');
    } finally {
      _updateState((state) => state.copyWith(clearBusyAddress: true));
    }
  }

  Future<void> removeDevice(BlueZDevice device) async {
    if (state.busyAddress != null) return;
    _updateState(
      (state) => state.copyWith(
        busyAddress: device.address,
        operation: BluetoothOperation.removing,
      ),
    );
    try {
      if (device.connected) await _disconnectDevice(device);
      await _adapter?.removeDevice(device.objectPath);
      _devices.remove(device.address);
      final connected = _devices.values.where((d) => d.connected).firstOrNull;
      if (connected == null) {
        await _unblockAllDevices();
      } else {
        await _applyDeviceBlocks(connected);
      }
      _publishDevices();
    } catch (e) {
      _reportError('Unable to remove ${bluetoothDeviceName(device)}: $e');
    } finally {
      _updateState((state) => state.copyWith(clearBusyAddress: true));
    }
  }

  // ── Pairing responses ──────────────────────────────────────────────────────

  Future<void> respondToPairing({
    required bool accepted,
    String? response,
  }) async {
    final request = state.pairingRequest;
    if (request == null) return;

    final device = _deviceForPath(request.devicePath);
    debugPrint(
      'Bluetooth: respondToPairing for ${device?.address}, accepted: $accepted',
    );

    if (request.needsResponse) {
      _client.agentRespond(
        request.requestId,
        accepted: accepted,
        response: response,
      );
    }
    if (!accepted) {
      await _cleanupFailedPairing(
        device,
        cancelPairing: !request.needsResponse,
      );
      await _startDiscovery();
    }
    _updateState((state) => state.copyWith(clearPairingRequest: true));
  }

  // ── Pairing request helpers (used by BluetoothPairingRequest widget) ───────

  BlueZDevice? deviceForPairingRequest(BlueZAgentRequest request) =>
      _deviceForPath(request.devicePath);

  // ── Private helpers ────────────────────────────────────────────────────────

  void _reportError(String message) => debugPrint('Bluetooth: $message');

  Future<void> _disconnectDevice(BlueZDevice device) async {
    _intentionalDisconnects.add(device.address);
    try {
      await device.disconnect();
    } finally {
      if (!device.connected) _intentionalDisconnects.remove(device.address);
      _connectedAddresses.remove(device.address);
    }
  }

  Future<void> _applyDeviceBlocks(BlueZDevice connected) async {
    for (final device in _devices.values.where((device) => device.paired)) {
      await _setDeviceBlocked(device, device.address != connected.address);
    }
  }

  Future<void> _unblockAllDevices() async {
    for (final device in _devices.values.where((device) => device.paired)) {
      await _setDeviceBlocked(device, false);
    }
  }

  Future<void> _updateDeviceBlocks(BlueZDevice? connected) async {
    try {
      if (connected == null) {
        await _unblockAllDevices();
      } else {
        await _applyDeviceBlocks(connected);
      }
      _publishDevices();
    } catch (e) {
      _reportError('Unable to update devices: $e');
    }
  }

  Future<void> _setDeviceBlocked(BlueZDevice device, bool blocked) async {
    if (device.blocked == blocked) return;

    final arguments = [
      'set-property',
      'org.bluez',
      device.objectPath,
      'org.bluez.Device1',
      'Blocked',
      'b',
      blocked.toString(),
    ];
    final result = await Process.run('busctl', arguments);
    if (result.exitCode != 0) {
      throw ProcessException(
        'busctl',
        arguments,
        result.stderr.toString().trim(),
        result.exitCode,
      );
    }
  }

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
        debugPrint(
          'Bluetooth: cancelPairing() failed for ${device.address}: $e',
        );
      }
    }

    if (device.connected) {
      try {
        await device.disconnect();
      } catch (e) {
        debugPrint('Bluetooth: disconnect() failed for ${device.address}: $e');
      }
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
    if (_disposed) return;
    _publishConnectionSignal();
    if (!_isOnBluetoothPage) return;

    // bluez_native 0.3.1 currently forwards an empty native filter, so keep
    // cached and unfiltered BlueZ objects out of the UI here as well.
    _updateState(
      (state) => state.copyWith(
        devices: List.unmodifiable(
          _devices.values.where(
            (device) =>
                device.paired || bluetoothDeviceSupportsMediaProfile(device),
          ),
        ),
      ),
    );
  }

  void _publishConnectionSignal() {
    ref
        .read(signalsProvider.notifier)
        .setBluetoothConnected(_devices.values.any((d) => d.connected));
  }

  void _disposeResources() {
    final wasDiscovering = _adapter?.discovering ?? false;
    _disposed = true;
    _scanTimer?.cancel();
    if (wasDiscovering) unawaited(_adapter?.stopDiscovery());
    _agentRequestSub?.cancel();
    _deviceAddedSub?.cancel();
    _deviceRemovedSub?.cancel();
    _deviceChangedSub?.cancel();
    _adapterChangedSub?.cancel();
    if (_agentRegistered) _client.unregisterAgent();
    unawaited(_client.close());
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final blueZClientFactoryProvider =
    Provider<BlueZClient Function()>((ref) => BlueZClient.new);

final bluetoothProvider =
    NotifierProvider<BluetoothNotifier, BluetoothState>(BluetoothNotifier.new);

/// Uses the demo backend when native initialization fails.
final nativeBluetoothAvailableProvider = Provider<bool?>((ref) =>
    ref.watch(bluetoothProvider.select((state) => state.nativeAvailable)));
