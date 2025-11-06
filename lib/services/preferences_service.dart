import 'package:shared_preferences/shared_preferences.dart';

/// Simple preferences service using SharedPreferences
/// Similar to UserDefaults in Swift
class PreferencesService {
  static SharedPreferences? _prefs;

  /// Initialize SharedPreferences
  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // MARK: - Disclaimer

  static const String _keyDisclaimerAccepted = 'didAcceptDisclaimer';

  /// Check if user has accepted disclaimer
  static bool hasAcceptedDisclaimer() {
    return _prefs?.getBool(_keyDisclaimerAccepted) ?? false;
  }

  /// Mark disclaimer as accepted
  static Future<void> setDisclaimerAccepted(bool accepted) async {
    await _prefs?.setBool(_keyDisclaimerAccepted, accepted);
  }

  // MARK: - Weekly Goal

  static const String _keyWeeklyGoal = 'goal';

  /// Get weekly session goal (default: 7)
  static int getWeeklyGoal() {
    return _prefs?.getInt(_keyWeeklyGoal) ?? 7;
  }

  /// Set weekly session goal
  static Future<void> setWeeklyGoal(int goal) async {
    await _prefs?.setInt(_keyWeeklyGoal, goal);
  }

  // MARK: - Generic Getters/Setters

  /// Get string value
  static String? getString(String key) {
    return _prefs?.getString(key);
  }

  /// Set string value
  static Future<void> setString(String key, String value) async {
    await _prefs?.setString(key, value);
  }

  /// Get int value
  static int? getInt(String key) {
    return _prefs?.getInt(key);
  }

  /// Set int value
  static Future<void> setInt(String key, int value) async {
    await _prefs?.setInt(key, value);
  }

  /// Get bool value
  static bool? getBool(String key) {
    return _prefs?.getBool(key);
  }

  /// Set bool value
  static Future<void> setBool(String key, bool value) async {
    await _prefs?.setBool(key, value);
  }

  /// Get double value
  static double? getDouble(String key) {
    return _prefs?.getDouble(key);
  }

  /// Set double value
  static Future<void> setDouble(String key, double value) async {
    await _prefs?.setDouble(key, value);
  }

  /// Clear all preferences
  static Future<void> clearAll() async {
    await _prefs?.clear();
  }

  /// Remove specific key
  static Future<void> remove(String key) async {
    await _prefs?.remove(key);
  }
}
