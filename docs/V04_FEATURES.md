# Android MVP 0.4.0

## Visual changes

Navy #161D28, elevated navy #212E3E, lime #DFE94B, teal summary card and bundled
DM Sans. Adapted from the supplied banking UI reference. Brand and app name are
centered in the header. Scan is the oversized icon in the exact middle of the
five-item dock (Home, Activity, Scan, Vendor, Profile). All routes including the
camera, review, QR form, settings and feedback retain bottom navigation and a
pinned primary action. Content fades gently above the dock; reduced motion
suppresses the effect. The simplified QR ring is also the Android launcher icon,
including adaptive and legacy variants.

## Working locally

- Scan and validate prototype merchant and personal transfer codes, then review.
- Simulate success, decline or uncertain results with explicit authorization.
- Separate peer transfer form and personal receiving QR creation.
- BSP, Kina and Other are demo bank labels only; destinations remain TEST codes.
- Fixed amount or sender-entered amount; validity 10 minutes, 24 hours or 30 days.
- Save, open, regenerate and delete receiving codes. Saved inventory survives restart.
- Share PNG with a white quiet zone, or a printable PDF. A printed copy cannot be
  remotely revoked offline; expiry is checked when scanned and authorized.
- Optional persistent history, off by default. Categorize, filter or delete records.
- Monthly successful demo purchase totals exclude transfers, declines and unknowns.
- Profile labels and optional monthly demo budget. Locally recorded savings goals
  track contributions; they do not establish bank savings or a savings percentile.
- Feedback drafts with a separate app-version attachment choice.
- JSON data export and explicit local deletion.

SQLite stores records in the app sandbox. Database encryption is not added in
this milestone. Banking PINs and OTPs have no entry fields or sync schema.
The app's password field belongs only to its optional backend account.

## Optional online features

Django source is in backend/. Deploy your own trusted HTTPS backend before use.
Sign-in, consented backup, restore, delete-account and update notices are wired.
Feedback travels inside the consented snapshot. Reopening the app attempts sync
when backup consent is enabled; a foreground sync button is also available.
Automatic background connectivity scheduling is not implemented. Offline records
remain available if the server cannot be reached. No sync route can make or retry
a payment. Conflicts require an explicit restore, never silent last-write-wins.

## Still dependent on integration / device validation

- Real banking, peer transfers and settlement verification are not implemented.
- SIM labels do not automatically select a SIM or verify registration.
- SMS import, background USSD navigation and verified bank/carrier integration
  remain unavailable. The existing fixed Android dialler handoff is assisted only.
- Real spending/saving percentiles require consenting, verified live records;
  simulated transactions cannot populate them.
- Native camera, share/print targets, Android secure storage and launcher appearance
  must be checked on the itel A100C. An Android build must run in GitHub Actions.
- iOS uses the common UI; its native icon and banking limitations are unchanged.

## Signing and updates

Build Android MVP produces a debug APK, not a Play Store release. The workflow
caches the development keystore for subsequent updates. If that cache is lost,
Android can reject an update because its signing key differs. Do not uninstall a
version with saved records before exporting them. A stable release keystore kept
outside source control is required before wider distribution.

## Build and install

Push this update to its feature branch. This automatically starts Build Android MVP
in the existing checks.yml workflow. Open the newest run on that branch. Download QRpay-Android-MVP-v0.4, extract the ZIP,
and open app-debug.apk on the Android phone. Keep exports/backups before replacing
an older installed version. No production deployment is performed by the workflow.
