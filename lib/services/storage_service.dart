import 'package:hive_flutter/hive_flutter.dart';
import '../models/session_model.dart';
import '../models/user_settings_model.dart';

/// Storage service for persisting app data using Hive
class StorageService {
  static const String _sessionsBoxName = 'sessions';
  static const String _settingsBoxName = 'settings';
  static const String _settingsKey = 'user_settings';

  static Box<SessionModel>? _sessionsBox;
  static Box<UserSettingsModel>? _settingsBox;

  /// Initialize Hive and open boxes
  static Future<void> initialize() async {
    // Initialize Hive Flutter
    await Hive.initFlutter();

    // Register adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(SessionModelAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(UserSettingsModelAdapter());
    }

    // Open boxes
    _sessionsBox = await Hive.openBox<SessionModel>(_sessionsBoxName);
    _settingsBox = await Hive.openBox<UserSettingsModel>(_settingsBoxName);
  }

  // MARK: - Session Storage

  /// Get all sessions
  static List<SessionModel> getSessions() {
    if (_sessionsBox == null) return [];
    return _sessionsBox!.values.toList();
  }

  /// Add a new session
  static Future<void> addSession(SessionModel session) async {
    if (_sessionsBox == null) return;
    await _sessionsBox!.add(session);
  }

  /// Update a session at index
  static Future<void> updateSession(int index, SessionModel session) async {
    if (_sessionsBox == null) return;
    await _sessionsBox!.putAt(index, session);
  }

  /// Delete a session at index
  static Future<void> deleteSession(int index) async {
    if (_sessionsBox == null) return;
    await _sessionsBox!.deleteAt(index);
  }

  /// Delete all sessions
  static Future<void> deleteAllSessions() async {
    if (_sessionsBox == null) return;
    await _sessionsBox!.clear();
  }

  /// Get session count
  static int getSessionCount() {
    return _sessionsBox?.length ?? 0;
  }

  // MARK: - Settings Storage

  /// Get user settings (returns default if not found)
  static UserSettingsModel getSettings() {
    if (_settingsBox == null) return UserSettingsModel();
    return _settingsBox!.get(_settingsKey, defaultValue: UserSettingsModel()) ??
        UserSettingsModel();
  }

  /// Save user settings
  static Future<void> saveSettings(UserSettingsModel settings) async {
    if (_settingsBox == null) return;
    await _settingsBox!.put(_settingsKey, settings);
  }

  // MARK: - Cleanup

  /// Close all boxes
  static Future<void> close() async {
    await _sessionsBox?.close();
    await _settingsBox?.close();
  }
}
