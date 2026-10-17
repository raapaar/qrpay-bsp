# BSP integration boundary

## Target

Android-first GUI for merchant payments through BSP's cellular banking channel,
without mobile data. The product target is scan, review, bank authorization and
verified result, with no SMS composer or USSD typing by the user. Version 0.1
implements the GUI simulation and an explicitly separate assisted menu handoff.
It does not claim to have implemented that live product target.

The requested entry point is `*131*6#`. It is fixed in Kotlin; QR data cannot
replace it or append a PIN. Physical-device/network validation remains outstanding.
The original supplied September specifications describe merchant code, amount,
description, account selection, merchant confirmation and payment confirmation.
Treat that sequence as a design baseline, not a verified current command protocol.

## Required bank contract

Obtain the supported channel and command format; whether third-party GUI automation
is permitted; bank-controlled or approved transient PIN handling; enrolled SIM and
dual-SIM behavior; merchant identity validation; amount/fee/limit rules; cancellation;
authoritative success/decline/unknown responses; duplicate handling; and status lookup
after timeout or app termination. Never log or persist raw PIN-bearing commands.

Android's `sendUssdRequest` exposes a request and callback, not a documented generic
controller for all interactive banking menus. The ACTION_DIAL implementation is a
real OS integration, but is not automatic execution of the payment steps. Do not
use accessibility screen automation as a hidden substitute for the missing contract.

## Next live feasibility milestone

1. Validate the fixed entry point on an enrolled BSP SIM in a physical Android phone.
2. Obtain a supported inquiry interface and authorized test procedure from BSP.
3. Implement an inquiry adapter using documented commands and fictitious test data
   or supplied sandbox access, with explicit per-request authorization.
4. Verify response semantics and lifecycle interruption handling.
5. Resolve no-retention versus ambiguous-payment recovery before money movement.
6. Implement and test payment submission only when its bank contract is established.

Do not enable a live PIN field until its destination and handling have been reviewed.
If added later, it must be transient, excluded from restoration and logging, and
cleared after use; never pass it to Railway or include it in QR content.

## Reference links

- BSP Mobile Banking: https://www.bsp.com.pg/personal-banking/ways-to-bank/mobile-banking/
- Original merchant fact-sheet URL from supplied documents:
  https://www.bsp.com.pg/media/2qjpccuc/fact-sheet-make-payments-using-mobile-banking-merchant-codes.pdf
  (could not be fetched during this implementation; not treated as current verification).
- Android TelephonyManager:
  https://developer.android.com/reference/android/telephony/TelephonyManager
- Apple telephone links:
  https://developer.apple.com/library/archive/featuredarticles/iPhoneURLScheme_Reference/PhoneLinks/PhoneLinks.html
- Flutter platform channels:
  https://docs.flutter.dev/platform-integration/platform-channels

