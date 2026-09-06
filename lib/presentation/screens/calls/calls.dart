import 'package:flutter_ics_homescreen/export.dart';

/// Dial-pad presentation only. Call availability will come from HFP later.
class CallsPage extends ConsumerStatefulWidget {
  const CallsPage({super.key});

  static Page<void> page() => const MaterialPage<void>(child: CallsPage());

  @override
  ConsumerState<CallsPage> createState() => _CallsPageState();
}

class _CallsPageState extends ConsumerState<CallsPage> {
  static const _keys = [
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
  String _number = '';

  void _append(String digit) {
    if (_number.length < 32) setState(() => _number += digit);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CommonTitle(
          title: 'Calls',
          hasBackButton: true,
          onPressed: () => ref.read(appProvider.notifier).update(AppState.apps),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1200;
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  constraints.maxWidth < 600 ? 24 : 148,
                  16,
                  constraints.maxWidth < 600 ? 24 : 64,
                  180,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: wide ? 1200 : 680),
                    child: wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildNumberPanel()),
                              const SizedBox(width: 48),
                              Expanded(child: _buildKeypad()),
                            ],
                          )
                        : Column(
                            children: [
                              _buildNumberPanel(),
                              const SizedBox(height: 24),
                              _buildKeypad(),
                            ],
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNumberPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Icon(
              Icons.bluetooth,
              size: 32,
              color: AGLDemoColors.jordyBlueColor,
            ),
            SizedBox(width: 12),
            Flexible(
              child: Text(
                'Bluetooth calling',
                style: TextStyle(
                  fontSize: 28,
                  color: AGLDemoColors.periwinkleColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: AGLDemoColors.backgroundInsetColor,
            border: Border.all(
              color: AGLDemoColors.jordyBlueColor.withValues(alpha: 0.45),
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  label: 'Phone number',
                  value: _number.isEmpty ? 'Empty' : _number,
                  excludeSemantics: true,
                  child: SizedBox(
                    height: 64,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _number.isEmpty ? 'Enter number' : _number,
                        key: const ValueKey('dialed-number'),
                        style: TextStyle(
                          fontSize: _number.isEmpty ? 36 : 48,
                          fontWeight: FontWeight.w400,
                          color: _number.isEmpty
                              ? AGLDemoColors.periwinkleColor
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                tooltip: 'Delete last digit',
                iconSize: 36,
                color: AGLDemoColors.periwinkleColor,
                disabledColor: AGLDemoColors.periwinkleColor.withValues(
                  alpha: 0.3,
                ),
                onPressed: _number.isEmpty
                    ? null
                    : () => setState(
                        () =>
                            _number = _number.substring(0, _number.length - 1),
                      ),
                icon: const Icon(Icons.backspace_outlined),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _number.isEmpty
                ? null
                : () => setState(() => _number = ''),
            style: TextButton.styleFrom(
              foregroundColor: AGLDemoColors.periwinkleColor,
              minimumSize: const Size(80, 56),
              textStyle: const TextStyle(fontSize: 24),
            ),
            child: const Text('Clear'),
          ),
        ),
      ],
    );
  }

  Widget _buildKeypad() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            for (final (digit, letters) in _keys)
              Semantics(
                button: true,
                onTap: () => _append(digit),
                onLongPress: digit == '0' ? () => _append('+') : null,
                label: digit == '*'
                    ? 'Star'
                    : digit == '#'
                    ? 'Hash'
                    : digit,
                hint: digit == '0' ? 'Hold to enter plus' : letters,
                excludeSemantics: true,
                child: Material(
                  color: Colors.transparent,
                  child: Ink(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AGLDemoColors.neonBlueColor),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AGLDemoColors.buttonFillEnabledColor,
                          AGLDemoColors.gradientBackgroundDarkColor,
                        ],
                      ),
                    ),
                    child: InkWell(
                      key: ValueKey('dial-key-$digit'),
                      borderRadius: BorderRadius.circular(4),
                      onTap: () => _append(digit),
                      onLongPress: digit == '0' ? () => _append('+') : null,
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  digit,
                                  style: const TextStyle(
                                    fontSize: 48,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  letters.isEmpty ? ' ' : letters,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    letterSpacing: 3,
                                    color: AGLDemoColors.periwinkleColor,
                                  ),
                                ),
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
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 80,
          child: ElevatedButton.icon(
            onPressed: null,
            style: ElevatedButton.styleFrom(
              disabledBackgroundColor: AGLDemoColors.buttonFillEnabledColor
                  .withValues(alpha: 0.4),
              disabledForegroundColor: AGLDemoColors.periwinkleColor.withValues(
                alpha: 0.45,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              textStyle: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w500,
              ),
            ),
            icon: const Icon(Icons.call_outlined, size: 36),
            label: const Text('Call'),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Calls are currently unavailable.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, color: AGLDemoColors.periwinkleColor),
        ),
      ],
    );
  }
}
