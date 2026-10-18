import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bluez_obex_native/bluez_obex_native.dart';
import 'package:flutter_ics_homescreen/data/data_providers/bluetooth_notifier.dart';
import 'package:flutter_ics_homescreen/data/data_providers/phone_data_notifier.dart';
import 'package:flutter_ics_homescreen/data/models/phone_models.dart';
import 'package:flutter_ics_homescreen/data/services/contact_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'phone_test_support.dart';

class _UnwritableStore extends ContactStore {
  _UnwritableStore(super.file);
  @override
  Future<void> save(
    String address,
    String source, {
    String? revision,
    String? listing,
  }) async {
    throw FileSystemException('read-only contact storage', file.path);
  }
}

void main() {
  late Directory directory;
  late ContactStore store;
  late ProviderContainer container;
  late List<TestObexBackend> backends;
  late List<TestObexBackend> opened;

  void createContainer() {
    container = ProviderContainer(
      overrides: [
        bluetoothProvider.overrideWith(TestBluetoothNotifier.new),
        contactStoreProvider.overrideWithValue(store),
        obexBackendFactoryProvider.overrideWithValue(() {
          final backend = backends.removeAt(0);
          opened.add(backend);
          return backend;
        }),
      ],
    );
    container.read(phoneDataProvider);
  }

  void publish(String? address, {bool pending = false}) {
    (container.read(bluetoothProvider.notifier) as TestBluetoothNotifier)
        .publish(
          BluetoothState(
            devices: address == null
                ? []
                : [phone(address, connected: !pending)],
            busyAddress: pending ? address : null,
            operation: pending ? BluetoothOperation.connecting : null,
          ),
        );
  }

  PhoneDataState state() => container.read(phoneDataProvider);
  Future<void> synced() =>
      waitUntil(() => state().mapAvailable && !state().busy);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('phone-sync-test-');
    store = ContactStore(File('${directory.path}/contacts.json'));
    backends = [];
    opened = [];
    createContainer();
  });
  tearDown(() async {
    container.dispose();
    await waitUntil(() => opened.every((backend) => backend.closed));
    await store.load(
      'AA:BB',
    ); // Wait for disk writes before removing the test directory.
    await directory.delete(recursive: true);
  });

  test(
    'loads cache while connecting; opens profiles only after the pairing sequence',
    () async {
      final backend = TestObexBackend();
      await store.save(
        'AA:BB',
        backend.source,
        revision: jsonEncode(['db', '1', '1']),
      );
      backends.add(backend);
      publish('AA:BB', pending: true);
      await waitUntil(() => state().contacts.isNotEmpty);
      expect(state().status, PhoneConnectionStatus.connecting);
      expect(opened, isEmpty);
      publish('AA:BB');
      // Repeated property updates must not start duplicate sessions.
      publish('AA:BB');
      publish('AA:BB');
      await synced();
      expect(backend.opens, 1);
      expect(backend.contactPulls, 0);
    },
  );

  test(
    'first connection persists contacts; restart reconnect skips unchanged download',
    () async {
      final first = TestObexBackend();
      backends.add(first);
      publish('AA:BB');
      await synced();
      expect(first.contactPulls, 1);
      expect((await store.load('AA:BB'))?.contacts.single.name, 'Aisha');
      container.dispose();
      await waitUntil(() => first.closed);
      store = ContactStore(store.file);
      createContainer();
      final second = TestObexBackend();
      backends.add(second);
      publish('AA:BB');
      await synced();
      expect(state().contacts.single.name, 'Aisha');
      expect(second.contactPulls, 0);
      expect(second.listCalls, 0); // Version counters are sufficient.
    },
  );

  test(
    'version changes detect number-only edits and an empty phonebook',
    () async {
      final backend = TestObexBackend();
      backends.add(backend);
      publish('AA:BB');
      await synced();
      backend.version = '2';
      backend.source = backend.source.replaceAll('+6012345', '+6099999');
      await container.read(phoneDataProvider.notifier).refreshContacts();
      expect(backend.contactPulls, 2);
      expect(state().contacts.single.primaryNumber, '+6099999');
      backend.version = '3';
      backend.entries = [];
      backend.source = '';
      await container.read(phoneDataProvider.notifier).refreshContacts();
      expect(state().contacts, isEmpty);
      expect((await store.load('AA:BB'))?.contacts, isEmpty);
    },
  );

  test(
    'listing fallback skips unchanged contacts; manual refresh updates number-only edits',
    () async {
      final first = TestObexBackend()..hasVersion = false;
      backends.add(first);
      publish('AA:BB');
      await synced();
      publish(null);
      await waitUntil(() => first.closed);
      final second = TestObexBackend()..hasVersion = false;
      backends.add(second);
      publish('AA:BB');
      await synced();
      expect(second.listCalls, 1);
      expect(second.contactPulls, 0);
      second.entries = [
        const BlueZObexPhonebookEntry(vcard: '1.vcf', name: 'Daniel'),
      ];
      second.source = second.source.replaceAll('Aisha', 'Daniel');
      await container.read(phoneDataProvider.notifier).refreshContacts();
      expect(second.contactPulls, 1);
      second.source = second.source.replaceAll('+6012345', '+6088888');
      await container
          .read(phoneDataProvider.notifier)
          .refreshContacts(force: true);
      expect(state().contacts.single.primaryNumber, '+6088888');
      expect(second.contactPulls, 2);
    },
  );

  test('failed download keeps the previous persisted phonebook', () async {
    final backend = TestObexBackend();
    backends.add(backend);
    publish('AA:BB');
    await synced();
    backend.version = '2';
    backend.failPull = true;
    await container.read(phoneDataProvider.notifier).refreshContacts();
    expect(state().contacts.single.name, 'Aisha');
    expect(state().error, contains('Contacts unavailable'));
    expect((await store.load('AA:BB'))?.revision, jsonEncode(['db', '1', '1']));
  });

  test(
    'failed metadata checks download rather than trusting stale contacts',
    () async {
      final backend = TestObexBackend()
        ..hasVersion = false
        ..failListing = true;
      backends.add(backend);
      publish('AA:BB');
      await synced();
      await container.read(phoneDataProvider.notifier).refreshContacts();
      expect(backend.contactPulls, 2);
    },
  );

  test(
    'switching phones ignores a late transfer and keeps the caches separate',
    () async {
      final first = TestObexBackend()..transferGate = Completer<void>();
      backends.add(first);
      publish('AA:BB');
      await waitUntil(() => first.contactPulls == 1);
      final second = TestObexBackend()
        ..source = 'BEGIN:VCARD\r\nFN:Daniel\r\nTEL:+6099999\r\nEND:VCARD\r\n';
      backends.add(second);
      publish('CC:DD');
      await waitUntil(() => first.closed);
      expect(state().contacts, isEmpty);
      first.transferGate!.complete();
      await synced();
      expect(state().deviceAddress, 'CC:DD');
      expect(state().contacts.single.name, 'Daniel');
      expect(await store.load('AA:BB'), isNull);
      expect((await store.load('CC:DD'))?.contacts.single.name, 'Daniel');
    },
  );

  test(
    'contact and recent transfers cannot change the shared PBAP folder concurrently',
    () async {
      final backend = TestObexBackend()..pullGate = Completer<void>();
      backends.add(backend);
      publish('AA:BB');
      await waitUntil(() => backend.contactPulls == 1);
      final recents = container
          .read(phoneDataProvider.notifier)
          .refreshRecents();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(backend.selectedBooks, ['pb']);
      backend.pullGate!.complete();
      await recents;
      await synced();
      expect(state().contacts.single.name, 'Aisha');
    },
  );

  test(
    'profile failure preserves cached contacts and supports retry',
    () async {
      final first = TestObexBackend()..failOpen = true;
      await store.save('AA:BB', first.source);
      backends.add(first);
      publish('AA:BB');
      await waitUntil(() => state().status == PhoneConnectionStatus.error);
      expect(state().contacts.single.name, 'Aisha');
      expect(first.closed, isTrue);
      final second = TestObexBackend();
      backends.add(second);
      await container.read(phoneDataProvider.notifier).retry();
      expect(second.contactPulls, 1);
      expect(state().mapAvailable, isTrue);
    },
  );

  test('a successful MAP sync does not hide contact download errors', () async {
    final backend = TestObexBackend()..failPull = true;
    backends.add(backend);
    publish('AA:BB');
    await synced();
    expect(state().mapAvailable, isTrue);
    expect(state().pbapAvailable, isFalse);
    expect(state().error, contains('Contacts unavailable'));
  });

  test(
    'disk write failures remain visible after other profile refreshes',
    () async {
      container.dispose();
      store = _UnwritableStore(store.file);
      createContainer();
      final backend = TestObexBackend();
      backends.add(backend);
      publish('AA:BB');
      await synced();
      expect(state().contacts.single.name, 'Aisha');
      expect(state().error, contains('could not be saved'));
      expect(await store.load('AA:BB'), isNull);
    },
  );

  test('incomplete contacts cannot replace the saved phonebook', () async {
    final backend = TestObexBackend();
    backends.add(backend);
    publish('AA:BB');
    await synced();
    backend.version = '2';
    backend.source = 'BEGIN:VCARD\r\nFN:Broken';
    await container.read(phoneDataProvider.notifier).refreshContacts();
    expect(state().contacts.single.name, 'Aisha');
    expect(state().error, contains('incomplete phonebook'));
    expect((await store.load('AA:BB'))?.contacts.single.name, 'Aisha');
  });

  test(
    'shows no contacts without a selected phone, even when caches exist',
    () async {
      await store.save('AA:BB', TestObexBackend().source);
      await store.save(
        'CC:DD',
        'BEGIN:VCARD\r\nFN:Daniel\r\nTEL:+6099999\r\nEND:VCARD\r\n',
      );
      container.dispose();
      createContainer();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(state().contacts, isEmpty);
      expect(state().contactsAddress, isNull);
      publish('AA:BB', pending: true);
      await waitUntil(() => state().contacts.isNotEmpty);
      expect(state().contactsAddress, 'AA:BB');
      expect(state().contacts.single.name, 'Aisha');
      publish('CC:DD', pending: true);
      expect(state().contacts, isEmpty);
      await waitUntil(() => state().contacts.isNotEmpty);
      expect(state().contactsAddress, 'CC:DD');
      expect(state().contacts.single.name, 'Daniel');
      publish(null);
      expect(state().contacts, isEmpty);
      expect(state().contactsAddress, isNull);
      expect((await store.load('AA:BB'))?.contacts.single.name, 'Aisha');
      expect((await store.load('CC:DD'))?.contacts.single.name, 'Daniel');
    },
  );

  test(
    'a device without a cache cannot see the previous phone contacts',
    () async {
      final first = TestObexBackend();
      backends.add(first);
      publish('AA:BB');
      await synced();
      final second = TestObexBackend()..failOpen = true;
      backends.add(second);
      publish('CC:DD', pending: true);
      expect(state().contacts, isEmpty);
      await waitUntil(() => state().contactsAddress == 'CC:DD');
      expect(state().contacts, isEmpty);
      publish('CC:DD');
      await waitUntil(() => state().status == PhoneConnectionStatus.error);
      expect(state().contacts, isEmpty);
      expect((await store.load('AA:BB'))?.contacts.single.name, 'Aisha');
      expect(await store.load('CC:DD'), isNull);
    },
  );

  test('returning to an earlier phone reuses its own cache', () async {
    final first = TestObexBackend();
    final second = TestObexBackend()
      ..source = 'BEGIN:VCARD\r\nFN:Daniel\r\nTEL:+6099999\r\nEND:VCARD\r\n';
    backends.addAll([first, second]);
    publish('AA:BB');
    await synced();
    publish('CC:DD');
    await synced();
    expect(state().contacts.single.name, 'Daniel');
    final reconnect = TestObexBackend();
    backends.add(reconnect);
    publish('AA:BB');
    await synced();
    expect(state().contacts.single.name, 'Aisha');
    expect(reconnect.contactPulls, 0);
    expect((await store.load('AA:BB'))?.address, 'AA:BB');
    expect((await store.load('CC:DD'))?.contacts.single.name, 'Daniel');
  });

  test(
    'cached contacts appear while a previous session is still opening',
    () async {
      final first = TestObexBackend()..openGate = Completer<void>();
      backends.add(first);
      publish('AA:BB');
      await waitUntil(() => first.opens == 1);
      final second = TestObexBackend()
        ..source = 'BEGIN:VCARD\r\nFN:Daniel\r\nTEL:+6099999\r\nEND:VCARD\r\n';
      await store.save(
        'CC:DD',
        second.source,
        revision: jsonEncode(['db', '1', '1']),
      );
      publish('CC:DD', pending: true);
      await waitUntil(() => state().contacts.isNotEmpty);
      expect(state().contacts.single.name, 'Daniel');
      expect(opened.length, 1);
      first.openGate!.complete();
      await waitUntil(() => first.closed);
      backends.add(second);
      publish('CC:DD');
      await synced();
      expect(second.contactPulls, 0);
    },
  );

  test(
    'a missing transfer object is not accepted as a successful download',
    () async {
      final backend = TestObexBackend();
      backends.add(backend);
      publish('AA:BB');
      await synced();
      backend.version = '2';
      backend.missingTransfer = true;
      backend.source = backend.source.replaceAll('Aisha', 'Daniel');
      await container.read(phoneDataProvider.notifier).refreshContacts();
      expect(state().contacts.single.name, 'Aisha');
      expect((await store.load('AA:BB'))?.contacts.single.name, 'Aisha');
    },
  );

  test(
    'alphabetic search does not match every contact through an empty number',
    () async {
      await store.save('AA:BB', TestObexBackend().source);
      publish('AA:BB', pending: true);
      await waitUntil(() => state().contacts.isNotEmpty);
      expect(
        await container.read(phoneDataProvider.notifier).searchContacts('Bob'),
        isEmpty,
      );
      expect(
        (await container
                .read(phoneDataProvider.notifier)
                .searchContacts('aish'))
            .single
            .name,
        'Aisha',
      );
    },
  );
}
