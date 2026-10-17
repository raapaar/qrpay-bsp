# Validation record

Implementation date: 17 October 2026.

## Executed successfully

`python scripts/check_project.py`: 5 checks passed in version 0.2.0.

1. No network, storage, analytics or credential-field dependencies in supplied
   application source, plus no clipboard export or application logging.
2. Android bridge uses only the fixed public menu with ACTION_DIAL, never a
   QR-provided command, SMS send or automatic USSD submission.
3. Applying platform overlays twice preserves camera permission, disabled backups,
   Android minimum SDK 23, camera description and the correct native channel file.
4. The iPhone IPA packager preserves executable permissions and Payload layout,
   tested against fixture files (not a real iOS build).
5. The packager rejects a simulator build as unsuitable for installation on a phone.

The ZIP is checked for archive integrity after generation. These source checks do
not establish that Flutter compiles, native builds succeed or device privacy holds.

## Blocked in authoring environment

`python scripts/bootstrap.py` exits with an actionable Flutter installation message.
Flutter, Dart and Android Gradle tools are not installed. No APK was built and no
Flutter unit/widget tests or emulator/device GUI checks were executed. No CI run
has been triggered. Python overlay tests use fixture platform files, not an actual
Flutter-generated platform project.

## Supplied for execution after Flutter setup

- 10 Dart domain tests: money boundaries, QR roundtrip, invalid/credential-bearing
  payloads, malformed/expired QR, duplicate submission, late callbacks, in-flight
  replacement, confirmation expiry, disabled live provider and uncertain outcomes.
- 2 widget tests: demo flow without credential input and background-session clearing.
- GitHub Actions: Flutter analysis, tests, Android debug APK and iOS simulator build.
- A manually triggered iPhone device build and unsigned IPA packaging workflow.
  Signing, installation and the actual macOS build remain unverified. No device
  IPA is included in the source archive.

## Physical-device acceptance still required

- Camera permission denied/granted, rear-camera scanning, malformed QR and offline use.
- Small screens, landscape, large text, screen reader labels and keyboard behavior.
- End session, two-minute inactivity, app backgrounding and force termination.
- Screenshot/recent-app protection on supported Android devices.
- Confirm ACTION_DIAL displays exactly *131*6# on enrolled SIM devices; verify
  unsupported devices fail clearly. No transfer is initiated by this prototype.
- Test dual-SIM/default dialler behavior before extending any bank transport.
- Real bank authorization, payment submission and authoritative status are untested
  and unavailable; do not use the prototype as a live payment acceptance tool.
