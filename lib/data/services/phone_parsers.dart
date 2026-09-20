import 'dart:convert';
import 'dart:typed_data';

import '../models/phone_models.dart';

List<PhoneContact> parseVCardContacts(String source) => _vCardBlocks(
  source,
).map(_contactFromVCard).whereType<PhoneContact>().toList();

List<RecentCall> parseVCardRecents(String source) =>
    _vCardBlocks(source).map(_recentFromVCard).whereType<RecentCall>().toList();

PhoneMessage parseBMessage({
  required PhoneMessage metadata,
  required String source,
  String? attachmentPath,
}) {
  final bodyMatch = RegExp(
    r'BEGIN:MSG\r?\n([\s\S]*?)\r?\nEND:MSG',
    caseSensitive: false,
  ).firstMatch(source);
  final body = bodyMatch?.group(1)?.replaceAll('\r\n', '\n').trim();
  return metadata.copyWith(
    body: body ?? metadata.subject,
    attachmentPath: attachmentPath,
  );
}

String buildBMessage({required String recipient, required String body}) {
  final safeBody = body.replaceAll('\r', '').replaceAll('\n', '\r\n');
  return 'BEGIN:BMSG\r\n'
      'VERSION:1.0\r\n'
      'STATUS:UNREAD\r\n'
      'TYPE:SMS_GSM\r\n'
      'BEGIN:BENV\r\n'
      'BEGIN:VCARD\r\n'
      'VERSION:2.1\r\n'
      'TEL:$recipient\r\n'
      'END:VCARD\r\n'
      'BEGIN:BBODY\r\n'
      'CHARSET:UTF-8\r\n'
      'LENGTH:${utf8.encode(safeBody).length}\r\n'
      'BEGIN:MSG\r\n'
      '$safeBody\r\n'
      'END:MSG\r\n'
      'END:BBODY\r\n'
      'END:BENV\r\n'
      'END:BMSG\r\n';
}

List<String> _vCardBlocks(String source) {
  final unfolded = source.replaceAll(RegExp(r'\r?\n[ \t]'), '');
  return RegExp(
    r'BEGIN:VCARD[\s\S]*?END:VCARD',
    caseSensitive: false,
  ).allMatches(unfolded).map((match) => match.group(0)!).toList();
}

PhoneContact? _contactFromVCard(String card) {
  final values = _vCardValues(card);
  final numbers = values
      .where((entry) => entry.key == 'TEL')
      .map((entry) => entry.value)
      .where((value) => normalizePhoneNumber(value).isNotEmpty)
      .toSet()
      .toList();
  if (numbers.isEmpty) return null;
  final name =
      _first(values, 'FN') ?? _formatStructuredName(_first(values, 'N'));
  final id = _first(values, 'UID') ?? '${name ?? ''}:${numbers.first}';
  return PhoneContact(
    id: id,
    name: (name == null || name.trim().isEmpty) ? numbers.first : name.trim(),
    numbers: numbers,
    photo: _photo(values),
  );
}

RecentCall? _recentFromVCard(String card) {
  final values = _vCardValues(card);
  final number = values
      .where((entry) => entry.key == 'TEL')
      .map((entry) => entry.value)
      .firstOrNull;
  final callLine = card
      .split(RegExp(r'\r?\n'))
      .where((line) => line.toUpperCase().startsWith('X-IRMC-CALL-DATETIME'))
      .firstOrNull;
  if (number == null || callLine == null) return null;
  final upper = callLine.toUpperCase();
  final value = callLine.substring(callLine.indexOf(':') + 1).trim();
  final type = upper.contains('MISSED')
      ? RecentCallType.missed
      : upper.contains('DIALED') || upper.contains('OUTGOING')
      ? RecentCallType.outgoing
      : upper.contains('RECEIVED') || upper.contains('INCOMING')
      ? RecentCallType.incoming
      : RecentCallType.unknown;
  final timestamp =
      _parseBluetoothDate(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
  final name =
      _first(values, 'FN') ??
      _formatStructuredName(_first(values, 'N')) ??
      number;
  return RecentCall(
    id: '${normalizePhoneNumber(number)}:${timestamp.millisecondsSinceEpoch}:${type.name}',
    name: name,
    number: number,
    timestamp: timestamp,
    type: type,
  );
}

List<MapEntry<String, String>> _vCardValues(String card) {
  final result = <MapEntry<String, String>>[];
  for (final line in card.split(RegExp(r'\r?\n'))) {
    final colon = line.indexOf(':');
    if (colon <= 0) continue;
    final key = line.substring(0, colon).split(';').first.toUpperCase();
    final value = _unescapeVCard(line.substring(colon + 1));
    result.add(MapEntry(key, value));
  }
  return result;
}

String? _first(List<MapEntry<String, String>> values, String key) => values
    .where((entry) => entry.key == key)
    .map((entry) => entry.value)
    .firstOrNull;

String? _formatStructuredName(String? value) {
  if (value == null) return null;
  final parts = value.split(';');
  final ordered = [
    if (parts.length > 1) parts[1],
    if (parts.isNotEmpty) parts[0],
  ].where((part) => part.trim().isNotEmpty);
  final name = ordered.join(' ').trim();
  return name.isEmpty ? null : name;
}

Uint8List? _photo(List<MapEntry<String, String>> values) {
  final encoded = _first(values, 'PHOTO');
  if (encoded == null || encoded.isEmpty || encoded.startsWith('http')) {
    return null;
  }
  try {
    return base64Decode(encoded);
  } on FormatException {
    return null;
  }
}

String _unescapeVCard(String value) => value
    .replaceAll(r'\n', '\n')
    .replaceAll(r'\N', '\n')
    .replaceAll(r'\,', ',')
    .replaceAll(r'\;', ';')
    .replaceAll(r'\\', '\\');

DateTime? _parseBluetoothDate(String value) {
  final match = RegExp(
    r'^(\d{4})(\d{2})(\d{2})T?(\d{2})(\d{2})(\d{2})',
  ).firstMatch(value);
  if (match == null) return DateTime.tryParse(value);
  return DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
    int.parse(match.group(4)!),
    int.parse(match.group(5)!),
    int.parse(match.group(6)!),
  );
}
