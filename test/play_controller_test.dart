import 'package:flutter_ics_homescreen/data/data_providers/app_provider.dart';
import 'package:flutter_ics_homescreen/data/data_providers/bluetooth_media_notifier.dart';
import 'package:flutter_ics_homescreen/data/data_providers/play_controller.dart';
import 'package:flutter_ics_homescreen/data/models/mediaplayer_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeBluetoothMediaNotifier extends BluetoothMediaNotifier {
  FakeBluetoothMediaNotifier({this.initialPlayState = PlayState.paused});

  final PlayState initialPlayState;
  int pauseCalls = 0;

  @override
  BluetoothMediaState build() => BluetoothMediaState(
    available: true,
    connected: true,
    playState: initialPlayState,
  );

  void reportPlayback(PlayState value) {
    state = state.copyWith(playState: value);
  }

  @override
  void pause() {
    pauseCalls++;
    reportPlayback(PlayState.paused);
  }
}

void main() {
  test('global pause follows Bluetooth playback without a media page', () {
    final bluetooth = FakeBluetoothMediaNotifier();
    final container = ProviderContainer(
      overrides: [bluetoothMediaProvider.overrideWith(() => bluetooth)],
    );
    addTearDown(container.dispose);
    final controller = container.read(playControllerProvider);
    controller.setSource(PlaySource.media);

    bluetooth.reportPlayback(PlayState.playing);

    expect(container.read(playStateProvider), isTrue);
    expect(controller.source, PlaySource.bluetooth);
    controller.pause();
    expect(bluetooth.pauseCalls, 1);
    expect(container.read(playStateProvider), isFalse);
    expect(controller.source, PlaySource.bluetooth);
  });

  test('detects Bluetooth already playing when the controller is created', () {
    final container = ProviderContainer(
      overrides: [
        bluetoothMediaProvider.overrideWith(
          () => FakeBluetoothMediaNotifier(initialPlayState: PlayState.playing),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(playControllerProvider).source, PlaySource.bluetooth);
  });

  test('playback changes retain the controller and saved FM resume source', () {
    final bluetooth = FakeBluetoothMediaNotifier();
    final container = ProviderContainer(
      overrides: [bluetoothMediaProvider.overrideWith(() => bluetooth)],
    );
    addTearDown(container.dispose);
    final controller = container.read(playControllerProvider);
    controller.pausedMediaSource = PlaySource.bluetooth;

    container.read(radioStateProvider.notifier).updatePlaying(true);
    expect(controller.source, PlaySource.radio);
    container.read(radioStateProvider.notifier).updatePlaying(false);
    container
        .read(mediaPlayerStateProvider.notifier)
        .updatePlayState(PlayState.playing);
    expect(controller.source, PlaySource.media);
    bluetooth.reportPlayback(PlayState.playing);
    expect(controller.source, PlaySource.bluetooth);
    expect(container.read(playControllerProvider), same(controller));
    expect(controller.pausedMediaSource, PlaySource.bluetooth);
  });
}
