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
    // cache now, but open PBAP only once that connection sequence finishes.
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
            if (payload is BlueZObexTransferProps) _recordTransfer(payload);
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
    } catch (error) {
      if (!_isCurrent(generation)) return;
      state = state.copyWith(
        status: PhoneConnectionStatus.error,
        busy: false,
        error: _friendlyError(error),
      );
    }
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

  void _setError(Object error) {
    state = state.copyWith(error: _friendlyError(error), busy: false);
  }
}

String _friendlyError(Object error) =>
    error.toString().replaceFirst(RegExp(r'^\w+(?:Exception|Error):\s*'), '');

final phoneDataProvider = NotifierProvider<PhoneDataNotifier, PhoneDataState>(
  PhoneDataNotifier.new,
);
