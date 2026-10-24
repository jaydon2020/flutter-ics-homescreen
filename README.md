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
Use the [PBAP, MAP, and Telephony test plan](docs/phone_integration_test_plan.md)
for automated checks and real-phone validation on desktop and AGL.

After selecting the workspace-automation Flutter SDK, launch the Toyota
homescreen device directly. The package build hook builds
`libpipewire_telephony_native.so`, and the custom-device install step copies it
into `.desktop-homescreen/lib`:

```sh
source ~/develop/bin/workspace-automation/setup_env.sh
flutter run -d desktop-homescreen
```

For refused radio/storage/KUKSA connections, see
[Runtime service troubleshooting](docs/runtime_services.md).

## Checks

```sh
flutter analyze --no-fatal-infos
flutter test --reporter expanded
```

The Flutter checks workflow runs both commands on pushes and pull requests.
Analysis fails on errors and warnings; existing informational lints are reported.
See [Application call controls](docs/phone_contact_telephony_review.md#application-call-controls)
for multi-call behavior and intentionally internal audio APIs.
