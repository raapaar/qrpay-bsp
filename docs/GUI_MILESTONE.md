# QRpay GUI foundation — version 0.3.0

## Included

Charcoal/yellow styling, rounded controls and the selected QR coin asset in the
app header. Bottom navigation opens Home, Scan, Activity, Vendor and Profile.
Vendor opens a separate demo QR creation screen. The existing K25 demonstration,
scenario selector, scanner and QR validator remain in use. Codes are unsigned,
accept test merchant identifiers only and expire after ten minutes. The system
launcher icons have not been replaced.

Activity and Profile are explicitly labelled empty/planned states. No fabricated
balance, transaction history or percentile is displayed. The Android dialler
handoff appears on Android only. Backgrounding clears the current session,
returns to Home and discards QR creation fields; two-minute inactivity clearing
continues to apply.

## Deferred

Personal transfers and receiving QR, saved vendor inventory, PNG/PDF exports,
local database, accounts, sync, feedback, comparisons, and supported bank/SIM
integrations are subsequent milestones. No new network or storage dependencies
are added in this milestone.

## Device acceptance

1. Open each bottom tab and check content with the phone's larger text setting.
2. Home → Try a K25 demo payment → authorize → finish. Repeat for decline and
   uncertain result. Confirm no credential field is offered.
3. Vendor → Create a demo merchant QR → Generate. Scan on a second device and
   confirm merchant and amount match the reviewed values.
4. Open a review or generator, background the app, then return. Home must appear
   with no payment session or populated generator remaining.
5. Test camera permission refusal and expiry of a generated code.

Use GitHub Actions on the feature branch for analysis, tests, and Android/iOS
builds. Build iPhone demo creates the unsigned IPA for the existing AltStore
installation route. A successful unsigned build still requires local signing
and iPhone testing.

## Verification in this authoring environment

- Five Python source/platform-overlay checks passed, including recursive Dart
  privacy scanning and unsigned IPA packaging fixtures.
- Added a narrow-screen widget test for all five tabs and QR generation, alongside
  the existing payment and background-clearing tests.
- Local Flutter execution was blocked by automatic approval review after its
  tooling attempted a cloud instance-metadata request. Flutter analysis, widget
  tests and native builds are not verified for this milestone.
- Repository reads succeed. Remote branch creation returned HTTP 403, so no
  remote branch, commit, pull request or build was created.
