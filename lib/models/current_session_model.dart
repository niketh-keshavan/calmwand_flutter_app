/// Model for tracking the currently active session
/// Ported from CurrentSessionModel in Classes.swift
class CurrentSessionModel {
  /// Temperature readings collected during the session
  List<double> temperatureSet = [];

  /// Time elapsed in seconds
  int timeElapsed = 0;

  /// Session ID received from Arduino device
  int? sessionId;

  /// Clear all session data
  void reset() {
    temperatureSet.clear();
    timeElapsed = 0;
    sessionId = null;
  }

  @override
  String toString() {
    return 'CurrentSessionModel(timeElapsed: $timeElapsed, sessionId: $sessionId, readings: ${temperatureSet.length})';
  }
}
