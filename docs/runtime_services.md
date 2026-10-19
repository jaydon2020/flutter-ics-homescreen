# Runtime service troubleshooting

Bluetooth contacts, call history, and HFP use BlueZ OBEX and PipeWire Telephony.
They do not require the radio, storage, or KUKSA gRPC services.

## gRPC connection refused / UNAVAILABLE

The app must reach a real service at each configured endpoint. Its defaults are:

| Service | Default endpoint | Configuration |
| --- | --- | --- |
| Radio | localhost:50053 | `[radio]` in `/etc/xdg/AGL/flutter-ics-homescreen.toml` |
| Storage for user profiles and units | localhost:50054 | `[storage]` in the same file |
| KUKSA | localhost:55555 | `/etc/xdg/AGL/kuksa.toml`, or `$XDG_CONFIG_HOME/AGL/kuksa.toml` |

Check the actual service host, including on the AGL target:

```sh
ss -ltn | rg ':(50053|50054|55555)\b'
```

If a backend runs elsewhere, configure its real hostname/IP and listening port.
`localhost` always refers to the machine running the homescreen. Ports printed
inside a Dart SocketException can be client socket ports; use the explicit
service endpoint in the app's diagnostic message to check the server.

The clients retry UNAVAILABLE connection setup with delays of 1, 2, 4, 8, 16,
then at most 30 seconds. An outage is reported once with its configured endpoint.
Radio and KUKSA subscriptions are recreated after failures; storage reloads user
profiles and units after reconnection. Last known unit preferences remain in
memory during an outage. Failed user write/control commands are not replayed.

Retries recover services that start late or return after an outage. They cannot
provide radio, profile persistence, or vehicle data when the service is absent
or the configured endpoint is wrong. Start the actual backend or correct its
configuration on that host. The same rule applies on desktop and AGL.

## OBEX UnknownObject during contact or call-history transfer

The app records BlueZ transfer events and checks the properties returned by the
transfer request. An explicit `complete` snapshot remains usable if the short-
lived Transfer1 object disappears before a later `GetAll` reaches it. Polling
continues for active transfers, and an UnknownObject error allows a short grace
period for queued native events to arrive. A missing object alone is never
accepted as success; error events and unconfirmed removals retain the old cache.

After updating the Dart code, use **R** in the `flutter run` terminal to hot
restart the app so existing providers and their native event listeners are
recreated. On AGL, rebuild/redeploy the app and restart its running instance.
