import 'dart:async';
import 'dart:io';

import 'package:bluez_obex_native/bluez_obex_native.dart';
import 'package:flutter_ics_homescreen/data/data_providers/bluetooth_notifier.dart';
import 'package:flutter_ics_homescreen/data/models/phone_models.dart';
import 'package:flutter_ics_homescreen/data/services/obex_backend.dart';
import 'package:flutter_ics_homescreen/data/services/phone_parsers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final obexBackendFactoryProvider = Provider<ObexBackend Function()>(
  (ref) => NativeObexBackend.new,
);

class PhoneDataNotifier extends Notifier<PhoneDataState> {
  ObexBackend? _backend;
  Directory? _temporaryDirectory;
  StreamSubscription<BlueZObexEvent>? _eventSubscription;
  int _generation = 0;
  bool _refreshingMessages = false;

  @override
  PhoneDataState build() {
    ref.onDispose(() => unawaited(_disposeNative(clearState: false)));
    ref.listen(bluetoothProvider, (previous, next) => _syncBluetooth(next));
    Future.microtask(() => _syncBluetooth(ref.read(bluetoothProvider)));
    return const PhoneDataState();
  }

  void _syncBluetooth(BluetoothState bluetooth) {
    final connected = bluetooth.devices
        .where(
          (device) => device.connected && bluetoothDeviceIsSupported(device),
        )
        .firstOrNull;
    final oldAddress = state.deviceAddress;
    if (connected == null && oldAddress != null) {
      unawaited(_disconnect());
    } else if (connected != null && connected.address != oldAddress) {
      unawaited(_connect(connected.address, bluetoothDeviceName(connected)));
    }
  }

  Future<void> retry() async {
    final connected = ref
        .read(bluetoothProvider)
        .devices
        .where(
          (device) => device.connected && bluetoothDeviceIsSupported(device),
        )
        .firstOrNull;
    if (connected == null) {
      await _disconnect();
      return;
    }
    await _connect(connected.address, bluetoothDeviceName(connected));
  }

  Future<void> _connect(String address, String name) async {
    final generation = ++_generation;
    await _disposeNative(clearState: false);
    state = PhoneDataState(
      status: PhoneConnectionStatus.connecting,
      deviceAddress: address,
      deviceName: name,
      busy: true,
    );
    final backend = ref.read(obexBackendFactoryProvider)();
    _backend = backend;
    try {
      _temporaryDirectory = await Directory.systemTemp.createTemp('agl-phone-');
      await backend.open(address).timeout(const Duration(seconds: 15));
      if (generation != _generation) return;
      _eventSubscription = backend.events.listen(
        (_) => unawaited(_refreshForNativeEvent()),
        onError: (Object error) => _setError(error),
        onDone: () => unawaited(_handleServiceLoss()),
      );
      state = state.copyWith(
        status: PhoneConnectionStatus.ready,
        busy: false,
        clearError: true,
      );
      // Contacts and call history share one PBAP session. Each refresh changes
      // its selected phonebook, so they must never run concurrently.
      await refreshContacts();
      await refreshRecents();
      await refreshConversations();
    } catch (error) {
      if (generation != _generation) return;
      state = state.copyWith(
        status: PhoneConnectionStatus.error,
        busy: false,
        error: _friendlyError(error),
      );
    }
  }

  Future<void> _refreshForNativeEvent() async {
    if (state.status != PhoneConnectionStatus.ready || state.busy) return;
    await refreshConversations(silent: true);
  }

  Future<void> _disconnect() async {
    ++_generation;
    await _disposeNative(clearState: true);
  }

  Future<void> _handleServiceLoss() async {
    ++_generation;
    await _disposeNative(clearState: true);
    state = state.copyWith(
      status: PhoneConnectionStatus.error,
      error: 'Bluetooth data service disconnected',
    );
  }

  Future<void> _disposeNative({required bool clearState}) async {
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    final backend = _backend;
    _backend = null;
    if (backend != null) {
      try {
        final objects = await backend.managedObjects();
        for (final transfer in objects.transfers) {
          try {
            await backend.cancelTransfer(transfer);
          } catch (_) {}
        }
      } catch (_) {}
      await backend.close();
    }
    final directory = _temporaryDirectory;
    _temporaryDirectory = null;
    if (directory != null && await directory.exists()) {
      await directory.delete(recursive: true);
    }
    if (clearState) state = const PhoneDataState();
  }

  Future<void> refreshContacts() async {
    final backend = _backend;
    final directory = _temporaryDirectory;
    if (backend == null || directory == null) return;
    try {
      await backend.selectPhonebook('int', 'pb');
      await backend.phonebookProperties();
      await backend.phonebookSize();
      await backend.phonebookFilterFields();
      final target = '${directory.path}/contacts.vcf';
      final transfer = await backend.pullAllPhonebook(
        target,
        filters: const {
          'Format': 'vcard30',
          'Fields': ['FN', 'N', 'TEL', 'UID', 'PHOTO'],
        },
      );
      await _waitForTransfer(transfer.transferPath);
      final contacts = parseVCardContacts(await File(target).readAsString());
      contacts.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      state = state.copyWith(
        contacts: contacts,
        pbapAvailable: true,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        pbapAvailable: false,
        error: 'Contacts unavailable: ${_friendlyError(error)}',
      );
    }
  }

  Future<List<PhoneContact>> searchContacts(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return state.contacts;
    final local = state.contacts
        .where(
          (contact) =>
              contact.name.toLowerCase().contains(normalized) ||
              contact.numbers.any(
                (number) => normalizePhoneNumber(
                  number,
                ).contains(normalizePhoneNumber(query)),
              ),
        )
        .toList();
    final backend = _backend;
    if (backend == null || !state.pbapAvailable) return local;
    try {
      await backend.searchPhonebook(
        'name',
        query,
        filters: const {'MaxCount': 50},
      );
    } catch (_) {}
    return local;
  }

  Future<void> refreshRecents() async {
    final backend = _backend;
    final directory = _temporaryDirectory;
    if (backend == null || directory == null) return;
    try {
      List<RecentCall> recents;
      try {
        recents = await _pullRecents('cch', '${directory.path}/combined.vcf');
      } catch (_) {
        final lists = <List<RecentCall>>[];
        for (final item in const [
          ('ich', 'incoming.vcf'),
          ('och', 'outgoing.vcf'),
          ('mch', 'missed.vcf'),
        ]) {
          lists.add(
            await _pullRecents(item.$1, '${directory.path}/${item.$2}'),
          );
        }
        recents = lists.expand((items) => items).toList();
      }
      final unique = <String, RecentCall>{
        for (final item in recents) item.id: item,
      };
      final sorted = unique.values.toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      state = state.copyWith(
        recents: sorted,
        pbapAvailable: true,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        error: 'Call history unavailable: ${_friendlyError(error)}',
      );
    }
  }

  Future<List<RecentCall>> _pullRecents(String phonebook, String target) async {
    final backend = _backend!;
    await backend.selectPhonebook('int', phonebook);
    final transfer = await backend.pullAllPhonebook(
      target,
      filters: const {'Format': 'vcard30'},
    );
    await _waitForTransfer(transfer.transferPath);
    return parseVCardRecents(await File(target).readAsString());
  }

  Future<void> refreshConversations({bool silent = false}) async {
    final backend = _backend;
    if (backend == null || _refreshingMessages) return;
    _refreshingMessages = true;
    if (!silent) state = state.copyWith(busy: true, clearError: true);
    try {
      await backend.messageAccessProperties();
      await backend.messageFilterFields();
      // UpdateInbox is an optional MAP operation. Several phones return
      // org.bluez.obex.Error.Failed: Not Implemented but still support listing
      // and downloading messages, so a rejected refresh must not disable MAP.
      try {
        await backend.updateInbox();
      } catch (_) {}
      final results = [
        await backend.listMessages('telecom/msg/inbox'),
        await backend.listMessages('telecom/msg/sent'),
      ];
      final messages =
          results.expand((items) => items).map(_messageFromProps).toList()
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      state = state.copyWith(
        messages: messages,
        conversations: _groupConversations(messages, state.contacts),
        mapAvailable: true,
        busy: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        mapAvailable: false,
        busy: false,
        error: 'Messages unavailable: ${_friendlyError(error)}',
      );
    } finally {
      _refreshingMessages = false;
    }
  }

  Future<void> openConversation(String id) async {
    state = state.copyWith(
      selectedConversationId: id,
      clearComposeAddress: true,
    );
    final conversation = state.conversations
        .where((item) => item.id == id)
        .firstOrNull;
    if (conversation == null) return;
    for (final message in conversation.messages.where(
      (item) => item.body == null,
    )) {
      await _downloadMessageBody(message);
    }
  }

  void closeConversation() => state = state.copyWith(
    clearSelectedConversation: true,
    clearComposeAddress: true,
  );

  void composeTo(String address) => state = state.copyWith(
    composeAddress: address,
    clearSelectedConversation: true,
  );

  Future<void> sendMessage(String address, String body) async {
    final backend = _backend;
    final directory = _temporaryDirectory;
    if (backend == null || directory == null || body.trim().isEmpty) return;
    state = state.copyWith(busy: true, clearError: true);
    try {
      final source = File(
        '${directory.path}/outgoing-${DateTime.now().microsecondsSinceEpoch}.bmsg',
      );
      await source.writeAsString(
        buildBMessage(recipient: address, body: body.trim()),
        flush: true,
      );
      final transfer = await backend.pushMessage(
        source.path,
        'telecom/msg/outbox',
        args: const {'Transparent': false, 'Retry': true},
      );
      await _waitForTransfer(transfer.transferPath);
      await refreshConversations(silent: true);
      state = state.copyWith(busy: false, clearError: true);
    } catch (error) {
      state = state.copyWith(
        busy: false,
        error: 'Message not sent: ${_friendlyError(error)}',
      );
      rethrow;
    }
  }

  Future<void> markRead(String messageId, bool read) async {
    await _backend?.setMessageRead(messageId, read);
    _replaceMessage(messageId, (message) => message.copyWith(read: read));
  }

  Future<void> deleteMessage(String messageId) async {
    await _backend?.setMessageDeleted(messageId, true);
    _replaceMessage(messageId, (message) => message.copyWith(deleted: true));
  }

  Future<void> restoreMessage(String messageId) async {
    await _backend?.setMessageDeleted(messageId, false);
    _replaceMessage(messageId, (message) => message.copyWith(deleted: false));
  }

  Future<String?> downloadAttachment(String messageId) async {
    final directory = _temporaryDirectory;
    final backend = _backend;
    if (directory == null || backend == null) return null;
    final target = '${directory.path}/attachment-${messageId.hashCode}.bmsg';
    final transfer = await backend.getMessage(
      messageId,
      target,
      attachment: true,
    );
    await _waitForTransfer(transfer.transferPath);
    _replaceMessage(
      messageId,
      (message) => message.copyWith(attachmentPath: target),
    );
    return target;
  }

  Future<void> pauseTransfer(String id) => _backend!.suspendTransfer(id);
  Future<void> resumeTransfer(String id) => _backend!.resumeTransfer(id);
  Future<void> cancelTransfer(String id) => _backend!.cancelTransfer(id);

  Future<void> _downloadMessageBody(PhoneMessage message) async {
    final backend = _backend!;
    final target =
        '${_temporaryDirectory!.path}/message-${message.id.hashCode}.bmsg';
    try {
      final transfer = await backend.getMessage(
        message.id,
        target,
        attachment: false,
      );
      await _waitForTransfer(transfer.transferPath);
      final parsed = parseBMessage(
        metadata: message,
        source: await File(target).readAsString(),
      );
      _replaceMessage(message.id, (_) => parsed);
      if (!message.read) await markRead(message.id, true);
    } catch (error) {
      _setError('Message could not be opened: ${_friendlyError(error)}');
    }
  }

  Future<void> _waitForTransfer(String id) async {
    final backend = _backend!;
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(deadline)) {
      BlueZObexTransferProps props;
      try {
        props = await backend.transferProperties(id);
      } catch (error) {
        // BlueZ can remove a short-lived Transfer1 object immediately after a
        // successful local transfer, before the next poll reaches it.
        if (_friendlyError(error).contains('UnknownObject')) return;
        rethrow;
      }
      final status = props.status.toLowerCase();
      final transferStatus = switch (status) {
        'complete' => PhoneTransferStatus.complete,
        'suspended' => PhoneTransferStatus.suspended,
        'error' => PhoneTransferStatus.failed,
        _ => PhoneTransferStatus.active,
      };
      state = state.copyWith(
        transfers: {
          ...state.transfers,
          id: PhoneTransferProgress(
            id: id,
            status: transferStatus,
            transferred: props.transferred,
            total: props.size,
          ),
        },
      );
      if (status == 'complete') return;
      if (status == 'error') throw StateError('OBEX transfer failed');
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    await backend.cancelTransfer(id);
    throw TimeoutException('OBEX transfer timed out');
  }

  void _replaceMessage(String id, PhoneMessage Function(PhoneMessage) update) {
    final messages = [
      for (final item in state.messages)
        if (item.id == id) update(item) else item,
    ];
    state = state.copyWith(
      messages: messages,
      conversations: _groupConversations(messages, state.contacts),
    );
  }

  void _setError(Object error) {
    state = state.copyWith(error: _friendlyError(error), busy: false);
  }
}

PhoneMessage _messageFromProps(BlueZObexMessageProps props) {
  final outgoing = props.sent || props.direction.toLowerCase().contains('out');
  final address = outgoing ? props.recipientAddress : props.senderAddress;
  final key = props.conversationId != 0
      ? 'conversation:${props.conversationId}'
      : 'address:${normalizePhoneNumber(address)}';
  return PhoneMessage(
    id: props.objectPath,
    conversationKey: key,
    sender: props.sender,
    senderAddress: props.senderAddress,
    recipient: props.recipient,
    recipientAddress: props.recipientAddress,
    timestamp: _parseMessageDate(props.timestamp),
    direction: outgoing
        ? PhoneMessageDirection.outgoing
        : PhoneMessageDirection.incoming,
    read: props.read,
    deleted: props.deleted,
    priority: props.priority,
    attachmentSize: props.attachmentSize,
    subject: props.subject,
  );
}

DateTime _parseMessageDate(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed != null) return parsed;
  final match = RegExp(
    r'^(\d{4})(\d{2})(\d{2})T?(\d{2})(\d{2})(\d{2})',
  ).firstMatch(value);
  if (match == null) return DateTime.fromMillisecondsSinceEpoch(0);
  return DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
    int.parse(match.group(4)!),
    int.parse(match.group(5)!),
    int.parse(match.group(6)!),
  );
}

List<Conversation> _groupConversations(
  List<PhoneMessage> messages,
  List<PhoneContact> contacts,
) {
  final groups = <String, List<PhoneMessage>>{};
  for (final message in messages.where((item) => !item.deleted)) {
    groups.putIfAbsent(message.conversationKey, () => []).add(message);
  }
  final result = groups.entries.map((entry) {
    final items = entry.value
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final latest = items.first;
    final address = latest.direction == PhoneMessageDirection.outgoing
        ? latest.recipientAddress
        : latest.senderAddress;
    final normalized = normalizePhoneNumber(address);
    final contact = contacts
        .where(
          (item) => item.numbers.any(
            (number) => normalizePhoneNumber(number) == normalized,
          ),
        )
        .firstOrNull;
    final nativeName = latest.direction == PhoneMessageDirection.outgoing
        ? latest.recipient
        : latest.sender;
    return Conversation(
      id: entry.key,
      title: contact?.name ?? (nativeName.isNotEmpty ? nativeName : address),
      address: address,
      messages: items,
    );
  }).toList();
  result.sort(
    (a, b) => (b.latest?.timestamp ?? DateTime(0)).compareTo(
      a.latest?.timestamp ?? DateTime(0),
    ),
  );
  return result;
}

String _friendlyError(Object error) =>
    error.toString().replaceFirst(RegExp(r'^\w+(?:Exception|Error):\s*'), '');

final phoneDataProvider = NotifierProvider<PhoneDataNotifier, PhoneDataState>(
  PhoneDataNotifier.new,
);
