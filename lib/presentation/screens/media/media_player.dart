import 'package:flutter_ics_homescreen/export.dart';
import 'package:flutter_ics_homescreen/data/data_providers/bluetooth_media_notifier.dart';
import 'package:flutter_ics_homescreen/data/data_providers/play_controller.dart';
import 'package:flutter_ics_homescreen/presentation/screens/settings/settings_screens/audio_settings/widget/slider_widgets.dart';
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
  bool isPhoneVolumePressed = false;
  bool _autoSelectBluetooth = true;
  late final ProviderSubscription<BluetoothMediaState> _bluetoothSubscription;

  @override
  void initState() {
    super.initState();
    _bluetoothSubscription = ref.listenManual(bluetoothMediaProvider, (
      _,
      next,
    ) {
      if (next.connected && _autoSelectBluetooth && mounted) {
        _selectSource('Bluetooth', automatic: true);
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _bluetoothSubscription.close();
    super.dispose();
  }

  void _selectSource(String source, {bool automatic = false}) {
    if (!automatic) _autoSelectBluetooth = false;
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
    final bluetoothMedia = isBluetooth
        ? ref.watch(bluetoothMediaProvider)
        : null;
    const albumArtSize = 400.0;
    Uint8List art = Uint8List(0);
    if (isBluetooth) {
      art = bluetoothMedia?.coverArt ?? Uint8List(0);
    } else {
      final playlistPosition = ref.watch(
        mediaPlayerStateProvider.select(
          (mediaplayer) => mediaplayer.playlistPosition,
        ),
      );
      final playlistArt = ref.watch(playlistArtProvider);
      if (playlistArt.containsKey(playlistPosition)) {
        art = playlistArt[playlistPosition]!;
      }
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
            SizedBox.square(
              dimension: albumArtSize,
              child: art.isNotEmpty
                  ? Image.memory(art, fit: BoxFit.contain)
                  : ColoredBox(
                      color: AGLDemoColors.jordyBlueColor.withValues(
                        alpha: 0.2,
                      ),
                      child: const Icon(
                        Icons.music_note,
                        size: albumArtSize,
                        color: AGLDemoColors.jordyBlueColor,
                      ),
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
            ] else ...[
              const SizedBox(height: 12),
              PlayListTable(
                title: bluetoothMedia!.album.isEmpty
                    ? 'Unknown album'
                    : bluetoothMedia.album,
                showPlaylist: false,
              ),
              if (bluetoothMedia.connected &&
                  bluetoothMedia.phoneVolumeAvailable)
                SizedBox(
                  height: 500,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      height: 160,
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      decoration: const ShapeDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            AGLDemoColors.neonBlueColor,
                            AGLDemoColors.resolutionBlueColor,
                            Color.fromARGB(127, 20, 31, 100),
                            Color(0xFF2962FF),
                          ],
                          stops: [0, 0, 1, 1],
                        ),
                        shape: StadiumBorder(
                          side: BorderSide(color: Color(0xFF5477D4)),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.volume_down,
                            color: AGLDemoColors.periwinkleColor,
                            size: 36,
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderThemeData(
                                trackShape: CustomRoundedRectSliderTrackShape(
                                  sliderVal: bluetoothMedia.phoneVolume / 10,
                                ),
                                activeTickMarkColor: Colors.transparent,
                                inactiveTickMarkColor: Colors.transparent,
                                inactiveTrackColor:
                                    AGLDemoColors.backgroundInsetColor,
                                thumbShape: PolygonSliderThumb(
                                  sliderValue: 3,
                                  thumbRadius: 23,
                                  isPressed: isPhoneVolumePressed,
                                ),
                                trackHeight: 16,
                              ),
                              child: Slider(
                                divisions: 10,
                                min: 0,
                                max: 100,
                                value: bluetoothMedia.phoneVolume,
                                onChanged: bluetoothMedia.phoneVolumeAvailable
                                    ? ref
                                          .read(bluetoothMediaProvider.notifier)
                                          .setPhoneVolume
                                    : null,
                                onChangeStart: (_) =>
                                    setState(() => isPhoneVolumePressed = true),
                                onChangeEnd: (_) => setState(
                                  () => isPhoneVolumePressed = false,
                                ),
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.volume_up,
                            color: AGLDemoColors.periwinkleColor,
                            size: 36,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ],
    );
  }
}
