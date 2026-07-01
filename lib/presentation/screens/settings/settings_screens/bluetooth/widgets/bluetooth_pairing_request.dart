import 'dart:ui';

import 'package:bluez_native/bluez_native.dart';

import '../../../../../../../export.dart';
import 'bluetooth_dialog.dart';

/// Full-screen overlay for incoming Bluetooth pairing requests.
///
/// Redesigned to follow native Android/iOS pairing dialog conventions:
///  - Device name displayed prominently at the top of the body
///  - PIN/passkey codes shown inside a distinct highlighted card
///    (matches Android's code-display container)
///  - Instruction text is secondary, below the code
///  - Input field for manual code entry uses native-style decoration
///  - Device-switch variant clearly names both devices involved
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
    final isInput = !isSwitchRequest &&
        (request.requestType == AgentRequestType.requestPinCode ||
            request.requestType == AgentRequestType.requestPasskey);
    final code = isSwitchRequest ? null : _pairingCode(request);
    final isSwitching = isSwitchRequest &&
        btState.operation == BluetoothOperation.switching &&
        btState.busyAddress == device?.address;

    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
        child: ColoredBox(
          color: const Color(0xB20A1238),
          child: Center(
            child: BluetoothDialog(
              title: isSwitchRequest ? 'Switch Device?' : 'Pairing Request',
              body: Column(
                children: [
                  // ── Device name (most prominent, native convention) ──
                  Text(
                    deviceName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Code display / input / switch description ──
                  if (isInput)
                    _PairingCodeInput(
                      controller: _controller,
                      isPasskey: request.requestType ==
                          AgentRequestType.requestPasskey,
                    )
                  else if (code != null)
                    _PairingCodeCard(code: code),

                  if (isInput || code != null) const SizedBox(height: 20),

                  // ── Instruction text (secondary, below code) ──
                  Text(
                    isSwitchRequest
                        ? request.requestId == -1
                            ? 'Paired successfully.\nSwitch connection from '
                                '${bluetoothDeviceName(switchFrom)}?'
                            : '$deviceName wants to connect.\n'
                                'This will disconnect '
                                '${bluetoothDeviceName(switchFrom)}.'
                        : isInput
                            ? 'Enter the code shown on your device.'
                            : code == null
                                ? 'Allow this device to pair?'
                                : 'Confirm this code matches your device.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AGLDemoColors.periwinkleColor,
                      fontSize: 26,
                      height: 1.4,
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
// PIN/passkey code display card
// ---------------------------------------------------------------------------

/// Displays a pairing code inside a contained, highlighted card.
/// Matches native Android Bluetooth pairing which shows the passkey in a
/// distinct, centered container with monospace-like typography.
class _PairingCodeCard extends StatelessWidget {
  const _PairingCodeCard({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      decoration: BoxDecoration(
        color: AGLDemoColors.neonBlueColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AGLDemoColors.jordyBlueColor.withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        code,
        style: GoogleFonts.brunoAce(
          color: Colors.white,
          fontSize: 64,
          letterSpacing: 10,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PIN/passkey input field
// ---------------------------------------------------------------------------

/// Text field for manual code entry, styled to match the code card aesthetic.
class _PairingCodeInput extends StatelessWidget {
  const _PairingCodeInput({
    required this.controller,
    required this.isPasskey,
  });

  final TextEditingController controller;
  final bool isPasskey;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 380,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AGLDemoColors.neonBlueColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AGLDemoColors.jordyBlueColor.withValues(alpha: 0.3),
        ),
      ),
      child: TextField(
        controller: controller,
        autofocus: true,
        textAlign: TextAlign.center,
        keyboardType: isPasskey ? TextInputType.number : TextInputType.text,
        maxLength: isPasskey ? 6 : null,
        style: GoogleFonts.brunoAce(
          color: Colors.white,
          fontSize: 48,
          letterSpacing: 6,
        ),
        decoration: InputDecoration(
          hintText: isPasskey ? '000000' : 'Enter code',
          hintStyle: TextStyle(
            color: AGLDemoColors.periwinkleColor.withValues(alpha: 0.3),
            fontSize: 48,
            letterSpacing: 6,
          ),
          counterText: '',
          border: InputBorder.none,
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
