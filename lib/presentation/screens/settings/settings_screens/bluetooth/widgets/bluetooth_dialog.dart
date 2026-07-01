import '../../../../../../../export.dart';

/// Reusable dialog shell for Bluetooth pairing and confirmation flows.
///
/// Layout follows native Android/iOS Bluetooth pairing sheet conventions:
///  - Bluetooth icon + title header (matches Android's system dialog)
///  - Centered body region with generous but proportional padding
///  - Cancel (outline/text) vs Confirm (filled primary) button pair,
///    right-aligned confirm following Material 3 dialog button placement
///
/// Retains the AGL glassmorphic visual identity (gradient border, radial
/// background, backdrop blur) while adopting native-style interaction layout.
class BluetoothDialog extends StatelessWidget {
  const BluetoothDialog({
    super.key,
    required this.title,
    required this.body,
    required this.cancelLabel,
    required this.confirmLabel,
    this.onCancel,
    this.onConfirm,
  });

  final String title;
  final Widget body;
  final String cancelLabel;
  final String confirmLabel;

  /// `null` disables the button (busy state — renders but does nothing).
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 680,
      decoration: BoxDecoration(
        // ponytail: one-pixel gradient border, same as before
        gradient: LinearGradient(
          colors: [
            AGLDemoColors.periwinkleColor.withValues(alpha: 0.2),
            AGLDemoColors.periwinkleColor,
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 16,
            offset: const Offset(1, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(1),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(27),
          gradient: const RadialGradient(
            radius: 1,
            colors: [AGLDemoColors.backgroundInsetColor, Colors.black],
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DialogHeader(title: title),
            Padding(
              padding: const EdgeInsets.fromLTRB(40, 32, 40, 40),
              child: body,
            ),
            _DialogActions(
              cancelLabel: cancelLabel,
              confirmLabel: confirmLabel,
              onCancel: onCancel,
              onConfirm: onConfirm,
            ),
          ],
        ),
      ),
    );
  }
}

/// Header with Bluetooth icon + title, matching native Android pairing sheets
/// which always show the system Bluetooth icon alongside the dialog title.
class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.center,
          colors: [
            AGLDemoColors.jordyBlueColor.withValues(alpha: 0.15),
            AGLDemoColors.jordyBlueColor.withValues(alpha: 0),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: AGLDemoColors.jordyBlueColor.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.bluetooth,
            color: AGLDemoColors.jordyBlueColor,
            size: 36,
          ),
          const SizedBox(width: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Button bar following native dialog conventions:
///  - Cancel: outline style (secondary action, left)
///  - Confirm: filled primary (primary action, right)
///  - Android places the affirmative action on the right
class _DialogActions extends StatelessWidget {
  const _DialogActions({
    required this.cancelLabel,
    required this.confirmLabel,
    this.onCancel,
    this.onConfirm,
  });

  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        border: Border(
          top: BorderSide(
            color: AGLDemoColors.periwinkleColor.withValues(alpha: 0.12),
          ),
        ),
      ),
      child: Row(
        children: [
          // Cancel — outline button (secondary, Android convention)
          Expanded(
            child: _OutlineButton(
              label: cancelLabel,
              onTap: onCancel ?? () {},
            ),
          ),
          const SizedBox(width: 20),
          // Confirm — filled primary button (affirmative, right side)
          Expanded(
            child: GenericButton(
              height: 80,
              width: double.infinity,
              text: confirmLabel,
              onTap: onConfirm ?? () {},
            ),
          ),
        ],
      ),
    );
  }
}

/// Outline-style button for secondary/cancel actions. Provides visual
/// asymmetry between cancel and confirm, matching native dialog convention
/// where the destructive/dismissive action is visually lighter.
class _OutlineButton extends StatelessWidget {
  const _OutlineButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 80,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(
            color: AGLDemoColors.periwinkleColor.withValues(alpha: 0.35),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(4),
          color: Colors.white.withValues(alpha: 0.04),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AGLDemoColors.periwinkleColor,
            fontSize: 40,
          ),
        ),
      ),
    );
  }
}
