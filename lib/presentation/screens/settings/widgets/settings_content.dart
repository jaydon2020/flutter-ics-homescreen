import 'package:flutter_ics_homescreen/export.dart';

import '../../../custom_icons/custom_icons.dart';
import '../settings_screens/voice_assistant/widgets/voice_assistant_settings_list_tile.dart';

class Settings extends ConsumerWidget {
  const Settings({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      //crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const CommonTitle(
          title: 'Settings',
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 144),
            children: [
              SettingsTile(
                  icon: Icons.calendar_month_outlined,
                  title: 'Date & Time',
                  onTap: () async {
                    ref.read(appProvider.notifier).update(AppState.dateTime);
                  }),
              const _BluetoothSettingsTile(),
              const _WifiSettingsTile(),
              SettingsTile(
                  icon: CustomIcons.wiredicon,
                  title: 'Wired',
                  onTap: () {
                    ref.read(appProvider.notifier).update(AppState.wired);
                  }),
              SettingsTile(
                  icon: Icons.tune,
                  title: 'Audio Settings',
                  onTap: () {
                    ref
                        .read(appProvider.notifier)
                        .update(AppState.audioSettings);
                  }),
              if (ref.watch(appConfigProvider
                  .select((config) => config.enableVoiceAssistant)))
                VoiceAssistantSettingsTile(
                    icon: Icons.keyboard_voice_outlined,
                    title: "Voice Assistant",
                    hasSwitch: true,
                    voidCallback: () {
                      ref
                          .read(appProvider.notifier)
                          .update(AppState.voiceAssistant);
                    }),
              if (ref.watch(storageClientConnectedProvider))
                SettingsTile(
                    icon: Icons.person_2_outlined,
                    title: 'Profiles',
                    onTap: () {
                      ref.read(appProvider.notifier).update(AppState.profiles);
                    }),
              SettingsTile(
                  icon: Icons.straighten,
                  title: 'Units',
                  onTap: () {
                    ref.read(appProvider.notifier).update(AppState.units);
                  }),
              SettingsTile(
                  icon: Icons.help_sharp,
                  title: 'Version Info',
                  onTap: () {
                    ref.read(appProvider.notifier).update(AppState.versionInfo);
                  }),
            ],
          ),
        ),
      ],
    );
  }
}

class _BluetoothSettingsTile extends ConsumerWidget {
  const _BluetoothSettingsTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nativeBluetoothAvailable = ref.watch(
      nativeBluetoothAvailableProvider,
    );

    if (nativeBluetoothAvailable == false) {
      final powered = ref.watch(
        signalsProvider.select((signal) => signal.isBluetoothConnected),
      );

      return SettingsTile(
        icon: Icons.bluetooth,
        title: 'Bluetooth',
        switchValue: powered,
        onSwitchChanged: (value) =>
            ref.read(signalsProvider.notifier).setBluetoothConnected(value),
        onTap: () {
          ref.read(appProvider.notifier).update(AppState.bluetooth);
        },
      );
    }

    final bluetooth = ref.watch(
      bluetoothProvider.select(
        (state) => (
          powered: state.powered,
          changingPower: state.changingPower,
        ),
      ),
    );

    return SettingsTile(
      icon: Icons.bluetooth,
      title: 'Bluetooth',
      switchValue: bluetooth.powered,
      switchBusy: bluetooth.changingPower,
      onSwitchChanged: (value) {
        ref.read(bluetoothProvider.notifier).setPowered(value);
      },
      onTap: () {
        ref.read(appProvider.notifier).update(AppState.bluetooth);
      },
    );
  }
}

class _WifiSettingsTile extends ConsumerWidget {
  const _WifiSettingsTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref.watch(
      signalsProvider.select((signal) => signal.isWifiConnected),
    );

    return SettingsTile(
      icon: Icons.wifi,
      title: 'Wifi',
      switchValue: connected,
      onSwitchChanged: (_) {
        ref.read(signalsProvider.notifier).toggleWifi();
      },
      onTap: () {
        ref.read(appProvider.notifier).update(AppState.wifi);
      },
    );
  }
}
