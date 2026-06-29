import 'package:flutter_ics_homescreen/export.dart';
import 'widgets/bluetooth_content.dart';

class BluetoothPage extends ConsumerWidget {
  const BluetoothPage({super.key});

  static Page<void> page() => const MaterialPage<void>(child: BluetoothPage());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The BlueZ agent is only registered while BluetoothScanPage is open,
    // so pairingRequest is always null here — no overlay needed.
    return const Scaffold(body: BluetoothContent());
  }
}
