import 'dart:async';

import 'package:flutter_ics_homescreen/export.dart';
import 'package:flutter_ics_homescreen/data/services/service_retry.dart';
import 'package:protos/storage-api.dart' as api;

class StorageClient {
  final StorageConfig config;
  final Ref ref;
  late api.ClientChannel channel;
  late api.DatabaseClient stub;
  late final ServiceRetry _retry;
  StreamSubscription<api.ConnectionState>? _channelSubscription;
  bool _connecting = false;
  bool _disposed = false;
  int _unavailableCount = 0;
  bool _wasReady = false;

  StorageClient({required this.config, required this.ref}) {
    debugPrint(
      "Connecting to storage service at ${config.hostname}:${config.port}",
    );
    api.ChannelCredentials creds = const api.ChannelCredentials.insecure();
    channel = api.ClientChannel(
      config.hostname,
      port: config.port,
      options: api.ChannelOptions(credentials: creds),
    );
    stub = api.DatabaseClient(channel);

    _retry = ServiceRetry('Storage service', config.hostname, config.port);
    ref.onDispose(() {
      _disposed = true;
      _retry.dispose();
      unawaited(_channelSubscription?.cancel());
      unawaited(channel.shutdown());
    });
    _channelSubscription = channel.onConnectionStateChanged.listen((
      api.ConnectionState state,
    ) {
      if (_disposed) return;
      //debugPrint('Storage API Connection state changed: $state');
      switch (state) {
        case api.ConnectionState.ready:
          _wasReady = true;
          debugPrint('Storage API channel connected');
          ref.read(storageClientConnectedProvider.notifier).update(true);
          break;
        default:
          ref.read(storageClientConnectedProvider.notifier).update(false);
          if (_wasReady && state != api.ConnectionState.shutdown) {
            _wasReady = false;
            _reportError(
              const api.GrpcError.unavailable('Storage connection closed'),
            );
          }
          break;
      }
    });
  }

  void _reportError(Object error) {
    if (_disposed) return;
    if (serviceUnavailable(error)) {
      ++_unavailableCount;
      ref.read(storageClientConnectedProvider.notifier).update(false);
    }
    _retry.failed(error, connect);
  }

  Future<void> connect() async {
    if (_disposed || _connecting) return;
    _connecting = true;
    final failures = _unavailableCount;
    try {
      // Check the read-only endpoint before loading profiles; the notifiers
      // retain defaults on failure and do not propagate transport errors.
      await stub.search(
        api.Key(key: UsersPath.InfotainmentUsers),
        options: api.CallOptions(timeout: const Duration(seconds: 5)),
      );
      if (_disposed) return;
      await ref.read(usersProvider.notifier).loadSettingsUsers();
      if (_disposed) return;
      await ref.read(unitStateProvider.notifier).loadSettingsUnits();
      if (!_disposed && failures == _unavailableCount) {
        ref.read(storageClientConnectedProvider.notifier).update(true);
        _retry.recovered();
      }
    } catch (error) {
      _reportError(error);
    } finally {
      _connecting = false;
    }
  }

  Future<api.StandardResponse> destroyDB() async {
    try {
      var response = await stub.destroyDB(api.DestroyArguments());
      return response;
    } catch (e) {
      _reportError(e);
      rethrow;
    }
  }

  Future<api.StandardResponse> write(api.KeyValue keyValue) async {
    try {
      var response = await stub.write(keyValue);
      return response;
    } catch (e) {
      _reportError(e);
      rethrow;
    }
  }

  Future<api.ReadResponse> read(api.Key key) async {
    try {
      var response = await stub.read(key);
      return response;
    } catch (e) {
      _reportError(e);
      rethrow;
    }
  }

  Future<api.StandardResponse> delete(api.Key key) async {
    try {
      var response = await stub.delete(key);
      return response;
    } catch (e) {
      _reportError(e);
      rethrow;
    }
  }

  Future<api.ListResponse> search(api.Key key) async {
    try {
      var response = await stub.search(key);
      return response;
    } catch (e) {
      _reportError(e);
      rethrow;
    }
  }

  Future<api.StandardResponse> deleteNodes(api.Key key) async {
    try {
      var response = await stub.deleteNodes(key);
      return response;
    } catch (e) {
      _reportError(e);
      rethrow;
    }
  }

  Future<api.ListResponse> listNodes(api.SubtreeInfo subtreeInfo) async {
    try {
      var response = await stub.listNodes(subtreeInfo);
      return response;
    } catch (e) {
      _reportError(e);
      rethrow;
    }
  }
}
