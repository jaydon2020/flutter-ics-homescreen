import 'package:flutter_ics_homescreen/core/utils/helpers.dart';
import 'package:flutter_ics_homescreen/data/data_providers/bluetooth_media_notifier.dart';
import 'package:flutter_ics_homescreen/export.dart';
import 'package:flutter_ics_homescreen/presentation/screens/settings/settings_screens/audio_settings/widget/slider_widgets.dart';

// Time to string helper, returns HH:MM:SS or MM:SS as appropriate
String timeToString(Duration time) {
  String result = "";
  if (time > const Duration(minutes: 59, seconds: 59)) {
    result = time.toString().split('.').first.padLeft(8, "0");
  } else {
    result = time.toString().substring(2, 7);
  }
  return result;
}

class MediaPlayerControls extends ConsumerStatefulWidget {
  const MediaPlayerControls({super.key, this.bluetooth = false});

  final bool bluetooth;

  @override
  ConsumerState<MediaPlayerControls> createState() =>
      _MediaPlayerControlsState();
}

class _MediaPlayerControlsState extends ConsumerState<MediaPlayerControls> {
  @override
  Widget build(BuildContext context) {
    var currentSong = ref.watch(
        mediaPlayerStateProvider.select((mediaplayer) => mediaplayer.song));
    final bluetoothMedia =
        widget.bluetooth ? ref.watch(bluetoothMediaProvider) : null;
    final showBluetoothErrors = widget.bluetooth &&
        ref.watch(appConfigProvider).showBluetoothErrors;

    String songName = "";
    String songDetail = "";
    Duration songLength = Duration.zero;
    Duration? songPosition;
    if (bluetoothMedia != null) {
      songName = bluetoothMedia.loading
          ? 'Connecting to Bluetooth media…'
          : !bluetoothMedia.connected
          ? showBluetoothErrors && bluetoothMedia.error != null
              ? bluetoothMedia.error!
              : 'No Bluetooth media connection'
          : bluetoothMedia.title.isEmpty
          ? 'Unknown track'
          : bluetoothMedia.title;
      songDetail = [
        bluetoothMedia.artist,
        bluetoothMedia.album,
      ].where((value) => value.isNotEmpty).join(' • ');
      songLength = bluetoothMedia.duration;
      songPosition = bluetoothMedia.position;
    } else if (currentSong != null) {
      songName = currentSong.title;
      songDetail = currentSong.artist;
      songLength = currentSong.duration;
    }

    return Material(
      color: Colors.transparent,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(
          songName,
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w400,
              shadows: [Helpers.dropShadowRegular],
              fontSize: 44),
        ),
        MediaPlayerControlsDetails(
            songDetail: songDetail, bluetooth: widget.bluetooth),
        MediaPlayerControlsSlider(
            songLength: songLength, songPosition: songPosition),
        MediaPlayerControlsActions(bluetooth: widget.bluetooth),
      ]),
    );
  }
}

class MediaPlayerControlsDetails extends ConsumerStatefulWidget {
  const MediaPlayerControlsDetails(
      {super.key, required this.songDetail, this.bluetooth = false});

  final String songDetail;
  final bool bluetooth;

  @override
  ConsumerState<MediaPlayerControlsDetails> createState() =>
      _MediaPlayerControlsDetailsState();
}

class _MediaPlayerControlsDetailsState
    extends ConsumerState<MediaPlayerControlsDetails> {
  bool isShuffleEnabled = false;
  bool isRepeatEnabled = false;
  @override
  Widget build(BuildContext context) {
    final bluetoothMedia =
        widget.bluetooth ? ref.watch(bluetoothMediaProvider) : null;
    final shuffleEnabled =
        bluetoothMedia?.shuffleEnabled ?? isShuffleEnabled;
    final repeatEnabled = bluetoothMedia?.repeatEnabled ?? isRepeatEnabled;
    final enabled = bluetoothMedia?.connected ?? true;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              widget.songDetail,
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w400,
                  fontSize: 40,
                  shadows: [Helpers.dropShadowRegular]),
            ),
          ),
        ),
        Row(
          children: [
            InkWell(
                customBorder: const CircleBorder(),
                onTap: enabled
                    ? () => widget.bluetooth
                        ? ref
                            .read(bluetoothMediaProvider.notifier)
                            .toggleShuffle()
                        : setState(
                            () => isShuffleEnabled = !isShuffleEnabled)
                    : null,
                child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SvgPicture.asset(
                      "assets/${shuffleEnabled ? "ShufflePressed.svg" : "Shuffle.svg"}",
                      width: 48,
                    ))),
            InkWell(
                customBorder: const CircleBorder(),
                onTap: enabled
                    ? () => widget.bluetooth
                        ? ref
                            .read(bluetoothMediaProvider.notifier)
                            .toggleRepeat()
                        : setState(() => isRepeatEnabled = !isRepeatEnabled)
                    : null,
                child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SvgPicture.asset(
                      "assets/${repeatEnabled ? "RepeatPressed.svg" : "Repeat.svg"}",
                      width: 48,
                    ))),
          ],
        )
      ],
    );
  }
}

class MediaPlayerControlsSlider extends ConsumerWidget {
  const MediaPlayerControlsSlider(
      {super.key, required this.songLength, this.songPosition});

  final Duration songLength;
  final Duration? songPosition;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Duration currentPosition =
        songPosition ?? ref.watch(mediaPlayerPositionProvider);

    if (songLength == Duration.zero) {
      currentPosition = Duration.zero;
    }
    String songLengthString = timeToString(songLength);
    String songPositionString = timeToString(currentPosition);

    return Column(children: [
      SizedBox(
        height: 80,
        child: SliderTheme(
          data: SliderThemeData(
            overlayShape: SliderComponentShape.noOverlay,
            valueIndicatorShape: SliderComponentShape.noOverlay,
            activeTickMarkColor: Colors.transparent,
            inactiveTickMarkColor: Colors.transparent,
            inactiveTrackColor: AGLDemoColors.periwinkleColor,
            thumbShape:
                const PolygonSliderThumb(sliderValue: 3, thumbRadius: 23),
            //trackHeight: 5,
          ),
          child: Slider(
            max: songLength.inMilliseconds.toDouble(),
            value: currentPosition.inMilliseconds
                .clamp(0, songLength.inMilliseconds)
                .toDouble(),
            onChangeStart: (double value) {
              // Disable timer so position will not change while control is
              // being dragged.  It will be re-enabled via the playback state
              // update from MPD.
              ref.read(mediaPlayerPositionProvider.notifier).pause();
            },
            onChanged: songPosition != null
                ? null
                : (double newValue) {
                    ref
                        .read(mediaPlayerPositionProvider.notifier)
                        .set(Duration(milliseconds: newValue.toInt()));
                  },
            onChangeEnd: (double newValue) {
              ref.read(mpdClientProvider).seek(newValue.toInt());
            },
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
                width: 80,
                height: 40,
                child: Text(
                  songPositionString,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      shadows: [Helpers.dropShadowRegular]),
                )),
            SizedBox(
                width: 80,
                height: 40,
                child: Text(
                  songLengthString,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      shadows: [Helpers.dropShadowRegular]),
                ))
          ],
        ),
      ),
    ]);
  }
}

class MediaPlayerControlsActions extends ConsumerStatefulWidget {
  const MediaPlayerControlsActions({super.key, this.bluetooth = false});

  final bool bluetooth;

  @override
  ConsumerState<MediaPlayerControlsActions> createState() =>
      _MediaPlayerControlsActionsState();
}

class _MediaPlayerControlsActionsState
    extends ConsumerState<MediaPlayerControlsActions> {
  bool isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bluetoothMedia =
        widget.bluetooth ? ref.watch(bluetoothMediaProvider) : null;
    final isPlaying = bluetoothMedia != null
        ? bluetoothMedia.playState == PlayState.playing
        : ref.watch(mediaPlayerStateProvider
                .select((mediaplayer) => mediaplayer.playState)) ==
            PlayState.playing;
    final enabled = bluetoothMedia?.connected ?? true;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        InkWell(
            customBorder: const CircleBorder(),
            onTap: enabled
                ? () => widget.bluetooth
                    ? ref.read(bluetoothMediaProvider.notifier).previous()
                    : ref.read(mpdClientProvider).previous()
                : null,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: SvgPicture.asset(
                "assets/SkipPrevious.svg",
                width: 48,
              ),
            )),
        const SizedBox(
          width: 120,
        ),
        InkWell(
            customBorder: const CircleBorder(),
            onTap: enabled
                ? () => widget.bluetooth
                    ? ref.read(bluetoothMediaProvider.notifier).playPause()
                    : isPlaying
                        ? ref.read(mpdClientProvider).pause()
                        : ref.read(mpdClientProvider).play()
                : null,
            onTapDown: enabled
                ? (details) => setState(() => isPressed = true)
                : null,
            onTapUp: enabled
                ? (details) => setState(() => isPressed = false)
                : null,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      isPressed ? Colors.white : AGLDemoColors.periwinkleColor,
                  boxShadow: [Helpers.boxDropShadowRegular]),
              child: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                color: AGLDemoColors.resolutionBlueColor,
                size: 60,
              ),
            )),
        const SizedBox(
          width: 120,
        ),
        InkWell(
            customBorder: const CircleBorder(),
            onTap: enabled
                ? () => widget.bluetooth
                    ? ref.read(bluetoothMediaProvider.notifier).next()
                    : ref.read(mpdClientProvider).next()
                : null,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: SvgPicture.asset(
                "assets/SkipNext.svg",
                width: 48,
              ),
            )),
      ],
    );
  }
}
