import 'dart:async';

import 'package:bluez_native/bluez_native.dart';

import '../../../../../../../export.dart';
import 'bluetooth_dialog.dart';

class BluetoothScanContent extends ConsumerStatefulWidget {
  const BluetoothScanContent({super.key});

  @override
  ConsumerState<BluetoothScanContent> createState() =>
      _BluetoothScanContentState();
}

class _BluetoothScanContentState extends ConsumerState<BluetoothScanContent> {
  // Cached so dispose() can call exitScanMode() without using ref, which is
  // detached by the time dispose() runs in Riverpod.
  late BluetoothNotifier _notifier;

  @override
  void initState() {
    super.initState();
    // Cache the notifier now while ref is still valid.
    _notifier = ref.read(bluetoothProvider.notifier);
    // Start discovery once this page is mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_notifier.enterScanMode());
    });
  }

  @override
  void dispose() {
    // exitScanMode stops discovery regardless of how the page is left
    // (back gesture, button, or programmatic navigation).
    // NOTE: ref.read() is NOT safe inside dispose() in Riverpod because the
    // ref is already detached — use the cached notifier instead.
    unawaited(_notifier.exitScanMode());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      bluetoothProvider.select(
        (state) => (
          devices: state.devices,
          scanning: state.scanning,
          scanTimedOut: state.scanTimedOut,
          busyAddress: state.busyAddress,
        ),
      ),
    );
    final devices = state.devices.where((d) => !d.paired).toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));

    return Column(
      children: [
        CommonTitle(
          title: 'Scan for New Device',
          hasBackButton: true,
          // Simply navigate — dispose() will call exitScanMode().
          onPressed: () =>
              ref.read(appProvider.notifier).updateNested(AppState.bluetooth),
        ),
        Expanded(
          child: state.scanTimedOut
              ? _ScanTimedOutView(onRefresh: () => _notifier.enterScanMode())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(144, 50, 144, 28),
                      child: Row(
                        children: [
                          const Text(
                            'Available Devices',
                            style: TextStyle(
                              color: AGLDemoColors.periwinkleColor,
                              fontSize: 32,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (state.scanning) ...[
                            const SizedBox(width: 20),
                            const SizedBox(
                              width: 48,
                              height: 48,
                              child: CircularProgressIndicator(strokeWidth: 3),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      child: devices.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.bluetooth_searching,
                                    color: AGLDemoColors.periwinkleColor,
                                    size: 72,
                                  ),
                                  SizedBox(height: 28),
                                  Text(
                                    'No devices available',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 36,
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Make sure your device is discoverable.',
                                    style: TextStyle(
                                      color: AGLDemoColors.periwinkleColor,
                                      fontSize: 24,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                144,
                                0,
                                144,
                                50,
                              ),
                              itemCount: devices.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final device = devices[index];
                                return _DiscoveredDeviceTile(
                                  device: device,
                                  busy: state.busyAddress == device.address,
                                  disabled: state.busyAddress != null,
                                );
                              },
                            ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 250),
      ],
    );
  }
}

/// Shown when the 2-minute scan timeout fires. Lets the user restart scan
/// mode without leaving the page.
class _ScanTimedOutView extends StatelessWidget {
  const _ScanTimedOutView({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.bluetooth_searching,
            color: AGLDemoColors.periwinkleColor,
            size: 72,
          ),
          const SizedBox(height: 28),
          const Text(
            'Scan timed out',
            style: TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 48),
          GenericButton(
            height: 100,
            width: 320,
            text: 'Refresh',
            onTap: onRefresh,
          ),
        ],
      ),
    );
  }
}

class _DiscoveredDeviceTile extends ConsumerWidget {
  const _DiscoveredDeviceTile({
    required this.device,
    required this.busy,
    required this.disabled,
  });

  final BlueZDevice device;
  final bool busy;
  final bool disabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 130,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          stops: busy ? const [0, 0.01, 0.8] : const [0.1, 1],
          colors: busy
              ? <Color>[
                  Colors.white,
                  Colors.blue,
                  const Color.fromARGB(16, 41, 98, 255),
                ]
              : <Color>[Colors.black, Colors.black12],
        ),
      ),
      child: InkWell(
        onTap: disabled
            ? null
            : () => connectBluetoothDevice(context, ref, device),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  bluetoothDeviceName(device),
                  style: TextStyle(
                    color: busy ? Colors.white : AGLDemoColors.periwinkleColor,
                    fontSize: 40,
                  ),
                ),
              ),
              if (busy) ...[
                const Padding(
                  padding: EdgeInsets.only(right: 24),
                  child: Text('Connecting...', style: TextStyle(fontSize: 26)),
                ),
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
