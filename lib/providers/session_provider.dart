import 'package:flutter/foundation.dart';
import '../models/session_model.dart';
import '../models/user_settings_model.dart';
import '../services/storage_service.dart';
import '../utils/regression_calculator.dart';

/// Session provider for managing session array and operations
/// Ported from SessionViewModel in Classes.swift
class SessionProvider extends ChangeNotifier {
  List<SessionModel> _sessionArray = [];
  final UserSettingsModel _userSettings;

  List<SessionModel> get sessionArray => List.unmodifiable(_sessionArray);

  SessionProvider(this._userSettings) {
    _loadSessions();
  }

  /// Load sessions from storage
  Future<void> _loadSessions() async {
    _sessionArray = StorageService.getSessions();
    notifyListeners();
  }

  /// Save sessions to storage
  Future<void> _saveSessions() async {
    // Sanitize non-finite values before saving
    final sanitized = _sessionArray.map((session) {
      return session.copyWith(
        score: session.score?.finiteOrNull,
        regressionA: session.regressionA?.finiteOrNull,
        regressionB: session.regressionB?.finiteOrNull,
        regressionK: session.regressionK?.finiteOrNull,
      );
    }).toList();

    // Clear and re-add all sessions
    await StorageService.deleteAllSessions();
    for (final session in sanitized) {
      await StorageService.addSession(session);
    }
  }

  /// Add a new session with automatic regression calculation
  Future<void> addSession({
    required int sessionId,
    required int duration,
    required double temperatureChange,
    required double inhaleTime,
    required double exhaleTime,
    required List<double> tempSetData,
  }) async {
    // Calculate regression parameters
    final params = RegressionCalculator.calculateRegressionParameters(
      duration: duration,
      tempSet: tempSetData,
      interval: _userSettings.interval,
    );

    if (params == null) {
      print('Failed to calculate regression parameters.');
      return;
    }

    final kAbs = params.k.abs();

    // Calculate score
    final rawScore = RegressionCalculator.calculateScore(
      a: params.a,
      b: params.b,
      k: kAbs,
      sessionDuration: duration,
    );

    // Make score safe
    final safeScore = (rawScore?.isFinite ?? false) ? rawScore : null;

    // Create new session
    final newSession = SessionModel(
      sessionNumber: sessionId,
      duration: duration,
      temperatureChange: temperatureChange,
      tempSetData: tempSetData,
      inhaleTime: inhaleTime,
      exhaleTime: exhaleTime,
      regressionA: params.a,
      regressionB: params.b,
      regressionK: kAbs,
      score: safeScore,
      comment: '',
    );

    _sessionArray.add(newSession);
    notifyListeners();
    await _saveSessions();
  }

  /// Update regression parameters and scores for all sessions
  Future<void> updateAllSessions() async {
    for (int i = 0; i < _sessionArray.length; i++) {
      _sessionArray[i] = RegressionCalculator.updateSessionWithRegressionData(
        session: _sessionArray[i],
        interval: _userSettings.interval,
      );
    }
    notifyListeners();
    await _saveSessions();
  }

  /// Update a specific session by index
  Future<void> updateSession(int index, SessionModel session) async {
    if (index >= 0 && index < _sessionArray.length) {
      _sessionArray[index] = session;
      notifyListeners();
      await _saveSessions();
    }
  }

  /// Update a specific session by reference
  Future<void> updateSessionByModel(SessionModel session) async {
    final index = _sessionArray.indexWhere((s) => s.sessionNumber == session.sessionNumber);
    if (index >= 0) {
      await updateSession(index, session);
    }
  }

  /// Update session comment
  Future<void> updateSessionComment(int index, String comment) async {
    if (index >= 0 && index < _sessionArray.length) {
      _sessionArray[index] = _sessionArray[index].copyWith(comment: comment);
      notifyListeners();
      await _saveSessions();
    }
  }

  /// Remove last session
  Future<void> removeLastSession() async {
    if (_sessionArray.isNotEmpty) {
      _sessionArray.removeLast();
      notifyListeners();
      await _saveSessions();
    }
  }

  /// Remove session at index
  Future<void> removeSession(int index) async {
    if (index >= 0 && index < _sessionArray.length) {
      _sessionArray.removeAt(index);
      notifyListeners();
      await _saveSessions();
    }
  }

  /// Delete a specific session by reference
  Future<void> deleteSession(SessionModel session) async {
    final index = _sessionArray.indexWhere((s) => s.sessionNumber == session.sessionNumber);
    if (index >= 0) {
      await removeSession(index);
    }
  }

  /// Remove all sessions
  Future<void> removeAllSessions() async {
    _sessionArray.clear();
    notifyListeners();
    await _saveSessions();
  }

  /// Get session count
  int get sessionCount => _sessionArray.length;

  /// Get latest session
  SessionModel? get latestSession =>
      _sessionArray.isNotEmpty ? _sessionArray.last : null;
}
