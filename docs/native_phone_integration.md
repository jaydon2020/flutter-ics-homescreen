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
