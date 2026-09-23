import 'package:flutter_ics_homescreen/export.dart';
import 'package:flutter_ics_homescreen/presentation/screens/calls/calls.dart';
import 'package:flutter_ics_homescreen/presentation/screens/apps/apps_content.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestPhoneDataNotifier extends PhoneDataNotifier {
  @override
  PhoneDataState build() => PhoneDataState(
    status: PhoneConnectionStatus.ready,
    deviceName: 'Test phone',
    pbapAvailable: true,
    mapAvailable: true,
    contacts: const [
      PhoneContact(
        id: 'aisha',
        name: 'Aisha Rahman',
        numbers: ['+60 12-345 6789'],
      ),
    ],
    recents: [
      RecentCall(
        id: 'recent',
        name: 'Aisha Rahman',
        number: '+60 12-345 6789',
        timestamp: DateTime(2026, 9, 20, 12),
        type: RecentCallType.incoming,
      ),
    ],
  );
}

class _TestCallNotifier extends CallStateNotifier {
  @override
  CallState build() => const CallState(
    status: CallStatus.idle,
    name: '',
    number: '',
    duration: Duration.zero,
    isMuted: false,
    isSpeaker: false,
    isHeld: false,
    connected: true,
  );

  @override
  Future<void> startCall(String number, {String? name}) async {}
}

class _ActiveCallNotifier extends CallStateNotifier {
  @override
  CallState build() => const CallState(
    status: CallStatus.active,
    name: 'Aisha Rahman',
    number: '+60 12-345 6789',
    duration: Duration(seconds: 12),
    isMuted: false,
    isSpeaker: false,
    isHeld: false,
    connected: true,
    activeCallId: '/call/1',
    participants: [
      CallParticipant(
        id: '/call/1',
        name: 'Aisha Rahman',
        number: '+60 12-345 6789',
        status: CallStatus.active,
      ),
    ],
  );

  @override
  Future<void> sendTones(String tones) async {}
  @override
  Future<void> toggleMute() async {}
  @override
  Future<void> toggleHold() async {}
  @override
  Future<void> endCall() async {}
}

void main() {
  Future<void> show(
    WidgetTester tester,
    Widget page, {
    Size size = const Size(1080, 1920),
    bool active = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          phoneDataProvider.overrideWith(_TestPhoneDataNotifier.new),
          callStateProvider.overrideWith(
            active ? _ActiveCallNotifier.new : _TestCallNotifier.new,
          ),
        ],
        child: MaterialApp(
          theme: ThemeData.dark().copyWith(splashFactory: NoSplash.splashFactory),
          home: Scaffold(body: page),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('Phone exposes Recents Contacts and Dial with stable keypad', (
    tester,
  ) async {
    await show(tester, const CallsPage());
    expect(find.text('Recents'), findsOneWidget);
    expect(find.text('Contacts'), findsOneWidget);
    expect(find.text('Dial'), findsOneWidget);
    final before = tester.getTopLeft(find.byKey(const ValueKey('dial-keypad')));
    expect(before.dy, greaterThan(1000));
    await tester.tap(find.byKey(const ValueKey('dial-key-6')));
    await tester.tap(find.byKey(const ValueKey('dial-key-0')));
    await tester.pump();
    expect(find.text('60'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('dial-keypad'))),
      before,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('dial-key-1'))).height,
      greaterThanOrEqualTo(88),
    );
  });

  testWidgets('Contacts and Recents use full-width automotive rows', (
    tester,
  ) async {
    await show(tester, const CallsPage());
    await tester.tap(find.byKey(const ValueKey('phone-tab-contacts')));
    await tester.pump();
    expect(find.text('Aisha Rahman'), findsOneWidget);
    expect(find.byTooltip('Message'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('phone-tab-recents')));
    await tester.pump();
    expect(find.byTooltip('Call'), findsOneWidget);
  });

  testWidgets('Active call keypad uses reserved middle region', (tester) async {
    await show(tester, const CallsPage(), active: true);
    final stage = tester.getTopLeft(
      find.byKey(const ValueKey('in-call-keypad-space')),
    );
    final controls = tester.getTopLeft(
      find.byKey(const ValueKey('in-call-controls')),
    );
    await tester.tap(find.byIcon(Icons.dialpad_rounded));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('in-call-keypad-space'))),
      stage,
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('in-call-controls'))),
      controls,
    );
    await tester.tap(find.byKey(const ValueKey('dtmf-key-5')));
    await tester.pump();
    expect(find.text('5'), findsWidgets);
    expect(find.text('Bluetooth'), findsNothing);
  });

  testWidgets('Messages shows explicit empty profile state', (tester) async {
    await show(tester, const MessagesPage());
    expect(find.text('Conversations'), findsOneWidget);
    expect(find.text('No conversations'), findsOneWidget);
    expect(find.byTooltip('Compose message'), findsOneWidget);
    expect(find.byTooltip('Refresh messages'), findsOneWidget);
  });

  testWidgets('Apps includes Phone and Messages tiles', (tester) async {
    await show(tester, const Apps());
    expect(find.text('Phone'), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);
  });

  testWidgets('Phone and active call remain usable in 1280x720 landscape', (
    tester,
  ) async {
    await show(tester, const CallsPage(), size: const Size(1280, 720));
    expect(find.byKey(const ValueKey('dial-keypad')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await show(
      tester,
      const CallsPage(),
      size: const Size(1280, 720),
      active: true,
    );
    expect(find.byKey(const ValueKey('in-call-controls')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Dashboard shell fits 1280x720 landscape', (tester) async {
    await show(
      tester,
      const Stack(
        children: [
          DashboardPage(),
          Positioned(top: 0, bottom: 0, left: 0, child: VolumeFanControl()),
        ],
      ),
      size: const Size(1280, 720),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
