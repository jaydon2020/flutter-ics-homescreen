import 'package:flutter/material.dart';
import 'package:flutter_ics_homescreen/core/constants/colors.dart';
import 'package:flutter_ics_homescreen/data/data_providers/app_provider.dart';
import 'package:flutter_ics_homescreen/data/data_providers/call_notifier.dart';
import 'package:flutter_ics_homescreen/data/models/call_state.dart';
import 'package:flutter_ics_homescreen/presentation/screens/apps/apps_content.dart';
import 'package:flutter_ics_homescreen/presentation/screens/calls/calls.dart';
import 'package:flutter_ics_homescreen/presentation/screens/calls/incoming_call_overlay.dart';
import 'package:flutter_ics_homescreen/presentation/screens/calls/ongoing_call_overlay.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> showPage(WidgetTester tester, Size size, Widget page) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(
            brightness: Brightness.dark,
            fontFamily: 'Fira Sans',
          ),
          home: Scaffold(body: page),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('dial pad enters digits, plus, star and hash and clears input', (
    tester,
  ) async {
    await showPage(tester, const Size(1080, 1920), const CallsPage());
    expect(find.text('Suggested contacts'), findsOneWidget);
    final dialKeyMaterial = tester.widget<Material>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('dial-key-1')),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(dialKeyMaterial.shape, isA<RoundedRectangleBorder>());
    final keypadWidth =
        tester.getSize(find.byKey(const ValueKey('dial-keypad'))).width;
    final firstSuggestion =
        tester.getRect(find.byKey(const ValueKey('suggested-contact-0')));
    final secondSuggestion =
        tester.getRect(find.byKey(const ValueKey('suggested-contact-1')));
    final phoneStatus =
        tester.getRect(find.byKey(const ValueKey('phone-status')));
    expect(keypadWidth, greaterThan(850));
    expect(firstSuggestion.width, closeTo(keypadWidth, 1));
    expect(secondSuggestion.width, closeTo(keypadWidth, 1));
    expect(firstSuggestion.height, 130);
    expect(secondSuggestion.height, 130);
    expect(firstSuggestion.top - phoneStatus.bottom, lessThan(100));
    expect(secondSuggestion.top, greaterThan(firstSuggestion.bottom));
    expect(find.text('Aisha Rahman'), findsOneWidget);
    expect(find.text('Daniel Tan'), findsOneWidget);
    final contactInk = tester.widget<Ink>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('suggested-contact-0')),
            matching: find.byType(Ink),
          )
          .first,
    );
    final contactGradient =
        (contactInk.decoration! as BoxDecoration).gradient! as LinearGradient;
    expect(contactGradient.colors, const [Colors.black, Colors.black12]);
    expect(contactGradient.stops, const [0.1, 1]);
    expect(
      tester.getSize(find.byKey(const ValueKey('dial-key-1'))),
      Size((keypadWidth - 16) / 3, 100),
    );
    final initialKeypadPosition =
        tester.getTopLeft(find.byKey(const ValueKey('dial-keypad')));
    await tester.longPress(find.byKey(const ValueKey('dial-key-0')));
    await tester.pumpAndSettle();
    for (final digit in ['6', '0', '1', '2', '*', '#']) {
      await tester.tap(find.byKey(ValueKey('dial-key-$digit')));
      await tester.pump();
    }
    final number = find.byKey(const ValueKey('dialed-number'));
    expect(tester.widget<Text>(number).data, '+6012*#');
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('dial-keypad'))),
      initialKeypadPosition,
    );
    await tester.tap(find.byTooltip('Delete last digit'));
    await tester.pump();
    expect(tester.widget<Text>(number).data, '+6012*');
    final numberY = tester.getCenter(number).dy;
    await tester.tap(find.text('Clear'));
    await tester.pump();
    expect(number, findsNothing);
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byTooltip('Delete last digit'),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    expect(
      tester.getCenter(find.byKey(const ValueKey('dial-key-1'))).dy,
      greaterThan(numberY + 40),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('landscape dial pad scrolls without overflow', (tester) async {
    await showPage(tester, const Size(1280, 720), const CallsPage());
    final key = find.byKey(const ValueKey('dial-key-9'));
    await tester.ensureVisible(key);
    await tester.tap(key);
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('dialed-number'))).data,
      '9',
    );
    await tester.ensureVisible(find.byIcon(Icons.call_rounded));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('active call controls remain usable in landscape',
      (tester) async {
    await showPage(tester, const Size(1280, 720), const CallsPage());
    await tester.tap(find.byKey(const ValueKey('dial-key-1')));
    await tester.pump();
    await tester.ensureVisible(find.byIcon(Icons.call_rounded));
    await tester.tap(find.byIcon(Icons.call_rounded));
    await tester.pump();

    expect(find.text('Calling'), findsWidgets);
    expect(find.text('End call'), findsOneWidget);
    expect(find.text('Bluetooth'), findsNothing);
    expect(find.byKey(const ValueKey('active-caller-card')), findsNothing);
    expect(find.byType(BackdropFilter), findsNothing);
    final callButtons = find.descendant(
      of: find.byKey(const ValueKey('in-call-controls')),
      matching: find.byType(ElevatedButton),
    );
    expect(callButtons, findsNWidgets(4));
    expect(tester.getSize(callButtons.first), const Size(96, 96));
    expect(
      tester.getSize(find.descendant(
        of: callButtons.first,
        matching: find.byType(Icon),
      )),
      const Size(57, 57),
    );
    expect(
      tester.getCenter(find.text('End call')).dx,
      closeTo(
        tester.getCenter(find.byKey(const ValueKey('in-call-controls'))).dx,
        1,
      ),
    );
    await tester.ensureVisible(find.byIcon(Icons.dialpad_rounded));
    final stagePosition = tester.getTopLeft(
      find.byKey(const ValueKey('in-call-keypad-space')),
    );
    final controlsPosition = tester.getTopLeft(
      find.byKey(const ValueKey('in-call-controls')),
    );
    await tester.tap(find.byIcon(Icons.dialpad_rounded));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('in-call-keypad-space'))),
      stagePosition,
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('in-call-controls'))),
      controlsPosition,
    );
    expect(find.text('ABC'), findsOneWidget);
    expect(find.text('WXYZ'), findsOneWidget);
    expect(
      tester.getCenter(find.text('Mute')).dy,
      closeTo(tester.getCenter(find.text('Hold')).dy, 1),
    );
    expect(
      tester.getCenter(find.text('End call')).dy,
      greaterThan(tester.getCenter(find.text('Hold')).dy),
    );
    final dtmfKeyMaterial = tester.widget<Material>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('dtmf-key-1')),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(dtmfKeyMaterial.shape, isA<RoundedRectangleBorder>());
    await tester.ensureVisible(find.byKey(const ValueKey('dtmf-key-5')));
    final inCallKeypadPosition =
        tester.getTopLeft(find.byKey(const ValueKey('in-call-keypad')));
    await tester.tap(find.byKey(const ValueKey('dtmf-key-5')));
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('dtmf-digits'))).data,
      '5',
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('in-call-keypad'))),
      inCallKeypadPosition,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('incoming call banner adapts to compact screens', (tester) async {
    await showPage(
      tester,
      const Size(420, 800),
      const Stack(children: [IncomingCallOverlay()]),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(IncomingCallOverlay)),
    );
    container
        .read(callStateProvider.notifier)
        .receiveIncomingCall('Jane Doe', '+1 (555) 234-5678');
    await tester.pump();

    expect(find.text('Jane Doe'), findsOneWidget);
    expect(find.text('Answer'), findsNothing);
    expect(find.text('Decline'), findsNothing);
    expect(
      tester.getSize(find.byKey(const ValueKey('incoming-call-banner'))).width,
      396,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('incoming-call-banner'))).height,
      132,
    );
    final incomingBanner = tester.widget<Container>(
      find.byKey(const ValueKey('incoming-call-banner')),
    );
    expect(
      (incomingBanner.decoration! as BoxDecoration).borderRadius,
      BorderRadius.circular(40),
    );
    expect((incomingBanner.decoration! as BoxDecoration).border, isNull);
    expect(
      (incomingBanner.decoration! as BoxDecoration).gradient,
      AGLDemoColors.callNotificationGradient,
    );
    expect(
      AGLDemoColors.callNotificationGradient.colors
          .every((color) => color.a == 1),
      isTrue,
    );
    expect(
      AGLDemoColors.callNotificationGradient.colors.first,
      isNot(Colors.white),
    );
    expect(
      tester.getCenter(find.byKey(const ValueKey('incoming-decline'))).dx,
      lessThan(tester.getCenter(find.text('Jane Doe')).dx),
    );
    expect(
      tester.getCenter(find.byKey(const ValueKey('incoming-answer'))).dx,
      greaterThan(tester.getCenter(find.text('Jane Doe')).dx),
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('incoming-answer')));
    await tester.pump();
    expect(container.read(callStateProvider).status, CallStatus.active);
    expect(find.text('Jane Doe'), findsNothing);
  });

  testWidgets('ongoing call widget reopens and ends calls outside phone app',
      (tester) async {
    await showPage(
      tester,
      const Size(1080, 1920),
      const Stack(children: [OngoingCallOverlay()]),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(OngoingCallOverlay)),
    );
    container.read(appProvider.notifier).update(AppState.apps);
    container.read(callStateProvider.notifier).startCall(
          '+1 (555) 432-1098',
          name: 'Roadside Assistance',
        );
    await tester.pump();

    expect(find.byKey(const ValueKey('ongoing-call-widget')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('ongoing-call-widget'))),
      const Size(1056, 132),
    );
    expect(find.text('Roadside Assistance'), findsOneWidget);
    expect(find.text('Calling'), findsOneWidget);
    final notification = tester.widget<Container>(
      find.byKey(const ValueKey('ongoing-call-widget')),
    );
    final notificationDecoration = notification.decoration! as BoxDecoration;
    expect(
      notificationDecoration.borderRadius,
      BorderRadius.circular(40),
    );
    expect(notificationDecoration.border, isNull);
    expect(
      notificationDecoration.gradient,
      AGLDemoColors.callNotificationGradient,
    );
    final callIcon = tester.widget<Container>(
      find.byKey(const ValueKey('ongoing-call-icon')),
    );
    final callIconDecoration = callIcon.decoration! as BoxDecoration;
    expect(callIconDecoration.border, isNull);
    expect(
      callIconDecoration.color,
      AGLDemoColors.callControlColor.withValues(alpha: 0.72),
    );
    final hangUp = find.byKey(const ValueKey('ongoing-hang-up'));
    expect(tester.getSize(hangUp), const Size(64, 64));
    final hangUpButton = tester.widget<IconButton>(
      find.descendant(of: hangUp, matching: find.byType(IconButton)),
    );
    expect(
      hangUpButton.style?.backgroundColor?.resolve({}),
      AGLDemoColors.callDangerColor.withValues(alpha: 0.12),
    );
    expect(hangUpButton.color, AGLDemoColors.callDangerColor);
    await tester.tap(find.byKey(const ValueKey('return-to-call')));
    await tester.pump();
    expect(container.read(appProvider), AppState.calls);
    expect(find.byKey(const ValueKey('ongoing-call-widget')), findsNothing);

    container.read(appProvider.notifier).update(AppState.apps);
    await tester.pump();
    await tester.tap(find.byTooltip('End call'));
    await tester.pump();
    expect(container.read(callStateProvider).status, CallStatus.ended);
    expect(find.byKey(const ValueKey('ongoing-call-widget')), findsNothing);
  });

  testWidgets('Calls opens from Applications without a launcher service', (
    tester,
  ) async {
    await showPage(tester, const Size(1080, 1920), const Apps());
    expect(find.text('Calls'), findsOneWidget);
    await tester.tap(find.text('Calls'));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Apps)),
    );
    expect(container.read(appProvider), AppState.calls);
  });

  test('launcher refresh keeps exactly one built-in Calls entry', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final apps = container.read(appLauncherListProvider);
    container.read(appLauncherListProvider.notifier).update(apps);
    expect(
      container
          .read(appLauncherListProvider)
          .where((app) => app.internal && app.id == 'calls'),
      hasLength(1),
    );
    container.read(appLauncherListProvider.notifier).update([]);
    expect(container.read(appLauncherListProvider).single.id, 'calls');
  });
}
