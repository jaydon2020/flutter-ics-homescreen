# Native phone integration

The Phone and Messages apps use PipeWire Telephony with automatic D-Bus
discovery and BlueZ OBEX for PBAP/MAP. Contacts are stored under the user's XDG
data directory. Temporary transfer files are deleted when the phone disconnects.

## Host development

```sh
flutter pub get
dart run tool/bootstrap_native_dependencies.dart
flutter run -d linux
```

The bootstrap command resolves `bluez_obex_native` from
`.dart_tool/package_config.json` and initializes its `sdbus-c++` submodule.
The PipeWire package build hook initializes its own submodule.

## AGL cross-build

Build and package both native libraries in the Yocto/SDK recipe. Set
`SKIP_NATIVE_BUILD=1` for the packages' build hooks and install
`libpipewire_telephony_native.so` and `libbluez_obex_native.so` in the target
loader path. Do not use host-built shared objects in the target image.

The application checks the user/session bus first and falls back to the system
bus. This supports host WirePlumber services started as user units while still
finding the normal AGL system-bus service. The AGL image must include a D-Bus
policy allowing the application user to call and observe that service. BlueZ
must expose PBAP and MAP through `obexd`; phones may require the user to approve
contact and message sharing after pairing.

Unavailable profiles are shown as unavailable in the UI. Production does not
substitute demo contacts, history, calls, or messages.
