import 'package:flutter_ics_homescreen/export.dart';
import 'package:flutter_ics_homescreen/data/data_providers/bluetooth_media_notifier.dart';
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
    final size = MediaQuery.sizeOf(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Stack(
      children: [
        SizedBox(
          width: size.width,
          height: size.height,
          // color: Colors.black,
          child: ref.watch(mediaPlayerBackgroundTextureProvider),
        ),
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              50,
              50,
              50,
              bottomInset < 50 ? 50 : bottomInset,
            ),
            child: const Media(),
          ),
        ),
      ],
    );
  }
}

class Media extends ConsumerStatefulWidget {
  const Media({super.key});

  @override
  ConsumerState<Media> createState() => _MediaState();
}

class _MediaState extends ConsumerState<Media> {
  PlaySource _pausedMediaSource = PlaySource.none;

  @override
  void initState() {
    // Set initial source so external control (like the volume bar button)
    // will work from the start.
    super.initState();
    final navState = ref.read(mediaNavStateProvider);
    final currentSource = ref.read(playControllerProvider).source;
    if (navState == MediaNavState.fm) {
      ref.read(playControllerProvider).setSource(PlaySource.radio);
    } else if (currentSource == PlaySource.radio ||
        currentSource == PlaySource.none) {
      _setSelectedMediaSource();
    }
  }

  void _setSelectedMediaSource() {
    final bluetoothSelected =
        ref.read(mediaSourceTabProvider) == MediaSourceTab.bluetooth;
    final bluetoothAvailable = ref.read(bluetoothMediaProvider).available;
    ref
        .read(playControllerProvider)
        .setSource(
          bluetoothSelected && bluetoothAvailable
              ? PlaySource.bluetooth
              : PlaySource.media,
        );
  }

  void onPressed(MediaNavState type) {
    if (type == MediaNavState.fm) {
      ref.read(mediaNavStateProvider.notifier).set(MediaNavState.fm);
      final currentSource = ref.read(playControllerProvider).source;
      final mpdPlaying =
          ref.read(mediaPlayerStateProvider).playState == PlayState.playing;
      final bluetoothPlaying =
          ref.read(bluetoothMediaProvider).playState == PlayState.playing;
      _pausedMediaSource = switch (currentSource) {
        PlaySource.bluetooth when bluetoothPlaying => PlaySource.bluetooth,
        PlaySource.media when mpdPlaying => PlaySource.media,
        _ when bluetoothPlaying => PlaySource.bluetooth,
        _ when mpdPlaying => PlaySource.media,
        _ => PlaySource.none,
      };
      if (mpdPlaying) {
        ref.read(mpdClientProvider).pause();
      }
      if (bluetoothPlaying) {
        ref.read(bluetoothMediaProvider.notifier).pause();
      }
      ref.read(playControllerProvider).setSource(PlaySource.radio);
      ref.read(radioClientProvider).start();
    } else if (type == MediaNavState.media) {
      ref.read(mediaNavStateProvider.notifier).set(MediaNavState.media);
      ref.read(radioClientProvider).stop();
      final resumeSource = _pausedMediaSource;
      _pausedMediaSource = PlaySource.none;
      if (resumeSource == PlaySource.bluetooth &&
          ref.read(bluetoothMediaProvider).connected) {
        ref.read(mediaSourceTabProvider.notifier).set(MediaSourceTab.bluetooth);
        ref.read(playControllerProvider).setSource(PlaySource.bluetooth);
        ref.read(bluetoothMediaProvider.notifier).play();
      } else {
        _setSelectedMediaSource();
        if (resumeSource == PlaySource.media) {
          ref.read(mpdClientProvider).play();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final navState = ref.watch(mediaNavStateProvider);
    final isBluetooth =
        navState == MediaNavState.media &&
        ref.watch(mediaSourceTabProvider) == MediaSourceTab.bluetooth &&
        ref.watch(bluetoothMediaProvider.select((state) => state.available));

    return Column(
      children: [
        const SizedBox(height: 55),
        PlayerNavigation(onPressed: onPressed),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 80),
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                primary: false,
                physics: isBluetooth
                    ? const NeverScrollableScrollPhysics()
                    : const ClampingScrollPhysics(),
                child: SizedBox(
                  height: isBluetooth ? constraints.maxHeight : null,
                  child: navState == MediaNavState.media
                      ? const MediaPlayer()
                      : navState == MediaNavState.fm
                      ? const RadioPlayer()
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
