import 'dart:ui';

import 'package:bluez_native/bluez_native.dart';

import '../../../../../../../export.dart';
import 'bluetooth_dialog.dart';

class BluetoothContent extends ConsumerWidget {
  const BluetoothContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final btState = ref.watch(bluetoothProvider);

    ref.listen<String?>(bluetoothProvider.select((s) => s.error), (_, next) {
      if (next == null) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(next)));
      ref.read(bluetoothProvider.notifier).clearError();
    });

    return Column(
      children: [
        CommonTitle(
          title: 'Bluetooth',
          hasBackButton: true,
          onPressed: () => ref.read(appProvider.notifier).back(),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 144),
            itemCount: btState.pairedDevices.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final device = btState.pairedDevices[index];
              return _PairedDeviceTile(
                device: device,
                busy: btState.busyAddress == device.address,
                operation: btState.busyAddress == device.address
                    ? btState.operation
                    : null,
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 150),
          child: GenericButton(
            height: 130,
            width: 501,
            text: 'Scan for New Device',
            onTap: () => ref
                .read(appProvider.notifier)
                .updateNested(AppState.bluetoothScan),
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
    BluetoothOperation.switching => 'Switching...',
    _ => 'Connecting...',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = device.connected || busy;
    final notifier = ref.read(bluetoothProvider.notifier);

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
        onTap: selected ? null : () => notifier.pairAndConnect(device),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  bluetoothDeviceName(device),
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : AGLDemoColors.periwinkleColor,
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
                      onPressed: () => notifier.disconnect(device),
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

// ---------------------------------------------------------------------------
// Forget confirmation dialog
// ---------------------------------------------------------------------------

Future<void> _showForgetDialog(
  BuildContext context,
  WidgetRef ref,
  BlueZDevice device,
) async {
  final name = bluetoothDeviceName(device);
  final isConnected = device.connected;

  final confirmed = await showDialog<bool>(
    context: context,
    barrierColor: const Color(0xB20A1238),
    builder: (ctx) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: BluetoothDialog(
          title: 'Forget Device?',
          body: Text(
            'Remove $name from paired devices?'
            '${isConnected ? '\n\nThe device will be disconnected.' : ''}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AGLDemoColors.periwinkleColor,
              fontSize: 28,
            ),
          ),
          cancelLabel: 'Cancel',
          onCancel: () => Navigator.of(ctx).pop(false),
          confirmLabel: 'Forget',
          onConfirm: () => Navigator.of(ctx).pop(true),
        ),
      ),
    ),
  );

  if (confirmed == true && context.mounted) {
    ref.read(bluetoothProvider.notifier).removeDevice(device);
  }
}
