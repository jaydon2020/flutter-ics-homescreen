import 'dart:async';
import 'dart:io';

import 'package:bluez_media_native/bluez_media_native.dart';
import 'package:flutter/foundation.dart';
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

double bluetoothVolumePercent(int volume) => volume.clamp(0, 127) * 100 / 127;

int bluetoothVolumeValue(double percent) =>
    (percent.clamp(0, 100) * 127 / 100).round();

bool bluetoothA2dpUuid(String uuid) =>
    uuid.toLowerCase() == '0000110a-0000-1000-8000-00805f9b34fb' ||
    uuid.toLowerCase() == '0000110b-0000-1000-8000-00805f9b34fb';

bool isA2dpTransport(BluezMediaTransport transport) =>
    bluetoothA2dpUuid(transport.uuid);

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
    this.coverArt,
    this.phoneVolume = 0,
    this.phoneVolumeAvailable = false,
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
  final Uint8List? coverArt;
  final double phoneVolume;
  final bool phoneVolumeAvailable;
  final String? error;
}

class BluetoothMediaNotifier extends StateNotifier<BluetoothMediaState> {
  BluetoothMediaNotifier() : super(const BluetoothMediaState()) {
    unawaited(_initialize());
  }

  BluezMediaClient? _client;
  BluezMediaPlayer? _player;
  BluezMediaTransport? _transport;
  Timer? _refreshTimer;
  final _subscriptions = <String, StreamSubscription<List<String>>>{};
  Directory? _coverArtDirectory;
  String? _trackKey;
  String? _coverArtRequestedTrackKey;
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
      final objects = client.getManagedObjects();
      final players = objects.players.map(client.player).toList();
      final transports = objects.transports.map(client.transport).toList();
      final activePaths = {...objects.players, ...objects.transports};

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
      for (final transport in transports) {
        _subscriptions.putIfAbsent(
          transport.objectPath,
          () => transport.propertiesChanged.listen((_) {
            if (transport.objectPath == _transport?.objectPath &&
                _player != null) {
              _publish(_player!);
            }
          }),
        );
        transport.refresh();
      }

      if (players.isEmpty) {
        _player = null;
        _transport = null;
        _trackKey = null;
        _coverArtRequestedTrackKey = null;
        state = const BluetoothMediaState(loading: false);
        return;
      }

      _player =
          players.where((player) => player.status == 'playing').firstOrNull ??
          players
              .where((player) => player.objectPath == _player?.objectPath)
              .firstOrNull ??
          players.first;
      final deviceTransports = transports
          .where((transport) => transport.device == _player!.device)
          .where(isA2dpTransport)
          .toList();
      _transport =
          deviceTransports
              .where((transport) => transport.state == 'active')
              .firstOrNull ??
          deviceTransports.firstOrNull;
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
          coverArt: state.coverArt,
          phoneVolume: state.phoneVolume,
          phoneVolumeAvailable: state.phoneVolumeAvailable,
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
    final trackKey = [
      track.title,
      track.artist,
      track.album,
      track.duration.inMilliseconds,
      player.imageHandle,
    ].join('\u001f');
    final trackChanged = trackKey != _trackKey;
    _trackKey = trackKey;
    final transport = _transport;

    state = BluetoothMediaState(
      loading: false,
      connected: transport?.state == 'active',
      title: track.title,
      artist: track.artist,
      album: track.album,
      duration: track.duration,
      position: Duration(milliseconds: player.position),
      shuffleEnabled: bluetoothMediaModeEnabled(player.shuffle),
      repeatEnabled: bluetoothMediaModeEnabled(player.repeat),
      coverArt: trackChanged ? null : state.coverArt,
      phoneVolume: transport == null
          ? 0
          : bluetoothVolumePercent(transport.volume),
      phoneVolumeAvailable: transport?.state == 'active',
      playState: switch (player.status.toLowerCase()) {
        'playing' => PlayState.playing,
        'paused' => PlayState.paused,
        _ => PlayState.stopped,
      },
    );

    if (player.obexPort != 0 &&
        player.imageHandle.isNotEmpty &&
        _coverArtRequestedTrackKey != trackKey) {
      _coverArtRequestedTrackKey = trackKey;
      unawaited(_loadCoverArt(player, trackKey));
    }
  }

  Future<void> _loadCoverArt(BluezMediaPlayer player, String trackKey) async {
    Directory? directory;
    try {
      directory = await Directory.systemTemp.createTemp('bluez_media_art_');
      final path = await player.getCoverArt('${directory.path}/cover-art');
      final bytes = await File(path).readAsBytes();
      if (_disposed || trackKey != _trackKey) {
        await directory.delete(recursive: true);
        return;
      }

      final previous = _coverArtDirectory;
      _coverArtDirectory = directory;
      _setCoverArt(bytes);
      if (previous != null) unawaited(previous.delete(recursive: true));
    } catch (error) {
      if (directory != null && await directory.exists()) {
        await directory.delete(recursive: true);
      }
      debugPrint('Bluetooth cover art unavailable: $error');
    }
  }

  void _setCoverArt(Uint8List coverArt) {
    state = BluetoothMediaState(
      loading: state.loading,
      connected: state.connected,
      title: state.title,
      artist: state.artist,
      album: state.album,
      duration: state.duration,
      position: state.position,
      playState: state.playState,
      shuffleEnabled: state.shuffleEnabled,
      repeatEnabled: state.repeatEnabled,
      coverArt: coverArt,
      phoneVolume: state.phoneVolume,
      phoneVolumeAvailable: state.phoneVolumeAvailable,
      error: state.error,
    );
  }

  void playPause() => _setPlayback(state.playState != PlayState.playing);

  void play() => _setPlayback(true);

  void pause() => _setPlayback(false);

  void _setPlayback(bool playing) {
    final player = _player;
    if (player == null) return;
    final previous = state.playState;
    final next = playing ? PlayState.playing : PlayState.paused;
    _setPlayState(next);

    Future.delayed(const Duration(milliseconds: 20), () {
      if (_disposed || _player?.objectPath != player.objectPath) return;
      try {
        playing ? player.play() : player.pause();
        player.refresh();
        _publish(player);
      } catch (error) {
        _setPlayState(previous);
        _setError('Bluetooth media command failed: $error');
      }
    });
  }

  void _setPlayState(PlayState playState) {
    state = BluetoothMediaState(
      loading: state.loading,
      connected: state.connected,
      title: state.title,
      artist: state.artist,
      album: state.album,
      duration: state.duration,
      position: state.position,
      playState: playState,
      shuffleEnabled: state.shuffleEnabled,
      repeatEnabled: state.repeatEnabled,
      coverArt: state.coverArt,
      phoneVolume: state.phoneVolume,
      phoneVolumeAvailable: state.phoneVolumeAvailable,
      error: state.error,
    );
  }

  void next() => _run((player) => player.next());

  void previous() => _run((player) => player.previous());

  void toggleShuffle() => _run(
    (player) => player.setShuffle(state.shuffleEnabled ? 'off' : 'alltracks'),
  );

  void toggleRepeat() => _run(
    (player) => player.setRepeat(state.repeatEnabled ? 'off' : 'singletrack'),
  );

  void setPhoneVolume(double value) {
    final transport = _transport;
    if (transport == null) return;
    try {
      transport.volume = bluetoothVolumeValue(value);
      if (_player != null) _publish(_player!);
    } catch (error) {
      _setError('Bluetooth volume command failed: $error');
    }
  }

  void _run(void Function(BluezMediaPlayer player) command) {
    final player = _player;
    if (player == null) return;
    try {
      command(player);
      player.refresh();
      _publish(player);
    } catch (error) {
      _setError('Bluetooth media command failed: $error');
    }
  }

  void _setError(String error) {
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
      coverArt: state.coverArt,
      phoneVolume: state.phoneVolume,
      phoneVolumeAvailable: state.phoneVolumeAvailable,
      error: error,
    );
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
    final coverArtDirectory = _coverArtDirectory;
    if (coverArtDirectory != null) {
      unawaited(coverArtDirectory.delete(recursive: true));
    }
    super.dispose();
  }
}

final bluetoothMediaProvider =
    StateNotifierProvider.autoDispose<
      BluetoothMediaNotifier,
      BluetoothMediaState
    >((ref) => BluetoothMediaNotifier());
