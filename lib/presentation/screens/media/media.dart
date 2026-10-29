import 'package:flutter_ics_homescreen/export.dart';
import 'package:flutter_ics_homescreen/data/data_providers/bluetooth_media_notifier.dart';
import 'package:flutter_ics_homescreen/presentation/screens/media/media_player.dart';
import 'package:flutter_ics_homescreen/presentation/screens/media/radio_player.dart';
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
  @override
  void initState() {
    super.initState();
    ref.read(playControllerProvider);
  }

  void onPressed(MediaNavState type) {
    ref.read(mediaNavStateProvider.notifier).set(type);
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
