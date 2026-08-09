import 'package:bluez_media_native/bluez_media_native.dart';
import 'package:flutter_ics_homescreen/data/data_providers/bluetooth_media_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps BlueZ AVRCP track metadata', () {
    final metadata = parseBluetoothTrack(const [
      BlueZMediaProperty(key: 'Title', value: 'Blue Train'),
      BlueZMediaProperty(key: 'Artist', value: 'John Coltrane'),
      BlueZMediaProperty(key: 'Album', value: 'Blue Train'),
      BlueZMediaProperty(key: 'Duration', value: '64500'),
    ]);

    expect(metadata.title, 'Blue Train');
    expect(metadata.artist, 'John Coltrane');
    expect(metadata.album, 'Blue Train');
    expect(metadata.duration, const Duration(milliseconds: 64500));
  });
}
