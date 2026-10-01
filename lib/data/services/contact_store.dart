import 'dart:convert';
import 'dart:io';

import 'package:flutter_ics_homescreen/data/models/phone_models.dart';
import 'package:flutter_ics_homescreen/data/services/phone_parsers.dart';

class ContactStore {
  ContactStore(this.file);

  final File file;

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

  Future<(String, List<PhoneContact>)?> load() async {
    if (!await file.exists()) return null;
    final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final address = data['address'] as String;
    final source = data['vcard'] as String;
    final contacts = parseVCardContacts(source)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return (address, contacts);
  }

  Future<void> save(String address, String source) async {
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
        jsonEncode({'address': address, 'vcard': source}),
        flush: true);
    await temporary.rename(file.path);
  }
}
