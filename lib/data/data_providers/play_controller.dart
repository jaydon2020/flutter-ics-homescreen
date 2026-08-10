import 'package:flutter_ics_homescreen/export.dart';
import 'bluetooth_media_notifier.dart';

enum PlaySource { none, media, radio, bluetooth }

final playSourceProvider = StateProvider<PlaySource>((ref) => PlaySource.media);

class PlayController {
  final Ref ref;

  PlayController({required this.ref});

  PlaySource get source => ref.read(playSourceProvider);

  void setSource(PlaySource newSource) {
    ref.read(playSourceProvider.notifier).state = newSource;
  }

  void play() async {
    switch (source) {
      case PlaySource.media:
        ref.read(mpdClientProvider).play();
        break;
      case PlaySource.radio:
        ref.read(radioClientProvider).start();
        break;
      case PlaySource.bluetooth:
        ref.read(bluetoothMediaProvider.notifier).play();
        break;
      default:
        break;
    }
  }

  void pause() async {
    switch (source) {
      case PlaySource.media:
        ref.read(mpdClientProvider).pause();
        break;
      case PlaySource.radio:
        ref.read(radioClientProvider).stop();
        break;
      case PlaySource.bluetooth:
        ref.read(bluetoothMediaProvider.notifier).pause();
        break;
      default:
        break;
    }
  }
}
