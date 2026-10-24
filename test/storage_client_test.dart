import 'package:flutter_ics_homescreen/data/data_providers/val_client.dart';
import 'package:flutter_ics_homescreen/data/data_providers/storage_client.dart';
import 'package:flutter_ics_homescreen/export.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protos/storage-api.dart' as api;

// A fresh database per test: no installed service or destructive live DB access.
class _Database extends api.DatabaseServiceBase {
  final values = <(String, String), String>{};
  @override
  Future<api.StandardResponse> write(
    api.ServiceCall call,
    api.KeyValue r,
  ) async {
    values[(r.namespace, r.key)] = r.value;
    return api.StandardResponse(success: true);
  }

  @override
  Future<api.ReadResponse> read(api.ServiceCall call, api.Key r) async =>
      api.ReadResponse(
        success: values.containsKey((r.namespace, r.key)),
        result: values[(r.namespace, r.key)] ?? '',
      );
  @override
  Future<api.StandardResponse> delete(api.ServiceCall call, api.Key r) async =>
      api.StandardResponse(
        success: values.remove((r.namespace, r.key)) != null,
      );
  @override
  Future<api.ListResponse> search(api.ServiceCall call, api.Key r) async =>
      api.ListResponse(
        success: true,
        result: values.keys
            .where((k) => k.$1 == r.namespace && k.$2.contains(r.key))
            .map((k) => k.$2),
      );
  @override
  Future<api.StandardResponse> deleteNodes(
    api.ServiceCall call,
    api.Key r,
  ) async {
    values.removeWhere((k, _) => k.$1 == r.namespace && k.$2.startsWith(r.key));
    return api.StandardResponse(success: true);
  }

  @override
  Future<api.ListResponse> listNodes(
    api.ServiceCall call,
    api.SubtreeInfo r,
  ) async =>
      api.ListResponse(success: true, result: values.keys.map((k) => k.$2));
  @override
  Future<api.StandardResponse> destroyDB(
    api.ServiceCall call,
    api.DestroyArguments r,
  ) async {
    values.clear();
    return api.StandardResponse(success: true);
  }
}

class _ValClient implements ValClient {
  @override
  void setDistanceUnit(DistanceUnit unit) {}
  @override
  void setTemperatureUnit(TemperatureUnit unit) {}
  @override
  void setPressureUnit(PressureUnit unit) {}
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

void main() {
  late api.Server server;
  late ProviderContainer container;
  ProviderContainer open() => ProviderContainer(
    overrides: [
      valClientProvider.overrideWithValue(_ValClient()),
      storageClientProvider.overrideWith(
        (ref) => StorageClient(
          config: StorageConfig(hostname: '127.0.0.1', port: server.port!),
          ref: ref,
        ),
      ),
    ],
  );
  setUp(() async {
    server = api.Server.create(services: [_Database()]);
    await server.serve(address: InternetAddress.loopbackIPv4, port: 0);
    container = open();
  });
  tearDown(() async {
    container.dispose();
    await server.shutdown();
  });

  test('storage RPCs preserve namespaces and support deletion', () async {
    final client = container.read(storageClientProvider);
    await client.write(api.KeyValue(key: 'Vehicle.Volume', value: '8'));
    await client.write(
      api.KeyValue(key: 'Vehicle.Volume', value: '12', namespace: 'phone-b'),
    );
    expect((await client.read(api.Key(key: 'Vehicle.Volume'))).result, '8');
    expect(
      (await client.read(
        api.Key(key: 'Vehicle.Volume', namespace: 'phone-b'),
      )).result,
      '12',
    );
    expect((await client.search(api.Key(key: 'Vehicle'))).result, [
      'Vehicle.Volume',
    ]);
    expect((await client.listNodes(api.SubtreeInfo())).result, hasLength(2));
    await client.delete(api.Key(key: 'Vehicle.Volume'));
    expect(
      (await client.read(api.Key(key: 'Vehicle.Volume'))).success,
      isFalse,
    );
    await client.deleteNodes(api.Key(key: 'Vehicle', namespace: 'phone-b'));
    expect(
      (await client.search(api.Key(key: '', namespace: 'phone-b'))).result,
      isEmpty,
    );
    await client.write(api.KeyValue(key: 'temporary', value: '1'));
    await client.destroyDB();
    expect((await client.search(api.Key(key: ''))).result, isEmpty);
  });

  test('users and per-user units reload after provider restart', () async {
    await container.read(storageClientProvider).connect();
    final users = container.read(usersProvider.notifier);
    await users.addUser('Mark');
    final mark = container.read(usersProvider).selectedUser.id;
    await container
        .read(unitStateProvider.notifier)
        .setDistanceUnit(DistanceUnit.miles);
    await users.addUser('Clara');
    final clara = container.read(usersProvider).selectedUser.id;
    await container
        .read(unitStateProvider.notifier)
        .setDistanceUnit(DistanceUnit.kilometers);
    await users.selectUser(mark);
    expect(container.read(unitStateProvider).distanceUnit, DistanceUnit.miles);
    container.dispose();
    container = open();
    await container.read(storageClientProvider).connect();
    expect(container.read(usersProvider).selectedUser.id, mark);
    expect(container.read(unitStateProvider).distanceUnit, DistanceUnit.miles);
    await container.read(usersProvider.notifier).selectUser(clara);
    expect(
      container.read(unitStateProvider).distanceUnit,
      DistanceUnit.kilometers,
    );
    await container.read(usersProvider.notifier).removeUser(mark);
    expect(
      container.read(usersProvider).users.any((u) => u.id == mark),
      isFalse,
    );
    final client = container.read(storageClientProvider);
    expect((await client.search(api.Key(key: mark))).result, isEmpty);
    expect(
      (await client.search(api.Key(key: '', namespace: mark))).result,
      isEmpty,
    );
  });
}
