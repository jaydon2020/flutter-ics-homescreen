import 'dart:convert';
import 'dart:io';

import 'package:flutter_ics_homescreen/data/services/contact_store.dart';
import 'package:flutter_test/flutter_test.dart';

const _first =
    'BEGIN:VCARD\r\nFN:Aisha Rahman\r\nTEL:+60123456789\r\nEND:VCARD\r\n';
const _second =
    'BEGIN:VCARD\r\nFN:Daniel Tan\r\nTEL:+60176543210\r\nEND:VCARD\r\n';

void main() {
  late Directory directory;
  late File file;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('contacts-test-');
    file = File('${directory.path}/data/contacts.json');
  });
  tearDown(() => directory.delete(recursive: true));

  test(
    'keeps separate phonebooks across restart and serializes writes',
    () async {
      final store = ContactStore(file);
      await Future.wait([
        store.save('AA:BB', _first, revision: 'r1', listing: 'list1'),
        store.save('CC:DD', _second),
      ]);
      final restarted = ContactStore(file);
      final first = await restarted.load('aa:bb');
      expect(first?.contacts.single.name, 'Aisha Rahman');
      expect(first?.revision, 'r1');
      expect(first?.listing, 'list1');
      expect(
        (await restarted.load('CC:DD'))?.contacts.single.name,
        'Daniel Tan',
      );
      expect((await restarted.load())?.address, 'CC:DD');
      expect(await restarted.load('another-phone'), isNull);
      expect((await file.stat()).mode & 0x1ff, 0x180); // 0600
      expect((await file.parent.stat()).mode & 0x1ff, 0x1c0); // 0700
    },
  );

  test('migrates the old single-phone cache without losing it', () async {
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({'address': 'phone-a', 'vcard': _first}),
    );
    final store = ContactStore(file);
    expect((await store.load('phone-a'))?.contacts.single.name, 'Aisha Rahman');
    await store.save('phone-b', _second);
    expect(
      (await ContactStore(file).load('phone-a'))?.contacts.single.name,
      'Aisha Rahman',
    );
    expect((await ContactStore(file).load())?.address, 'phone-b');
  });

  test(
    'a rejected phonebook preserves the old file and does not poison later writes',
    () async {
      final store = ContactStore(file);
      await store.save('phone-a', _first);
      await expectLater(
        store.save('phone-a', 'BEGIN:VCARD'),
        throwsFormatException,
      );
      expect(
        (await store.load('phone-a'))?.contacts.single.name,
        'Aisha Rahman',
      );
      await store.save('phone-a', _second);
      expect((await store.load('phone-a'))?.contacts.single.name, 'Daniel Tan');
    },
  );

  test('a corrupt cache can be replaced by a successful sync', () async {
    await file.parent.create(recursive: true);
    await file.writeAsString('{broken');
    final store = ContactStore(file);
    expect(await store.load(), isNull);
    await store.save('phone-a', _first);
    expect((await store.load('phone-a'))?.contacts.single.name, 'Aisha Rahman');
  });
}
