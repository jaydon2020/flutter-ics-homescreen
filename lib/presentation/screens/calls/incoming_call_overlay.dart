import 'package:flutter_ics_homescreen/export.dart';

/// Full-width, glanceable incoming-call banner.
class IncomingCallOverlay extends ConsumerWidget {
  const IncomingCallOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final call = ref.watch(callStateProvider);
    if (call.status != CallStatus.incoming) return const SizedBox.shrink();

    final notifier = ref.read(callStateProvider.notifier);
    return Positioned(
      top: 8,
      left: 12,
      right: 12,
      child: SafeArea(
        child: Material(
          color: Colors.transparent,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 600;
              return Container(
                key: const ValueKey('incoming-call-banner'),
                height: 132,
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 10 : 22,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: AGLDemoColors.callNotificationGradient,
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.55),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _NotifierAction(
                      label: 'Decline',
                      icon: Icons.call_end_rounded,
                      color: AGLDemoColors.callDangerColor,
                      compact: compact,
                      onPressed: notifier.rejectCall,
                    ),
                    Expanded(
                      child: Center(
                        child: _CallerDetails(call: call, compact: compact),
                      ),
                    ),
                    _NotifierAction(
                      label: 'Answer',
                      icon: Icons.call_rounded,
                      color: AGLDemoColors.greenColor,
                      compact: compact,
                      darkForeground: true,
                      onPressed: notifier.acceptCall,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CallerDetails extends StatelessWidget {
  const _CallerDetails({required this.call, required this.compact});

  final CallState call;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final details = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          call.name.isEmpty ? 'Unknown caller' : call.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            fontSize: compact ? 18 : 24,
            height: 1.1,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          compact ? call.number : 'Incoming call  •  ${call.number}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            fontSize: compact ? 12 : 15,
            color: AGLDemoColors.periwinkleColor.withValues(alpha: 0.8),
          ),
        ),
      ],
    );

    if (compact) return details;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AGLDemoColors.callControlColor,
          ),
          child: const Icon(
            Icons.person_rounded,
            size: 38,
            color: AGLDemoColors.periwinkleColor,
          ),
        ),
        const SizedBox(width: 18),
        Flexible(child: details),
      ],
    );
  }
}

class _NotifierAction extends StatelessWidget {
  const _NotifierAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.compact,
    required this.onPressed,
    this.darkForeground = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool compact;
  final VoidCallback onPressed;
  final bool darkForeground;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label call',
      child: InkWell(
        key: ValueKey('incoming-${label.toLowerCase()}'),
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: compact ? 72 : 112,
          height: 88,
          child: Center(
            child: Container(
              width: compact ? 54 : 64,
              height: compact ? 54 : 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
              child: Icon(
                icon,
                size: compact ? 25 : 30,
                color: darkForeground
                    ? AGLDemoColors.backgroundInsetColor
                    : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
