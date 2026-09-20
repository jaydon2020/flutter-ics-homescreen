import 'package:bluez_obex_native/bluez_obex_native.dart';

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
    final client = await BlueZObexClient.connect();
    _client = client;
    Object? pbapError;
    try {
      _pbapSession = await client.createSession(address, target: 'pbap');
    } catch (error) {
      pbapError = error;
    }
    try {
      _mapSession = await client.createSession(address, target: 'map');
    } catch (mapError) {
      if (_pbapSession == null) {
        await client.dispose();
        _client = null;
        throw StateError('PBAP failed: $pbapError; MAP failed: $mapError');
      }
    }
  }

  @override
  Future<void> close() async {
    final pbap = _pbapSession;
    final map = _mapSession;
    final client = _client;
    _pbapSession = null;
    _mapSession = null;
    _client = null;
    try {
      await pbap?.remove();
    } catch (_) {}
    try {
      await map?.remove();
    } catch (_) {}
    await client?.dispose();
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
  Future<void> setMessageFolder(String folder) =>
      _messageAccess.setFolder(folder);
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
  }) async {
    final messages = await _messageAccess.listMessages(
      folder,
      filters: filters,
    );
    return [for (final message in messages) await message.properties()];
  }

  @override
  Future<void> updateInbox() => _messageAccess.updateInbox();
  @override
  Future<BlueZObexTransferResult> pushMessage(
    String sourceFile,
    String folder, {
    Map<String, Object?> args = const {},
  }) => _messageAccess.pushMessage(sourceFile, folder, args: args);
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
