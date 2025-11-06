# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Calmwand is a Flutter mobile application that communicates with a Bluetooth LE device (Calmwand) for biofeedback/relaxation sessions. The app was ported from a Swift iOS application and tracks temperature-based breathing exercises with real-time sensor data, calculates session scores using exponential regression, and maintains session history.

## Development Commands

### Running the App
```bash
flutter run
```

### Testing
```bash
flutter test
```

### Building
```bash
# Android
flutter build apk

# iOS
flutter build ios

# Web
flutter build web
```

### Code Generation
The project uses code generation for Hive models. After modifying models with `@HiveType` annotations, run:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Linting
```bash
flutter analyze
```

### Dependency Management
```bash
# Install dependencies
flutter pub get

# Update dependencies
flutter pub upgrade
```

## Architecture

### State Management
The app uses **Provider** for state management with three main providers:

1. **SettingsProvider** (`lib/providers/settings_provider.dart`) - Manages user settings, must be initialized first as other providers depend on it
2. **SessionProvider** (`lib/providers/session_provider.dart`) - Manages session history, performs regression calculations, depends on SettingsProvider
3. **CurrentSessionProvider** (`lib/providers/current_session_provider.dart`) - Tracks active session state
4. **BluetoothService** (`lib/providers/bluetooth_service.dart`) - Manages BLE device connection and communication

The provider hierarchy is critical: SettingsProvider must be created before SessionProvider since SessionProvider uses `ChangeNotifierProxyProvider` and depends on SettingsProvider settings. See `lib/main.dart:38-63` for the initialization order.

### Data Persistence
The app uses **Hive** (NoSQL database) for local storage:
- Session data stored in 'sessions' box (`SessionModel`)
- User settings stored in 'settings' box (`UserSettingsModel`)
- Storage service initialized in `main()` before app starts
- Models use code generation (`.g.dart` files) for Hive type adapters

### Bluetooth Communication
The app uses `flutter_blue_plus` to communicate with the Calmwand device via custom BLE service (UUID: `87f23fe2-4b42-11ed-bdc3-0242ac120000`). Key characteristics include:
- Temperature data streaming
- Brightness, inhale/exhale time, motor strength controls
- Arduino file system operations (list, read, delete files from device)
- Session ID synchronization

Platform-specific behavior: On web, BLE scanning requires explicit user action (button tap); on mobile, auto-scans when Bluetooth is ready.

### Session Scoring Algorithm
Sessions are scored (0-100) using exponential regression on temperature data:
- Equation: `y = A - B * exp(-k * x)`
- Three parameters (A, B, k) calculated from temperature readings
- Score factors in predicted temperature increase, relaxation factor, and speed factor
- Regression calculation in `lib/utils/regression_calculator.dart`
- Non-finite values (NaN, Infinity) are sanitized to null before storage

### Navigation Flow
1. **SplashScreen** → Shows disclaimer, navigates to HomeScreen
2. **HomeScreen** → Main hub with options for:
   - Start new session (requires BLE connection)
   - View session history
   - Access settings
   - Import Arduino files
   - View how-to guide
3. **BluetoothConnectionScreen** → Device pairing
4. **SessionDetailScreen** → Active session with real-time data
5. **SessionSummaryScreen** → Post-session results
6. **SessionHistoryScreen** → Past sessions list

### Model Structure
- **SessionModel** (`lib/models/session_model.dart`) - Core session data with temperature arrays, regression parameters, score, duration, breathing times. Uses Hive for persistence and supports JSON export.
- **UserSettingsModel** - User preferences including interval settings used in regression calculations
- **CurrentSessionModel** - Temporary state for ongoing session

### Key Features
- Portrait-only orientation (locked in `main.dart:18-21`)
- Wakelock enabled during sessions to prevent screen sleep
- Material 3 design, forced light mode
- Temperature data visualization using `fl_chart` package
- Session export/sharing via CSV using `share_plus`

## Important Notes

### Dependencies Not in pubspec.yaml
The code imports several packages that are missing from `pubspec.yaml`. Before working on features, ensure these dependencies are added:
- `provider` (state management)
- `hive` and `hive_flutter` (local storage)
- `flutter_blue_plus` (Bluetooth LE)
- `fl_chart` (charting)
- `share_plus` (sharing functionality)
- `shared_preferences` (simple key-value storage)
- `path_provider` (file paths)
- `build_runner` (dev dependency for code generation)

### Bluetooth Constants
All BLE UUIDs are centralized in `lib/constants/bluetooth_constants.dart`. The device uses a custom service UUID and specific characteristic UUIDs for each data type. Arduino protocol commands (GETLIST, GETFILE, DELETE, etc.) are also defined here.

### Regression Calculation
The exponential regression algorithm is ported from Swift and must handle edge cases:
- Requires minimum 2 temperature points
- Time array and temperature set must be aligned
- A-minus-Y values must be positive (skips invalid points)
- All calculated values sanitized for NaN/Infinity before storage
- Score calculation has safety checks for finite values
