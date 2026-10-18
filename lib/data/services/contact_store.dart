import 'dart:convert';
import 'dart:io';

import 'package:flutter_ics_homescreen/data/models/phone_models.dart';
import 'package:flutter_ics_homescreen/data/services/phone_parsers.dart';

void validatePhonebook(String source) {
  if (source.trim().isEmpty) return;
  final cards = RegExp(r'BEGIN:VCARD[\s\S]*?END:VCARD', caseSensitive: false);
  if (source.replaceAll(cards, '').trim().isNotEmpty) {
    throw const FormatException('Received an incomplete phonebook');
  }
}

class CachedPhonebook {
  CachedPhonebook({
    required this.address,
    required this.source,
    this.revision,
    this.listing,
  });

  final String address;
  final String source;
  final String? revision;
  final String? listing;

  List<PhoneContact> get contacts =>
      parseVCardContacts(source)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}

class ContactStore {
  ContactStore(this.file);

  final File file;
  Future<void> _writes = Future.value();

  static ContactStore? forCurrentUser() {
    final home = Platform.environment['HOME'];
    final dataHome = Platform.environment['XDG_DATA_HOME'];
    final root = dataHome != null && dataHome.isNotEmpty
        ? dataHome
        : home != null && home.isNotEmpty
        ? '$home/.local/share'
        : null;
    if (root == null) return null;
    return ContactStore(File('$root/flutter-ics-homescreen/contacts.json'));
  }

  static String _key(String address) =>
      address.replaceAll(':', '').toLowerCase();

  Future<Map<String, dynamic>> _read() async {
    if (!await file.exists()) return {};
    try {
      final data =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      // Preserve the single-phone cache written by earlier releases.
      if (data['address'] is String && data['vcard'] is String) {
        final key = _key(data['address'] as String);
        return {
          'phones': {key: data},
        };
      }
      return data;
    } on FormatException {
      return {};
    } on TypeError {
      return {};
    }
  }

  Future<CachedPhonebook?> load(String address) async {
    await _writes;
    final data = await _read();
    final key = _key(address);
    final phones = data['phones'];
    if (phones is! Map) return null;
    final entry = phones[key];
    if (entry is! Map ||
        entry['address'] is! String ||
        entry['vcard'] is! String) {
      return null;
    }
    if (_key(entry['address'] as String) != key) return null;
    validatePhonebook(entry['vcard'] as String);
    return CachedPhonebook(
      address: entry['address'] as String,
      source: entry['vcard'] as String,
      revision: entry['revision'] as String?,
      listing: entry['listing'] as String?,
    );
  }

  Future<void> save(
    String address,
    String source, {
    String? revision,
    String? listing,
  }) {
    // A phone switch can finish a previous disk write while the next one starts.
    final write = _writes.then((_) async {
      validatePhonebook(source);
      final data = await _read();
      final phones = data['phones'] is Map
          ? Map<String, dynamic>.from(data['phones'] as Map)
          : <String, dynamic>{};
      final key = _key(address);
      phones[key] = {
        'address': address,
        'vcard': source,
        'revision': revision,
        'listing': listing,
      };
      await file.parent.create(recursive: true);
      await _chmod('700', file.parent.path);
      final temporary = File('${file.path}.tmp');
      await temporary.create();
      await _chmod('600', temporary.path);
      await temporary.writeAsString(
        jsonEncode({'version': 2, 'phones': phones}),
        flush: true,
      );
      await temporary.rename(file.path);
    });
    _writes = write.then((_) {}, onError: (Object _, StackTrace __) {});
    return write;
  }

  Future<void> _chmod(String mode, String path) async {
    final result = await Process.run('chmod', [mode, path]);
    if (result.exitCode != 0) {
      throw FileSystemException('Cannot protect contact cache', path);
    }
  }
}
