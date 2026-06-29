import '../../../../../../../export.dart';

/// Used by [BluetoothPairingRequest] and the forget confirmation dialog
/// in [BluetoothContent] to avoid duplicating the gradient border chrome.
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
        gradient: LinearGradient(
          colors: [
            AGLDemoColors.periwinkleColor.withValues(alpha: 0.2),
            AGLDemoColors.periwinkleColor,
          ],
        ),
        borderRadius: BorderRadius.circular(40),
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
          borderRadius: BorderRadius.circular(39),
          gradient: const RadialGradient(
            radius: 1,
            colors: [AGLDemoColors.backgroundInsetColor, Colors.black],
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DialogTitle(title),
            Padding(
              padding: const EdgeInsets.fromLTRB(42, 48, 42, 54),
              child: body,
            ),
            _DialogButtons(
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

class _DialogTitle extends StatelessWidget {
  const _DialogTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 34),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.center,
          colors: [
            AGLDemoColors.jordyBlueColor.withValues(alpha: 0.2),
            AGLDemoColors.jordyBlueColor.withValues(alpha: 0),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: AGLDemoColors.jordyBlueColor.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _DialogButtons extends StatelessWidget {
  const _DialogButtons({
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
      padding: const EdgeInsets.symmetric(horizontal: 42, vertical: 36),
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
          Expanded(
            child: GenericButton(
              height: 88,
              width: double.infinity,
              text: cancelLabel,
              onTap: onCancel ?? () {},
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: GenericButton(
              height: 88,
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
