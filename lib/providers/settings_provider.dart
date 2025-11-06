import 'package:flutter/foundation.dart';
import '../models/user_settings_model.dart';
import '../services/storage_service.dart';

/// Provider for user settings
/// Ported from UserSettingsModel in Classes.swift
class SettingsProvider extends ChangeNotifier {
  UserSettingsModel _settings;

  SettingsProvider() : _settings = StorageService.getSettings() {
    _loadSettings();
  }

  UserSettingsModel get settings => _settings;
  int get interval => _settings.interval;
  bool get isCelsius => _settings.isCelsius;
  String get temperatureUnit => _settings.temperatureUnit;

  /// Load settings from storage
  Future<void> _loadSettings() async {
    _settings = StorageService.getSettings();
    notifyListeners();
  }

  /// Save settings to storage
  Future<void> _saveSettings() async {
    await StorageService.saveSettings(_settings);
  }

  /// Update temperature recording interval
  Future<void> setInterval(int interval) async {
    if (interval > 0) {
      _settings = _settings.copyWith(interval: interval);
      notifyListeners();
      await _saveSettings();
    }
  }

  /// Toggle temperature unit
  Future<void> toggleTemperatureUnit() async {
    _settings = _settings.copyWith(isCelsius: !_settings.isCelsius);
    notifyListeners();
    await _saveSettings();
  }

  /// Set temperature unit
  Future<void> setTemperatureUnit(bool celsius) async {
    _settings = _settings.copyWith(isCelsius: celsius);
    notifyListeners();
    await _saveSettings();
  }

  /// Convert temperature based on current setting
  double convertTemperature(double fahrenheit) {
    return _settings.convertTemperature(fahrenheit);
  }
}
