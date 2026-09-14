import 'package:flutter_ics_homescreen/export.dart';

const phoneKeypadKeys = [
  ('1', ''),
  ('2', 'ABC'),
  ('3', 'DEF'),
  ('4', 'GHI'),
  ('5', 'JKL'),
  ('6', 'MNO'),
  ('7', 'PQRS'),
  ('8', 'TUV'),
  ('9', 'WXYZ'),
  ('*', ''),
  ('0', '+'),
  ('#', ''),
];

/// The shared Bluetooth and in-call keypad.
class PhoneKeypad extends StatelessWidget {
  const PhoneKeypad({
    required this.keyPrefix,
    required this.onKeyPressed,
    super.key,
    this.onZeroLongPress,
  });

  final String keyPrefix;
  final ValueChanged<String> onKeyPressed;
  final VoidCallback? onZeroLongPress;

  @override
  Widget build(BuildContext context) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        mainAxisExtent: 100,
      ),
      children: [
        for (final (digit, letters) in phoneKeypadKeys)
          Semantics(
            button: true,
            label: switch (digit) {
              '*' => 'Star',
              '#' => 'Hash',
              _ => digit,
            },
            hint: digit == '0' && onZeroLongPress != null
                ? 'Hold to enter plus'
                : letters.isEmpty
                    ? null
                    : letters,
            excludeSemantics: true,
            child: LayoutBuilder(
              builder: (context, constraints) => Center(
                child: SizedBox(
                  width: constraints.constrainWidth(164),
                  height: constraints.constrainHeight(88),
                  child: Material(
                    color: AGLDemoColors.callControlColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(
                        color: AGLDemoColors.jordyBlueColor
                            .withValues(alpha: 0.28),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      key: ValueKey('$keyPrefix-$digit'),
                      borderRadius: BorderRadius.circular(24),
                      splashColor:
                          AGLDemoColors.neonBlueColor.withValues(alpha: 0.28),
                      highlightColor:
                          AGLDemoColors.jordyBlueColor.withValues(alpha: 0.14),
                      onTap: () => onKeyPressed(digit),
                      onLongPress: digit == '0' ? onZeroLongPress : null,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              digit,
                              style: const TextStyle(
                                fontSize: 30,
                                height: 1,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                            if (letters.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                letters,
                                style: TextStyle(
                                  fontSize: 10,
                                  height: 1,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.6,
                                  color: AGLDemoColors.periwinkleColor
                                      .withValues(alpha: 0.78),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
