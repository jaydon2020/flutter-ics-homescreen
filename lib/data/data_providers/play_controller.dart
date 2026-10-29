import 'package:flutter_ics_homescreen/export.dart';
import 'bluetooth_media_notifier.dart';

enum PlaySource { none, media, radio, bluetooth }

class PlayController {
  final Ref ref;
  PlaySource source = PlaySource.none;

  PlayController({required this.ref});

  void setSource(PlaySource newSource) {
    source = newSource;
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
