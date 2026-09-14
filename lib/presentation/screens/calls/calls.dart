import 'package:flutter_ics_homescreen/export.dart';

/// Bluetooth phone dialer.
class CallsPage extends ConsumerStatefulWidget {
  const CallsPage({super.key});

  static Page<void> page() => const MaterialPage<void>(child: CallsPage());

  @override
  ConsumerState<CallsPage> createState() => _CallsPageState();
}

class _CallsPageState extends ConsumerState<CallsPage> {
  static const _suggestions = [
    ('Aisha Rahman', '+60 12-345 6789', 'assets/contact_aisha_rahman.png'),
    ('Daniel Tan', '+60 17-654 3210', 'assets/contact_daniel_tan.png'),
  ];

  String _number = '';

  void _append(String digit) {
    if (_number.length < 32) setState(() => _number += digit);
  }

  void _delete() {
    if (_number.isNotEmpty) {
      setState(() => _number = _number.substring(0, _number.length - 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final call = ref.watch(callStateProvider);
    final inCall = call.status == CallStatus.active ||
        call.status == CallStatus.dialing ||
        call.status == CallStatus.held;

    return Column(
      children: [
        CommonTitle(
          title: 'Calls',
          hasBackButton: true,
          onPressed: () => ref.read(appProvider.notifier).update(AppState.apps),
        ),
        Expanded(
          child: inCall
              ? const ActiveCallScreen()
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 900 &&
                        constraints.maxWidth > constraints.maxHeight;
                    final leftPadding =
                        constraints.maxWidth >= 700 ? 120.0 : 28.0;
                    return SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        leftPadding,
                        20,
                        wide ? 72 : 28,
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
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                children: [
                                  _buildPhoneHeader(),
                                  const SizedBox(height: 24),
                                  _buildSuggestedContacts(),
                                ],
                              ),
                              if (wide)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      flex: 4,
                                      child: _buildDialHeader(),
                                    ),
                                    const SizedBox(width: 48),
                                    Expanded(
                                      flex: 6,
                                      child: _buildDialControls(),
                                    ),
                                  ],
                                )
                              else
                                _buildDialControls(
                                  header: _buildDialHeader(),
                                ),
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

  Widget _buildPhoneHeader() {
    return Row(
      key: const ValueKey('phone-status'),
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AGLDemoColors.jordyBlueColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.phone_in_talk_rounded,
            color: AGLDemoColors.jordyBlueColor,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Phone',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Ready to call',
                style: TextStyle(
                  color: AGLDemoColors.periwinkleColor,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        _buildIncomingPreview(),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AGLDemoColors.greenColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bluetooth_rounded,
                size: 17,
                color: AGLDemoColors.greenColor,
              ),
              SizedBox(width: 7),
              Text(
                'Connected',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AGLDemoColors.greenColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDialHeader() {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: Semantics(
        label: 'Phone number',
        value: _number.isEmpty ? 'Empty' : _number,
        excludeSemantics: true,
        child: _number.isEmpty
            ? const SizedBox.shrink()
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _number,
                  key: const ValueKey('dialed-number'),
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.4,
                    color: Colors.white,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildDialControls({Widget? header}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (header != null) ...[
          header,
          const SizedBox(height: 20),
        ],
        _buildKeypad(),
        const SizedBox(height: 24),
        _buildDialActions(),
      ],
    );
  }

  Widget _buildSuggestedContacts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Suggested contacts',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AGLDemoColors.periwinkleColor.withValues(alpha: 0.82),
          ),
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < _suggestions.length; index++) ...[
          if (index > 0) const SizedBox(height: 10),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  stops: [0.1, 1],
                  colors: [Colors.black, Colors.black12],
                ),
              ),
              child: InkWell(
                key: ValueKey('suggested-contact-$index'),
                borderRadius: BorderRadius.circular(18),
                onTap: () => ref.read(callStateProvider.notifier).startCall(
                      _suggestions[index].$2,
                      name: _suggestions[index].$1,
                    ),
                child: SizedBox(
                  height: 130,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AGLDemoColors.jordyBlueColor
                                .withValues(alpha: 0.18),
                            image: DecorationImage(
                              image: AssetImage(_suggestions[index].$3),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _suggestions[index].$1,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _suggestions[index].$2,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AGLDemoColors.periwinkleColor
                                      .withValues(alpha: 0.65),
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.call_outlined,
                          size: 30,
                          color: AGLDemoColors.greenColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDialActions() {
    return Row(
      children: [
        Expanded(
          child: Center(
            child: TextButton(
              onPressed:
                  _number.isEmpty ? null : () => setState(() => _number = ''),
              style: TextButton.styleFrom(
                foregroundColor: AGLDemoColors.periwinkleColor,
                disabledForegroundColor:
                    AGLDemoColors.periwinkleColor.withValues(alpha: 0.42),
                minimumSize: const Size(88, 56),
                textStyle: const TextStyle(fontSize: 17),
              ),
              child: const Text('Clear'),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: Semantics(
              label: 'Call',
              button: true,
              child: SizedBox.square(
                dimension: 76,
                child: ElevatedButton(
                  onPressed: _number.isEmpty
                      ? null
                      : () => ref
                          .read(callStateProvider.notifier)
                          .startCall(_number),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AGLDemoColors.greenColor,
                    disabledBackgroundColor:
                        AGLDemoColors.greenColor.withValues(alpha: 0.24),
                    foregroundColor: AGLDemoColors.backgroundInsetColor,
                    disabledForegroundColor:
                        AGLDemoColors.periwinkleColor.withValues(alpha: 0.42),
                    shape: const CircleBorder(),
                    padding: EdgeInsets.zero,
                    elevation: _number.isEmpty ? 0 : 3,
                  ),
                  child: const Icon(Icons.call_rounded, size: 34),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: IconButton(
              tooltip: 'Delete last digit',
              iconSize: 28,
              padding: const EdgeInsets.all(14),
              color: AGLDemoColors.periwinkleColor,
              disabledColor:
                  AGLDemoColors.periwinkleColor.withValues(alpha: 0.42),
              onPressed: _number.isEmpty ? null : _delete,
              icon: const Icon(Icons.backspace_outlined),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIncomingPreview() {
    return IconButton(
      tooltip: 'Preview incoming call',
      onPressed: () => ref
          .read(callStateProvider.notifier)
          .receiveIncomingCall('Jane Doe', '+1 (555) 234-5678'),
      style: IconButton.styleFrom(
        foregroundColor: AGLDemoColors.periwinkleColor,
        backgroundColor: AGLDemoColors.callControlColor,
        minimumSize: const Size.square(48),
      ),
      icon: const Icon(Icons.notifications_none_rounded, size: 22),
    );
  }

  Widget _buildKeypad() {
    return PhoneKeypad(
      key: const ValueKey('dial-keypad'),
      keyPrefix: 'dial-key',
      onKeyPressed: _append,
      onZeroLongPress: () => _append('+'),
    );
  }
}
