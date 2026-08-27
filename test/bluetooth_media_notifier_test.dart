import 'package:bluez_media_native/bluez_media_native.dart';
import 'package:flutter_ics_homescreen/data/data_providers/bluetooth_media_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('orders the current item first and newer items before older items', () {
    const items = [
      BluetoothMediaItem(
        objectPath: '/item/1',
        name: 'Oldest',
        artist: '',
        album: '',
        playable: true,
      ),
      BluetoothMediaItem(
        objectPath: '/item/2',
        name: 'Playing',
        artist: '',
        album: '',
        playable: true,
      ),
      BluetoothMediaItem(
        objectPath: '/item/3',
        name: 'Newest',
        artist: '',
        album: '',
        playable: true,
      ),
    ];

    final ordered = orderBluetoothMediaItems(
      items,
      currentItemPath: '/item/2',
      currentTitle: '',
    );

    expect(ordered.map((item) => item.name), ['Playing', 'Newest', 'Oldest']);
  });

  test('uses demo media until the native backend is available', () {
    const unavailable = BluetoothMediaState();

    expect(unavailable.available, isFalse);
    expect(unavailable.copyWith(available: true).available, isTrue);
    expect(unavailable.copyWith(coverArtLoading: true).coverArtLoading, isTrue);
  });

  test('maps BlueZ AVRCP track metadata', () {
    final metadata = parseBluetoothTrack(const [
      BlueZMediaProperty(key: 'Title', value: 'Blue Train'),
      BlueZMediaProperty(key: 'Artist', value: 'John Coltrane'),
      BlueZMediaProperty(key: 'Album', value: 'Blue Train'),
      BlueZMediaProperty(key: 'Duration', value: '64500'),
      BlueZMediaProperty(key: 'Item', value: '/player0/item1'),
    ]);

    expect(metadata.title, 'Blue Train');
    expect(metadata.artist, 'John Coltrane');
    expect(metadata.album, 'Blue Train');
    expect(metadata.duration, const Duration(milliseconds: 64500));
    expect(metadata.itemPath, '/player0/item1');
  });

  test('maps BlueZ repeat and shuffle modes', () {
    expect(bluetoothMediaModeEnabled('off'), isFalse);
    expect(bluetoothMediaModeEnabled(''), isFalse);
    expect(bluetoothMediaModeEnabled('singletrack'), isTrue);
    expect(bluetoothMediaModeEnabled('alltracks'), isTrue);
  });

  test('recognizes A2DP transports only', () {
    expect(bluetoothA2dpUuid('0000110a-0000-1000-8000-00805f9b34fb'), isTrue);
    expect(bluetoothA2dpUuid('0000110b-0000-1000-8000-00805f9b34fb'), isTrue);
    expect(bluetoothA2dpUuid('0000111f-0000-1000-8000-00805f9b34fb'), isFalse);
  });
}
