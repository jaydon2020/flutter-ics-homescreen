import 'package:flutter_ics_homescreen/export.dart';
import 'package:flutter_ics_homescreen/data/data_providers/play_controller.dart';
import 'media_player_controls.dart';
import 'play_list_table.dart';
import 'segmented_buttons.dart';

class MediaPlayer extends ConsumerStatefulWidget {
  const MediaPlayer({super.key});

  @override
  ConsumerState<MediaPlayer> createState() => _MediaPlayerState();
}

class _MediaPlayerState extends ConsumerState<MediaPlayer> {
  String selectedNav = "USB";
  List<String> navItems = ["USB", "SD", "Bluetooth"];

  void _selectSource(String source) {
    if (source == 'Bluetooth') {
      ref.read(mpdClientProvider).pause();
      ref.read(playControllerProvider).setSource(PlaySource.bluetooth);
    } else {
      ref.read(playControllerProvider).setSource(PlaySource.media);
    }
    setState(() => selectedNav = source);
  }

  @override
  Widget build(BuildContext context) {
    final isBluetooth = selectedNav == 'Bluetooth';
    double albumArtSize = 400;
    final playlistPosition = ref.watch(
      mediaPlayerStateProvider.select(
        (mediaplayer) => mediaplayer.playlistPosition,
      ),
    );
    final playlistArt = ref.watch(playlistArtProvider);
    Uint8List art = Uint8List(0);
    if (playlistArt.containsKey(playlistPosition)) {
      art = playlistArt[playlistPosition]!;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButtons(
          navItems: navItems,
          selectedNav: selectedNav,
          onChanged: _selectSource,
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            art.isNotEmpty && !isBluetooth
                ? Image.memory(
                    art,
                    width: albumArtSize,
                    height: albumArtSize,
                    fit: BoxFit.contain,
                  )
                : Container(
                    width: albumArtSize,
                    height: albumArtSize,
                    color: AGLDemoColors.jordyBlueColor.withValues(alpha: 0.2),
                    child: Icon(
                      Icons.music_note,
                      size: albumArtSize,
                      color: AGLDemoColors.jordyBlueColor,
                    ),
                  ),
          ],
        ),
        const SizedBox(height: 40),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MediaPlayerControls(bluetooth: isBluetooth),
            if (!isBluetooth) ...[
              const SizedBox(height: 12),
              const PlayListTable(),
            ],
          ],
        ),
      ],
    );
  }
}
