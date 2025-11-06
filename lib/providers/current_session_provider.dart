import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/current_session_model.dart';

/// Provider for managing the currently active session
/// Ported from CurrentSessionModel and related timer logic
class CurrentSessionProvider extends ChangeNotifier {
  final CurrentSessionModel _model = CurrentSessionModel();

  Timer? _timer;
  bool _isSessionActive = false;

  // Getters
  List<double> get temperatureSet => _model.temperatureSet;
  int get timeElapsed => _model.timeElapsed;
  int? get sessionId => _model.sessionId;
  bool get isSessionActive => _isSessionActive;

  // Setters
  set sessionId(int? id) {
    _model.sessionId = id;
    notifyListeners();
  }

  /// Start session timer
  void startSession({required int recordingInterval, required Function() onTick}) {
    if (_isSessionActive) return;

    _isSessionActive = true;
    _model.reset();
    notifyListeners();

    // Timer ticks every second
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _model.timeElapsed++;

      // Call onTick every recording interval to capture temperature
      if (_model.timeElapsed % recordingInterval == 0) {
        onTick();
      }

      notifyListeners();
    });
  }

  /// End session timer
  void endSession() {
    _timer?.cancel();
    _timer = null;
    _isSessionActive = false;
    notifyListeners();
  }

  /// Add temperature reading
  void addTemperatureReading(double temperature) {
    _model.temperatureSet.add(temperature);
    notifyListeners();
  }

  /// Reset session data
  void reset() {
    _model.reset();
    _timer?.cancel();
    _timer = null;
    _isSessionActive = false;
    notifyListeners();
  }

  /// Format time as MM:SS
  String getFormattedTime() {
    final minutes = _model.timeElapsed ~/ 60;
    final seconds = _model.timeElapsed % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
