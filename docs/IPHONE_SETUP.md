# Install the simulated MVP on an iPhone from Windows

This guide uses a GitHub macOS runner to compile the Flutter source and AltStore
Classic on Windows to sign it for personal testing. A paid Apple Developer Program
membership is not required for this route. It is separate from TestFlight and does
not use AltStore PAL or require EU alternative marketplace eligibility.

The package contains build instructions and source, not an already built IPA.
No QRpay repository or workflow run exists yet. Builds and device compatibility
remain unverified until the workflow and device tests pass.

## First prepare the repository

Create an empty private repository called qrpay-bsp in your GitHub account. Do not
initialize it with a README if you will push the supplied folder as a new repository.
Share its URL with the assistant, and make sure the GitHub connection can access it.
The project files, including .github/workflows, must be at the repository root.
An initial commit is necessary before the manually triggered workflow is available.
Hosted macOS runner use is subject to your GitHub account's Actions allowance and
billing settings; check them before starting builds.

## Build the device app

In GitHub select Actions, Build iPhone demo, Run workflow, then the default branch.
The macOS runner installs Flutter 3.35.7, generates native projects, runs analysis
and tests, and builds a release-mode ARM64 iPhone application without code signing.
If any check fails, inspect the failing step before attempting installation.

When successful, download the QRpay-iPhone-unsigned artifact and extract
QRpay-Demo-unsigned.ipa. An unsigned IPA cannot be tapped to install directly and
is not suitable for TestFlight. The following personal signing step is required.
The older iOS simulator workflow does NOT produce an installable phone app.

## Install AltStore Classic using Windows

Follow the official Windows guide:
https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows

It describes installing iTunes and iCloud from Apple, installing AltServer,
connecting and trusting the iPhone, selecting Install AltStore in AltServer, and
enabling Developer Mode. Follow its current troubleshooting guidance if your
Windows installation has the Microsoft Store versions of Apple's tools.

AltServer/AltStore requires Apple account authentication to provision the apps.
Enter those details only in the local signing tools. Do not send passwords,
two-factor codes or certificates to the assistant, GitHub issues or workflow logs.
This is third-party personal-device signing software, not a bank integration.

## Install QRpay

Keep AltServer running on the PC with connectivity to the iPhone. Transfer the
extracted IPA to Files on your iPhone using a method available to you, such as
iCloud Drive. In AltStore Classic open My Apps, use the plus button, select the
IPA and complete the personal signing/install process.

Free-account apps expire after seven days unless refreshed. AltStore's documented
limit is three active sideloaded apps, including AltStore itself. See:
https://faq.altstore.io/altstore-classic/your-altstore

Once installed, the mobile demo does not contact Railway or any banking service.
Internet is needed for initial build, download, signing and periodic refresh.

## Test on your iPhone 16

1. Open QRpay Demo, select Try a K25 demo payment and authorize the simulation.
2. Verify every result says it is a demo and no money moved.
3. Generate a merchant QR on another device, then scan it with the iPhone camera.
4. Generate a QR on the iPhone and scan it with a second device running the demo.
5. Try declined and uncertain-result scenarios.
6. Switch apps and return; the banking session should have cleared.
7. Switch mobile data and Wi-Fi off; the installed native demo should still work.
8. End the session. No PIN, statement or transaction history is retained.

Do not enter a real banking PIN. No PIN field or live payment function is present.
The Android-assisted BSP menu is unavailable on iOS; it is not part of this test.

## Alternative Apple distribution routes

If you already have a paid Apple Developer Program account, a signed TestFlight
build can be configured instead. If you have access to a Mac, local Xcode personal
device signing is another route. Neither route has been configured in this package.
