import 'package:flutter_ics_homescreen/export.dart';
import 'package:protos/storage-api.dart' as api;

class StorageClient {
  final StorageConfig config;
  final Ref ref;
  late api.ClientChannel channel;
  late api.DatabaseClient stub;

  StorageClient({required this.config, required this.ref}) {
    debugPrint(
        "Connecting to storage service at ${config.hostname}:${config.port}");
    api.ChannelCredentials creds = const api.ChannelCredentials.insecure();
    channel = api.ClientChannel(config.hostname,
        port: config.port, options: api.ChannelOptions(credentials: creds));
    stub = api.DatabaseClient(channel);

    channel.onConnectionStateChanged.listen((api.ConnectionState state) {
      //debugPrint('Storage API Connection state changed: $state');
      switch (state) {
        case api.ConnectionState.ready:
          debugPrint('Storage API channel connected');
          ref.read(storageClientConnectedProvider.notifier).update(true);
          break;
        default:
          ref.read(storageClientConnectedProvider.notifier).update(false);
          break;
      }
    });
  }

  void connect() async {
    await ref.read(usersProvider.notifier).loadSettingsUsers();
    await ref.read(unitStateProvider.notifier).loadSettingsUnits();
  }

  Future<api.StandardResponse> destroyDB() async {
    try {
      var response = await stub.destroyDB(api.DestroyArguments());
      return response;
    } catch (e) {
      debugPrint('$e');
      rethrow;
    }
  }

  Future<api.StandardResponse> write(api.KeyValue keyValue) async {
    try {
      var response = await stub.write(keyValue);
      return response;
    } catch (e) {
      debugPrint('$e');
      rethrow;
    }
  }

  Future<api.ReadResponse> read(api.Key key) async {
    try {
      var response = await stub.read(key);
      return response;
    } catch (e) {
      debugPrint('$e');
      rethrow;
    }
  }

  Future<api.StandardResponse> delete(api.Key key) async {
    try {
      var response = await stub.delete(key);
      return response;
    } catch (e) {
      debugPrint('$e');
      rethrow;
    }
  }

  Future<api.ListResponse> search(api.Key key) async {
    try {
      var response = await stub.search(key);
      return response;
    } catch (e) {
      debugPrint('$e');
      rethrow;
    }
  }

  Future<api.StandardResponse> deleteNodes(api.Key key) async {
    try {
      var response = await stub.deleteNodes(key);
      return response;
    } catch (e) {
      debugPrint('$e');
      rethrow;
    }
  }

  Future<api.ListResponse> listNodes(api.SubtreeInfo subtreeInfo) async {
    try {
      var response = await stub.listNodes(subtreeInfo);
      return response;
    } catch (e) {
      debugPrint('$e');
      rethrow;
    }
  }
}
