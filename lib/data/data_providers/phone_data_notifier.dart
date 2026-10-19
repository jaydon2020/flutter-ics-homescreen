import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bluez_obex_native/bluez_obex_native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_ics_homescreen/data/data_providers/bluetooth_notifier.dart';
import 'package:flutter_ics_homescreen/data/models/phone_models.dart';
import 'package:flutter_ics_homescreen/data/services/contact_store.dart';
import 'package:flutter_ics_homescreen/data/services/obex_backend.dart';
import 'package:flutter_ics_homescreen/data/services/phone_parsers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final obexBackendFactoryProvider = Provider<ObexBackend Function()>(
  (ref) => NativeObexBackend.new,
);

final contactStoreProvider = Provider<ContactStore?>(
  (ref) => ContactStore.forCurrentUser(),
);

class PhoneDataNotifier extends Notifier<PhoneDataState> {
  ObexBackend? _backend;
  Directory? _temporaryDirectory;
  StreamSubscription<BlueZObexEvent>? _eventSubscription;
  int _generation = 0;
  bool _disposed = false;
  int? _refreshingMessages;
  String? _requestedAddress;
  bool _requestSession = false;
  CachedPhonebook? _cachedPhonebook;
  Future<void> _lifecycle = Future.value();
  Future<void> _pbap = Future.value();
  final _transferSnapshots = <String, BlueZObexTransferProps>{};

  bool _isCurrent(int generation, [ObexBackend? backend]) =>
      !_disposed &&
      generation == _generation &&
      (backend == null || identical(backend, _backend));

  @override
  PhoneDataState build() {
    ref.onDispose(() {
      _disposed = true;
      ++_generation;
      unawaited(_lifecycle.then((_) => _disposeNative()));
    });
    ref.listen(bluetoothProvider, (previous, next) => _syncBluetooth(next));
    Future.microtask(() {
      if (!_disposed) _syncBluetooth(ref.read(bluetoothProvider));
    });
    return const PhoneDataState();
  }

  Future<void> _loadCachedContacts(int generation, String address) async {
    if (!_isCurrent(generation)) return;
    try {
      final cached = await ref.read(contactStoreProvider)?.load(address);
      if (!_isCurrent(generation)) return;
      _cachedPhonebook = cached;
      state = state.copyWith(
        contacts: cached?.contacts ?? const [],
        contactsAddress: address,
      );
    } catch (error) {
      // A damaged cache should not prevent a fresh phonebook transfer.
      if (_isCurrent(generation)) {
        _cachedPhonebook = null;
        state = state.copyWith(contacts: const [], contactsAddress: address);
      }
      debugPrint('Could not load cached contacts: $error');
    }
  }

  void _syncBluetooth(BluetoothState bluetooth) {
    if (_disposed) return;
    final pending = bluetooth.operation == BluetoothOperation.connecting
        ? bluetooth.busyAddress
        : null;
    final device = bluetooth.devices
        .where(
          (device) => pending != null
              ? device.address == pending
              : device.connected && bluetoothDeviceIsSupported(device),
        )
        .firstOrNull;
    final address = pending ?? device?.address;
    // Pairing establishes a temporary link which BlueZ then resets. Load the
    // cache now, but open PBAP/MAP only once that connection sequence finishes.
    final openSession = pending == null && device != null;
    if (address == _requestedAddress && openSession == _requestSession) return;
    if (address == null) {
      unawaited(_disconnect());
    } else {
      unawaited(
        _connect(
          address,
          device == null ? address : bluetoothDeviceName(device),
          openSession: openSession,
        ),
      );
    }
  }

  Future<void> retry() async {
    final bluetooth = ref.read(bluetoothProvider);
    final connected = bluetooth.devices
        .where(
          (device) => device.connected && bluetoothDeviceIsSupported(device),
        )
        .firstOrNull;
    if (connected == null) {
      _syncBluetooth(bluetooth);
      return;
    }
    await _connect(
      connected.address,
      bluetoothDeviceName(connected),
      forceContacts: true,
    );
  }

  Future<void> _connect(
    String address,
    String name, {
    bool openSession = true,
    bool forceContacts = false,
  }) async {
    final generation = ++_generation;
    _transferSnapshots.clear();
    _requestedAddress = address;
    _requestSession = openSession;
    state = PhoneDataState(
      status: PhoneConnectionStatus.connecting,
      deviceAddress: address,
      deviceName: name,
      contacts: state.contactsAddress == address ? state.contacts : const [],
      contactsAddress: address,
      busy: true,
    );
    final cachedContacts = _loadCachedContacts(generation, address);
    final task = _lifecycle.then((_) async {
      await _disposeNative();
      if (!_isCurrent(generation)) return;
      await cachedContacts;
      if (!_isCurrent(generation) || !openSession) return;
      try {
        final backend = ref.read(obexBackendFactoryProvider)();
        _backend = backend;
        _temporaryDirectory = await Directory.systemTemp.createTemp(
          'agl-phone-',
        );
        if (!_isCurrent(generation, backend)) return;
        await backend.open(address).timeout(const Duration(seconds: 15));
        if (!_isCurrent(generation, backend)) return;
        _eventSubscription = backend.events.listen(
          (event) {
            if (!_isCurrent(generation, backend)) return;
            final payload = event.payload;
            if (payload is BlueZObexTransferProps) {
              _recordTransfer(payload);
            } else if (event.type == BlueZObexEventType.message ||
                event.type == BlueZObexEventType.messageAccess) {
              unawaited(_refreshForNativeEvent());
            }
          },
          onError: (Object error) {
            if (_isCurrent(generation, backend)) _setError(error);
          },
          onDone: () {
            if (_isCurrent(generation, backend)) {
              unawaited(_handleServiceLoss());
            }
          },
        );
        state = state.copyWith(
          status: PhoneConnectionStatus.ready,
          busy: false,
          clearError: true,
        );
      } catch (_) {
        await _disposeNative();
        rethrow;
      }
    });
    _lifecycle = task.then((_) {}, onError: (Object _, StackTrace __) {});
    try {
      await task;
      if (!_isCurrent(generation) || !openSession) return;
      await refreshContacts(force: forceContacts);
      if (!_isCurrent(generation)) return;
      await refreshRecents();
      if (!_isCurrent(generation)) return;
      await refreshConversations();
    } catch (error) {
      if (!_isCurrent(generation)) return;
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
    _transferSnapshots.clear();
    _requestedAddress = null;
    _requestSession = false;
    state = const PhoneDataState();
    final task = _lifecycle.then((_) => _disposeNative());
    _lifecycle = task.then((_) {}, onError: (Object _, StackTrace __) {});
    await task;
  }

  Future<void> _handleServiceLoss() async {
    await _disconnect();
    if (_disposed || _requestedAddress != null) return;
    state = state.copyWith(
      status: PhoneConnectionStatus.error,
      error: 'Bluetooth data service disconnected',
    );
  }

  Future<void> _disposeNative() async {
    final subscription = _eventSubscription;
    final backend = _backend;
    final directory = _temporaryDirectory;
    _eventSubscription = null;
    _backend = null;
    _temporaryDirectory = null;
    await subscription?.cancel();
    // Removing our sessions cancels their transfers. Never cancel the global
    // ObjectManager transfer list: it includes other applications' transfers.
    try {
      await backend?.close();
    } catch (error) {
      debugPrint('Could not close phone data session: $error');
    }
    if (directory != null && await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<void> _queuePhonebook(Future<void> Function() operation) {
    final task = _pbap.then((_) => operation());
    _pbap = task.then((_) {}, onError: (Object _, StackTrace __) {});
    return task;
  }

  Future<void> refreshContacts({bool force = false}) {
    final backend = _backend;
    final directory = _temporaryDirectory;
    final address = state.deviceAddress;
    final generation = _generation;
    if (backend == null || directory == null || address == null) {
      return Future.value();
    }
    return _queuePhonebook(() async {
      if (!_isCurrent(generation, backend)) return;
      try {
        await backend.selectPhonebook('int', 'pb');
        String? revision;
        try {
          await backend.updatePhonebookVersion();
          final props = await backend.phonebookProperties();
          if (props.databaseIdentifier.isNotEmpty &&
              props.primaryCounter.isNotEmpty &&
              props.secondaryCounter.isNotEmpty) {
            revision = jsonEncode([
              props.databaseIdentifier,
              props.primaryCounter,
              props.secondaryCounter,
            ]);
          }
        } catch (_) {} // PBAP version counters are optional.
        final cached = _cachedPhonebook;
        String? listing;
        if (revision == null || cached?.revision == null) {
          try {
            final size = await backend.phonebookSize();
            final entries = await backend.listPhonebook(
              filters: const {'Order': 'indexed', 'MaxCount': 65535},
            );
            if (entries.length == size) {
              final rows = entries.map((e) => [e.vcard, e.name]).toList()
                ..sort((a, b) => a[0].compareTo(b[0]));
              listing = jsonEncode(rows);
            }
          } catch (_) {} // An inconclusive check requires a full transfer.
        }
        if (!_isCurrent(generation, backend)) return;
        // shortcut: Listings omit numbers/photos. Without version counters,
        // edits to those fields require the explicit Refresh contacts action.
        final unchanged =
            cached != null &&
            cached.address.replaceAll(':', '').toLowerCase() ==
                address.replaceAll(':', '').toLowerCase() &&
            (revision != null
                ? revision == cached.revision
                : listing != null && listing == cached.listing);
        if (!force && unchanged) {
          state = state.copyWith(
            pbapAvailable: true,
            clearError: state.error?.startsWith('Contacts ') ?? false,
          );
          await _saveContacts(cached, generation, backend);
          return;
        }
        final target = '${directory.path}/contacts.vcf';
        final file = File(target);
        if (await file.exists()) await file.delete();
        if (!_isCurrent(generation, backend)) return;
        final transfer = await backend.pullAllPhonebook(
          target,
          filters: const {
            'Format': 'vcard30',
            'Fields': ['FN', 'N', 'TEL', 'UID', 'PHOTO'],
          },
        );
        await _waitForTransfer(
          transfer,
          backend: backend,
          generation: generation,
        );
        final source = await file.readAsString();
        validatePhonebook(source);
        if (source.trim().isEmpty && await backend.phonebookSize() != 0) {
          throw const FormatException('Received an incomplete phonebook');
        }
        if (!_isCurrent(generation, backend)) return;
        final updated = CachedPhonebook(
          address: address,
          source: source,
          revision: revision,
          listing: listing,
        );
        state = state.copyWith(
          contacts: updated.contacts,
          contactsAddress: address,
          pbapAvailable: true,
          clearError: state.error?.startsWith('Contacts ') ?? false,
        );
        _cachedPhonebook = updated;
        await _saveContacts(updated, generation, backend);
      } catch (error) {
        if (!_isCurrent(generation, backend)) return;
        state = state.copyWith(
          pbapAvailable: false,
          error: 'Contacts unavailable: ${_friendlyError(error)}',
        );
      }
    });
  }

  Future<void> _saveContacts(
    CachedPhonebook phonebook,
    int generation,
    ObexBackend backend,
  ) async {
    try {
      final store = ref.read(contactStoreProvider);
      if (store == null) {
        throw StateError('No contact storage directory is configured');
      }
      await store.save(
        phonebook.address,
        phonebook.source,
        revision: phonebook.revision,
        listing: phonebook.listing,
      );
    } catch (error) {
      if (_isCurrent(generation, backend)) {
        _setError('Contacts loaded but could not be saved: $error');
      }
    }
  }

  Future<List<PhoneContact>> searchContacts(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return state.contacts;
    final number = normalizePhoneNumber(query);
    return state.contacts
        .where(
          (contact) =>
              contact.name.toLowerCase().contains(normalized) ||
              (number.isNotEmpty &&
                  contact.numbers.any(
                    (value) => normalizePhoneNumber(value).contains(number),
                  )),
        )
        .toList();
  }

  Future<void> refreshRecents() {
    final backend = _backend;
    final directory = _temporaryDirectory;
    final generation = _generation;
    if (backend == null || directory == null) return Future.value();
    return _queuePhonebook(() async {
      if (!_isCurrent(generation, backend)) return;
      try {
        List<RecentCall> recents;
        try {
          recents = await _pullRecents(
            backend,
            generation,
            'cch',
            '${directory.path}/combined.vcf',
          );
        } catch (_) {
          final lists = <List<RecentCall>>[];
          for (final item in const [
            ('ich', 'incoming.vcf'),
            ('och', 'outgoing.vcf'),
            ('mch', 'missed.vcf'),
          ]) {
            lists.add(
              await _pullRecents(
                backend,
                generation,
                item.$1,
                '${directory.path}/${item.$2}',
              ),
            );
          }
          recents = lists.expand((items) => items).toList();
        }
        if (!_isCurrent(generation, backend)) return;
        final unique = <String, RecentCall>{
          for (final item in recents) item.id: item,
        };
        final sorted = unique.values.toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        state = state.copyWith(
          recents: sorted,
          clearError:
              state.error?.startsWith('Call history unavailable:') ?? false,
        );
      } catch (error) {
        if (!_isCurrent(generation, backend)) return;
        state = state.copyWith(
          error: 'Call history unavailable: ${_friendlyError(error)}',
        );
      }
    });
  }

  Future<List<RecentCall>> _pullRecents(
    ObexBackend backend,
    int generation,
    String phonebook,
    String target,
  ) async {
    if (!_isCurrent(generation, backend)) {
      throw StateError('Phone disconnected');
    }
    await backend.selectPhonebook('int', phonebook);
    final transfer = await backend.pullAllPhonebook(
      target,
      filters: const {'Format': 'vcard30'},
    );
    await _waitForTransfer(transfer, backend: backend, generation: generation);
    return parseVCardRecents(await File(target).readAsString());
  }

  Future<void> refreshConversations({bool silent = false}) async {
    final backend = _backend;
    final generation = _generation;
    if (backend == null || _refreshingMessages == generation) return;
    _refreshingMessages = generation;
    if (!silent) state = state.copyWith(busy: true);
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
      if (!_isCurrent(generation, backend)) return;
      final messages =
          results.expand((items) => items).map(_messageFromProps).toList()
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      state = state.copyWith(
        messages: messages,
        conversations: _groupConversations(messages, state.contacts),
        mapAvailable: true,
        busy: false,
        clearError: state.error?.startsWith('Messages unavailable:') ?? false,
      );
    } catch (error) {
      if (!_isCurrent(generation, backend)) return;
      state = state.copyWith(
        mapAvailable: false,
        busy: false,
        error: 'Messages unavailable: ${_friendlyError(error)}',
      );
    } finally {
      if (_refreshingMessages == generation) _refreshingMessages = null;
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
    final generation = _generation;
    for (final message in conversation.messages.where(
      (item) => item.body == null,
    )) {
      if (!_isCurrent(generation)) return;
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
    final generation = _generation;
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
      await _waitForTransfer(
        transfer,
        backend: backend,
        generation: generation,
      );
      if (!_isCurrent(generation, backend)) return;
      await refreshConversations(silent: true);
      if (!_isCurrent(generation, backend)) return;
      state = state.copyWith(busy: false);
    } catch (error) {
      if (!_isCurrent(generation, backend)) return;
      state = state.copyWith(
        busy: false,
        error: 'Message not sent: ${_friendlyError(error)}',
      );
      rethrow;
    }
  }

  Future<void> markRead(String messageId, bool read) async {
    final backend = _backend;
    final generation = _generation;
    if (backend == null) return;
    await backend.setMessageRead(messageId, read);
    if (!_isCurrent(generation, backend)) return;
    _replaceMessage(messageId, (message) => message.copyWith(read: read));
  }

  Future<void> deleteMessage(String messageId) async {
    final backend = _backend;
    final generation = _generation;
    if (backend == null) return;
    await backend.setMessageDeleted(messageId, true);
    if (!_isCurrent(generation, backend)) return;
    _replaceMessage(messageId, (message) => message.copyWith(deleted: true));
  }

  Future<void> restoreMessage(String messageId) async {
    final backend = _backend;
    final generation = _generation;
    if (backend == null) return;
    await backend.setMessageDeleted(messageId, false);
    if (!_isCurrent(generation, backend)) return;
    _replaceMessage(messageId, (message) => message.copyWith(deleted: false));
  }

  Future<String?> downloadAttachment(String messageId) async {
    final directory = _temporaryDirectory;
    final backend = _backend;
    final generation = _generation;
    if (directory == null || backend == null) return null;
    final target = '${directory.path}/attachment-${messageId.hashCode}.bmsg';
    final transfer = await backend.getMessage(
      messageId,
      target,
      attachment: true,
    );
    await _waitForTransfer(transfer, backend: backend, generation: generation);
    if (!_isCurrent(generation, backend)) return null;
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
    final backend = _backend;
    final directory = _temporaryDirectory;
    final generation = _generation;
    if (backend == null || directory == null) return;
    final target = '${directory.path}/message-${message.id.hashCode}.bmsg';
    try {
      final transfer = await backend.getMessage(
        message.id,
        target,
        attachment: false,
      );
      await _waitForTransfer(
        transfer,
        backend: backend,
        generation: generation,
      );
      if (!_isCurrent(generation, backend)) return;
      final source = await File(target).readAsString();
      if (!_isCurrent(generation, backend)) return;
      final parsed = parseBMessage(metadata: message, source: source);
      _replaceMessage(message.id, (_) => parsed);
      if (!message.read) await markRead(message.id, true);
    } catch (error) {
      if (!_isCurrent(generation, backend)) return;
      _setError('Message could not be opened: ${_friendlyError(error)}');
    }
  }

  bool _transferFinished(BlueZObexTransferProps? props) =>
      props?.status.toLowerCase() == 'complete' ||
      props?.status.toLowerCase() == 'error';

  void _recordTransfer(BlueZObexTransferProps props) {
    // A late polling response must not overwrite a terminal event snapshot.
    if (!_transferFinished(_transferSnapshots[props.objectPath])) {
      _transferSnapshots[props.objectPath] = props;
    }
  }

  Future<void> _waitForTransfer(
    BlueZObexTransferResult transfer, {
    required ObexBackend backend,
    required int generation,
  }) async {
    if (!_isCurrent(generation, backend)) {
      throw StateError('Phone disconnected');
    }
    final id = transfer.transferPath;
    final initial = {
      for (final property in transfer.properties)
        property.key.toLowerCase(): property.value,
    };
    if (initial.containsKey('status')) {
      _recordTransfer(
        BlueZObexTransferProps(
          objectPath: id,
          status: initial['status']!,
          size: int.tryParse(initial['size'] ?? '') ?? 0,
          transferred: int.tryParse(initial['transferred'] ?? '') ?? 0,
        ),
      );
    }
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(deadline)) {
      if (!_isCurrent(generation, backend)) {
        throw StateError('Phone disconnected');
      }
      var props = _transferSnapshots[id];
      if (!_transferFinished(props)) {
        try {
          final polled = await backend.transferProperties(id);
          if (!_isCurrent(generation, backend)) {
            throw StateError('Phone disconnected');
          }
          _recordTransfer(polled);
          props = _transferSnapshots[id];
        } catch (error) {
          if (!error.toString().contains('UnknownObject')) rethrow;
          // Native events queued while GetAll was in flight can confirm that
          // BlueZ completed or failed the transfer before removing its object.
          if (!_transferFinished(_transferSnapshots[id])) {
            await Future<void>.delayed(const Duration(milliseconds: 200));
          }
          props = _transferSnapshots[id];
          if (!_transferFinished(props)) rethrow;
        }
      }
      if (!_isCurrent(generation, backend)) {
        throw StateError('Phone disconnected');
      }
      final status = props!.status.toLowerCase();
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
