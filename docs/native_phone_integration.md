# Native phone integration

The Phone and Messages apps use PipeWire Telephony with automatic D-Bus
discovery and BlueZ OBEX for PBAP/MAP. Contacts are stored under the user's XDG
data directory. Temporary transfer files are deleted when the phone disconnects.

## Connection and contact synchronization

Both phone data and telephony providers start with the app. A paired phone must
also establish its Bluetooth connection before PBAP, MAP, or HFP can be used.
While pairing or connecting, the app can already display that phone's saved
contacts. It waits for the explicit Bluetooth connection sequence to finish
before opening the data sessions.

Cache reads require an explicit device address. Selecting another phone clears
the old phone's displayed contacts immediately; a phone without a cache starts
with an empty list. Startup without a selected phone and disconnects also show
no contacts. Stored contacts remain on disk for their owning device, and caller
names are resolved only from contacts tagged with the connected phone's address.

On reconnect, the app restores the cache for that Bluetooth address and checks
the phone's PBAP database identifier and primary/secondary version counters.
When these match, it reuses the saved vCards without downloading them again.
When version counters are unavailable, it compares the complete contact listing
(vCard handles and names, checked against the phonebook size). Changes or an
inconclusive check trigger a new download. Contact count alone is never used as
proof that the phonebook is unchanged.

The fallback listing cannot detect a number or photo edit under an unchanged
handle/name. Use **Refresh contacts** in the Contacts tab to force a download in
that case. BlueZ documents the counters as optional and listings as handle/name
pairs in its [PhonebookAccess API](https://github.com/bluez/bluez/blob/master/doc/org.bluez.obex.PhonebookAccess.rst).

Contacts are saved separately by normalized Bluetooth address in
`$XDG_DATA_HOME/flutter-ics-homescreen/contacts.json`, or
`$HOME/.local/share/flutter-ics-homescreen/contacts.json` when XDG_DATA_HOME is
unset. The single-phone format from earlier releases is migrated when saved.
Writes are serialized within the app, use an atomic file replacement, and set
the cache file to mode 0600 and its directory to 0700. Failed transfers keep the
previous phonebook. A storage failure is reported while loaded contacts remain
usable. The cache intentionally survives disconnects; deleting the file removes
all saved phonebooks.

PBAP contact and recent-call transfers are serialized because they select
different folders on the same session. HFP follows the selected Bluetooth
address independently through PipeWire Telephony. A phone switch invalidates
old async results, and only the selected gateway's calls reach the UI. Caller
names update when that phone's cached contacts finish loading.

See [Contact and telephony review](phone_contact_telephony_review.md) for the
review findings, flow, and validation limits.

## Host development

```sh
flutter pub get
dart run tool/bootstrap_native_dependencies.dart
flutter run -d linux
```

The bootstrap command resolves `bluez_obex_native` from
`.dart_tool/package_config.json` and initializes its `sdbus-c++` submodule.
The PipeWire package build hook initializes its own submodule.

For `flutter build linux`, Flutter configures FFI plugin CMake projects before
running Dart build hooks. The homescreen's Linux CMake setup therefore also
initializes the pinned PipeWire `sdbus-cpp` submodule when it is missing. Git
and network access are required for that first initialization; subsequent
builds reuse the checkout. No separate library-loading script is needed.
The Linux install rules copy native assets into the bundle's `lib/` directory,
including the OBEX and PipeWire telephony libraries built by the hooks.

## AGL cross-build

Let the Dart build hooks cross-build both native libraries with BitBake's CMake
toolchain, then install the generated native assets in the Flutter bundle's
`lib/` directory. Do not use host-built shared objects in the target image.

Flutter 3.38 writes `.dart_tool/flutter_build/*/native_assets.json`. The Yocto
AOT step must pass a target-correct copy of that manifest to
`frontend_server_aot` with `--native-assets`; otherwise the installed `.so`
files exist but `@Native` cannot resolve them. For `flutter-auto`, bundled
library entries must resolve to the installed bundle directory, for example
`/usr/share/flutter/flutter_ics_homescreen/3.38.3/release/lib`, rather than
relative to `/usr/bin/flutter-auto`. No runtime environment variable or
external loader script is required.

The application checks the user/session bus first and falls back to the system
bus. This supports host WirePlumber services started as user units while still
finding the normal AGL system-bus service. The AGL image must include a D-Bus
policy allowing the application user to call and observe that service. BlueZ
must expose PBAP and MAP through `obexd`; phones may require the user to approve
contact and message sharing after pairing.

Unavailable profiles are shown as unavailable in the UI. Production does not
substitute demo contacts, history, calls, or messages.
