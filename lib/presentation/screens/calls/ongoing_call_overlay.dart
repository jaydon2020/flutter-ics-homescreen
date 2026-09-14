import 'package:flutter_ics_homescreen/export.dart';

/// Compact call controls shown after the user leaves the Calls app.
class OngoingCallOverlay extends ConsumerWidget {
  const OngoingCallOverlay({super.key});

  String _formatDuration(Duration duration) {
    String digits(int value) => value.toString().padLeft(2, '0');
    final time = '${digits(duration.inMinutes.remainder(60))}:'
        '${digits(duration.inSeconds.remainder(60))}';
    return duration.inHours == 0 ? time : '${digits(duration.inHours)}:$time';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final call = ref.watch(callStateProvider);
    final app = ref.watch(appProvider);
    final visible = app != AppState.calls &&
        (call.status == CallStatus.dialing ||
            call.status == CallStatus.active ||
            call.status == CallStatus.held);
    if (!visible) return const SizedBox.shrink();

    final notifier = ref.read(callStateProvider.notifier);
    final held = call.status == CallStatus.held;
    final status = call.status == CallStatus.dialing
        ? 'Calling'
        : held
            ? 'On hold'
            : _formatDuration(call.duration);
    final accent = held ? AGLDemoColors.yellowColor : AGLDemoColors.greenColor;

    return Positioned(
      top: 8,
      left: 12,
      right: 12,
      child: SafeArea(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: Container(
            key: const ValueKey('ongoing-call-widget'),
            height: 132,
            padding: const EdgeInsets.symmetric(
              horizontal: 22,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              gradient: AGLDemoColors.callNotificationGradient,
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'Return to active call',
                    child: InkWell(
                      key: const ValueKey('return-to-call'),
                      borderRadius: BorderRadius.circular(20),
                      onTap: () =>
                          ref.read(appProvider.notifier).update(AppState.calls),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            Container(
                              key: const ValueKey('ongoing-call-icon'),
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AGLDemoColors.callControlColor
                                    .withValues(alpha: 0.72),
                              ),
                              child: Icon(
                                held ? Icons.pause_rounded : Icons.call_rounded,
                                color: accent,
                                size: 25,
                              ),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    call.name.isEmpty ? call.number : call.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Container(
                                        width: 7,
                                        height: 7,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: accent,
                                        ),
                                      ),
                                      const SizedBox(width: 7),
                                      Text(
                                        status,
                                        key: const ValueKey(
                                          'ongoing-call-status',
                                        ),
                                        style: TextStyle(
                                          color: accent,
                                          fontSize: 13,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        color: AGLDemoColors.periwinkleColor
                                            .withValues(alpha: 0.65),
                                        size: 18,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _QuickAction(
                  label: call.isMuted ? 'Unmute' : 'Mute',
                  icon:
                      call.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                  selected: call.isMuted,
                  onPressed: call.status == CallStatus.dialing
                      ? null
                      : notifier.toggleMute,
                ),
                const SizedBox(width: 8),
                _QuickAction(
                  key: const ValueKey('ongoing-hang-up'),
                  label: 'End call',
                  icon: Icons.call_end_rounded,
                  color: AGLDemoColors.callDangerColor,
                  onPressed: notifier.endCall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.color,
    this.selected = false,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final foreground = color ??
        (selected ? AGLDemoColors.yellowColor : AGLDemoColors.periwinkleColor);
    return Tooltip(
      message: label,
      child: SizedBox.square(
        dimension: color == null ? 48 : 64,
        child: IconButton(
          onPressed: onPressed,
          color: foreground,
          disabledColor: foreground.withValues(alpha: 0.3),
          style: IconButton.styleFrom(
            backgroundColor: color?.withValues(alpha: 0.12) ??
                foreground.withValues(alpha: selected ? 0.18 : 0.08),
            shape: const CircleBorder(),
          ),
          icon: Icon(
            icon,
            size: color == null ? 24 : 30,
            color: foreground,
          ),
        ),
      ),
    );
  }
}
