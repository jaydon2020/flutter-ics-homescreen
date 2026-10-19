import 'dart:async';

import 'package:flutter_ics_homescreen/data/data_providers/radio_client.dart'
    as radio_client;
import 'package:flutter_ics_homescreen/data/data_providers/storage_client.dart';
import 'package:flutter_ics_homescreen/data/data_providers/units_notifier.dart';
import 'package:flutter_ics_homescreen/data/data_providers/users_notifier.dart';
import 'package:flutter_ics_homescreen/data/data_providers/val_client.dart';
import 'package:flutter_ics_homescreen/data/models/users.dart';
import 'package:flutter_ics_homescreen/data/services/service_retry.dart';
import 'package:flutter_ics_homescreen/export.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protos/radio_api.dart' as radio;
import 'package:protos/storage-api.dart' as storage;
import 'package:protos/val_api.dart' as val;

Future<int> _unusedPort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

Future<void> _until(bool Function() done) async {
  final deadline = DateTime.now().add(const Duration(seconds: 8));
  while (!done()) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('Service did not recover');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

class _RadioService extends radio.RadioServiceBase {
  int subscriptions = 0;
  int startCalls = 0;
  bool failStart = false;
  final events = StreamController<radio.StatusResponse>.broadcast();
  @override
  Future<radio.GetBandParametersResponse> getBandParameters(
    radio.ServiceCall call,
    radio.GetBandParametersRequest request,
  ) async => radio.GetBandParametersResponse(
    min: 87500000,
    max: 108000000,
    step: 100000,
  );
  @override
  Future<radio.GetFrequencyResponse> getFrequency(
    radio.ServiceCall call,
    radio.GetFrequencyRequest request,
  ) async => radio.GetFrequencyResponse(frequency: 101700000);
  @override
  Stream<radio.StatusResponse> getStatusEvents(
    radio.ServiceCall call,
    radio.StatusRequest request,
  ) async* {
    subscriptions++;
    yield radio.StatusResponse(
      frequency: radio.FrequencyStatus(frequency: 101700000),
    );
    yield* events.stream;
  }

  @override
  Future<radio.StartResponse> start(
    radio.ServiceCall call,
    radio.StartRequest request,
  ) async {
    startCalls++;
    if (failStart) {
      throw const radio.GrpcError.unavailable('temporarily unavailable');
    }
    return radio.StartResponse();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

class _StorageService extends storage.DatabaseServiceBase {
  int searches = 0;
  @override
  Future<storage.ListResponse> search(
    storage.ServiceCall call,
    storage.Key request,
  ) async {
    searches++;
    return storage.ListResponse();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

class _Users extends UsersNotifier {
  int loads = 0;
  @override
  Users build() => Users.initial();
  @override
  Future<void> loadSettingsUsers() async {
    loads++;
  }
}

class _Units extends UnitsNotifier {
  int loads = 0;
  @override
  Units build() => const Units.initial();
  @override
  Future<void> loadSettingsUnits() async {
    loads++;
  }
}

class _ValService extends val.VALServiceBase {
  int subscriptions = 0;
  final events = StreamController<val.SubscribeResponse>.broadcast();
  @override
  Future<val.GetResponse> get(
    val.ServiceCall call,
    val.GetRequest request,
  ) async => val.GetResponse();
  @override
  Stream<val.SubscribeResponse> subscribe(
    val.ServiceCall call,
    val.SubscribeRequest request,
  ) async* {
    subscriptions++;
    yield val.SubscribeResponse();
    yield* events.stream;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

void main() {
  testWidgets('connection retries back off, deduplicate, and stop on dispose', (
    tester,
  ) async {
    final retry = ServiceRetry('Test', 'localhost', 1234);
    var attempts = 0;
    void reconnect() => attempts++;
    retry.failed(const radio.GrpcError.unavailable('refused'), reconnect);
    retry.failed(const radio.GrpcError.unavailable('duplicate'), reconnect);
    await tester.pump(const Duration(seconds: 1));
    expect(attempts, 1);
    retry.failed(const radio.GrpcError.unavailable('refused'), reconnect);
    await tester.pump(const Duration(seconds: 1));
    expect(attempts, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(attempts, 2);
    retry.recovered();
    retry.failed(const radio.GrpcError.unavailable('refused again'), reconnect);
    await tester.pump(const Duration(seconds: 1));
    expect(attempts, 3);
    retry.failed(const radio.GrpcError.unavailable('refused'), reconnect);
    retry.dispose();
    await tester.pump(const Duration(seconds: 60));
    expect(attempts, 3);
  });

  testWidgets('permission errors do not trigger connection retries', (
    tester,
  ) async {
    final retry = ServiceRetry('Test', 'localhost', 1234);
    var attempts = 0;
    retry.failed(
      const radio.GrpcError.permissionDenied('denied'),
      () => attempts++,
    );
    await tester.pump(const Duration(seconds: 60));
    expect(attempts, 0);
    retry.dispose();
  });

  test(
    'radio recovers when the server starts late and never replays a failed Start',
    () async {
      final port = await _unusedPort();
      final service = _RadioService();
      final server = radio.Server.create(services: [service]);
      final container = ProviderContainer(
        overrides: [
          radioClientProvider.overrideWith(
            (ref) => radio_client.RadioClient(
              config: RadioConfig(
                hostname: '127.0.0.1',
                port: port,
                presets: '',
              ),
              ref: ref,
            ),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await service.events.close();
        await server.shutdown();
      });
      final client = container.read(radioClientProvider);
      await client
          .connect(); // Server is absent: connection setup must return safely.
      await server.serve(address: '127.0.0.1', port: port);
      await _until(() => service.subscriptions == 1);
      expect(container.read(radioStateProvider).freqCurrent, 101700000);
      service.failStart = true;
      client.start();
      await _until(() => service.startCalls == 1);
      service.failStart = false;
      await _until(() => service.subscriptions == 2);
      expect(service.startCalls, 1);
    },
  );

  test(
    'storage reloads profiles and units after a late server becomes available',
    () async {
      final port = await _unusedPort();
      final service = _StorageService();
      final server = storage.Server.create(services: [service]);
      final container = ProviderContainer(
        overrides: [
          storageClientProvider.overrideWith(
            (ref) => StorageClient(
              config: StorageConfig(hostname: '127.0.0.1', port: port),
              ref: ref,
            ),
          ),
          usersProvider.overrideWith(_Users.new),
          unitStateProvider.overrideWith(_Units.new),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await server.shutdown();
      });
      await container.read(storageClientProvider).connect();
      expect(container.read(storageClientConnectedProvider), isFalse);
      expect((container.read(usersProvider.notifier) as _Users).loads, 0);
      await server.serve(address: '127.0.0.1', port: port);
      await _until(
        () => (container.read(unitStateProvider.notifier) as _Units).loads == 1,
      );
      expect((container.read(usersProvider.notifier) as _Users).loads, 1);
      expect(container.read(storageClientConnectedProvider), isTrue);
      await server.shutdown();
      await _until(() => !container.read(storageClientConnectedProvider));
      await server.serve(address: '127.0.0.1', port: port);
      await _until(
        () => (container.read(unitStateProvider.notifier) as _Units).loads == 2,
      );
      expect((container.read(usersProvider.notifier) as _Users).loads, 2);
      expect(container.read(storageClientConnectedProvider), isTrue);
    },
  );

  test(
    'KUKSA establishes one subscription after a late server starts',
    () async {
      final port = await _unusedPort();
      final service = _ValService();
      final server = val.Server.create(services: [service]);
      final defaults = KuksaConfig.defaultConfig();
      final container = ProviderContainer(
        overrides: [
          valClientProvider.overrideWith(
            (ref) => ValClient(
              config: KuksaConfig(
                hostname: '127.0.0.1',
                port: port,
                authorizationFile: '',
                authorization: '',
                useTls: false,
                caCertificateFile: '',
                readCaCertificateFile: '',
                caCertificate: defaults.caCertificate,
                tlsServerName: '',
              ),
              ref: ref,
            ),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await service.events.close();
        await server.shutdown();
      });
      await container.read(valClientProvider).subscribe();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await server.serve(address: '127.0.0.1', port: port);
      await _until(() => service.subscriptions == 1);
      expect(service.subscriptions, 1);
    },
  );
}
