import 'package:flutter_ics_homescreen/data/data_providers/bluetooth_media_notifier.dart';
import 'package:flutter_ics_homescreen/data/data_providers/play_controller.dart';
import 'package:flutter_ics_homescreen/data/data_providers/radio_notifier.dart';
import 'package:flutter_ics_homescreen/presentation/screens/media/media_nav_notifier.dart';
import 'package:flutter_ics_homescreen/presentation/screens/media/media_player.dart';
import 'package:flutter_ics_homescreen/export.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestBluetoothMediaNotifier extends BluetoothMediaNotifier {
  int pauses = 0;

  @override
  BluetoothMediaState build() => const BluetoothMediaState(
    loading: false,
    available: true,
    connected: true,
    title: 'Test song',
    artist: 'Test artist',
    playState: PlayState.playing,
  );

  @override
  void pause() => pauses++;
}

class _BluetoothTabNotifier extends MediaSourceTabNotifier {
  @override
  MediaSourceTab build() => MediaSourceTab.bluetooth;
}

class _TestRadioStateNotifier extends RadioStateNotifier {
  @override
  RadioState build() => const RadioState(
    freqMin: 87900000,
    freqMax: 108300000,
    freqStep: 200000,
    freqCurrent: 101700000,
    playing: false,
    scanning: false,
  );
}

void main() {
  testWidgets('Bluetooth media player fits the automotive landscape viewport', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 720);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bluetoothMediaProvider.overrideWith(_TestBluetoothMediaNotifier.new),
          mediaSourceTabProvider.overrideWith(_BluetoothTabNotifier.new),
        ],
        child: const MaterialApp(home: Scaffold(body: MediaPlayer())),
      ),
    );
    await tester.pump();
    expect(find.text('Bluetooth'), findsWidgets);
    expect(find.text('Test song'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('changing media tabs does not interrupt Bluetooth playback', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1920, 1080);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bluetoothMediaProvider.overrideWith(_TestBluetoothMediaNotifier.new),
          mediaSourceTabProvider.overrideWith(_BluetoothTabNotifier.new),
          radioStateProvider.overrideWith(_TestRadioStateNotifier.new),
        ],
        child: const MaterialApp(home: Scaffold(body: Media())),
      ),
    );

    await tester.tap(find.text('USB'));
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(Media)),
    );
    expect(container.read(mediaSourceTabProvider), MediaSourceTab.usb);
    expect(
      (container.read(bluetoothMediaProvider.notifier)
              as _TestBluetoothMediaNotifier)
          .pauses,
      0,
    );
  });

  testWidgets('opening the FM page does not change playback', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1920, 1080);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bluetoothMediaProvider.overrideWith(_TestBluetoothMediaNotifier.new),
          mediaSourceTabProvider.overrideWith(_BluetoothTabNotifier.new),
          radioStateProvider.overrideWith(_TestRadioStateNotifier.new),
        ],
        child: const MaterialApp(home: Scaffold(body: Media())),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Media)),
    );
    final controller = container.read(playControllerProvider);

    await tester.tap(find.text('FM'));
    await tester.pump();

    expect(container.read(mediaNavStateProvider), MediaNavState.fm);
    expect(container.read(radioStateProvider).playing, isFalse);
    expect(controller.source, PlaySource.bluetooth);
    expect(
      (container.read(bluetoothMediaProvider.notifier)
              as _TestBluetoothMediaNotifier)
          .pauses,
      0,
    );
  });

  test(
    'starting local media or FM pauses Bluetooth and activates the source',
    () {
      final container = ProviderContainer(
        overrides: [
          bluetoothMediaProvider.overrideWith(_TestBluetoothMediaNotifier.new),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(playControllerProvider);
      final bluetooth =
          container.read(bluetoothMediaProvider.notifier)
              as _TestBluetoothMediaNotifier;

      container
          .read(mediaPlayerStateProvider.notifier)
          .updatePlayState(PlayState.playing);
      expect(bluetooth.pauses, 1);
      expect(controller.source, PlaySource.media);

      container.read(radioStateProvider.notifier).updatePlaying(true);
      expect(bluetooth.pauses, 2);
      expect(controller.source, PlaySource.radio);
    },
  );
}
