import 'package:flutter_ics_homescreen/export.dart';

class ActiveCallScreen extends ConsumerStatefulWidget {
  const ActiveCallScreen({super.key});

  @override
  ConsumerState<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends ConsumerState<ActiveCallScreen> {
  bool _showKeypad = false;
  String _dtmfDigits = '';

  String _formatDuration(Duration duration) {
    String digits(int value) => value.toString().padLeft(2, '0');
    final time = '${digits(duration.inMinutes.remainder(60))}:'
        '${digits(duration.inSeconds.remainder(60))}';
    return duration.inHours == 0 ? time : '${digits(duration.inHours)}:$time';
  }

  @override
  Widget build(BuildContext context) {
    final call = ref.watch(callStateProvider);
    final notifier = ref.read(callStateProvider.notifier);
    final status = switch (call.status) {
      CallStatus.dialing => 'Calling',
      CallStatus.held => 'On hold',
      CallStatus.ended => 'Call ended',
      _ => 'Connected',
    };
    final accent =
        call.isHeld ? AGLDemoColors.yellowColor : AGLDemoColors.jordyBlueColor;

    return LayoutBuilder(
      builder: (context, constraints) {
        final leftPadding = constraints.maxWidth >= 700 ? 120.0 : 28.0;
        final stage = SizedBox(
          key: const ValueKey('in-call-keypad-space'),
          height: 488,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedOpacity(
                opacity: _showKeypad ? 0 : 1,
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 160),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 144,
                      height: 144,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent.withValues(alpha: 0.1),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.42),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        size: 76,
                        color: AGLDemoColors.periwinkleColor,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      call.name.isEmpty ? 'Unknown caller' : call.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      call.number,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        color: AGLDemoColors.periwinkleColor
                            .withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      call.status == CallStatus.dialing
                          ? status
                          : '$status  •  ${_formatDuration(call.duration)}',
                      key: const ValueKey('call-status'),
                      style: TextStyle(
                        color: accent,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IgnorePointer(
                ignoring: !_showKeypad,
                child: ExcludeSemantics(
                  excluding: !_showKeypad,
                  child: AnimatedOpacity(
                    opacity: _showKeypad ? 1 : 0,
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 160),
                    curve: Curves.easeOutCubic,
                    child: _buildKeypad(),
                  ),
                ),
              ),
            ],
          ),
        );
        final actions = Column(
          key: const ValueKey('in-call-controls'),
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 24,
              runSpacing: 16,
              children: [
                _CallAction(
                  icon:
                      call.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                  label: call.isMuted ? 'Unmute' : 'Mute',
                  selected: call.isMuted,
                  selectedColor: AGLDemoColors.yellowColor,
                  onPressed: notifier.toggleMute,
                ),
                _CallAction(
                  icon: Icons.dialpad_rounded,
                  label: _showKeypad ? 'Hide keypad' : 'Keypad',
                  selected: _showKeypad,
                  onPressed: () => setState(() => _showKeypad = !_showKeypad),
                ),
                _CallAction(
                  icon: call.isHeld
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                  label: call.isHeld ? 'Resume' : 'Hold',
                  selected: call.isHeld,
                  selectedColor: AGLDemoColors.yellowColor,
                  onPressed: notifier.toggleHold,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _CallAction(
              icon: Icons.call_end_rounded,
              label: 'End call',
              fillColor: AGLDemoColors.callDangerColor,
              onPressed: notifier.endCall,
            ),
          ],
        );
        final controls = Column(
          mainAxisSize: MainAxisSize.min,
          children: [stage, const SizedBox(height: 24), actions],
        );

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            leftPadding,
            20,
            constraints.maxWidth >= 700 ? 72 : 28,
            160,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 980,
                minHeight: constraints.maxHeight > 180
                    ? constraints.maxHeight - 180
                    : 0,
              ),
              child: Center(child: controls),
            ),
          ),
        );
      },
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        SizedBox(
          height: 48,
          width: double.infinity,
          child: _dtmfDigits.isEmpty
              ? const SizedBox.shrink()
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _dtmfDigits,
                    key: const ValueKey('dtmf-digits'),
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 3,
                      color: Colors.white,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 16),
        PhoneKeypad(
          key: const ValueKey('in-call-keypad'),
          keyPrefix: 'dtmf-key',
          onKeyPressed: (digit) => setState(() => _dtmfDigits += digit),
        ),
      ],
    );
  }
}

class _CallAction extends StatelessWidget {
  const _CallAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
    this.selectedColor = AGLDemoColors.jordyBlueColor,
    this.fillColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool selected;
  final Color selectedColor;
  final Color? fillColor;

  @override
  Widget build(BuildContext context) {
    final color = fillColor ?? selectedColor;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: SizedBox(
        width: 104,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 96,
              child: ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: fillColor ??
                      (selected
                          ? color.withValues(alpha: 0.24)
                          : AGLDemoColors.callControlColor),
                  foregroundColor: fillColor == null && !selected
                      ? Colors.white
                      : fillColor == null
                          ? color
                          : Colors.white,
                  elevation: fillColor == null ? 0 : 3,
                  padding: EdgeInsets.zero,
                  shape: const CircleBorder(),
                  side: fillColor == null
                      ? BorderSide(
                          color: selected
                              ? color
                              : AGLDemoColors.jordyBlueColor
                                  .withValues(alpha: 0.22),
                        )
                      : BorderSide.none,
                ),
                child: Icon(icon, size: 57),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: TextStyle(
                fontSize: 15,
                color: selected
                    ? color
                    : AGLDemoColors.periwinkleColor.withValues(alpha: 0.86),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
