import 'package:hive/hive.dart';

part 'user_settings_model.g.dart';

/// User settings and preferences
/// Ported from UserSettingsModel in Classes.swift
@HiveType(typeId: 1)
class UserSettingsModel {
  /// Temperature recording interval in seconds (default: 5)
  @HiveField(0)
  int interval;

  /// Whether to display temperature in Celsius (default: false = Fahrenheit)
  @HiveField(1)
  bool isCelsius;

  UserSettingsModel({
    this.interval = 5,
    this.isCelsius = false,
  });

  /// Convert Fahrenheit to Celsius
  double toCelsius(double fahrenheit) {
    return (fahrenheit - 32) * 5 / 9;
  }

  /// Convert Celsius to Fahrenheit
  double toFahrenheit(double celsius) {
    return celsius * 9 / 5 + 32;
  }

  /// Convert temperature based on current setting
  double convertTemperature(double fahrenheit) {
    return isCelsius ? toCelsius(fahrenheit) : fahrenheit;
  }

  /// Get temperature unit string
  String get temperatureUnit => isCelsius ? '°C' : '°F';

  /// Create a copy with updated fields
  UserSettingsModel copyWith({
    int? interval,
    bool? isCelsius,
  }) {
    return UserSettingsModel(
      interval: interval ?? this.interval,
      isCelsius: isCelsius ?? this.isCelsius,
    );
  }

  @override
  String toString() {
    return 'UserSettingsModel(interval: $interval, isCelsius: $isCelsius)';
  }
}
