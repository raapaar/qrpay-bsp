# QRpay Android MVP — 0.4.0

Independent Flutter prototype for offline QR payments and personal transfers.
All transaction outcomes are simulated. No money moves and this is not an official
bank app. Existing BSP menu handoff remains manual, Android-only and unverified.

## What's new

- Navy/teal banking theme, bundled DM Sans and consistent Material icons.
- Centered simplified logo and app name; new Android launcher icon.
- Larger scan icon in the exact center of the five-item bottom dock.
- Bottom navigation and pinned actions on every page, including scanner controls.
- Gentle content fade above the dock, respecting reduced motion.
- Personal receiving QR and peer transfer simulation.
- Saved receiving QR inventory with fixed or sender-entered amounts and expiry.
- PNG sharing with a quiet zone, and printable PDF export.
- SQLite records that survive restart; optional demo history, categories and filters.
- Monthly demo purchase totals, an optional budget and self-recorded savings goals.
- Profile preferences, feedback drafts, data export and local deletion.
- Optional HTTPS Django accounts/backup/restore/deletion and update notices.

Only TEST receiving identifiers are accepted. Named banks are demo labels. SIM
preferences do not select a SIM or prove bank registration. Real SMS/USSD banking,
settlement verification and real peer rankings require further supported integration.
See [feature scope](docs/V04_FEATURES.md) for precise capabilities and limitations.

## Android build — no Flutter installation needed on your PC

Pushing the update automatically starts **Build Android MVP** in the existing
checks.yml workflow. Open the newest run on the update branch at:
https://github.com/raapaar/qrpay-bsp/actions/workflows/checks.yml

On success download **QRpay-Android-MVP-v0.4**. Extract the ZIP, transfer
app-debug.apk to the phone, and install. Android's installation-source permission
may need enabling. Never disable Play Protect. This workflow builds Android only;
the separate Build iPhone demo workflow is unchanged.

This is a development APK. Preserve exports before any reinstall. Cached debug
signing keys are not a substitute for a stable private release-signing setup.

## Local development

Use Flutter 3.35.7, Python 3.10+, Android SDK and Java 17. Start from the repository root:

```powershell
python scripts/bootstrap.py
cd mobile
flutter analyze
flutter test
flutter devices
flutter run
```

Bootstrap regenerates platform projects, preserves Dart sources, installs reviewed
Android overlays and applies the launcher icon. pubspec.lock is committed to pin
transitive dependencies. Android minSdk is 23. The prototype was targeted for the
itel A100C (A6611L), Android 15, 720 × 1612; device-level acceptance is still required.

## Offline data and privacy

Local history is off until enabled in Profile. Saving a QR or feedback explicitly
retains that item. SQLite is sandboxed by Android but not separately encrypted.
App account tokens use secure storage; bank PINs and OTPs are never requested.
Export records before deleting app data or reinstalling with a different key.
Backgrounding still clears an active payment session; consented retained records
remain. Deleting a local copy does not delete a cloud copy or printed QR.

## Optional backend

No server is deployed or preconfigured. [backend/README.md](backend/README.md)
contains Django/PostgreSQL configuration. App account credentials are separate
from banking authorization. Enable backup only after reviewing the server address
and records being shared. Sync never initiates, repeats or verifies a payment.

## References and assets

See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). The banking repository supplied
the visual direction. The scroll reference informed the fading behavior. Hotpot's
repository lists icon libraries, including Material Icons; it is not a font pack.
The QR ring asset is decorative branding, not a payment QR code.
