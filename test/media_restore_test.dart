import 'package:flutter_ics_homescreen/data/data_providers/bluetooth_media_notifier.dart';
import 'package:flutter_ics_homescreen/presentation/screens/media/media_nav_notifier.dart';
import 'package:flutter_ics_homescreen/presentation/screens/media/media_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestBluetoothMediaNotifier extends BluetoothMediaNotifier {
  @override
  BluetoothMediaState build() => const BluetoothMediaState(
    loading: false,
    available: true,
    connected: true,
    title: 'Test song',
    artist: 'Test artist',
  );
}

class _BluetoothTabNotifier extends MediaSourceTabNotifier {
  @override
  MediaSourceTab build() => MediaSourceTab.bluetooth;
}

void main() {
  testWidgets('Bluetooth media player fits the automotive landscape viewport', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 720);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bluetoothMediaProvider.overrideWith(_TestBluetoothMediaNotifier.new),
          mediaSourceTabProvider.overrideWith(_BluetoothTabNotifier.new),
        ],
        child: const MaterialApp(home: Scaffold(body: MediaPlayer())),
      ),
    );
    await tester.pump();
    expect(find.text('Bluetooth'), findsWidgets);
    expect(find.text('Test song'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
