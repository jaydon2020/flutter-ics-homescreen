import 'package:flutter_ics_homescreen/export.dart';

/// Modern In-Call Interface.
/// Inspired by modern iOS/Android in-call screens & automotive cockpit designs.
class ActiveCallScreen extends ConsumerStatefulWidget {
  const ActiveCallScreen({super.key});

  @override
  ConsumerState<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends ConsumerState<ActiveCallScreen> {
  bool _showKeypad = false;
  String _dtmfDigits = '';

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    final hours = duration.inHours;
    if (hours > 0) {
      return '${twoDigits(hours)}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final callState = ref.watch(callStateProvider);
    final callNotifier = ref.read(callStateProvider.notifier);

    final statusText = callState.status == CallStatus.dialing
        ? 'Dialing...'
        : callState.status == CallStatus.held
            ? 'Call On Hold'
            : callState.status == CallStatus.ended
                ? 'Call Ended'
                : 'Connected';

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Status Header Pill
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: AGLDemoColors.backgroundInsetColor
                          .withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AGLDemoColors.jordyBlueColor
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          callState.isSpeaker
                              ? Icons.volume_up
                              : Icons.bluetooth_audio,
                          color: AGLDemoColors.jordyBlueColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          statusText,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AGLDemoColors.periwinkleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Avatar & Caller Info Card
                  Column(
                    children: [
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AGLDemoColors.neonBlueColor
                              .withValues(alpha: 0.12),
                          border: Border.all(
                            color: callState.isHeld
                                ? AGLDemoColors.yellowColor
                                : AGLDemoColors.neonBlueColor,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (callState.isHeld
                                      ? AGLDemoColors.yellowColor
                                      : AGLDemoColors.neonBlueColor)
                                  .withValues(alpha: 0.35),
                              blurRadius: 28,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            Icons.person,
                            size: 80,
                            color: callState.isHeld
                                ? AGLDemoColors.yellowColor
                                : AGLDemoColors.periwinkleColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        callState.name.isEmpty
                            ? 'Unknown Caller'
                            : callState.name,
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        callState.number,
                        style: const TextStyle(
                          fontSize: 22,
                          color: AGLDemoColors.periwinkleColor,
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Live Duration Chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 8),
                        decoration: BoxDecoration(
                          color: AGLDemoColors.backgroundInsetColor,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AGLDemoColors.greenColor
                                .withValues(alpha: 0.4),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AGLDemoColors.greenColor
                                  .withValues(alpha: 0.15),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: Text(
                          _formatDuration(callState.duration),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: AGLDemoColors.greenColor,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // In-Call DTMF Keypad Overlay
                  if (_showKeypad) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: AGLDemoColors.backgroundInsetColor
                            .withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AGLDemoColors.jordyBlueColor
                              .withValues(alpha: 0.4),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _dtmfDigits.isEmpty ? 'Keypad' : _dtmfDigits,
                            style: const TextStyle(
                              fontSize: 24,
                              color: Colors.white,
                              letterSpacing: 4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 16,
                            runSpacing: 12,
                            alignment: WrapAlignment.center,
                            children: ['1', '2', '3', '4', '5', '6', '7', '8', '9', '*', '0', '#']
                                .map(
                                  (digit) => SizedBox(
                                    width: 52,
                                    height: 52,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        backgroundColor: AGLDemoColors
                                            .jordyBlueColor
                                            .withValues(alpha: 0.2),
                                        shape: const CircleBorder(),
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _dtmfDigits += digit;
                                        });
                                      },
                                      child: Text(
                                        digit,
                                        style: const TextStyle(
                                          fontSize: 22,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // In-Call Action Control Bar (Sleek Round Controls)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Mute Button
                      _buildControlButton(
                        icon: callState.isMuted
                            ? Icons.mic_off
                            : Icons.mic,
                        label: callState.isMuted ? 'Unmute' : 'Mute',
                        isActive: callState.isMuted,
                        activeColor: AGLDemoColors.yellowColor,
                        onPressed: callNotifier.toggleMute,
                      ),

                      // Keypad Toggle
                      _buildControlButton(
                        icon: Icons.dialpad,
                        label: _showKeypad ? 'Hide Keypad' : 'Keypad',
                        isActive: _showKeypad,
                        activeColor: AGLDemoColors.neonBlueColor,
                        onPressed: () {
                          setState(() {
                            _showKeypad = !_showKeypad;
                          });
                        },
                      ),

                      // Speaker Toggle
                      _buildControlButton(
                        icon: callState.isSpeaker
                            ? Icons.volume_up
                            : Icons.bluetooth_audio,
                        label: callState.isSpeaker ? 'Speaker' : 'Bluetooth',
                        isActive: callState.isSpeaker,
                        activeColor: AGLDemoColors.neonBlueColor,
                        onPressed: callNotifier.toggleSpeaker,
                      ),

                      // Hold Button
                      _buildControlButton(
                        icon: callState.isHeld
                            ? Icons.play_arrow
                            : Icons.pause,
                        label: callState.isHeld ? 'Resume' : 'Hold',
                        isActive: callState.isHeld,
                        activeColor: AGLDemoColors.yellowColor,
                        onPressed: callNotifier.toggleHold,
                      ),

                      // End Call Button
                      Semantics(
                        button: true,
                        label: 'End Call',
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 72,
                              height: 72,
                              child: ElevatedButton(
                                onPressed: callNotifier.endCall,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      AGLDemoColors.redProgressStrokeColor,
                                  foregroundColor: Colors.white,
                                  shape: const CircleBorder(),
                                  elevation: 6,
                                  shadowColor: AGLDemoColors
                                      .redProgressStrokeColor
                                      .withValues(alpha: 0.5),
                                ),
                                child: const Icon(
                                  Icons.call_end,
                                  size: 36,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'End Call',
                              style: TextStyle(
                                fontSize: 15,
                                color: AGLDemoColors.periwinkleColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onPressed,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: isActive
                    ? activeColor.withValues(alpha: 0.25)
                    : AGLDemoColors.jordyBlueColor.withValues(alpha: 0.12),
                foregroundColor: isActive ? activeColor : Colors.white,
                shape: const CircleBorder(),
                side: BorderSide(
                  color: isActive
                      ? activeColor
                      : AGLDemoColors.jordyBlueColor.withValues(alpha: 0.3),
                  width: isActive ? 2 : 1,
                ),
                elevation: isActive ? 4 : 0,
              ),
              child: Icon(
                icon,
                size: 28,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: isActive ? activeColor : AGLDemoColors.periwinkleColor,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
