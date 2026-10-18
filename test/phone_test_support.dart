import 'dart:async';
import 'dart:io';

import 'package:bluez_native/bluez_native.dart';
import 'package:bluez_obex_native/bluez_obex_native.dart' hide BlueZDevice;
import 'package:flutter_ics_homescreen/data/data_providers/bluetooth_notifier.dart';
import 'package:flutter_ics_homescreen/data/services/obex_backend.dart';

class TestBluetoothNotifier extends BluetoothNotifier {
  @override
  BluetoothState build() => const BluetoothState();
  void publish(BluetoothState next) => state = next;
}

BlueZDevice phone(String address, {bool connected = true}) =>
    _Phone(address, connected);

class _Phone implements BlueZDevice {
  _Phone(this.address, this.connected);
  @override
  final String address;
  @override
  final bool connected;
  @override
  String get name => address;
  @override
  String get alias => address;
  @override
  bool get paired => true;
  @override
  bool get trusted => true;
  @override
  int get deviceClass => 0x020c;
  @override
  List<BlueZUUID> get uuids => const [];
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Unexpected Bluetooth operation: ${invocation.memberName}',
  );
}

Future<void> waitUntil(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('Condition not reached');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

class TestObexBackend implements ObexBackend {
  String source =
      'BEGIN:VCARD\r\nUID:a\r\nFN:Aisha\r\nTEL:+6012345\r\nEND:VCARD\r\n';
  String version = '1';
  bool hasVersion = true;
  bool failListing = false;
  bool failPull = false;
  bool missingTransfer = false;
  bool closed = false;
  bool failMap = false;
  bool failOpen = false;
  int contactPulls = 0;
  int listCalls = 0;
  int opens = 0;
  String selected = '';
  Completer<void>? pullGate;
  Completer<void>? transferGate;
  Completer<void>? openGate;
  final selectedBooks = <String>[];
  List<BlueZObexPhonebookEntry> entries = [
    const BlueZObexPhonebookEntry(vcard: '1.vcf', name: 'Aisha'),
  ];
  final controller = StreamController<BlueZObexEvent>.broadcast();

  @override
  Stream<BlueZObexEvent> get events => controller.stream;
  @override
  Future<void> open(String address) async {
    opens++;
    if (openGate != null) await openGate!.future;
    if (failOpen) throw StateError('Permission denied');
  }

  @override
  Future<void> close() async {
    closed = true;
    await controller.close();
  }

  @override
  Future<void> selectPhonebook(String location, String phonebook) async {
    selected = phonebook;
    selectedBooks.add(phonebook);
  }

  @override
  Future<void> updatePhonebookVersion() async {
    if (!hasVersion) throw UnsupportedError('NotSupported');
  }

  @override
  Future<BlueZObexPhonebookProps> phonebookProperties() async =>
      BlueZObexPhonebookProps(
        objectPath: '/pbap',
        databaseIdentifier: 'db',
        primaryCounter: version,
        secondaryCounter: '1',
      );
  @override
  Future<int> phonebookSize() async => entries.length;
  @override
  Future<List<BlueZObexPhonebookEntry>> listPhonebook({
    Map<String, Object?> filters = const {},
  }) async {
    listCalls++;
    if (failListing) throw StateError('Forbidden');
    return entries;
  }

  @override
  Future<BlueZObexTransferResult> pullAllPhonebook(
    String targetFile, {
    Map<String, Object?> filters = const {},
  }) async {
    final book = selected;
    if (book == 'pb') {
      contactPulls++;
      final content = source;
      if (pullGate != null) await pullGate!.future;
      if (failPull) throw StateError('Transfer failed');
      await File(targetFile).writeAsString(content);
    } else {
      await File(targetFile).writeAsString('');
    }
    return BlueZObexTransferResult(transferPath: '/transfer/$book');
  }

  @override
  Future<BlueZObexTransferProps> transferProperties(String path) async {
    if (path == '/transfer/pb' && transferGate != null) {
      await transferGate!.future;
    }
    if (missingTransfer) throw StateError('UnknownObject');
    return BlueZObexTransferProps(objectPath: path, status: 'complete');
  }

  @override
  Future<BlueZObexMessageAccessProps> messageAccessProperties() async {
    if (failMap) throw StateError('MAP unavailable');
    return const BlueZObexMessageAccessProps(objectPath: '/map');
  }

  @override
  Future<List<String>> messageFilterFields() async => [];
  @override
  Future<void> updateInbox() async {}
  @override
  Future<List<BlueZObexMessageProps>> listMessages(
    String folder, {
    Map<String, Object?> filters = const {},
  }) async => [];

  // Any unexpected native operation fails the test instead of accessing D-Bus.
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Unexpected OBEX operation: ${invocation.memberName}',
  );
}
