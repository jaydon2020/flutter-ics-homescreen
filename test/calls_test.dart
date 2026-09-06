import 'package:flutter/material.dart';
import 'package:flutter_ics_homescreen/data/data_providers/app_provider.dart';
import 'package:flutter_ics_homescreen/presentation/screens/apps/apps_content.dart';
import 'package:flutter_ics_homescreen/presentation/screens/calls/calls.dart';
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
    await tester.longPress(find.byKey(const ValueKey('dial-key-0')));
    await tester.pumpAndSettle();
    for (final digit in ['6', '0', '1', '2', '*', '#']) {
      await tester.tap(find.byKey(ValueKey('dial-key-$digit')));
      await tester.pump();
    }
    final number = find.byKey(const ValueKey('dialed-number'));
    expect(tester.widget<Text>(number).data, '+6012*#');
    await tester.tap(find.byTooltip('Delete last digit'));
    await tester.pump();
    expect(tester.widget<Text>(number).data, '+6012*');
    await tester.tap(find.text('Clear'));
    await tester.pump();
    expect(tester.widget<Text>(number).data, 'Enter number');
    expect(
      tester.widget<IconButton>(find.byType(IconButton)).onPressed,
      isNull,
    );
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
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
    await tester.ensureVisible(find.text('Call'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
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
