# Kibo Admin

Control panel for the Kibo Trade subscription (default TZS 50,000 / month): see every installation, record payments,
switch subscriptions on/off, send a message to a customer's app. Same design as Kibo Trade; Android, iOS, macOS, Windows.

## How it works
Both apps talk to YOUR Firebase project (Firestore + Authentication) over the public REST API using plain `http`;
no Firebase plugins are compiled in (no CocoaPods / Swift Package Manager / Gradle changes).

- Each Kibo Trade install signs in anonymously, registers itself as a free trial, and sends a light heartbeat
  (business name, TIN, device/OS, app version, last-seen time, five counters). No customer data, receipts or prices.
- Kibo Admin (you) sees them all, records payments (extends `paidUntil` by N calendar months from the current expiry,
  or from today if already expired), and can Deactivate / Activate / Extend.
- The POS app caches its state: valid until `paidUntil`, 3 days grace, then it shows a lock screen (customers can still
  open Reports and export their data). It must re-verify online at least every 14 days; a phone clock set back is detected.
  All numbers (price, trial, grace, offline days, payment instructions) are edited in Kibo Admin > Settings.

## Setup (once)
1. Firebase console: create a project, add a Firestore Database.
2. Authentication > Sign-in method: enable **Email/Password** and **Anonymous**.
3. Authentication > Users: add your admin email + password, copy the user's **UID**.
4. Firestore > Data: create collection `admins`, document ID = that UID (any field).
5. Firestore > Rules: paste the rules (Kibo Admin > Settings > "Setup help" > Copy) and Publish.
6. In Kibo Trade set the Project ID and Web API key in `lib/license_config.dart` (or `--dart-define`), then build it.
   Leave the placeholders and the POS app runs with NO subscription checks.
7. Build and open Kibo Admin, sign in with project ID, Web API key, admin email and password.

## Build (Codemagic)
`codemagic.yaml` has android-apk, ios-ipa-altstore (unsigned), macos-app and windows-app workflows; same method as Kibo Trade.

## Limits (be aware)
- Enforcement is in the app: it deters casual non-payment but cannot stop a determined person who modifies the app.
- Payments are recorded by you after you receive mobile money. Automatic collection (M-Pesa/Selcom/etc. callbacks) needs
  a server (e.g. Cloud Functions) and a payment-provider account; not included.
- Security rules are your protection: only users listed in `admins` can change status/expiry; test them in the
  Firebase Rules Playground before relying on them.
- Tell your customers what is collected (the POS app lists it under Settings > Subscription).
