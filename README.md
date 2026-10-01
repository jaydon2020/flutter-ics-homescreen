# flutter_ics_homescreen

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Useful environment variables

- **DEBUG_DISPLAY** enables the Device Preview.
- **DISABLE_BKG_ANIMATION** disables the main background animation.

Use them like this:

```
flutter run --dart-define=DEBUG_DISPLAY=true,DISABLE_BKG_ANIMATION=true
```

## Phone, contacts, and messages

See [Native phone integration](docs/native_phone_integration.md) for PBAP, MAP,
PipeWire Telephony, host bootstrap, and AGL cross-build requirements.

After selecting the workspace-automation Flutter SDK, launch the Toyota
homescreen device directly. Its custom-device install step must build and copy
`libpipewire_telephony_native.so` into `.desktop-homescreen/lib`:

```sh
source ~/develop/bin/workspace-automation/setup_env.sh
flutter run -d desktop-homescreen
```
