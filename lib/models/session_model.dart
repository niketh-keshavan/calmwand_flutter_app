import 'package:hive/hive.dart';

part 'session_model.g.dart';

/// Model representing a single Calmwand session
/// Ported from SessionModel.swift
@HiveType(typeId: 0)
class SessionModel {
  /// Unique session identifier
  @HiveField(0)
  final int sessionNumber;

  /// Session duration in seconds
  @HiveField(1)
  final int duration;

  /// Temperature change during the session (Fahrenheit)
  @HiveField(2)
  final double temperatureChange;

  /// Array of temperature readings (Fahrenheit)
  @HiveField(3)
  final List<double> tempSetData;

  /// Inhale time in seconds
  @HiveField(4)
  final double inhaleTime;

  /// Exhale time in seconds
  @HiveField(5)
  final double exhaleTime;

  /// Regression parameter A (exponential curve fitting)
  @HiveField(6)
  final double? regressionA;

  /// Regression parameter B (exponential curve fitting)
  @HiveField(7)
  final double? regressionB;

  /// Regression parameter k (exponential curve fitting)
  @HiveField(8)
  final double? regressionK;

  /// Calculated session score (0-100)
  @HiveField(9)
  final double? score;

  /// User comment for this session
  @HiveField(10)
  String comment;

  /// Timestamp when session was created
  @HiveField(11)
  final DateTime timestamp;

  SessionModel({
    required this.sessionNumber,
    required this.duration,
    required this.temperatureChange,
    required this.tempSetData,
    required this.inhaleTime,
    required this.exhaleTime,
    this.regressionA,
    this.regressionB,
    this.regressionK,
    this.score,
    this.comment = '',
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Convert to JSON for storage/export
  Map<String, dynamic> toJson() {
    return {
      'sessionNumber': sessionNumber,
      'duration': duration,
      'temperatureChange': temperatureChange,
      'tempSetData': tempSetData,
      'inhaleTime': inhaleTime,
      'exhaleTime': exhaleTime,
      'regressionA': regressionA,
      'regressionB': regressionB,
      'regressionK': regressionK,
      'score': score,
      'comment': comment,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Create from JSON (supports legacy format)
  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      sessionNumber: json['sessionNumber'] ?? json['id'] ?? 0,
      duration: json['duration'] ?? 0,
      temperatureChange: (json['temperatureChange'] ?? 0).toDouble(),
      tempSetData: (json['tempSetData'] as List?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      inhaleTime: (json['inhaleTime'] ?? 0).toDouble(),
      exhaleTime: (json['exhaleTime'] ?? 0).toDouble(),
      regressionA: json['regressionA']?.toDouble(),
      regressionB: json['regressionB']?.toDouble(),
      regressionK: json['regressionK']?.toDouble() ?? json['regressionk']?.toDouble(), // Support legacy format
      score: json['score']?.toDouble(),
      comment: json['comment'] ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }

  /// Create a copy with updated fields
  SessionModel copyWith({
    int? sessionNumber,
    int? duration,
    double? temperatureChange,
    List<double>? tempSetData,
    double? inhaleTime,
    double? exhaleTime,
    double? regressionA,
    double? regressionB,
    double? regressionK,
    double? score,
    String? comment,
    DateTime? timestamp,
  }) {
    return SessionModel(
      sessionNumber: sessionNumber ?? this.sessionNumber,
      duration: duration ?? this.duration,
      temperatureChange: temperatureChange ?? this.temperatureChange,
      tempSetData: tempSetData ?? this.tempSetData,
      inhaleTime: inhaleTime ?? this.inhaleTime,
      exhaleTime: exhaleTime ?? this.exhaleTime,
      regressionA: regressionA ?? this.regressionA,
      regressionB: regressionB ?? this.regressionB,
      regressionK: regressionK ?? this.regressionK,
      score: score ?? this.score,
      comment: comment ?? this.comment,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  String toString() {
    return 'SessionModel(sessionNumber: $sessionNumber, duration: $duration, score: $score)';
  }
}

/// Extension for sanitizing non-finite values
extension DoubleExtension on double {
  /// Returns null if the value is not finite (NaN, Infinity, -Infinity)
  double? get finiteOrNull => isFinite ? this : null;
}
