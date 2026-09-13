import 'package:flutter_ics_homescreen/export.dart';

/// Dial-pad presentation with active call and incoming call integration.
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
    final callState = ref.watch(callStateProvider);

    final isCallActive = callState.status == CallStatus.active ||
        callState.status == CallStatus.dialing ||
        callState.status == CallStatus.held;

    return Stack(
      children: [
        Column(
          children: [
            CommonTitle(
              title: 'Calls',
              hasBackButton: true,
              onPressed: () =>
                  ref.read(appProvider.notifier).update(AppState.apps),
            ),
            Expanded(
              child: isCallActive
                  ? const ActiveCallScreen()
                  : LayoutBuilder(
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
                              constraints:
                                  BoxConstraints(maxWidth: wide ? 1120 : 560),
                              child: wide
                                  ? Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
        ),
        const IncomingCallOverlay(),
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
                onPressed: _number.isEmpty
                    ? null
                    : () => setState(() => _number = ''),
                style: TextButton.styleFrom(
                  foregroundColor: AGLDemoColors.periwinkleColor,
                  minimumSize: const Size(64, 64),
                  textStyle: const TextStyle(fontSize: 22),
                ),
                child: const Text('Clear'),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Semantics(
                label: 'Call',
                child: SizedBox.square(
                  dimension: 88,
                  child: ElevatedButton(
                    onPressed: () {
                      final dialNumber = _number.isEmpty
                          ? '+1 (555) 019-2834'
                          : _number;
                      ref
                          .read(callStateProvider.notifier)
                          .startCall(dialNumber);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AGLDemoColors.greenColor,
                      foregroundColor: Colors.black,
                      shape: const CircleBorder(),
                      padding: EdgeInsets.zero,
                      elevation: 6,
                    ),
                    child: const Icon(Icons.call, size: 38),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: IconButton(
                tooltip: 'Delete last digit',
                iconSize: 32,
                padding: const EdgeInsets.all(16),
                color: AGLDemoColors.periwinkleColor,
                disabledColor:
                    AGLDemoColors.periwinkleColor.withValues(alpha: 0.3),
                onPressed: _number.isEmpty
                    ? null
                    : () => setState(
                          () =>
                              _number = _number.substring(0, _number.length - 1),
                        ),
                icon: const Icon(Icons.backspace_outlined),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        const Text(
          'Call',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            color: AGLDemoColors.periwinkleColor,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AGLDemoColors.backgroundInsetColor.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AGLDemoColors.jordyBlueColor.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.tune, color: AGLDemoColors.jordyBlueColor, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Call Notifier Simulation Controls',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AGLDemoColors.periwinkleColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  // Button 1: Known Contact
                  OutlinedButton.icon(
                    onPressed: () {
                      ref.read(callStateProvider.notifier).receiveIncomingCall(
                            'Jane Doe',
                            '+1 (555) 234-5678',
                          );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AGLDemoColors.greenColor,
                      side: BorderSide(
                        color: AGLDemoColors.greenColor.withValues(alpha: 0.6),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.ring_volume, size: 18),
                    label: const Text('Incoming: Jane Doe'),
                  ),
                  // Button 2: Work Call
                  OutlinedButton.icon(
                    onPressed: () {
                      ref.read(callStateProvider.notifier).receiveIncomingCall(
                            'Sarah (Manager)',
                            '+1 (555) 987-6543',
                          );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AGLDemoColors.jordyBlueColor,
                      side: BorderSide(
                        color: AGLDemoColors.jordyBlueColor.withValues(alpha: 0.6),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.business_center_outlined, size: 18),
                    label: const Text('Incoming: Manager'),
                  ),
                  // Button 3: Unknown Call
                  OutlinedButton.icon(
                    onPressed: () {
                      ref.read(callStateProvider.notifier).receiveIncomingCall(
                            'Unknown Caller',
                            '+1 (800) 555-0199',
                          );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AGLDemoColors.yellowColor,
                      side: BorderSide(
                        color: AGLDemoColors.yellowColor.withValues(alpha: 0.6),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.help_outline, size: 18),
                    label: const Text('Incoming: Unknown'),
                  ),
                  // Button 4: Start Outgoing Call
                  OutlinedButton.icon(
                    onPressed: () {
                      ref.read(callStateProvider.notifier).startCall(
                            '+1 (555) 432-1098',
                            name: 'Roadside Assistance',
                          );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AGLDemoColors.periwinkleColor,
                      side: BorderSide(
                        color: AGLDemoColors.periwinkleColor.withValues(alpha: 0.6),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.call_made, size: 18),
                    label: const Text('Start Outgoing Call'),
                  ),
                  // Button 5: Reset Call State
                  OutlinedButton.icon(
                    onPressed: () {
                      ref.read(callStateProvider.notifier).endCall();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AGLDemoColors.redProgressStrokeColor,
                      side: BorderSide(
                        color: AGLDemoColors.redProgressStrokeColor
                            .withValues(alpha: 0.6),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('Reset Call Notifier'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
