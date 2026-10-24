import 'package:flutter_ics_homescreen/export.dart';
import 'package:flutter_ics_homescreen/presentation/screens/calls/calls.dart';
import 'package:flutter_ics_homescreen/presentation/screens/apps/apps_content.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestPhoneDataNotifier extends PhoneDataNotifier {
  bool? requestedForce;
  @override
  Future<void> refreshContacts({bool force = false}) async {
    requestedForce = force;
  }

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

class _ManyContactsPhoneDataNotifier extends _TestPhoneDataNotifier {
  @override
  PhoneDataState build() => super.build().copyWith(
    contacts: List.generate(
      25,
      (index) => PhoneContact(
        id: '$index',
        name: 'Contact ${index.toString().padLeft(2, '0')}',
        numbers: ['+6012$index'],
      ),
    ),
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
  final commands = <String>[];
  CallState get current => state;
  void publish(CallState next) => state = next;
  @override
  Future<void> swapCalls() async => commands.add('swap');
  @override
  Future<void> releaseAndSwap() async => commands.add('releaseAndSwap');
  @override
  Future<void> createMultiparty() async => commands.add('merge');
  @override
  Future<void> holdAndAnswer() async => commands.add('holdAndAnswer');
  @override
  Future<void> releaseAndAnswer() async => commands.add('releaseAndAnswer');
  @override
  Future<void> acceptCall() async => commands.add('answer');
  @override
  Future<void> rejectCall() async => commands.add('decline');
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
  Future<void> sendTones(String tones) async => commands.add('tones:$tones');
  @override
  Future<void> toggleMute() async => commands.add('mute');
  @override
  Future<void> endCall() async => commands.add('end');
}

void main() {
  Future<void> show(
    WidgetTester tester,
    Widget page, {
    Size size = const Size(1080, 1920),
    bool active = false,
    bool manyContacts = false,
    _ActiveCallNotifier? callNotifier,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          phoneDataProvider.overrideWith(
            manyContacts
                ? _ManyContactsPhoneDataNotifier.new
                : _TestPhoneDataNotifier.new,
          ),
          callStateProvider.overrideWith(
            callNotifier != null
                ? () => callNotifier
                : active
                ? _ActiveCallNotifier.new
                : _TestCallNotifier.new,
          ),
        ],
        child: MaterialApp(
          theme: ThemeData.dark().copyWith(
            splashFactory: NoSplash.splashFactory,
          ),
          home: Scaffold(body: page),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('single call controls match commands and disable while busy', (
    tester,
  ) async {
    final notifier = _ActiveCallNotifier();
    await show(tester, const ActiveCallScreen(), callNotifier: notifier);
    expect(find.text('Hold'), findsNothing);
    expect(find.text('Resume'), findsNothing);
    expect(find.text('Swap'), findsNothing);
    await tester.tap(find.byIcon(Icons.mic_rounded));
    await tester.tap(find.byIcon(Icons.dialpad_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('dtmf-key-5')));
    await tester.tap(find.byIcon(Icons.call_end_rounded));
    expect(notifier.commands, ['mute', 'tones:5', 'end']);
    notifier.publish(
      notifier.current.copyWith(busy: true, error: 'Command failed'),
    );
    await tester.pump();
    expect(find.text('Command failed'), findsOneWidget);
    for (final button in tester.widgetList<ElevatedButton>(
      find.byType(ElevatedButton),
    )) {
      expect(button.onPressed, isNull);
    }
    await tester.tap(find.byKey(const ValueKey('dtmf-key-5')));
    expect(notifier.commands, ['mute', 'tones:5', 'end']);
  });

  testWidgets('active and held calls expose swap, release and merge', (
    tester,
  ) async {
    final notifier = _ActiveCallNotifier();
    await show(tester, const ActiveCallScreen(), callNotifier: notifier);
    notifier.publish(
      notifier.current.copyWith(
        participants: [
          ...notifier.current.participants,
          const CallParticipant(
            id: 'held',
            name: 'Other caller',
            number: '456',
            status: CallStatus.held,
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.tap(find.byIcon(Icons.swap_calls_rounded));
    await tester.tap(find.byIcon(Icons.call_merge_rounded));
    await tester.tap(find.byIcon(Icons.call_end_rounded).first);
    expect(notifier.commands, ['swap', 'merge', 'releaseAndSwap']);
    expect(tester.takeException(), isNull);
  });

  for (final width in [480.0, 1280.0]) {
    testWidgets('waiting call offers explicit answer choices at width $width', (
      tester,
    ) async {
      final notifier = _ActiveCallNotifier();
      await show(
        tester,
        const Stack(children: [IncomingCallOverlay()]),
        size: Size(width, 720),
        callNotifier: notifier,
      );
      notifier.publish(
        notifier.current.copyWith(
          status: CallStatus.incoming,
          participants: [
            ...notifier.current.participants,
            const CallParticipant(
              id: 'waiting',
              name: 'Waiting caller',
              number: '456',
              status: CallStatus.incoming,
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Hold & answer'));
      await tester.tap(find.text('End & answer'));
      await tester.tap(find.byKey(const ValueKey('incoming-decline')));
      await tester.tap(find.byKey(const ValueKey('incoming-answer')));
      expect(notifier.commands, [
        'holdAndAnswer',
        'releaseAndAnswer',
        'decline',
        'holdAndAnswer',
      ]);
      notifier.publish(notifier.current.copyWith(busy: true));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('incoming-answer')));
      expect(notifier.commands, hasLength(4));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('single incoming call answers without a waiting operation', (
    tester,
  ) async {
    final notifier = _ActiveCallNotifier();
    await show(
      tester,
      const Stack(children: [IncomingCallOverlay()]),
      callNotifier: notifier,
    );
    notifier.publish(
      notifier.current.copyWith(
        status: CallStatus.incoming,
        participants: const [
          CallParticipant(
            id: 'incoming',
            name: 'Caller',
            number: '456',
            status: CallStatus.incoming,
          ),
        ],
      ),
    );
    await tester.pump();
    expect(find.text('Hold & answer'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('incoming-answer')));
    expect(notifier.commands, ['answer']);
  });

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

  testWidgets('Contacts refresh forces a full phonebook update', (
    tester,
  ) async {
    await show(tester, const CallsPage());
    await tester.tap(find.byKey(const ValueKey('phone-tab-contacts')));
    await tester.pump();
    final refresh = find.byTooltip('Refresh contacts');
    expect(refresh, findsOneWidget);
    await tester.tap(refresh);
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CallsPage)),
    );
    final notifier =
        container.read(phoneDataProvider.notifier) as _TestPhoneDataNotifier;
    expect(notifier.requestedForce, isTrue);
  });

  testWidgets('Contacts keep a large scrollbar for long phonebooks', (
    tester,
  ) async {
    await show(tester, const CallsPage(), manyContacts: true);
    await tester.tap(find.byKey(const ValueKey('phone-tab-contacts')));
    await tester.pump();
    final scrollbar = tester.widget<RawScrollbar>(find.byType(RawScrollbar));
    expect(scrollbar.thickness, 28);
    await tester.drag(find.byType(ListView), const Offset(0, -4000));
    await tester.pumpAndSettle();
    expect(find.text('Contact 24'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
