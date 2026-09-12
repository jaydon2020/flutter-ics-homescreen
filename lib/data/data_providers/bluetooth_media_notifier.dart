import 'dart:async';
import 'dart:io';

import 'package:bluez_media_native/bluez_media_native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/mediaplayer_state.dart';
import 'app_config_provider.dart';

({
  String title,
  String artist,
  String album,
  Duration duration,
  String itemPath,
})
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
    itemPath: metadata['item'] ?? '',
  );
}

bool bluetoothMediaModeEnabled(String mode) =>
    mode.isNotEmpty && mode.toLowerCase() != 'off';

bool bluetoothA2dpUuid(String uuid) =>
    uuid.toLowerCase() == '0000110a-0000-1000-8000-00805f9b34fb' ||
    uuid.toLowerCase() == '0000110b-0000-1000-8000-00805f9b34fb';

bool isA2dpTransport(BluezMediaTransport transport) =>
    bluetoothA2dpUuid(transport.uuid);

/// Lightweight DTO for a browsable AVRCP media item.
@immutable
class BluetoothMediaItem {
  const BluetoothMediaItem({
    required this.objectPath,
    required this.name,
    required this.artist,
    required this.album,
    required this.playable,
  });

  final String objectPath;
  final String name;
  final String artist;
  final String album;
  final bool playable;
}

String _mediaItemProperty(BluezMediaItem item, String key) {
  for (final property in item.metadata) {
    final propertyKey = property.key.toLowerCase();
    if (propertyKey == key || propertyKey == 'xesam:$key') {
      return property.value.trim();
    }
  }
  return '';
}

String _mediaItemTitle(BluezMediaItem item) {
  final name = item.name.trim();
  return name.isNotEmpty ? name : _mediaItemProperty(item, 'title');
}

BluetoothMediaItem _toMediaItem(BluezMediaItem item) {
  return BluetoothMediaItem(
    objectPath: item.objectPath,
    name: _mediaItemTitle(item),
    artist: _mediaItemProperty(item, 'artist'),
    album: _mediaItemProperty(item, 'album'),
    playable: item.playable,
  );
}

List<BluetoothMediaItem> orderBluetoothMediaItems(
  List<BluetoothMediaItem> items, {
  required String currentItemPath,
  required String currentTitle,
}) {
  final ordered = items.reversed.toList();
  final currentIndex = ordered.indexWhere(
    (item) => currentItemPath.isNotEmpty
        ? item.objectPath == currentItemPath
        : currentTitle.isNotEmpty && item.name == currentTitle,
  );
  if (currentIndex > 0) {
    ordered.insert(0, ordered.removeAt(currentIndex));
  }
  return ordered;
}

@immutable
class BluetoothMediaState {
  const BluetoothMediaState({
    this.loading = true,
    this.available = false,
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
    this.coverArtLoading = false,
    this.currentItemPath = '',
    this.mediaItems = const [],
  });

  final bool loading;
  final bool available;
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
  final bool coverArtLoading;

  final String currentItemPath;

  /// Browsable AVRCP playlist items reported by BlueZ (MediaItem1 objects).
  final List<BluetoothMediaItem> mediaItems;

  BluetoothMediaState copyWith({
    bool? loading,
    bool? available,
    bool? connected,
    String? title,
    String? artist,
    String? album,
    Duration? duration,
    Duration? position,
    PlayState? playState,
    bool? shuffleEnabled,
    bool? repeatEnabled,
    Uint8List? coverArt,
    bool? coverArtLoading,
    String? currentItemPath,
    List<BluetoothMediaItem>? mediaItems,
  }) {
    return BluetoothMediaState(
      loading: loading ?? this.loading,
      available: available ?? this.available,
      connected: connected ?? this.connected,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      position: position ?? this.position,
      playState: playState ?? this.playState,
      shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
      repeatEnabled: repeatEnabled ?? this.repeatEnabled,
      coverArt: coverArt ?? this.coverArt,
      coverArtLoading: coverArtLoading ?? this.coverArtLoading,
      currentItemPath: currentItemPath ?? this.currentItemPath,
      mediaItems: mediaItems ?? this.mediaItems,
    );
  }
}

class BluetoothMediaNotifier extends Notifier<BluetoothMediaState> {
  @override
  BluetoothMediaState build() {
    ref.onDispose(_disposeResources);
    _enableCoverArtNative = ref.read(appConfigProvider).enableCoverArtNative;
    unawaited(_initialize());
    return const BluetoothMediaState();
  }

  BluezMediaClient? _client;
  BluezMediaPlayer? _player;
  BluezMediaTransport? _transport;
  final _clientSubscriptions = <StreamSubscription<dynamic>>[];
  final _objectSubscriptions = <String, StreamSubscription<List<String>>>{};
  final _listedFolderPaths = <String>{};
  final _refreshedItemPaths = <String>{};
  Timer? _positionTimer;
  Timer? _coverArtRetryTimer;
  int _coverArtRetryCount = 0;
  String? _coverArtKey;
  String? _coverArtRequestedKey;
  bool _coverArtLoading = false;
  bool _coverArtPending = false;
  bool _refreshingPosition = false;
  bool _playingItem = false;
  bool _disposed = false;
  late final bool _enableCoverArtNative;
  Directory? _coverArtDirectory;

  Future<void> _initialize() async {
    BluezMediaClient? client;
    try {
      client = await BluezMediaClient.create(
        manageCoverArt: _enableCoverArtNative,
      );
      if (_disposed) {
        await client.close();
        return;
      }
      _client = client;
      debugPrint(
        'Bluetooth cover art mode: '
        '${_enableCoverArtNative ? 'native' : 'mpris'}',
      );
      _clientSubscriptions.addAll([
        client.playerAdded.listen(_playerAdded),
        client.playerRemoved.listen(_playerRemoved),
        client.transportAdded.listen(_transportAdded),
        client.transportRemoved.listen(_transportRemoved),
        client.itemAdded.listen(_itemAdded),
        client.itemRemoved.listen(_itemRemoved),
        client.folderAdded.listen(_folderAdded),
        client.folderRemoved.listen(_folderRemoved),
      ]);
      for (final player in client.players) {
        _watchPlayer(player);
      }
      for (final transport in client.transports) {
        _watchTransport(transport);
      }
      for (final item in client.items) {
        _watchItem(item);
      }
      for (final folder in client.folders) {
        _watchFolder(folder);
      }
      _updateState((state) => state.copyWith(available: true));
      _syncMedia();
    } catch (error) {
      _cancelSubscriptions();
      if (client != null) {
        if (identical(_client, client)) _client = null;
        try {
          await client.close();
        } catch (closeError) {
          _logError('Unable to close Bluetooth media client', closeError);
        }
      }
      if (_disposed) return;
      _logError('Bluetooth media is unavailable', error);
      _updateState((_) => const BluetoothMediaState(loading: false));
    }
  }

  void _playerAdded(BluezMediaPlayer player) {
    _watchPlayer(player);
    _syncMedia();
  }

  void _playerRemoved(BluezMediaPlayer player) {
    _removeObjectSubscription('player:${player.objectPath}');
    _syncMedia();
  }

  void _transportAdded(BluezMediaTransport transport) {
    _watchTransport(transport);
    _syncMedia();
  }

  void _transportRemoved(BluezMediaTransport transport) {
    _removeObjectSubscription('transport:${transport.objectPath}');
    _syncMedia();
  }

  void _watchPlayer(BluezMediaPlayer player) {
    _objectSubscriptions.putIfAbsent(
      'player:${player.objectPath}',
      () => player.propertiesChanged.listen(
        (_) => _syncMedia(),
        onError: (Object error) =>
            _logError('Unable to monitor Bluetooth player', error),
      ),
    );
  }

  void _watchTransport(BluezMediaTransport transport) {
    _objectSubscriptions.putIfAbsent(
      'transport:${transport.objectPath}',
      () => transport.propertiesChanged.listen(
        (_) => _syncMedia(),
        onError: (Object error) =>
            _logError('Unable to monitor Bluetooth transport', error),
      ),
    );
  }

  void _removeObjectSubscription(String key) {
    final subscription = _objectSubscriptions.remove(key);
    if (subscription != null) unawaited(subscription.cancel());
  }

  void _itemAdded(BluezMediaItem item) {
    _watchItem(item);
    _syncItems();
  }

  void _itemRemoved(BluezMediaItem item) {
    _refreshedItemPaths.remove(item.objectPath);
    _removeObjectSubscription('item:${item.objectPath}');
    _syncItems();
  }

  void _folderAdded(BluezMediaFolder folder) {
    _watchFolder(folder);
    _loadFolderItems(folder);
  }

  void _folderRemoved(BluezMediaFolder folder) {
    _listedFolderPaths.remove(folder.objectPath);
    _removeObjectSubscription('folder:${folder.objectPath}');
    _syncItems();
  }

  void _watchFolder(BluezMediaFolder folder) {
    _objectSubscriptions.putIfAbsent(
      'folder:${folder.objectPath}',
      () => folder.propertiesChanged.listen(
        (_) {
          _listedFolderPaths.remove(folder.objectPath);
          _loadFolderItems(folder);
        },
        onError: (Object error) =>
            _logError('Unable to monitor Bluetooth media folder', error),
      ),
    );
  }

  void _watchItem(BluezMediaItem item) {
    _objectSubscriptions.putIfAbsent(
      'item:${item.objectPath}',
      () => item.propertiesChanged.listen(
        (_) => _syncItems(),
        onError: (Object error) =>
            _logError('Unable to monitor Bluetooth media item', error),
      ),
    );
    if (_mediaItemTitle(item).isEmpty &&
        _refreshedItemPaths.add(item.objectPath)) {
      unawaited(_refreshItem(item));
    }
  }

  Future<void> _refreshItem(BluezMediaItem item) async {
    try {
      await item.refresh();
      if (!_disposed) _syncItems();
    } catch (error) {
      _logError('Unable to refresh Bluetooth media item', error);
    }
  }

  void _syncItems() {
    if (_disposed) return;
    final client = _client;
    if (client == null) return;
    final player = _player;
    final items = List<BluetoothMediaItem>.unmodifiable(
      client.items
          .where(
            (item) =>
                item.playable &&
                item.playerPath == player?.objectPath &&
                _mediaItemTitle(item).isNotEmpty,
          )
          .map(_toMediaItem)
          .toList(),
    );
    if (!_sameMediaItems(state.mediaItems, items)) {
      _updateState((state) => state.copyWith(mediaItems: items));
    }
  }

  void _loadFolderItems(BluezMediaFolder folder) {
    final player = _player;
    if (_disposed ||
        player == null ||
        !_folderBelongsToPlayer(folder.objectPath, player.objectPath) ||
        !_listedFolderPaths.add(folder.objectPath)) {
      return;
    }
    unawaited(_listFolderItems(folder, player.objectPath));
  }

  Future<void> _listFolderItems(
    BluezMediaFolder folder,
    String playerPath,
  ) async {
    try {
      final items = await folder.listItems();
      if (_disposed || _player?.objectPath != playerPath) return;
      for (final item in items) {
        _watchItem(item);
      }
      _syncItems();
    } catch (error) {
      _listedFolderPaths.remove(folder.objectPath);
      _logError('Unable to list Bluetooth media items', error);
    }
  }

  void _syncMedia() {
    if (_disposed) return;
    final client = _client;
    if (client == null) return;
    final players = client.players;
    if (players.isEmpty) {
      _player = null;
      _transport = null;
      _coverArtKey = null;
      _coverArtRetryTimer?.cancel();
      _coverArtRetryTimer = null;
      _coverArtRetryCount = 0;
      _coverArtRequestedKey = null;
      _coverArtPending = false;
      _listedFolderPaths.clear();
      _refreshedItemPaths.clear();
      _stopPositionRefresh();
      final coverArtDirectory = _coverArtDirectory;
      _coverArtDirectory = null;
      if (coverArtDirectory != null) {
        unawaited(_deleteDirectory(coverArtDirectory));
      }
      _updateState(
        (_) => const BluetoothMediaState(loading: false, available: true),
      );
      return;
    }

    final currentPlayerPath = _player?.objectPath;
    _player =
        players.where((player) => player.status == 'playing').firstOrNull ??
        players
            .where((player) => player.objectPath == currentPlayerPath)
            .firstOrNull ??
        players.first;
    final playerChanged = currentPlayerPath != _player!.objectPath;
    if (playerChanged) {
      _listedFolderPaths.clear();
      _refreshedItemPaths.clear();
    }

    final transports = client.transports
        .where((transport) => transport.device == _player!.device)
        .where(isA2dpTransport)
        .toList();
    final currentTransportPath = _transport?.objectPath;
    _transport =
        transports
            .where((transport) => transport.state == 'active')
            .firstOrNull ??
        transports
            .where((transport) => transport.objectPath == currentTransportPath)
            .firstOrNull ??
        transports.firstOrNull;
    _publish(_player!);
    if (playerChanged) {
      _syncItems();
      for (final folder in client.folders) {
        _loadFolderItems(folder);
      }
    }
  }

  void _publish(BluezMediaPlayer player) {
    if (_disposed || player.objectPath != _player?.objectPath) return;

    final track = parseBluetoothTrack(player.track);
    final transport = _transport;
    final canLoadCoverArt = _enableCoverArtNative
        ? player.obexPort != 0 && player.imageHandle.isNotEmpty
        : track.itemPath.isNotEmpty;
    final coverArtKey = canLoadCoverArt
        ? '${player.objectPath}\u001f${player.imageHandle}\u001f${track.itemPath}'
        : null;
    if (_coverArtKey != coverArtKey) {
      _coverArtRetryTimer?.cancel();
      _coverArtRetryTimer = null;
      _coverArtRetryCount = 0;
    }
    _coverArtKey = coverArtKey;
    final loadingCoverArt =
        coverArtKey != null &&
        (_coverArtRequestedKey != coverArtKey ||
            _coverArtLoading ||
            _coverArtPending);
    // An idle A2DP transport is still connected; "active" only means that it
    // is currently streaming audio.
    final connected = transport != null;
    final playState = switch (player.status.toLowerCase()) {
      'playing' => PlayState.playing,
      'paused' => PlayState.paused,
      _ => PlayState.stopped,
    };

    _updateState(
      (state) => BluetoothMediaState(
        loading: false,
        available: true,
        connected: connected,
        title: track.title,
        artist: track.artist,
        album: track.album,
        duration: track.duration,
        position: Duration(milliseconds: player.position),
        playState: playState,
        shuffleEnabled: bluetoothMediaModeEnabled(player.shuffle),
        repeatEnabled: bluetoothMediaModeEnabled(player.repeat),
        // Keep the current image visible until its replacement is ready.
        coverArt: coverArtKey == null ? null : state.coverArt,
        coverArtLoading: loadingCoverArt,
        currentItemPath: track.itemPath,
        // Keep the current item list; _syncItems() updates it independently.
        mediaItems: state.mediaItems,
      ),
    );
    _updatePositionRefresh(connected && playState == PlayState.playing);

    if (coverArtKey == null) {
      _coverArtRequestedKey = null;
      _coverArtPending = false;
    } else if (_coverArtRequestedKey != coverArtKey) {
      _coverArtRequestedKey = coverArtKey;
      if (_coverArtLoading) {
        _coverArtPending = true;
      } else {
        _startCoverArtLoad(player, coverArtKey);
      }
    }
  }

  void _startCoverArtLoad(BluezMediaPlayer player, String coverArtKey) {
    _coverArtLoading = true;
    unawaited(_loadCoverArt(player, coverArtKey));
  }

  void _updatePositionRefresh(bool playing) {
    if (!playing) {
      _stopPositionRefresh();
      return;
    }
    _positionTimer ??= Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(_refreshPosition()),
    );
  }

  void _stopPositionRefresh() {
    _positionTimer?.cancel();
    _positionTimer = null;
  }

  Future<void> _refreshPosition() async {
    final player = _player;
    if (_disposed || player == null || _refreshingPosition) return;
    _refreshingPosition = true;
    try {
      await player.refresh();
    } catch (error) {
      _logError('Unable to refresh Bluetooth media position', error);
    } finally {
      _refreshingPosition = false;
    }
  }

  Future<void> _loadCoverArt(
    BluezMediaPlayer player,
    String coverArtKey,
  ) async {
    Directory? directory;
    try {
      final Uint8List bytes;
      if (!_enableCoverArtNative) {
        final itemPath = parseBluetoothTrack(player.track).itemPath;
        final client = _client;
        if (client == null) throw StateError('Bluetooth media is unavailable');
        bytes = await client.getMprisCoverArt(itemPath);
      } else {
        directory = await Directory.systemTemp.createTemp('bluez_media_art_');
        final path = await player.getCoverArt('${directory.path}/cover-art');
        bytes = await File(path).readAsBytes();
      }
      if (_disposed || coverArtKey != _coverArtKey) {
        if (directory != null) await _deleteDirectory(directory);
        return;
      }
      final previous = _coverArtDirectory;
      _coverArtDirectory = directory;
      directory = null;
      _updateState(
        (state) => state.copyWith(coverArt: bytes, coverArtLoading: false),
      );
      if (previous != null) unawaited(_deleteDirectory(previous));
    } catch (error) {
      if (directory != null) await _deleteDirectory(directory);
      _coverArtPending = false;
      if (!_disposed && coverArtKey == _coverArtKey) {
        final retryLimit = _enableCoverArtNative ? 2 : 10;
        if (_coverArtRetryCount < retryLimit) {
          // Keep the request key during backoff so position updates cannot
          // bypass the delay. Retry even when a paused player emits no updates.
          _coverArtRetryCount++;
          _coverArtRetryTimer = Timer(
            Duration(
              seconds: _enableCoverArtNative ? 2 * _coverArtRetryCount : 2,
            ),
            () {
              _coverArtRetryTimer = null;
              final currentPlayer = _player;
              if (_disposed ||
                  currentPlayer == null ||
                  coverArtKey != _coverArtKey) {
                return;
              }
              _startCoverArtLoad(currentPlayer, coverArtKey);
            },
          );
        } else {
          _logError('Bluetooth cover art is unavailable', error);
        }
      }
    } finally {
      _coverArtLoading = false;
      if (!_disposed && _coverArtPending) {
        _coverArtPending = false;
        final player = _player;
        final coverArtKey = _coverArtKey;
        if (player != null && coverArtKey != null) {
          _startCoverArtLoad(player, coverArtKey);
        }
      } else if (!_disposed && state.coverArtLoading) {
        _updateState((state) => state.copyWith(coverArtLoading: false));
      }
    }
  }

  void playPause() =>
      unawaited(_setPlayback(state.playState != PlayState.playing));

  void play() => unawaited(_setPlayback(true));

  void pause() => unawaited(_setPlayback(false));

  Future<void> _setPlayback(bool playing) async {
    final player = _player;
    if (player == null) return;
    final previous = state.playState;
    _setPlayState(playing ? PlayState.playing : PlayState.paused);
    try {
      if (playing) {
        await player.play();
      } else {
        await player.pause();
      }
      if (_disposed || player.objectPath != _player?.objectPath) return;
      await player.refresh();
      _publish(player);
    } catch (error) {
      if (!_disposed && player.objectPath == _player?.objectPath) {
        _setPlayState(previous);
      }
      _logError('Bluetooth media command failed', error);
    }
  }

  void _setPlayState(PlayState playState) {
    _updateState((state) => state.copyWith(playState: playState));
    _updatePositionRefresh(state.connected && playState == PlayState.playing);
  }

  /// Play a specific [BluezMediaItem] by its object path.
  void playItem(String objectPath) {
    final client = _client;
    if (client == null || _disposed || _playingItem) return;
    _playingItem = true;
    unawaited(() async {
      try {
        await client.playItem(objectPath);
      } catch (error) {
        _logError('Bluetooth play item failed', error);
      } finally {
        _playingItem = false;
      }
    }());
  }

  void next() => unawaited(_run((player) => player.next()));

  void previous() => unawaited(_run((player) => player.previous()));

  void toggleShuffle() => unawaited(
    _run(
      (player) => player.setShuffle(state.shuffleEnabled ? 'off' : 'alltracks'),
    ),
  );

  void toggleRepeat() => unawaited(
    _run(
      (player) => player.setRepeat(state.repeatEnabled ? 'off' : 'singletrack'),
    ),
  );

  Future<void> _run(
    Future<void> Function(BluezMediaPlayer player) command,
  ) async {
    final player = _player;
    if (player == null) return;
    try {
      await command(player);
      if (_disposed || player.objectPath != _player?.objectPath) return;
      await player.refresh();
      _publish(player);
    } catch (error) {
      _logError('Bluetooth media command failed', error);
    }
  }

  void _updateState(
    BluetoothMediaState Function(BluetoothMediaState state) update,
  ) {
    if (!_disposed) state = update(state);
  }

  void _logError(String message, Object error) =>
      debugPrint('Bluetooth media: $message: $error');

  Future<void> _deleteDirectory(Directory directory) async {
    try {
      if (await directory.exists()) await directory.delete(recursive: true);
    } catch (error) {
      _logError('Unable to remove temporary cover art', error);
    }
  }

  void _disposeResources() {
    _disposed = true;

    _coverArtRetryTimer?.cancel();
    _coverArtRetryTimer = null;
    _coverArtPending = false;
    _playingItem = false;
    _stopPositionRefresh();
    _cancelSubscriptions();
    _listedFolderPaths.clear();
    _refreshedItemPaths.clear();
    final client = _client;
    _client = null;
    if (client != null) unawaited(_closeClient(client));
    final coverArtDirectory = _coverArtDirectory;
    _coverArtDirectory = null;
    if (coverArtDirectory != null) {
      unawaited(_deleteDirectory(coverArtDirectory));
    }
  }

  Future<void> _closeClient(BluezMediaClient client) async {
    try {
      await client.close();
    } catch (error) {
      _logError('Unable to close Bluetooth media client', error);
    }
  }

  void _cancelSubscriptions() {
    for (final subscription in _objectSubscriptions.values) {
      unawaited(subscription.cancel());
    }
    for (final subscription in _clientSubscriptions) {
      unawaited(subscription.cancel());
    }
    _objectSubscriptions.clear();
    _clientSubscriptions.clear();
  }
}

bool _folderBelongsToPlayer(String folderPath, String playerPath) =>
    folderPath == playerPath || folderPath.startsWith('$playerPath/');

bool _sameMediaItems(
  List<BluetoothMediaItem> left,
  List<BluetoothMediaItem> right,
) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    final a = left[index];
    final b = right[index];
    if (a.objectPath != b.objectPath ||
        a.name != b.name ||
        a.artist != b.artist ||
        a.album != b.album ||
        a.playable != b.playable) {
      return false;
    }
  }
  return true;
}

final bluetoothMediaProvider =
    NotifierProvider<BluetoothMediaNotifier, BluetoothMediaState>(
      BluetoothMediaNotifier.new,
    );
