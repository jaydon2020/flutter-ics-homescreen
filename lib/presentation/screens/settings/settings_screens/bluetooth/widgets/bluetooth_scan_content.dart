import 'package:bluez_native/bluez_native.dart';

import '../../../../../../../export.dart';

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
    // enterScanMode registers the BlueZ agent, sets pairable + discoverable,
    // and starts discovery. The agent lifetime is tied to this page.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifier.enterScanMode();
    });
  }

  @override
  void dispose() {
    // exitScanMode stops discovery regardless of how the page is left
    // (back gesture, button, or programmatic navigation).
    // NOTE: ref.read() is NOT safe inside dispose() in Riverpod because the
    // ref is already detached — use the cached notifier instead.
    _notifier.exitScanMode();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bluetoothProvider);
    final devices = state.unpairedDevices;

    ref.listen<String?>(bluetoothProvider.select((value) => value.error), (
      previous,
      next,
    ) {
      if (next == null || next == previous) return;
      if (!ref.read(appConfigProvider).showBluetoothErrors) {
        ref.read(bluetoothProvider.notifier).clearError();
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(next)));
      ref.read(bluetoothProvider.notifier).clearError();
    });

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
              ? _ScanTimedOutView(
                  onRefresh: () => _notifier.enterScanMode(),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    vertical: 50,
                    horizontal: 144,
                  ),
                  itemCount: devices.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    return _DiscoveredDeviceTile(
                      device: device,
                      busy: state.busyAddress == device.address,
                      onConnected: () {
                        if (!mounted) return;
                        ref
                            .read(appProvider.notifier)
                            .updateNested(AppState.bluetooth);
                      },
                    );
                  },
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
    required this.onConnected,
  });

  final BlueZDevice device;
  final bool busy;
  final VoidCallback onConnected;

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
        onTap: busy
            ? null
            : () async {
                final connected = await ref
                    .read(bluetoothProvider.notifier)
                    .pairAndConnect(device);
                if (connected) onConnected();
              },
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
