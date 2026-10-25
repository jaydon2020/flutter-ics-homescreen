import 'dart:async';
import 'dart:io';

import 'package:bluez_obex_native/bluez_obex_native.dart';
import 'package:flutter_ics_homescreen/data/data_providers/bluetooth_notifier.dart';
import 'package:flutter_ics_homescreen/data/data_providers/phone_data_notifier.dart';
import 'package:flutter_ics_homescreen/data/services/contact_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'phone_test_support.dart';

class _MessagesBackend extends TestObexBackend {
  Completer<void>? listGate;
  Completer<void>? sendGate;
  final sending = Completer<void>();
  int sends = 0;
  bool failSend = false;
  bool failRefresh = false;
  List<BlueZObexMessageProps> inbox = const [
    BlueZObexMessageProps(
      objectPath: '/map/message1',
      senderAddress: '+60123',
      subject: 'Preview',
      read: true,
    ),
  ];

  @override
  Future<List<BlueZObexMessageProps>> listMessages(
    String folder, {
    Map<String, Object?> filters = const {},
  }) async {
    if (listGate != null) await listGate!.future;
    if (failRefresh) throw StateError('Listing failed');
    return folder.endsWith('inbox') ? inbox : [];
  }

  @override
  Future<BlueZObexTransferResult> getMessage(
    String path,
    String targetFile, {
    bool attachment = true,
  }) async {
    await File(
      targetFile,
    ).writeAsString('BEGIN:MSG\r\nComplete message body\r\nEND:MSG\r\n');
    return BlueZObexTransferResult(
      transferPath: '/body/$targetFile',
      properties: const [BlueZObexProperty(key: 'Status', value: 'complete')],
    );
  }

  @override
  Future<BlueZObexTransferResult> pushMessage(
    String sourceFile,
    String folder, {
    Map<String, Object?> args = const {},
  }) async {
    sends++;
    if (!sending.isCompleted) sending.complete();
    if (sendGate != null) await sendGate!.future;
    if (failSend) throw StateError('Send rejected');
    return BlueZObexTransferResult(
      transferPath: '/send/$sends',
      properties: const [BlueZObexProperty(key: 'Status', value: 'complete')],
    );
  }
}

void main() {
  late ProviderContainer container;
  late _MessagesBackend backend;
  late Directory cache;
  final opened = <_MessagesBackend>[];
  setUp(() async {
    backend = _MessagesBackend();
    opened.clear();
    cache = await Directory.systemTemp.createTemp('map-flow-');
    container = ProviderContainer(
      overrides: [
        bluetoothProvider.overrideWith(TestBluetoothNotifier.new),
        obexBackendFactoryProvider.overrideWithValue(() {
          opened.add(backend);
          return backend;
        }),
        contactStoreProvider.overrideWithValue(
          ContactStore(File('${cache.path}/contacts.json')),
        ),
      ],
    );
    container.read(phoneDataProvider);
    (container.read(bluetoothProvider.notifier) as TestBluetoothNotifier)
        .publish(BluetoothState(devices: [phone('AA:BB')]));
    await waitUntil(() => container.read(phoneDataProvider).mapAvailable);
  });
  tearDown(() async {
    container.dispose();
    await waitUntil(() => opened.every((backend) => backend.closed));
    await cache.delete(recursive: true);
  });

  test(
    'refresh preserves downloaded bodies and attachments, and updates metadata',
    () async {
      final notifier = container.read(phoneDataProvider.notifier);
      await notifier.openConversation(
        container.read(phoneDataProvider).conversations.single.id,
      );
      final attachment = await notifier.downloadAttachment('/map/message1');
      backend.inbox = const [
        BlueZObexMessageProps(
          objectPath: '/map/message1',
          senderAddress: '+60123',
          subject: 'New preview',
          read: false,
        ),
      ];
      await notifier.refreshConversations();
      final message = container.read(phoneDataProvider).messages.single;
      expect(message.body, 'Complete message body');
      expect(message.attachmentPath, attachment);
      expect(message.subject, 'New preview');
      expect(message.read, isFalse);
    },
  );

  for (final failRefresh in [false, true]) {
    test(
      'overlapping refresh (failure=$failRefresh) cannot unlock or duplicate a send',
      () async {
        backend.listGate = Completer<void>();
        backend.sendGate = Completer<void>();
        backend.failRefresh = failRefresh;
        final notifier = container.read(phoneDataProvider.notifier);
        final refresh = notifier.refreshConversations(silent: true);
        final send = notifier.sendMessage('+60123', 'Test message');
        await backend.sending.future;
        backend.listGate!.complete();
        await refresh;
        expect(container.read(phoneDataProvider).busy, isTrue);
        await notifier.sendMessage('+60123', 'Duplicate');
        expect(backend.sends, 1);
        backend.failRefresh = false;
        backend.sendGate!.complete();
        await send;
        expect(container.read(phoneDataProvider).busy, isFalse);
      },
    );
  }

  test('send failure unlocks the controls and permits retry', () async {
    backend.failSend = true;
    final notifier = container.read(phoneDataProvider.notifier);
    await expectLater(notifier.sendMessage('+60123', 'Test'), throwsStateError);
    expect(container.read(phoneDataProvider).error, contains('Send rejected'));
    expect(container.read(phoneDataProvider).busy, isFalse);
    backend.failSend = false;
    await notifier.sendMessage('+60123', 'Retry');
    expect(backend.sends, 2);
    expect(container.read(phoneDataProvider).error, isNull);
  });

  test('different alphabetic and unknown SMS senders stay separate', () async {
    backend.inbox = const [
      BlueZObexMessageProps(objectPath: '/map/1', senderAddress: 'BANK01'),
      BlueZObexMessageProps(objectPath: '/map/2', senderAddress: 'SHOP01'),
      BlueZObexMessageProps(objectPath: '/map/3', senderAddress: '01'),
      BlueZObexMessageProps(objectPath: '/map/4'),
      BlueZObexMessageProps(objectPath: '/map/5'),
    ];
    await container.read(phoneDataProvider.notifier).refreshConversations();
    expect(container.read(phoneDataProvider).conversations, hasLength(5));
  });

  test(
    'phone switch clears bodies and ignores an old send completion',
    () async {
      final notifier = container.read(phoneDataProvider.notifier);
      await notifier.openConversation(
        container.read(phoneDataProvider).conversations.single.id,
      );
      final first = backend;
      first.sendGate = Completer<void>();
      final send = notifier.sendMessage('+60123', 'Old phone');
      await first.sending.future;
      backend = _MessagesBackend();
      (container.read(bluetoothProvider.notifier) as TestBluetoothNotifier)
          .publish(BluetoothState(devices: [phone('CC:DD')]));
      await waitUntil(
        () =>
            container.read(phoneDataProvider).deviceAddress == 'CC:DD' &&
            container.read(phoneDataProvider).mapAvailable,
      );
      first.sendGate!.complete();
      await send;
      expect(container.read(phoneDataProvider).messages.single.body, isNull);
      expect(container.read(phoneDataProvider).busy, isFalse);
      expect(backend.sends, 0);
      await notifier.sendMessage('+60456', 'New phone');
      expect(backend.sends, 1);
    },
  );
}
