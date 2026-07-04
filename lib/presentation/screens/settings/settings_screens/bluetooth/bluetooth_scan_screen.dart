import 'package:flutter_ics_homescreen/export.dart';

import 'widgets/bluetooth_pairing_request.dart';
import 'widgets/bluetooth_scan_content.dart';

class BluetoothScanPage extends ConsumerWidget {
  const BluetoothScanPage({super.key});

  static Page<void> page() =>
      const MaterialPage<void>(child: BluetoothScanPage());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<String?>(bluetoothProvider.select((state) => state.error), (
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

    return const Scaffold(
      body: Stack(
        children: [BluetoothScanContent(), BluetoothPairingRequest()],
      ),
    );
  }
}
