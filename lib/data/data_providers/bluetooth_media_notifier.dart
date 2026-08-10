import 'dart:async';

import 'package:bluez_media_native/bluez_media_native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/mediaplayer_state.dart';

({String title, String artist, String album, Duration duration})
parseBluetoothTrack(Iterable<BlueZMediaProperty> track) {
  final metadata = {
    for (final property in track) property.key.toLowerCase(): property.value,
  };
  return (
    title: metadata['title'] ?? metadata['xesam:title'] ?? '',
    artist: metadata['artist'] ?? metadata['xesam:artist'] ?? '',
    album: metadata['album'] ?? metadata['xesam:album'] ?? '',
    duration: Duration(
      milliseconds: int.tryParse(metadata['duration'] ?? '') ?? 0,
    ),
  );
}

bool bluetoothMediaModeEnabled(String mode) =>
    mode.isNotEmpty && mode.toLowerCase() != 'off';

class BluetoothMediaState {
  const BluetoothMediaState({
    this.loading = true,
    this.connected = false,
    this.title = '',
    this.artist = '',
    this.album = '',
    this.duration = Duration.zero,
    this.position = Duration.zero,
    this.playState = PlayState.stopped,
    this.shuffleEnabled = false,
    this.repeatEnabled = false,
    this.error,
  });

  final bool loading;
  final bool connected;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final Duration position;
  final PlayState playState;
  final bool shuffleEnabled;
  final bool repeatEnabled;
  final String? error;
}

class BluetoothMediaNotifier extends StateNotifier<BluetoothMediaState> {
  BluetoothMediaNotifier() : super(const BluetoothMediaState()) {
    unawaited(_initialize());
  }

  BluezMediaClient? _client;
  BluezMediaPlayer? _player;
  Timer? _refreshTimer;
  final _subscriptions = <String, StreamSubscription<List<String>>>{};
  bool _refreshing = false;
  bool _disposed = false;

  Future<void> _initialize() async {
    try {
      final client = BluezMediaClient.create();
      _client = client;
      await client.ready.timeout(const Duration(seconds: 3), onTimeout: () {});
      if (_disposed) return;
      await _refresh();
      if (_disposed) return;
      _refreshTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => unawaited(_refresh()),
      );
    } catch (error) {
      if (_disposed) return;
      state = BluetoothMediaState(
        loading: false,
        error: 'Bluetooth media is unavailable: $error',
      );
    }
  }

  Future<void> _refresh() async {
    final client = _client;
    if (client == null || _refreshing) return;
    _refreshing = true;

    try {
      final paths = client.getManagedObjects().players;
      final players = paths.map(client.player).toList();
      final activePaths = paths.toSet();

      for (final entry in _subscriptions.entries.toList()) {
        if (!activePaths.contains(entry.key)) {
          await entry.value.cancel();
          _subscriptions.remove(entry.key);
        }
      }

      for (final player in players) {
        _subscriptions.putIfAbsent(
          player.objectPath,
          () => player.propertiesChanged.listen((_) => _publish(player)),
        );
        player.refresh();
      }

      if (players.isEmpty) {
        _player = null;
        state = const BluetoothMediaState(loading: false);
        return;
      }

      _player =
          players.where((player) => player.status == 'playing').firstOrNull ??
          players
              .where((player) => player.objectPath == _player?.objectPath)
              .firstOrNull ??
          players.first;
      _publish(_player!);
    } catch (error) {
      if (!_disposed) {
        state = BluetoothMediaState(
          loading: false,
          connected: state.connected,
          title: state.title,
          artist: state.artist,
          album: state.album,
          duration: state.duration,
          position: state.position,
          playState: state.playState,
          shuffleEnabled: state.shuffleEnabled,
          repeatEnabled: state.repeatEnabled,
          error: 'Unable to read Bluetooth media: $error',
        );
      }
    } finally {
      _refreshing = false;
    }
  }

  void _publish(BluezMediaPlayer player) {
    if (_disposed) return;
    if (_player != null && player.objectPath != _player!.objectPath) return;

    final track = parseBluetoothTrack(player.track);

    state = BluetoothMediaState(
      loading: false,
      connected: true,
      title: track.title,
      artist: track.artist,
      album: track.album,
      duration: track.duration,
      position: Duration(milliseconds: player.position),
      shuffleEnabled: bluetoothMediaModeEnabled(player.shuffle),
      repeatEnabled: bluetoothMediaModeEnabled(player.repeat),
      playState: switch (player.status.toLowerCase()) {
        'playing' => PlayState.playing,
        'paused' => PlayState.paused,
        _ => PlayState.stopped,
      },
    );
  }

  void playPause() => _run((player) {
    if (state.playState == PlayState.playing) {
      player.pause();
    } else {
      player.play();
    }
  });

  void play() => _run((player) => player.play());

  void pause() => _run((player) => player.pause());

  void next() => _run((player) => player.next());

  void previous() => _run((player) => player.previous());

  void toggleShuffle() => _run(
    (player) => player.setShuffle(state.shuffleEnabled ? 'off' : 'alltracks'),
  );

  void toggleRepeat() => _run(
    (player) => player.setRepeat(state.repeatEnabled ? 'off' : 'singletrack'),
  );

  void _run(void Function(BluezMediaPlayer player) command) {
    final player = _player;
    if (player == null) return;
    try {
      command(player);
      player.refresh();
      _publish(player);
    } catch (error) {
      state = BluetoothMediaState(
        loading: false,
        connected: true,
        title: state.title,
        artist: state.artist,
        album: state.album,
        duration: state.duration,
        position: state.position,
        playState: state.playState,
        shuffleEnabled: state.shuffleEnabled,
        repeatEnabled: state.repeatEnabled,
        error: 'Bluetooth media command failed: $error',
      );
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _refreshTimer?.cancel();
    for (final subscription in _subscriptions.values) {
      unawaited(subscription.cancel());
    }
    final client = _client;
    _client = null;
    client?.close();
    super.dispose();
  }
}

final bluetoothMediaProvider =
    StateNotifierProvider.autoDispose<
      BluetoothMediaNotifier,
      BluetoothMediaState
    >((ref) => BluetoothMediaNotifier());
