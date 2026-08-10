import 'package:flutter_ics_homescreen/export.dart';
import 'package:flutter_ics_homescreen/presentation/screens/media/media_player.dart';
import 'package:flutter_ics_homescreen/presentation/screens/media/radio_player.dart';
import 'package:flutter_ics_homescreen/data/data_providers/play_controller.dart';
import 'media_nav_notifier.dart';
import 'player_navigation.dart';

final mediaPlayerBackgroundTextureProvider = Provider((ref) {
  return SvgPicture.asset(
    'assets/MediaPlayerBackgroundTextures.svg',
    // alignment: Alignment.center,
    fit: BoxFit.cover,
    //width: 200,
    //height: 200,
  );
});

class MediaPage extends ConsumerWidget {
  const MediaPage({super.key});

  static Page<void> page() => const MaterialPage<void>(child: MediaPage());
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Size size = MediaQuery.sizeOf(context);

    return Stack(
      children: [
        SizedBox(
          width: size.width,
          height: size.height,
          // color: Colors.black,
          child: ref.read(mediaPlayerBackgroundTextureProvider),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 50, horizontal: 50),
          child: Media(),
        )
      ],
    );
  }
}

class MediaPlayingStateNotifier extends Notifier<bool> {
  @override
  bool build() {
    return false;
  }

  set(bool value) {
    state = value;
  }
}

final mediaPlayingStateProvider =
    NotifierProvider<MediaPlayingStateNotifier, bool>(
        MediaPlayingStateNotifier.new);

class Media extends ConsumerStatefulWidget {
  const Media({super.key});

  @override
  ConsumerState<Media> createState() => _MediaState();
}

class _MediaState extends ConsumerState<Media> {
  onPressed(MediaNavState type) {
    if (type == MediaNavState.fm) {
      ref.read(mediaNavStateProvider.notifier).set(MediaNavState.fm);
      ref.read(playControllerProvider).setSource(PlaySource.radio);

      bool mediaPlaying = false;
      if (ref.read(mediaPlayerStateProvider).playState == PlayState.playing) {
        ref.read(mpdClientProvider).pause();
        mediaPlaying = true;
      }
      ref.read(mediaPlayingStateProvider.notifier).set(mediaPlaying);
      ref.read(radioClientProvider).start();
    } else if (type == MediaNavState.media) {
      ref.read(mediaNavStateProvider.notifier).set(MediaNavState.media);
      ref.read(playControllerProvider).setSource(PlaySource.media);

      ref.read(radioClientProvider).stop();
      if (ref.read(mediaPlayingStateProvider)) {
        ref.read(mpdClientProvider).play();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var navState = ref.watch(mediaNavStateProvider);

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(
            height: 55,
          ),
          PlayerNavigation(
            onPressed: (val) {
              onPressed(val);
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 80),
            child: SingleChildScrollView(
              child: navState == MediaNavState.media
                  ? const MediaPlayer()
                  : navState == MediaNavState.fm
                      ? const RadioPlayer()
                      : Container(),
            ),
          ),
        ],
      ),
    );
  }
}
