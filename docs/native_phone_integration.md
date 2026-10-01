# Native phone integration

The Phone and Messages apps use PipeWire Telephony with automatic D-Bus
discovery and BlueZ OBEX for PBAP/MAP. Personal data is kept in memory and
temporary files are deleted whenever the Bluetooth phone disconnects.

## Host development

```sh
flutter pub get
dart run tool/bootstrap_native_dependencies.dart
flutter run -d linux
```

The bootstrap command resolves the pinned packages from
`.dart_tool/package_config.json` and initializes their `sdbus-c++` submodules.

## AGL cross-build

Build and package both native libraries in the Yocto/SDK recipe. Provide the
target PipeWire library to the plugin's CMake build with `PWT_PREBUILT_LIBRARY`. Set
`SKIP_NATIVE_BUILD=1` for the OBEX package and install
`libbluez_obex_native.so` in the target loader path. Do not use a host-built
shared object in the target image.

The application checks the user/session bus first and falls back to the system
bus. This supports host WirePlumber services started as user units while still
finding the normal AGL system-bus service. The AGL image must include a D-Bus
policy allowing the application user to call and observe that service. BlueZ
must expose PBAP and MAP through `obexd`; phones may require the user to approve
contact and message sharing after pairing.

Unavailable profiles are shown as unavailable in the UI. Production does not
substitute demo contacts, history, calls, or messages.
