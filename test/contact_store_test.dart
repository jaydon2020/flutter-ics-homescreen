import 'dart:io';

import 'package:flutter_ics_homescreen/data/services/contact_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('restores the last transferred phonebook after a new store is created',
      () async {
    final directory = await Directory.systemTemp.createTemp('contacts-test-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/data/contacts.json');
    const first =
        'BEGIN:VCARD\r\nFN:Aisha Rahman\r\nTEL:+60123456789\r\nEND:VCARD\r\n';
    const second =
        'BEGIN:VCARD\r\nFN:Daniel Tan\r\nTEL:+60176543210\r\nEND:VCARD\r\n';

    await ContactStore(file).save('phone-a', first);
    var cached = await ContactStore(file).load();
    expect(cached?.$1, 'phone-a');
    expect(cached?.$2.single.name, 'Aisha Rahman');

    await ContactStore(file).save('phone-b', second);
    cached = await ContactStore(file).load();
    expect(cached?.$1, 'phone-b');
    expect(cached?.$2.single.name, 'Daniel Tan');
  });
}
