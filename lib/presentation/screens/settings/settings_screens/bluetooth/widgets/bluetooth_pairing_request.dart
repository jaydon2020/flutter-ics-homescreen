import 'dart:ui';

import 'package:bluez_native/bluez_native.dart';

import '../../../../../../../export.dart';
import 'bluetooth_dialog.dart';

class BluetoothPairingRequest extends ConsumerStatefulWidget {
  const BluetoothPairingRequest({super.key});

  @override
  ConsumerState<BluetoothPairingRequest> createState() =>
      _BluetoothPairingRequestState();
}

class _BluetoothPairingRequestState
    extends ConsumerState<BluetoothPairingRequest> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final btState = ref.watch(bluetoothProvider);
    final request = btState.pairingRequest;
    if (request == null) return const SizedBox.shrink();

    final notifier = ref.read(bluetoothProvider.notifier);
    final device = notifier.deviceForPairingRequest(request);
    final deviceName = device != null
        ? bluetoothDeviceName(device)
        : _addressFromPath(request.devicePath);

    final switchFrom = notifier.deviceToDisconnectForPairingRequest(request);
    final isSwitchRequest = switchFrom != null;
    final isInput =
        !isSwitchRequest &&
        (request.requestType == AgentRequestType.requestPinCode ||
            request.requestType == AgentRequestType.requestPasskey);
    final code = isSwitchRequest ? null : _pairingCode(request);
    final isSwitching =
        isSwitchRequest &&
        btState.operation == BluetoothOperation.switching &&
        btState.busyAddress == device?.address;

    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
        child: ColoredBox(
          color: const Color(0xB20A1238),
          child: Center(
            child: BluetoothDialog(
              title: isSwitchRequest
                  ? 'Switch Bluetooth Device?'
                  : 'Bluetooth Pairing Request',
              body: Column(
                children: [
                  Text(
                    deviceName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (isInput)
                    SizedBox(
                      width: 380,
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        textAlign: TextAlign.center,
                        keyboardType:
                            request.requestType ==
                                AgentRequestType.requestPasskey
                            ? TextInputType.number
                            : TextInputType.text,
                        maxLength:
                            request.requestType ==
                                AgentRequestType.requestPasskey
                            ? 6
                            : null,
                        style: const TextStyle(
                          color: AGLDemoColors.periwinkleColor,
                          fontSize: 54,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Enter code',
                          counterText: '',
                        ),
                      ),
                    )
                  else if (code != null)
                    Text(
                      code,
                      style: GoogleFonts.brunoAce(
                        color: AGLDemoColors.periwinkleColor,
                        fontSize: 72,
                        letterSpacing: 8,
                        shadows: const [
                          Shadow(
                            color: Colors.black,
                            offset: Offset(2, 3),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  Text(
                    isSwitchRequest
                        ? '$deviceName wants to connect.\n'
                              'This will disconnect '
                              '${bluetoothDeviceName(switchFrom)}.'
                        : isInput
                        ? 'Enter the code shown on your device.'
                        : code == null
                        ? 'Allow this device to pair?'
                        : 'Enter this code on your device to\nconfirm pairing.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AGLDemoColors.periwinkleColor,
                      fontSize: 28,
                    ),
                  ),
                ],
              ),
              cancelLabel: 'Cancel',
              onCancel: isSwitching
                  ? null
                  : () => notifier.respondToPairing(accepted: false),
              confirmLabel: isSwitching
                  ? 'Switching...'
                  : isSwitchRequest
                  ? 'Switch'
                  : 'Confirm',
              onConfirm: isSwitching
                  ? null
                  : isSwitchRequest
                  ? notifier.switchToPairingDevice
                  : () => notifier.respondToPairing(
                      accepted: true,
                      response: isInput ? _controller.text : null,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String? _pairingCode(BlueZAgentRequest request) {
  switch (request.requestType) {
    case AgentRequestType.requestConfirmation:
    case AgentRequestType.displayPasskey:
      return request.passkey.toString().padLeft(6, '0');
    case AgentRequestType.displayPinCode:
      return request.pinCode;
    default:
      return null;
  }
}

String _addressFromPath(String path) =>
    path.split('/').last.replaceFirst('dev_', '').replaceAll('_', ':');
