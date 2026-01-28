# CalmWand Flutter App

CalmWand is a Flutter application for managing and reviewing sessions recorded by the CalmWand device. It supports mobile and desktop platforms, Bluetooth Low Energy (BLE) communication for importing session data from the device, Firebase authentication and Firestore syncing for cloud backups, and a web build intended for desktop/laptop use.

## Key Features

- BLE session import from CalmWand hardware (Arduino firmware compatible).
- Local session storage and cloud sync with Firebase (Auth + Firestore).
- Session history, detail views and session export/import tools.
- Desktop-first web build with a quick client-side check to block mobile/tablet browsers.

## Architecture & Notable Files

- `lib/` — Dart source for app logic, providers, services, screens and widgets.
- `lib/firebase_options.dart` — Firebase platform configuration (keep local, do not commit).
- `android/app/google-services.json` — Android Firebase config (keep local, do not commit).
- `web/index.html` — Web bootstrap and the desktop-only client-side check.

## Local Development

Requirements: Flutter SDK (compatible version), Firebase CLI for hosting deploys when needed.

Run the app locally in Chrome (desktop recommended):

```bash
flutter run -d chrome
```

To run on a connected Android device/emulator:

```bash
flutter run
```

## Build Web (production)

Build the web output to `build/web`:

```bash
flutter build web --release
```

## Deploy to Firebase Hosting

1. Ensure `firebase.json` has `"public": "build/web"` and an SPA rewrite to `index.html`.
2. Login to Firebase and deploy:

```bash
firebase login
firebase deploy --only hosting
```

CI-friendly deploys: create a token with `firebase login:ci` and add it as the `FIREBASE_TOKEN` secret in your CI, then run:

```bash
firebase deploy --only hosting --token "$FIREBASE_TOKEN"
```

## Security / Git

- Do NOT commit `lib/firebase_options.dart` or `android/app/google-services.json` to the repository. They contain API keys and app identifiers. Keep them local or supply via CI secrets/environment.
- If you accidentally pushed API keys, rotate them in the Firebase console and scrub git history.

## Notes

- The web build is desktop-first; the app includes a small client-side check in `web/index.html` that displays a friendly message on phones/tablets to avoid poor UX on small screens.
- BLE behavior differs between native and web builds; import reliability includes timeouts and EOF fallbacks in code.

## Contributing

Open an issue or submit a PR. For deployment automation, I can add a GitHub Actions workflow that builds and deploys the web build to Firebase when you want.

---

Updated: January 27, 2026


