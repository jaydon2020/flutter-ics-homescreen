import 'package:bluez_obex_native/bluez_obex_native.dart';
import 'package:dbus/dbus.dart';

/// Complete application-facing surface for BlueZ PBAP, MAP and transfers.
/// Tests replace this interface; production never falls back to sample data.
abstract interface class ObexBackend {
  Stream<BlueZObexEvent> get events;
  Future<void> open(String address);
  Future<void> close();
  Future<BlueZObexManagedObjects> managedObjects();

  Future<BlueZObexSessionProps> pbapSessionProperties();
  Future<String> pbapCapabilities();
  Future<BlueZObexPhonebookProps> phonebookProperties();
  Future<void> selectPhonebook(String location, String phonebook);
  Future<int> phonebookSize();
  Future<List<String>> phonebookFilterFields();
  Future<List<BlueZObexPhonebookEntry>> listPhonebook({
    Map<String, Object?> filters = const {},
  });
  Future<List<BlueZObexPhonebookEntry>> searchPhonebook(
    String field,
    String value, {
    Map<String, Object?> filters = const {},
  });
  Future<BlueZObexTransferResult> pullPhonebook(
    String vcard,
    String targetFile, {
    Map<String, Object?> filters = const {},
  });
  Future<BlueZObexTransferResult> pullAllPhonebook(
    String targetFile, {
    Map<String, Object?> filters = const {},
  });
  Future<void> updatePhonebookVersion();

  Future<BlueZObexSessionProps> mapSessionProperties();
  Future<String> mapCapabilities();
  Future<BlueZObexMessageAccessProps> messageAccessProperties();
  Future<void> setMessageFolder(String folder);
  Future<List<BlueZObexMessageFolder>> listMessageFolders({
    Map<String, Object?> filters = const {},
  });
  Future<List<String>> messageFilterFields();
  Future<List<BlueZObexMessageProps>> listMessages(
    String folder, {
    Map<String, Object?> filters = const {},
  });
  Future<void> updateInbox();
  Future<BlueZObexTransferResult> pushMessage(
    String sourceFile,
    String folder, {
    Map<String, Object?> args = const {},
  });
  Future<BlueZObexMessageProps> messageProperties(String path);
  Future<BlueZObexTransferResult> getMessage(
    String path,
    String targetFile, {
    bool attachment = true,
  });
  Future<void> setMessageRead(String path, bool read);
  Future<void> setMessageDeleted(String path, bool deleted);

  Future<BlueZObexTransferProps> transferProperties(String path);
  Future<void> cancelTransfer(String path);
  Future<void> suspendTransfer(String path);
  Future<void> resumeTransfer(String path);
}

class NativeObexBackend implements ObexBackend {
  BlueZObexClient? _client;
  BlueZObexSession? _pbapSession;
  BlueZObexSession? _mapSession;
  DBusClient? _sessionBus;
  String? _messageFolder;
  int _generation = 0;
  Future<void> _mapOperations = Future.value();

  BlueZObexClient get _connected =>
      _client ?? (throw StateError('OBEX is not connected'));
  BlueZObexPhonebook get _phonebook =>
      _pbapSession?.phonebook ?? (throw StateError('PBAP is unavailable'));
  BlueZObexMessageAccess get _messageAccess =>
      _mapSession?.messageAccess ?? (throw StateError('MAP is unavailable'));

  @override
  Stream<BlueZObexEvent> get events => _connected.events;

  @override
  Future<void> open(String address) async {
    await close();
    final generation = _generation;
    final client = await BlueZObexClient.connect();
    if (generation != _generation) {
      await client.dispose();
      throw StateError('Phone data connection was cancelled');
    }
    _client = client;
    _sessionBus = DBusClient.session();
    Object? pbapError;
    try {
      _pbapSession = await _createSession(client, generation, address, 'pbap');
    } catch (error) {
      if (generation != _generation) rethrow;
      pbapError = error;
    }
    try {
      _mapSession = await _createSession(client, generation, address, 'map');
    } catch (mapError) {
      if (generation != _generation) rethrow;
      if (_pbapSession == null) {
        await close();
        throw StateError('PBAP failed: $pbapError; MAP failed: $mapError');
      }
    }
  }

  Future<BlueZObexSession> _createSession(
    BlueZObexClient client,
    int generation,
    String address,
    String target,
  ) async {
    final session = await client.createSession(address, target: target);
    if (generation != _generation) {
      try {
        await session.remove();
      } catch (_) {}
      throw StateError('Phone data connection was cancelled');
    }
    return session;
  }

  @override
  Future<void> close() async {
    ++_generation;
    final pbap = _pbapSession;
    final map = _mapSession;
    final client = _client;
    final sessionBus = _sessionBus;
    _pbapSession = null;
    _mapSession = null;
    _client = null;
    _sessionBus = null;
    _messageFolder = null;
    try {
      await pbap?.remove();
    } catch (_) {}
    try {
      await map?.remove();
    } catch (_) {}
    await client?.dispose();
    await sessionBus?.close();
  }

  @override
  Future<BlueZObexManagedObjects> managedObjects() =>
      _connected.getManagedObjects();
  @override
  Future<BlueZObexSessionProps> pbapSessionProperties() =>
      _pbapSession!.properties();
  @override
  Future<String> pbapCapabilities() => _pbapSession!.capabilities();
  @override
  Future<BlueZObexPhonebookProps> phonebookProperties() =>
      _phonebook.properties();
  @override
  Future<void> selectPhonebook(String location, String phonebook) =>
      _phonebook.select(location, phonebook);
  @override
  Future<int> phonebookSize() => _phonebook.getSize();
  @override
  Future<List<String>> phonebookFilterFields() => _phonebook.listFilterFields();
  @override
  Future<List<BlueZObexPhonebookEntry>> listPhonebook({
    Map<String, Object?> filters = const {},
  }) => _phonebook.list(filters: filters);
  @override
  Future<List<BlueZObexPhonebookEntry>> searchPhonebook(
    String field,
    String value, {
    Map<String, Object?> filters = const {},
  }) => _phonebook.search(field, value, filters: filters);
  @override
  Future<BlueZObexTransferResult> pullPhonebook(
    String vcard,
    String targetFile, {
    Map<String, Object?> filters = const {},
  }) => _phonebook.pull(vcard, targetFile, filters: filters);
  @override
  Future<BlueZObexTransferResult> pullAllPhonebook(
    String targetFile, {
    Map<String, Object?> filters = const {},
  }) => _phonebook.pullAll(targetFile, filters: filters);
  @override
  Future<void> updatePhonebookVersion() => _phonebook.updateVersion();

  @override
  Future<BlueZObexSessionProps> mapSessionProperties() =>
      _mapSession!.properties();
  @override
  Future<String> mapCapabilities() => _mapSession!.capabilities();
  @override
  Future<BlueZObexMessageAccessProps> messageAccessProperties() =>
      _messageAccess.properties();
  @override
  Future<void> setMessageFolder(String folder) => _queueMap(() async {
    await _messageAccess.setFolder(folder);
    _messageFolder = folder;
  });

  @override
  Future<List<BlueZObexMessageFolder>> listMessageFolders({
    Map<String, Object?> filters = const {},
  }) => _messageAccess.listFolders(filters: filters);
  @override
  Future<List<String>> messageFilterFields() =>
      _messageAccess.listFilterFields();
  @override
  Future<List<BlueZObexMessageProps>> listMessages(
    String folder, {
    Map<String, Object?> filters = const {},
  }) => _withMessageFolder(
    folder,
    (child) => _listMessagesOverDBus(child, filters),
  );

  Future<T> _queueMap<T>(Future<T> Function() operation) {
    final generation = _generation;
    final task = _mapOperations.then((_) {
      if (generation != _generation) {
        throw StateError('Phone data connection was cancelled');
      }
      return operation();
    });
    _mapOperations = task.then((_) {}, onError: (Object _, StackTrace __) {});
    return task;
  }

  Future<T> _withMessageFolder<T>(
    String folder,
    Future<T> Function(String child) operation,
  ) => _queueMap(() async {
    final generation = _generation;
    final normalized = folder.replaceAll(RegExp(r'^/+|/+$'), '');
    final separator = normalized.lastIndexOf('/');
    final child = separator < 0
        ? normalized
        : normalized.substring(separator + 1);
    if (separator >= 0) {
      final parent = '/${normalized.substring(0, separator)}';
      if (parent != _messageFolder) {
        await _messageAccess.setFolder(parent);
        if (generation != _generation) {
          throw StateError('Phone data connection was cancelled');
        }
        _messageFolder = parent;
      }
    }
    return operation(child);
  });

  Future<List<BlueZObexMessageProps>> _listMessagesOverDBus(
    String folder,
    Map<String, Object?> filters,
  ) async {
    final bus = _sessionBus ?? (throw StateError('OBEX is not connected'));
    final session = _mapSession ?? (throw StateError('MAP is unavailable'));
    final object = DBusRemoteObject(
      bus,
      name: 'org.bluez.obex',
      path: DBusObjectPath(session.objectPath),
    );
    final response = await object.callMethod(
      'org.bluez.obex.MessageAccess1',
      'ListMessages',
      [DBusString(folder), _dbusFilters(filters)],
      replySignature: DBusSignature('a{oa{sv}}'),
    );
    final entries = (response.returnValues.single as DBusDict).children;
    return entries.entries.map((entry) {
      final values = (entry.value as DBusDict).mapStringVariant();
      T value<T>(String name, T fallback) {
        final native = values[name]?.toNative();
        return native is T ? native : fallback;
      }

      return BlueZObexMessageProps(
        objectPath: entry.key.asObjectPath().value,
        folder: value('Folder', ''),
        subject: value('Subject', ''),
        timestamp: value('Timestamp', ''),
        sender: value('Sender', ''),
        senderAddress: value('SenderAddress', ''),
        replyTo: value('ReplyTo', ''),
        recipient: value('Recipient', ''),
        recipientAddress: value('RecipientAddress', ''),
        type: value('Type', ''),
        size: value('Size', 0),
        text: value('Text', false),
        status: value('Status', ''),
        attachmentSize: value('AttachmentSize', 0),
        priority: value('Priority', false),
        read: value('Read', false),
        deleted: value('Deleted', false),
        sent: value('Sent', false),
        protected: value('Protected', false),
        deliveryStatus: value('DeliveryStatus', ''),
        conversationId: value('ConversationId', 0),
        conversationName: value('ConversationName', ''),
        direction: value('Direction', ''),
        attachmentMimeTypes: value('AttachmentMimeTypes', ''),
      );
    }).toList();
  }

  DBusDict _dbusFilters(Map<String, Object?> filters) =>
      DBusDict.stringVariant({
        for (final entry in filters.entries)
          if (_dbusValue(entry.key, entry.value) case final value?)
            entry.key: value,
      });

  DBusValue? _dbusValue(String name, Object? value) => switch (value) {
    bool value => DBusBoolean(value),
    int value when name == 'SubjectLength' && value >= 0 && value <= 0xff =>
      DBusByte(value),
    int value when value >= 0 && value <= 0xffff => DBusUint16(value),
    String value => DBusString(value),
    List<String> value => DBusArray.string(value),
    _ => null,
  };

  @override
  Future<void> updateInbox() => _messageAccess.updateInbox();
  @override
  Future<BlueZObexTransferResult> pushMessage(
    String sourceFile,
    String folder, {
    Map<String, Object?> args = const {},
  }) => _withMessageFolder(
    folder,
    (child) => _messageAccess.pushMessage(sourceFile, child, args: args),
  );
  @override
  Future<BlueZObexMessageProps> messageProperties(String path) =>
      _connected.message(path).properties();
  @override
  Future<BlueZObexTransferResult> getMessage(
    String path,
    String targetFile, {
    bool attachment = true,
  }) => _connected.message(path).get(targetFile, attachment: attachment);
  @override
  Future<void> setMessageRead(String path, bool read) =>
      _connected.message(path).setRead(read);
  @override
  Future<void> setMessageDeleted(String path, bool deleted) =>
      _connected.message(path).setDeleted(deleted);
  @override
  Future<BlueZObexTransferProps> transferProperties(String path) =>
      _connected.transfer(path).properties();
  @override
  Future<void> cancelTransfer(String path) =>
      _connected.transfer(path).cancel();
  @override
  Future<void> suspendTransfer(String path) =>
      _connected.transfer(path).suspend();
  @override
  Future<void> resumeTransfer(String path) =>
      _connected.transfer(path).resume();
}
