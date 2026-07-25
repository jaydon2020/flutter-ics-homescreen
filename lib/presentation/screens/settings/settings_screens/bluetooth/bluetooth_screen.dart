import 'package:flutter_ics_homescreen/export.dart';
import 'widgets/bluetooth_content.dart';
import 'widgets/bluetooth_pairing_request.dart';

class BluetoothPage extends ConsumerWidget {
  const BluetoothPage({super.key});

  static Page<void> page() => const MaterialPage<void>(child: BluetoothPage());

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
        children: [
          BluetoothContent(),
          BluetoothPairingRequest(),
        ],
      ),
    );
  }
}
