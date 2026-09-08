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
                    constraints: BoxConstraints(maxWidth: wide ? 1120 : 560),
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
                              const SizedBox(height: 36),
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bluetooth,
              size: 24,
              color: AGLDemoColors.jordyBlueColor,
            ),
            SizedBox(width: 12),
            Flexible(
              child: Text(
                'Bluetooth calling',
                style: TextStyle(
                  fontSize: 22,
                  color: AGLDemoColors.periwinkleColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
                      alignment: Alignment.center,
                      child: Text(
                        _number.isEmpty ? 'Enter number' : _number,
                        key: const ValueKey('dialed-number'),
                        style: TextStyle(
                          fontSize: _number.isEmpty ? 42 : 56,
                          fontWeight: FontWeight.w300,
                          color: _number.isEmpty
                              ? AGLDemoColors.periwinkleColor
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Text(
          'Hold 0 for +',
          style: TextStyle(fontSize: 20, color: AGLDemoColors.jordyBlueColor),
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
          mainAxisSpacing: 18,
          crossAxisSpacing: 36,
          childAspectRatio: 1,
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
                  color: AGLDemoColors.jordyBlueColor.withValues(alpha: 0.09),
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: Ink(
                    child: InkWell(
                      key: ValueKey('dial-key-$digit'),
                      customBorder: const CircleBorder(),
                      splashColor:
                          AGLDemoColors.neonBlueColor.withValues(alpha: 0.3),
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
                                    fontWeight: FontWeight.w300,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  letters.isEmpty ? ' ' : letters,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    letterSpacing: 2,
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
        const SizedBox(height: 32),
        Row(children: [
          Expanded(
              child: Center(
                  child: TextButton(
            onPressed:
                _number.isEmpty ? null : () => setState(() => _number = ''),
            style: TextButton.styleFrom(
              foregroundColor: AGLDemoColors.periwinkleColor,
              minimumSize: const Size(64, 64),
              textStyle: const TextStyle(fontSize: 22),
            ),
            child: const Text('Clear'),
          ))),
          Expanded(
              child: Center(
                  child: Semantics(
                      label: 'Call',
                      child: SizedBox.square(
                        dimension: 88,
                        child: ElevatedButton(
                          onPressed: null,
                          style: ElevatedButton.styleFrom(
                            disabledBackgroundColor: AGLDemoColors.greenColor
                                .withValues(alpha: 0.18),
                            disabledForegroundColor:
                                AGLDemoColors.greenColor.withValues(
                              alpha: 0.65,
                            ),
                            shape: const CircleBorder(),
                            padding: EdgeInsets.zero,
                            textStyle: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          child: const Icon(Icons.call, size: 38),
                        ),
                      )))),
          Expanded(
              child: Center(
                  child: IconButton(
            tooltip: 'Delete last digit',
            iconSize: 32,
            padding: const EdgeInsets.all(16),
            color: AGLDemoColors.periwinkleColor,
            disabledColor: AGLDemoColors.periwinkleColor.withValues(alpha: 0.3),
            onPressed: _number.isEmpty
                ? null
                : () => setState(
                      () => _number = _number.substring(0, _number.length - 1),
                    ),
            icon: const Icon(Icons.backspace_outlined),
          ))),
        ]),
        const SizedBox(height: 12),
        const Text('Call',
            textAlign: TextAlign.center,
            style:
                TextStyle(fontSize: 20, color: AGLDemoColors.periwinkleColor)),
        const SizedBox(height: 24),
        Text('Calls are currently unavailable.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 20,
                color: AGLDemoColors.periwinkleColor.withValues(alpha: 0.6))),
      ],
    );
  }
}
