import 'package:flutter_ics_homescreen/export.dart';

enum MediaNavState { media, fm, am, xm }

enum MediaSourceTab { usb, sd, bluetooth }

class MediaNavStateNotifier extends Notifier<MediaNavState> {
  @override
  MediaNavState build() {
    return MediaNavState.media;
  }

  set(MediaNavState value) {
    state = value;
  }
}

final mediaNavStateProvider =
    NotifierProvider<MediaNavStateNotifier, MediaNavState>(
        MediaNavStateNotifier.new);

class MediaSourceTabNotifier extends Notifier<MediaSourceTab> {
  @override
  MediaSourceTab build() => MediaSourceTab.usb;

  void set(MediaSourceTab value) => state = value;
}

final mediaSourceTabProvider =
    NotifierProvider<MediaSourceTabNotifier, MediaSourceTab>(
        MediaSourceTabNotifier.new);
