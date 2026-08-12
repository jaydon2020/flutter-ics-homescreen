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

  test('maps BlueZ repeat and shuffle modes', () {
    expect(bluetoothMediaModeEnabled('off'), isFalse);
    expect(bluetoothMediaModeEnabled(''), isFalse);
    expect(bluetoothMediaModeEnabled('singletrack'), isTrue);
    expect(bluetoothMediaModeEnabled('alltracks'), isTrue);
  });

  test('converts BlueZ transport volume to the shared volume bar range', () {
    expect(bluetoothVolumePercent(0), 0);
    expect(bluetoothVolumePercent(127), 100);
    expect(bluetoothVolumeValue(0), 0);
    expect(bluetoothVolumeValue(100), 127);
  });

  test('recognizes A2DP transports only', () {
    expect(bluetoothA2dpUuid('0000110a-0000-1000-8000-00805f9b34fb'), isTrue);
    expect(bluetoothA2dpUuid('0000110b-0000-1000-8000-00805f9b34fb'), isTrue);
    expect(bluetoothA2dpUuid('0000111f-0000-1000-8000-00805f9b34fb'), isFalse);
  });
}
