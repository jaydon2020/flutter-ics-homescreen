import 'dart:ui';

import 'package:bluez_native/bluez_native.dart';

import '../../../../../../../export.dart';
import 'bluetooth_dialog.dart';

class BluetoothContent extends ConsumerWidget {
  const BluetoothContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final btState = ref.watch(
      bluetoothProvider.select(
        (state) => (
          devices: state.devices,
          busyAddress: state.busyAddress,
          disconnectingAddress: state.disconnectingAddress,
          operation: state.operation,
        ),
      ),
    );
    final pairedDevices = btState.devices.where((d) => d.paired).toList()
      ..sort((a, b) {
        if (a.connected != b.connected) return a.connected ? -1 : 1;
        return bluetoothDeviceName(a).compareTo(bluetoothDeviceName(b));
      });

    return Column(
      children: [
        CommonTitle(
          title: 'Bluetooth',
          hasBackButton: true,
          onPressed: () => ref.read(appProvider.notifier).back(),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(144, 50, 144, 28),
                child: Text(
                  'Saved Devices',
                  style: TextStyle(
                    color: AGLDemoColors.periwinkleColor,
                    fontSize: 32,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: pairedDevices.isEmpty
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
                              'No saved devices',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Scan for a new device to get started.',
                              style: TextStyle(
                                color: AGLDemoColors.periwinkleColor,
                                fontSize: 24,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(144, 0, 144, 50),
                        itemCount: pairedDevices.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final device = pairedDevices[index];
                          final disconnecting =
                              btState.disconnectingAddress == device.address;
                          return _PairedDeviceTile(
                            device: device,
                            busy: btState.busyAddress == device.address ||
                                disconnecting,
                            operation: disconnecting
                                ? BluetoothOperation.disconnecting
                                : btState.busyAddress == device.address
                                    ? btState.operation
                                    : null,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 150),
          child: GenericButton(
            height: 130,
            width: 501,
            text: 'Scan for New Device',
            onTap: () {
              if (bluetoothPairingLimitReached(pairedDevices.length)) {
                _showPairingLimitDialog(context);
                return;
              }
              ref.read(appProvider.notifier).replace(AppState.bluetoothScan);
            },
          ),
        ),
        const SizedBox(height: 100),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Paired device row
// ---------------------------------------------------------------------------

class _PairedDeviceTile extends ConsumerWidget {
  const _PairedDeviceTile({
    required this.device,
    required this.busy,
    required this.operation,
  });

  final BlueZDevice device;
  final bool busy;
  final BluetoothOperation? operation;

  String get _statusLabel => switch (operation) {
        BluetoothOperation.disconnecting => 'Disconnecting...',
        BluetoothOperation.removing => 'Removing...',
        _ => 'Connecting...',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = device.connected || busy;

    return Container(
      height: 130,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          stops: selected ? const [0, 0.01, 0.8] : const [0.1, 1],
          colors: selected
              ? [
                  Colors.white,
                  Colors.blue,
                  const Color.fromARGB(16, 41, 98, 255),
                ]
              : [Colors.black, Colors.black12],
        ),
      ),
      child: InkWell(
        onTap: busy || device.connected
            ? null
            : () => connectBluetoothDevice(ref, device),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  bluetoothDeviceName(device),
                  style: TextStyle(
                    color:
                        selected ? Colors.white : AGLDemoColors.periwinkleColor,
                    fontSize: 40,
                  ),
                ),
              ),
              if (busy) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 15),
                  child: Text(
                    _statusLabel,
                    style: const TextStyle(fontSize: 26),
                  ),
                ),
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              ] else ...[
                if (device.connected)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1C2D92),
                        side: const BorderSide(
                          color: Color(0xFF285DF4),
                          width: 2,
                        ),
                      ),
                      onPressed: () => _disconnect(context, ref, device),
                      child: const Padding(
                        padding: EdgeInsets.all(18),
                        child: Text(
                          'Disconnect',
                          style: TextStyle(
                            color: Color(0xFFC1D8FF),
                            fontSize: 26,
                          ),
                        ),
                      ),
                    ),
                  ),
                IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => _showForgetDialog(context, ref, device),
                  icon: const Icon(
                    Icons.close,
                    color: AGLDemoColors.periwinkleColor,
                    size: 48,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _disconnect(
  BuildContext context,
  WidgetRef ref,
  BlueZDevice device,
) async {
  final confirmed = await showBluetoothConfirmationDialog(
    context,
    title: 'Disconnect Device?',
    message: 'Disconnect ${bluetoothDeviceName(device)}?',
    confirmLabel: 'Disconnect',
  );
  if (confirmed && context.mounted) {
    ref.read(bluetoothProvider.notifier).disconnect(device);
  }
}

Future<void> _showPairingLimitDialog(BuildContext context) => showDialog<void>(
      context: context,
      barrierColor: const Color(0xB20A1238),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: BluetoothDialog(
            title: 'Device Limit Reached',
            body: const Text(
              'A maximum of $maxPairedBluetoothDevices Bluetooth devices can be paired. '
              'Forget a paired device before scanning for a new one.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: AGLDemoColors.periwinkleColor, fontSize: 28),
            ),
            cancelLabel: null,
            confirmLabel: 'OK',
            onConfirm: () => Navigator.of(ctx).pop(),
          ),
        ),
      ),
    );

// ---------------------------------------------------------------------------
// Forget confirmation dialog
// ---------------------------------------------------------------------------

Future<void> _showForgetDialog(
  BuildContext context,
  WidgetRef ref,
  BlueZDevice device,
) async {
  final name = bluetoothDeviceName(device);

  final confirmed = await showBluetoothConfirmationDialog(
    context,
    title: 'Forget Device?',
    message: 'You will no longer be paired with $name.',
    confirmLabel: 'Forget',
  );

  if (confirmed == true && context.mounted) {
    ref.read(bluetoothProvider.notifier).removeDevice(device);
  }
}
