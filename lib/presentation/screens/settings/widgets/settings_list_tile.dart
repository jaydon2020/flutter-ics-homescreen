import 'package:flutter_ics_homescreen/export.dart';

class SettingsTile extends ConsumerWidget {
  final IconData icon;
  final String title;
  final bool hasSwitch;
  final VoidCallback voidCallback;
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.hasSwitch,
    required this.voidCallback,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wifiConnected = title == 'Wifi'
        ? ref.watch(signalsProvider.select((signal) => signal.isWifiConnected))
        : false;
    final nativeBluetoothAvailable = title == 'Bluetooth'
        ? ref.watch(nativeBluetoothAvailableProvider)
        : null;
    final demoBluetoothOn =
        title == 'Bluetooth' && nativeBluetoothAvailable == false
            ? ref.watch(
                signalsProvider.select(
                  (signal) => signal.isBluetoothConnected,
                ),
              )
            : false;
    final bluetoothState =
        title == 'Bluetooth' && nativeBluetoothAvailable != false
            ? ref.watch(
                bluetoothProvider.select(
                  (state) => (
                    powered: state.powered,
                    changingPower: state.changingPower
                  ),
                ),
              )
            : null;
    var isSwitchOn = true;
    if (title == 'Bluetooth') {
      isSwitchOn = nativeBluetoothAvailable == false
          ? demoBluetoothOn
          : bluetoothState?.powered ?? false;
    } else if (title == 'Wifi') {
      isSwitchOn = wifiConnected;
    }
    return Column(
      children: [
        GestureDetector(
          onTap: isSwitchOn ? voidCallback : null,
          child: Container(
            height: 130,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: isSwitchOn ? [0.3, 1] : [0.8, 1],
                colors: isSwitchOn
                    ? <Color>[Colors.black, Colors.black12]
                    : <Color>[
                        const Color.fromARGB(50, 0, 0, 0),
                        Colors.transparent,
                      ],
              ),
            ),
            child: Card(
              color: Colors.transparent,
              elevation: 5,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 24,
                ),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      color: AGLDemoColors.periwinkleColor,
                      size: 48,
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontSize: 40),
                      ),
                    ),
                    hasSwitch
                        ? Container(
                            width: 126,
                            height: 80,
                            decoration: const ShapeDecoration(
                              color: AGLDemoColors.gradientBackgroundDarkColor,
                              shape: StadiumBorder(
                                side: BorderSide(
                                  color: Color(0xFF5477D4),
                                  width: 4,
                                ),
                              ),
                            ),
                            child: FittedBox(
                              fit: BoxFit.fill,
                              child: Switch(
                                value: isSwitchOn,
                                onChanged: bluetoothState?.changingPower == true
                                    ? null
                                    : (bool value) {
                                        switch (title) {
                                          case 'Bluetooth':
                                            if (nativeBluetoothAvailable ==
                                                false) {
                                              ref
                                                  .read(
                                                    signalsProvider.notifier,
                                                  )
                                                  .setBluetoothConnected(value);
                                            } else {
                                              ref
                                                  .read(
                                                    bluetoothProvider.notifier,
                                                  )
                                                  .setPowered(value);
                                            }
                                            break;
                                          case 'Wifi':
                                            ref
                                                .read(signalsProvider.notifier)
                                                .toggleWifi();
                                            break;
                                          default:
                                        }
                                      },
                                inactiveTrackColor: Colors.transparent,
                                activeTrackColor: Colors.transparent,
                                thumbColor: WidgetStateProperty.all<Color>(
                                  AGLDemoColors.periwinkleColor,
                                ),
                              ),
                            ),
                          )
                        : const SizedBox(),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
