import 'package:flutter_ics_homescreen/export.dart';

/// Dynamic Capsule Top Banner for Incoming Phone Calls.
/// Inspired by modern Dynamic Island & Automotive HUD notification pills.
class IncomingCallOverlay extends ConsumerWidget {
  const IncomingCallOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callState = ref.watch(callStateProvider);
    if (callState.status != CallStatus.incoming) {
      return const SizedBox.shrink();
    }

    final callNotifier = ref.read(callStateProvider.notifier);

    return Positioned(
      top: 12,
      left: 20,
      right: 20,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Material(
            color: Colors.transparent,
            elevation: 16,
            borderRadius: BorderRadius.circular(40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 740),
              child: Container(
                height: 76,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AGLDemoColors.gradientBackgroundDarkColor,
                      AGLDemoColors.backgroundInsetColor,
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(
                    color: AGLDemoColors.neonBlueColor.withValues(alpha: 0.7),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.85),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: AGLDemoColors.neonBlueColor.withValues(alpha: 0.3),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Avatar Badge with Glowing Indicator Ring
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AGLDemoColors.greenColor.withValues(alpha: 0.15),
                        border: Border.all(
                          color: AGLDemoColors.greenColor,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AGLDemoColors.greenColor
                                .withValues(alpha: 0.4),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.person,
                          size: 32,
                          color: AGLDemoColors.periwinkleColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Name & Subtitle Info
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            callState.name.isEmpty
                                ? 'Unknown Caller'
                                : callState.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AGLDemoColors.greenColor,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${callState.number} • Incoming Call',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AGLDemoColors.jordyBlueColor,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Driver Call Actions (Decline / Accept Pills)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Decline Action
                        Semantics(
                          button: true,
                          label: 'Decline Call',
                          child: SizedBox(
                            width: 52,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: callNotifier.rejectCall,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    AGLDemoColors.redProgressStrokeColor,
                                foregroundColor: Colors.white,
                                shape: const CircleBorder(),
                                padding: EdgeInsets.zero,
                                elevation: 4,
                                shadowColor: AGLDemoColors
                                    .redProgressStrokeColor
                                    .withValues(alpha: 0.4),
                              ),
                              child: const Icon(
                                Icons.call_end,
                                size: 26,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Accept Action
                        Semantics(
                          button: true,
                          label: 'Accept Call',
                          child: SizedBox(
                            width: 52,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: callNotifier.acceptCall,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AGLDemoColors.greenColor,
                                foregroundColor: Colors.black,
                                shape: const CircleBorder(),
                                padding: EdgeInsets.zero,
                                elevation: 4,
                                shadowColor: AGLDemoColors.greenColor
                                    .withValues(alpha: 0.4),
                              ),
                              child: const Icon(
                                Icons.call,
                                size: 26,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
