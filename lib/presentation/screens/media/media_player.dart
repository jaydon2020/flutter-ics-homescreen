import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter_ics_homescreen/export.dart';
import 'package:flutter_ics_homescreen/core/utils/helpers.dart';
import 'package:flutter_ics_homescreen/data/data_providers/bluetooth_media_notifier.dart';
import 'package:flutter_ics_homescreen/data/data_providers/play_controller.dart';
import 'media_player_controls.dart';
import 'media_nav_notifier.dart';
import 'play_list_table.dart';
import 'segmented_buttons.dart';

class MediaPlayer extends ConsumerStatefulWidget {
  const MediaPlayer({super.key});

  @override
  ConsumerState<MediaPlayer> createState() => _MediaPlayerState();
}

class _MediaPlayerState extends ConsumerState<MediaPlayer> {
  static const navItems = ['USB', 'SD', 'Bluetooth'];
  bool _autoSelectBluetooth = true;
  Uint8List? _displayedCoverArt;
  int _coverArtRequest = 0;

  @override
  void initState() {
    super.initState();
    ref.listenManual<({bool available, bool connected})>(
      bluetoothMediaProvider.select(
        (state) => (available: state.available, connected: state.connected),
      ),
      (previous, next) {
        if (next.available && previous?.available != true) {
          if (ref.read(mediaSourceTabProvider) == MediaSourceTab.bluetooth) {
            _selectSource('Bluetooth');
          }
        } else if (!next.available &&
            ref.read(mediaSourceTabProvider) == MediaSourceTab.bluetooth) {
          ref.read(playControllerProvider).setSource(PlaySource.media);
        }
        if (!next.connected) {
          _queueCoverArt(null);
        } else if (previous?.connected != true) {
          _queueCoverArt(ref.read(bluetoothMediaProvider).coverArt);
        }
        if (next.connected &&
            previous != null &&
            !previous.connected &&
            _autoSelectBluetooth &&
            mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _autoSelectBluetooth) {
              _selectSource('Bluetooth', automatic: true);
            }
          });
        }
      },
      fireImmediately: true,
    );
    ref.listenManual<Uint8List?>(
      bluetoothMediaProvider.select((state) => state.coverArt),
      (_, next) => _queueCoverArt(next),
      fireImmediately: true,
    );
  }

  void _queueCoverArt(Uint8List? art) {
    final request = ++_coverArtRequest;
    if (art == null || art.isEmpty) {
      if (_displayedCoverArt != null && mounted) {
        setState(() => _displayedCoverArt = null);
      }
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && request == _coverArtRequest) {
        unawaited(_decodeCoverArt(art, request));
      }
    });
  }

  Future<void> _decodeCoverArt(Uint8List art, int request) async {
    var failed = false;
    await precacheImage(
      MemoryImage(art),
      context,
      onError: (error, _) {
        failed = true;
        debugPrint('Bluetooth media: Unable to decode cover art: $error');
      },
    );
    if (failed || !mounted || request != _coverArtRequest) return;
    if (!identical(_displayedCoverArt, art)) {
      setState(() => _displayedCoverArt = art);
    }
  }

  void _selectSource(String source, {bool automatic = false}) {
    if (!automatic) _autoSelectBluetooth = false;
    final tab = switch (source) {
      'SD' => MediaSourceTab.sd,
      'Bluetooth' => MediaSourceTab.bluetooth,
      _ => MediaSourceTab.usb,
    };
    ref.read(mediaSourceTabProvider.notifier).set(tab);
    if (source == 'Bluetooth' && ref.read(bluetoothMediaProvider).available) {
      ref.read(mpdClientProvider).pause();
      ref.read(playControllerProvider).setSource(PlaySource.bluetooth);
    } else {
      if (source != 'Bluetooth') {
        ref.read(bluetoothMediaProvider.notifier).pause();
      }
      ref.read(playControllerProvider).setSource(PlaySource.media);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedTab = ref.watch(mediaSourceTabProvider);
    final selectedNav = switch (selectedTab) {
      MediaSourceTab.usb => 'USB',
      MediaSourceTab.sd => 'SD',
      MediaSourceTab.bluetooth => 'Bluetooth',
    };
    final isBluetooth =
        selectedTab == MediaSourceTab.bluetooth &&
        ref.watch(bluetoothMediaProvider.select((state) => state.available));
    final bluetoothMedia = isBluetooth
        ? ref.watch(
            bluetoothMediaProvider.select(
              (state) => (
                album: state.album,
                artist: state.artist,
                connected: state.connected,
                coverArt: state.coverArt,
                coverArtLoading: state.coverArtLoading,
                currentItemPath: state.currentItemPath,
                title: state.title,
              ),
            ),
          )
        : null;
    // ── Cover art resolution ──────────────────────────────────────────────
    const albumArtSize = 400.0;
    Uint8List art;
    if (isBluetooth) {
      art = _displayedCoverArt ?? Uint8List(0);
    } else {
      final playlistPosition = ref.watch(
        mediaPlayerStateProvider.select(
          (mediaplayer) => mediaplayer.playlistPosition,
        ),
      );
      art =
          ref.watch(
            playlistArtProvider.select((art) => art[playlistPosition]),
          ) ??
          Uint8List(0);
    }
    final coverArtFaded =
        isBluetooth &&
        art.isNotEmpty &&
        (bluetoothMedia!.coverArtLoading ||
            !identical(_displayedCoverArt, bluetoothMedia.coverArt));

    if (isBluetooth) {
      final bluetooth = bluetoothMedia!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButtons(
            navItems: navItems,
            selectedNav: selectedNav,
            onChanged: _selectSource,
          ),
          const SizedBox(height: 32),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxHeight > constraints.maxWidth) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: _buildCoverArt(
                          art,
                          albumArtSize,
                          faded: coverArtFaded,
                        ),
                      ),
                      const SizedBox(height: 40),
                      const MediaPlayerControls(bluetooth: true),
                      const SizedBox(height: 12),
                      _BluetoothMediaHeader(
                        title: bluetooth.album.isEmpty
                            ? 'Songs'
                            : bluetooth.album,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _BluetoothMediaItemList(
                          connected: bluetooth.connected,
                          currentItemPath: bluetooth.currentItemPath,
                          currentTitle: bluetooth.title,
                          currentArtist: bluetooth.artist,
                          currentAlbum: bluetooth.album,
                        ),
                      ),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final artSize = constraints.biggest.shortestSide
                                    .clamp(0.0, albumArtSize)
                                    .toDouble();
                                return Center(
                                  child: _buildCoverArt(
                                    art,
                                    artSize,
                                    faded: coverArtFaded,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    const Expanded(
                      flex: 5,
                      child: MediaPlayerControls(bluetooth: true),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _BluetoothMediaHeader(
                            title: bluetooth.album.isEmpty
                                ? 'Songs'
                                : bluetooth.album,
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: _BluetoothMediaItemList(
                              connected: bluetooth.connected,
                              currentItemPath: bluetooth.currentItemPath,
                              currentTitle: bluetooth.title,
                              currentArtist: bluetooth.artist,
                              currentAlbum: bluetooth.album,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      );
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
          children: [_buildCoverArt(art, albumArtSize)],
        ),
        const SizedBox(height: 40),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MediaPlayerControls(bluetooth: isBluetooth),
            const SizedBox(height: 12),
            const PlayListTable(),
          ],
        ),
      ],
    );
  }

  Widget _buildCoverArt(Uint8List art, double size, {bool faded = false}) {
    return SizedBox.square(
      dimension: size,
      child: AnimatedOpacity(
        opacity: faded ? 0.45 : 1,
        duration: faded ? const Duration(milliseconds: 250) : Duration.zero,
        child: art.isNotEmpty
            ? Image.memory(
                art,
                width: size,
                height: size,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              )
            : ColoredBox(
                color: AGLDemoColors.jordyBlueColor.withValues(alpha: 0.2),
                child: Icon(
                  Icons.music_note,
                  size: size,
                  color: AGLDemoColors.jordyBlueColor,
                ),
              ),
      ),
    );
  }
}

class _BluetoothMediaHeader extends ConsumerWidget {
  const _BluetoothMediaHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w400,
                    fontSize: 40,
                  ),
                ),
              ),
              Opacity(
                opacity: 0.5,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: SvgPicture.asset('assets/AppleMusic.svg', width: 32),
                ),
              ),
            ],
          ),
        ),
        InkWell(
          customBorder: const CircleBorder(),
          onTap: () =>
              ref.read(appProvider.notifier).update(AppState.audioSettings),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: SvgPicture.asset('assets/AudioSettings.svg', width: 48),
          ),
        ),
      ],
    );
  }
}

/// Displays the Bluetooth media item list.
///
/// When the phone exposes AVRCP browsable items (MediaItem1 D-Bus objects),
/// those are shown as a scrollable list. Each row is tappable to play that
/// item. When no browsable items are available, a single now-playing row
/// is shown instead.
class _BluetoothMediaItemList extends ConsumerStatefulWidget {
  const _BluetoothMediaItemList({
    required this.connected,
    required this.currentItemPath,
    required this.currentTitle,
    required this.currentArtist,
    required this.currentAlbum,
  });

  final bool connected;
  final String currentItemPath;
  final String currentTitle;
  final String currentArtist;
  final String currentAlbum;

  @override
  ConsumerState<_BluetoothMediaItemList> createState() =>
      _BluetoothMediaItemListState();
}

class _BluetoothMediaItemListState
    extends ConsumerState<_BluetoothMediaItemList> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaItems = ref.watch(
      bluetoothMediaProvider.select((state) => state.mediaItems),
    );

    // If the phone exposes browsable items, show those.
    // Otherwise, fall back to a single row for the currently-playing track.
    final List<_MediaListItem> items;
    if (mediaItems.isNotEmpty) {
      items =
          orderBluetoothMediaItems(
                mediaItems,
                currentItemPath: widget.currentItemPath,
                currentTitle: widget.currentTitle,
              )
              .map(
                (item) => _MediaListItem(
                  objectPath: item.objectPath,
                  title: item.name,
                  subtitle: item.artist.isNotEmpty
                      ? item.artist
                      : item.album.isNotEmpty
                      ? item.album
                      : '',
                  isPlaying: widget.currentItemPath.isNotEmpty
                      ? item.objectPath == widget.currentItemPath
                      : item.name == widget.currentTitle,
                  playable: item.playable,
                ),
              )
              .toList();
      if (widget.currentTitle.isNotEmpty &&
          !items.any((item) => item.isPlaying)) {
        items.insert(
          0,
          _MediaListItem(
            title: widget.currentTitle,
            subtitle: widget.currentArtist.isNotEmpty
                ? widget.currentArtist
                : widget.currentAlbum,
            isPlaying: true,
          ),
        );
      }
    } else {
      final subtitle = widget.connected && widget.currentTitle.isNotEmpty
          ? widget.currentArtist.isNotEmpty
                ? widget.currentArtist
                : widget.currentAlbum
          : '';
      items = [
        _MediaListItem(
          title: !widget.connected
              ? 'No Bluetooth media connection'
              : widget.currentTitle.isEmpty
              ? 'No media items available'
              : widget.currentTitle,
          subtitle: subtitle,
          isPlaying: widget.connected && widget.currentTitle.isNotEmpty,
        ),
      ];
    }

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: LayoutBuilder(
          builder: (context, constraints) => RawScrollbar(
            controller: _scrollController,
            thickness: 32,
            thumbVisibility: items.length * 100 > constraints.maxHeight,
            interactive: true,
            thumbColor: AGLDemoColors.periwinkleColor,
            radius: const Radius.circular(10),
            minThumbLength: 60,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(scrollbars: false, overscroll: false),
              child: ListView.separated(
                controller: _scrollController,
                padding: EdgeInsets.zero,
                physics: const ClampingScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  return _BluetoothMediaRow(
                    item: items[index],
                    onTap: items[index].playable
                        ? () => ref
                              .read(bluetoothMediaProvider.notifier)
                              .playItem(items[index].objectPath)
                        : null,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MediaListItem {
  const _MediaListItem({
    this.objectPath = '',
    required this.title,
    required this.subtitle,
    this.isPlaying = false,
    this.playable = false,
  });

  final String objectPath;
  final String title;
  final String subtitle;
  final bool isPlaying;
  final bool playable;
}

class _BluetoothMediaRow extends StatelessWidget {
  const _BluetoothMediaRow({required this.item, this.onTap});

  final _MediaListItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 44),
      child: Ink(
        height: 92,
        decoration: BoxDecoration(
          border: item.isPlaying
              ? const Border(left: BorderSide(color: Colors.white, width: 4))
              : null,
          gradient: LinearGradient(
            colors: item.isPlaying
                ? [
                    AGLDemoColors.neonBlueColor,
                    AGLDemoColors.neonBlueColor.withValues(alpha: 0.15),
                  ]
                : [Colors.black, Colors.black.withValues(alpha: 0.20)],
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 24),
            child: Column(
              children: [
                Expanded(
                  flex: 6,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AutoSizeText(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        shadows: [Helpers.dropShadowRegular],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        shadows: [Helpers.dropShadowRegular],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
