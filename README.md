# calmwand

Flutter app for the CalmWand, a handheld biofeedback device. The wand measures palm temperature during paced-breathing sessions and streams it over Bluetooth LE; the app paces the breathing, records the session, fits a warming curve to score it, and keeps history locally (Hive) with optional cloud sync (Firebase). Ported from an earlier Swift iOS app.

Targets: Android, iOS, and a desktop-only web build hosted on Firebase.

## Repo layout

*   [lib/](lib): all app code
    *   [constants/](lib/constants): BLE UUIDs and the Arduino command strings
    *   [models/](lib/models): Hive-persisted data classes (`.g.dart` adapters are committed)
    *   [providers/](lib/providers): app state (sessions, active session, settings)
    *   [services/](lib/services): Bluetooth, Hive storage, SharedPreferences, Firebase auth, Firestore sync
    *   [screens/](lib/screens), [widgets/](lib/widgets): UI
    *   [utils/](lib/utils): regression/scoring math, CSV export, theme
*   [arduino/](arduino): firmware for the wand itself. Kept here for reference; it is flashed separately via the Arduino IDE.
*   [web/](web): web bootstrap, including the mobile-browser block in [index.html](web/index.html)
*   [firebase.json](firebase.json), [.firebaserc](.firebaserc): Firebase project + hosting config

## Getting started

You need the Flutter SDK (Dart SDK >= 3.9.2). Install from https://docs.flutter.dev/get-started/install and make sure `flutter` is on your PATH.

A fresh clone will not build. Two files are gitignored because they contain Firebase API keys, and [lib/main.dart](lib/main.dart) imports one of them:

*   `lib/firebase_options.dart`
*   `android/app/google-services.json`

Either get copies from a current maintainer, or regenerate them yourself (you need to be a member of the Firebase project first, see below):

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=calmwand-flutter-app
```

Then:

```bash
flutter pub get
flutter run -d chrome   # web, desktop browser
flutter run             # connected Android device / emulator
```

Web Bluetooth only works in Chromium browsers, so use Chrome for web development.

## Everyday commands

```bash
flutter analyze
flutter test
flutter build apk
flutter build ios
flutter build web --release
```

If you change a model annotated with `@HiveType` (session_model.dart, user_settings_model.dart), regenerate the adapters:

```bash
dart run build_runner build --delete-conflicting-outputs
```

The generated `.g.dart` files are committed, so you only need this when the models change. Never reuse or renumber existing `@HiveField` indices. Hive reads old data by field number, and changing them corrupts users' stored history.

## How the app fits together

State management is Provider. The wiring lives in [main.dart](lib/main.dart) and the order matters: `SettingsProvider` must exist before `SessionProvider` (it supplies the recording interval used in scoring), and `CloudSessionService` is rebuilt from `AuthService` whenever login state changes.

*   `BluetoothService` ([services/bluetooth_service.dart](lib/services/bluetooth_service.dart)) owns the BLE connection: scanning, connecting, characteristic discovery, notifications, and the Arduino file-transfer protocol.
*   `CurrentSessionProvider` runs the 1-second session timer and collects a temperature reading every `interval` seconds (default 5).
*   `SessionProvider` holds the session list, runs the regression when a session ends, writes to Hive, and mirrors changes to Firestore when logged in.
*   `StorageService` wraps two Hive boxes: `sessions` and `settings`.
*   `PreferencesService` wraps SharedPreferences for small flags (disclaimer accepted, last login email).

Screen flow: splash -> disclaimer (first launch only) -> login (skippable) -> home. Home is a bottom tab bar: session, history, settings, guide.

### Talking to the wand

All UUIDs and command strings are in [bluetooth_constants.dart](lib/constants/bluetooth_constants.dart). One custom service, eleven characteristics: temperature (notify), brightness / inhale time / exhale time / motor strength (read+write), a session-ID characteristic, and five more implementing a small file protocol for pulling logged sessions off the wand's SD card (`GETLIST`, `GETFILE:<name>`, `DELETE:<name>`, `DELETEALL`, `START`, `CANCEL`, with `END` / `EOF` as terminators).

Temperature arrives as an integer string, degrees Fahrenheit times 100 (`8523` = 85.23 °F). Inhale/exhale times are written in milliseconds.

Web and native behave differently, on purpose:

*   Native scans automatically when Bluetooth comes up; web requires a user gesture (browser rule) and auto-connects to whatever the user picked in the chooser popup.
*   On web, characteristic reads and `setNotifyValue` are slow and flaky, so setup is fire-and-forget with short timeouts, and initial settings reads are skipped entirely.
*   The SD-card file transfer can lose its EOF packet; there's a 3-second stall detector that treats the transfer as complete rather than hanging forever.

### Scoring

When a session ends, [regression_calculator.dart](lib/utils/regression_calculator.dart) fits `y = A - B * exp(-k * x)` to the temperature readings (a warming hand approaches an asymptote). The score (0-100) combines the predicted temperature rise, how fast it happened (`k`), and session length; you need roughly 10 minutes for a max score. Non-finite results are nulled out before storage. The math was ported line-for-line from the Swift app; be careful changing it, because old sessions get rescored with the same code.

## Firebase

Project: `calmwand-flutter-app` at https://console.firebase.google.com. Three pieces are in use: Authentication (email/password), Firestore, and Hosting. To do anything below you need project access: an owner adds you under Project settings -> Users and permissions.

### Accounts

There is no in-app signup, on purpose; the login screen tells users to contact an administrator. To manage accounts, go to Build -> Authentication -> Users in the console:

*   Add user: "Add user" button, enter email + password, share the credentials out-of-band.
*   Reset a password: three-dot menu on the user row -> Reset password (sends an email), or just delete and re-add.
*   Disable / delete: same menu. Deleting the auth user does not delete their Firestore data.

Login is optional. Signed-out users get full functionality with local-only storage.

### Data

Firestore layout:

```
users/{uid}/sessions/{sessionNumber}_{timestampMillis}
```

Each doc is a `SessionModel.toJson()` plus `uploadedAt` and `userId`. Local Hive is the source of truth; the cloud is a mirror. On login the app fetches the user's cloud sessions once and merges them into local storage (new ones added, changed comments taken from cloud). After that, individual saves/edits/deletes are pushed as they happen, with 10-15 s timeouts so a dead connection never blocks the UI. Editing a session's date changes its doc ID, so that path deletes the old doc and writes a new one.

Firestore security rules live in the console (Build -> Firestore Database -> Rules), not in this repo. They should restrict each user to their own `users/{uid}` subtree. Check them before touching anything auth-related.

### Hosting (web deploy)

Deploys are manual:

```bash
flutter build web --release
firebase deploy --only hosting
```

`firebase.json` serves `build/web` with an SPA rewrite. The two GitHub Actions workflows in [.github/workflows/](.github/workflows) were generated by the Firebase CLI for a Node project and run `npm ci && npm run build`, which fails here. They've never worked. Fix them to install Flutter and run the build above, or delete them and keep deploying manually.

The web build refuses mobile browsers: a script in [web/index.html](web/index.html) checks the user agent and screen size and shows a "use a desktop" message instead of loading the app.

## Sharp edges

Things to know before you debug something "impossible":

*   A session whose length is an exact multiple of the recording interval (e.g. ending at exactly 60 s with a 5 s interval) produces one more reading than the regression's time array expects, the fit bails out, and the session is silently dropped. If a user swears they finished a session and it isn't in history, this is why.
*   `sessionNumber` comes from the wand and is not unique: the firmware counter resets, and SD-card imports reuse numbers. Several code paths (delete, the history list's `Dismissible` keys, the detail screen's lookup) assume it is. Duplicates can delete the wrong session or crash the list.
*   Every save rewrites the whole sessions box (`deleteAllSessions` then re-add). Killing the app mid-save can lose history.
*   An unexpected BLE disconnect does not fully reset `BluetoothService`; `isDeviceReady` and the characteristic references go stale until the user manually disconnects/reconnects.
*   The session list is insertion-ordered until a cloud merge sorts it newest-first, so display order differs depending on whether a fetch has run.
*   The wakelock is enabled in `main()` and never released, so the screen stays awake for the whole app lifetime, not just during sessions.
*   The disclaimer screen still claims all data stays on-device, which stopped being true when Firestore sync was added. Fix the text before any store submission.
*   The one widget test pumps the app without initializing Firebase or Hive, so `flutter test` fails as-is.
*   Local notifications and timezone data are initialized in `main()` but nothing schedules a notification anywhere.

## Git notes

Never commit `lib/firebase_options.dart` or `android/app/google-services.json`. If keys do leak into history, rotate them in the console and scrub the history. `ios/build/`, `android/build/`, and `.firebase/` cache files have been committed in the past by accident.
