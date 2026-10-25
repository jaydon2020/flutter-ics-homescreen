import 'dart:convert';
import 'package:flutter_ics_homescreen/data/models/phone_models.dart';
import 'package:flutter_ics_homescreen/data/services/phone_parsers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final body in ['Hello', 'Café 🚗\nSecond line']) {
    test('bMessage LENGTH includes UTF-8 content and its frame: $body', () {
      final wire = buildBMessage(recipient: '+60123', body: body);
      final declared = int.parse(
        RegExp(r'LENGTH:(\d+)').firstMatch(wire)!.group(1)!,
      );
      final start = wire.indexOf('BEGIN:MSG\r\n');
      final end = wire.indexOf('END:BBODY');
      expect(declared, utf8.encode(wire.substring(start, end)).length);
      if (body == 'Hello') expect(declared, 27);
    });
  }
  test('normalizes international phone numbers', () {
    expect(normalizePhoneNumber('+60 (12) 345-6789'), '+60123456789');
    expect(normalizePhoneNumber('03 1234 5678'), '0312345678');
  });

  test('parses contacts with multiple numbers', () {
    const source =
        'BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Aisha Rahman\r\nUID:42\r\nTEL;TYPE=CELL:+60123456789\r\nTEL;TYPE=WORK:0312345678\r\nEND:VCARD\r\n';
    final contacts = parseVCardContacts(source);
    expect(contacts.single.name, 'Aisha Rahman');
    expect(contacts.single.numbers, ['+60123456789', '0312345678']);
  });

  test('parses Bluetooth call history metadata', () {
    const source =
        'BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Daniel Tan\r\nTEL:+60176543210\r\nX-IRMC-CALL-DATETIME;TYPE=MISSED:20260920T141500\r\nEND:VCARD\r\n';
    final call = parseVCardRecents(source).single;
    expect(call.type, RecentCallType.missed);
    expect(call.timestamp, DateTime(2026, 9, 20, 14, 15));
  });

  test('builds and parses a valid bMessage body', () {
    final metadata = PhoneMessage(
      id: '/message/1',
      conversationKey: 'address:+6012',
      sender: 'Aisha',
      senderAddress: '+6012',
      recipient: '',
      recipientAddress: '',
      timestamp: DateTime(2026),
      direction: PhoneMessageDirection.incoming,
      read: false,
      deleted: false,
      priority: false,
      attachmentSize: 0,
    );
    final encoded = buildBMessage(recipient: '+6012', body: 'Hello from MAP');
    expect(encoded, contains('BEGIN:BMSG'));
    expect(
      parseBMessage(metadata: metadata, source: encoded).body,
      'Hello from MAP',
    );
  });
}
