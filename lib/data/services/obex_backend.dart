import 'package:bluez_obex_native/bluez_obex_native.dart';

abstract interface class ObexBackend {
  Stream<BlueZObexEvent> get events;
  Future<void> open(String address);
  Future<void> close();
  Future<BlueZObexPhonebookProps> phonebookProperties();
  Future<void> selectPhonebook(String location, String phonebook);
  Future<int> phonebookSize();
  Future<List<BlueZObexPhonebookEntry>> listPhonebook({
    Map<String, Object?> filters = const {},
  });
  Future<BlueZObexTransferResult> pullAllPhonebook(
    String targetFile, {
    Map<String, Object?> filters = const {},
  });
  Future<void> updatePhonebookVersion();
  Future<BlueZObexTransferProps> transferProperties(String path);
  Future<void> cancelTransfer(String path);
}

class NativeObexBackend implements ObexBackend {
  BlueZObexClient? _client;
  BlueZObexSession? _session;
  int _generation = 0;

  BlueZObexClient get _connected =>
      _client ?? (throw StateError('PBAP is not connected'));
  BlueZObexPhonebook get _phonebook =>
      _session?.phonebook ?? (throw StateError('PBAP is unavailable'));

  @override
  Stream<BlueZObexEvent> get events => _connected.events;

  @override
  Future<void> open(String address) async {
    await close();
    final generation = _generation;
    final client = await BlueZObexClient.connect();
    if (generation != _generation) {
      await client.dispose();
      throw StateError('PBAP connection was cancelled');
    }
    _client = client;
    try {
      final session = await client.createSession(address, target: 'pbap');
      if (generation != _generation) {
        await session.remove();
        throw StateError('PBAP connection was cancelled');
      }
      _session = session;
    } catch (_) {
      await close();
      rethrow;
    }
  }

  @override
  Future<void> close() async {
    ++_generation;
    final session = _session;
    final client = _client;
    _session = null;
    _client = null;
    try {
      await session?.remove();
    } catch (_) {}
    await client?.dispose();
  }

  @override
  Future<BlueZObexPhonebookProps> phonebookProperties() =>
      _phonebook.properties();

  @override
  Future<void> selectPhonebook(String location, String phonebook) =>
      _phonebook.select(location, phonebook);

  @override
  Future<int> phonebookSize() => _phonebook.getSize();

  @override
  Future<List<BlueZObexPhonebookEntry>> listPhonebook({
    Map<String, Object?> filters = const {},
  }) => _phonebook.list(filters: filters);

  @override
  Future<BlueZObexTransferResult> pullAllPhonebook(
    String targetFile, {
    Map<String, Object?> filters = const {},
  }) => _phonebook.pullAll(targetFile, filters: filters);

  @override
  Future<void> updatePhonebookVersion() => _phonebook.updateVersion();

  @override
  Future<BlueZObexTransferProps> transferProperties(String path) =>
      _connected.transfer(path).properties();

  @override
  Future<void> cancelTransfer(String path) =>
      _connected.transfer(path).cancel();
}
