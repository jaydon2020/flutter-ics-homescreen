# PBAP, MAP, and Telephony test plan

Use this checklist to validate the Bluetooth phone integration on both the
Linux desktop target and an AGL target. Run the automated suite first, then run
the real-phone cases because D-Bus policy, BlueZ OBEX, HFP, SCO routing, and
phone permissions cannot be proven by mocks.

Record the date, target, phone model/OS, Bluetooth address suffix, result, and a
short log or screenshot reference for every manual case. Do not attach contact
names, phone numbers, or message bodies to public bug reports.

## Test setup

- Pair two phones with different contacts so device isolation can be checked.
- On each phone, allow contact, call-history, message, and phone-call access.
- Keep at least one contact with two numbers and one recent incoming, outgoing,
  and missed call.
- Keep at least one SMS conversation, and use a safe test recipient for sending.
- On AGL, confirm BlueZ `obexd` and PipeWire Telephony are running and that the
  homescreen user can access their D-Bus services.
- Start from the repository root after loading the workspace environment:

```sh
source ~/develop/bin/workspace-automation/setup_env.sh
flutter pub get
```

## Automated checks

Run the complete gate used by CI:

```sh
flutter analyze --no-fatal-infos
flutter test --reporter expanded
```

For a faster phone-only run:

```sh
flutter test \
  test/contact_store_test.dart \
  test/phone_parsers_test.dart \
  test/phone_data_notifier_test.dart \
  test/telephony_flow_test.dart \
  test/calls_test.dart \
  --reporter expanded
```

Pass criteria: analysis has no errors or warnings, every test passes, and no
test process hangs after completion. Informational lints are currently allowed.

The automated tests cover:

- PBAP vCard and call-history parsing, per-device persistence, cache migration,
  atomic writes, permissions, reconnect reuse, forced refresh, phone switching,
  PBAP operation serialization, invalid data, and OBEX completion races.
- MAP bMessage construction/parsing, session availability, inbox loading, and
  separation of MAP success from PBAP errors.
- Telephony gateway selection, every backend command, command errors, duplicate
  taps, call waiting, active/held calls, transport removal, mute restoration,
  call identity changes, reconnects, and stale asynchronous results.
- Phone, Messages, incoming-call, and active-call widgets at desktop and
  automotive landscape sizes.

## PBAP manual cases

| ID | Test | Expected result |
|---|---|---|
| PBAP-01 | Pair and connect phone A with contact sharing allowed. Open Contacts and Recents. | Contacts and recent calls load once; the UI becomes ready without an error. |
| PBAP-02 | Restart the homescreen while phone A remains paired, then reconnect it. | Phone A's cached contacts appear while reconnecting. Unchanged contacts are not downloaded again. |
| PBAP-03 | Disconnect phone A and restart the app with no selected phone. | No contacts from phone A are displayed, while its cache remains on disk. |
| PBAP-04 | Connect phone B after phone A. | Phone A's contacts disappear immediately; only phone B's contacts and caller names appear. |
| PBAP-05 | Reconnect phone A. | Phone A gets its own saved contacts; phone B's contacts never appear. |
| PBAP-06 | Add, rename, and remove a contact on the connected phone, then reconnect. | The changed phonebook is downloaded when PBAP version metadata or listing changes. |
| PBAP-07 | Edit only a phone number, then select **Refresh contacts**. | A forced download shows the new number even if the phone does not provide version counters. |
| PBAP-08 | Deny contact access on the phone and reconnect. | The UI reports contacts unavailable, keeps the last valid cache, and does not replace it with an empty or partial download. |
| PBAP-09 | Re-enable contact access and select Retry/Refresh. | Contacts recover without restarting or repairing the phone. |
| PBAP-10 | Open Contacts and refresh Recents at the same time. | Both finish with correct data; PBAP folder selection does not mix contacts and history. |
| PBAP-11 | Place incoming, outgoing, and missed calls, then refresh Recents. | Each entry has the correct direction, name/number, and timestamp. |
| PBAP-12 | Inspect the cache path and permissions. | Data is stored per normalized Bluetooth address in `contacts.json`; the file is mode `0600` and its directory is mode `0700`. |

Default cache path when `XDG_DATA_HOME` is unset:

```text
$HOME/.local/share/flutter-ics-homescreen/contacts.json
```

## MAP manual cases

| ID | Test | Expected result |
|---|---|---|
| MAP-01 | Connect a phone with message access allowed and open Messages. | Conversations load and the Messages screen reports no profile error. |
| MAP-02 | Open a conversation containing incoming and outgoing messages. | Messages are ordered correctly, use the correct direction, and show the resolved contact name when available. |
| MAP-03 | Receive a new SMS while Messages is open. | A MAP notification or refresh updates the conversation without duplicating messages. |
| MAP-04 | Select **Refresh messages** on a phone that rejects optional `UpdateInbox`. | Existing MAP access stays available and message download still runs. |
| MAP-05 | Send a short message to the safe test recipient. | One outgoing message is sent, the UI remains responsive, and the conversation refreshes without duplicates. |
| MAP-06 | Open an unread conversation. | Messages are marked read when supported; failure to mark one message does not discard the conversation. |
| MAP-07 | Deny message access and reconnect. | Messages shows MAP unavailable while Contacts and Telephony continue independently. |
| MAP-08 | Re-enable message access and retry. | Conversations recover without repairing the phone. |
| MAP-09 | Switch from phone A to phone B while a message refresh is running. | Late phone-A results are ignored; only phone-B conversations remain visible. |
| MAP-10 | Trigger an incoming message during a PBAP contact refresh. | Both operations complete without corrupting contacts, recents, or conversations. |

## Telephony and SCO manual cases

| ID | Test | Expected result |
|---|---|---|
| TEL-01 | Dial a number from Dial, Recents, Contacts, and a message conversation. | Each route starts one outgoing call using the selected phone. Rapid double taps do not dial twice. |
| TEL-02 | Receive a call while viewing another app. | The incoming-call banner shows the correct contact for the connected phone and offers Answer and Decline. |
| TEL-03 | Answer, decline, and end separate test calls. | Each button sends one operation and the overlay/screen follows the native call state. |
| TEL-04 | During an active call, enter DTMF digits. | Each pressed digit is sent once and the call remains active. |
| TEL-05 | Mute and unmute the microphone. | Mute sets microphone gain to zero; unmute restores the previous nonzero gain. |
| TEL-06 | Create a second waiting call while one call is active. | The banner offers **Hold & answer** and **End & answer**; the main Answer action performs Hold & answer. |
| TEL-07 | With active and held calls, use Swap, End & swap, and Merge. | Only topology-valid controls appear and each operation changes the calls as labeled. A single call never shows Hold/Resume. |
| TEL-08 | Rapidly press Answer, End call, or another command while it is pending. | Controls visibly disable and only one native operation is submitted. Errors unlock the controls and appear in the UI. |
| TEL-09 | Transition from one active call to another. | The displayed participant changes and the duration resets for the new primary call. |
| TEL-10 | Disconnect phone A during a call, then connect phone B. | Phone A's call and gateway state clear; no late result or caller name appears for phone B. |
| TEL-11 | Stop and restart the PipeWire Telephony service while the phone stays connected. | The UI reports disconnection, Retry reconnects, and new commands work on the fresh service. |
| TEL-12 | Make and answer calls on desktop and AGL while monitoring audio. | SCO activates when the call becomes active; audio is bidirectional, uses the expected route, and has no persistent echo or silence. |
| TEL-13 | Remove SCO transport or disable Bluetooth during a call. | Codec, transport state, and RejectSCO data clear instead of showing stale values. |
| TEL-14 | Test the phone's supported codecs on AGL. | Each negotiated codec routes stable bidirectional audio and is correctly reported in diagnostics. |

## Result record

Copy this block for each target and phone combination:

```text
Date:
Target and image/commit:
Phone model and OS:
Bluetooth address suffix:
Case IDs passed:
Case IDs failed:
Evidence/log location:
Notes:
```

When reporting a failure, include the case ID, application commit, service
state, and a log covering the action. Redact names, complete addresses, phone
numbers, and message content.
