import 'package:flutter/foundation.dart';
import '../models/session_model.dart';
import '../models/user_settings_model.dart';
import '../services/storage_service.dart';
import '../services/cloud_session_service.dart';
import '../utils/regression_calculator.dart';

/// Session provider for managing session array and operations
/// Ported from SessionViewModel in Classes.swift
class SessionProvider extends ChangeNotifier {
  List<SessionModel> _sessionArray = [];
  final UserSettingsModel _userSettings;
  CloudSessionService? _cloudService;
  bool _isLoadingFromCloud = false;

  List<SessionModel> get sessionArray => List.unmodifiable(_sessionArray);
  bool get isLoadingFromCloud => _isLoadingFromCloud;

  SessionProvider(this._userSettings) {
    _loadSessions();
  }

  /// Set the cloud service for syncing (called after login)
  void setCloudService(CloudSessionService? service) {
    final wasLoggedIn = _cloudService?.isLoggedIn ?? false;
    _cloudService = service;
    
    // If user just logged in, fetch cloud sessions
    if (service != null && service.isLoggedIn && !wasLoggedIn) {
      fetchAndMergeCloudSessions();
    }
  }

  /// Fetch sessions from cloud and merge with local storage
  Future<void> fetchAndMergeCloudSessions() async {
    if (_cloudService == null || !_cloudService!.isLoggedIn) {
      print('⏭️ Skip cloud fetch: not logged in');
      return;
    }

    _isLoadingFromCloud = true;
    notifyListeners();

    try {
      print('☁️ Fetching sessions from cloud...');
      final cloudSessions = await _cloudService!.fetchSessions().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('⏱️ Cloud fetch timed out');
          return <SessionModel>[];
        },
      );

      if (cloudSessions.isNotEmpty) {
        // Create a map of existing sessions by their unique key
        final existingSessionsMap = <String, int>{};
        for (int i = 0; i < _sessionArray.length; i++) {
          final key = '${_sessionArray[i].sessionNumber}_${_sessionArray[i].timestamp.millisecondsSinceEpoch}';
          existingSessionsMap[key] = i;
        }

        // Merge cloud sessions: update existing or add new
        int added = 0;
        int updated = 0;
        for (final cloudSession in cloudSessions) {
          final key = '${cloudSession.sessionNumber}_${cloudSession.timestamp.millisecondsSinceEpoch}';
          
          if (existingSessionsMap.containsKey(key)) {
            // Update existing session (e.g., comment might have been updated on another device)
            final index = existingSessionsMap[key]!;
            if (_sessionArray[index].comment != cloudSession.comment) {
              _sessionArray[index] = cloudSession;
              await StorageService.updateSession(index, cloudSession);
              updated++;
            }
          } else {
            // Add new session from cloud
            _sessionArray.add(cloudSession);
            await StorageService.addSession(cloudSession);
            added++;
          }
        }

        if (added > 0 || updated > 0) {
          print('✅ Added $added, updated $updated sessions from cloud');
          // Sort by timestamp descending
          _sessionArray.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          notifyListeners();
        } else {
          print('✅ Cloud sessions already in sync');
        }
      }
    } catch (e) {
      print('❌ Error fetching cloud sessions: $e');
    } finally {
      _isLoadingFromCloud = false;
      notifyListeners();
    }
  }

  /// Load sessions from storage
  Future<void> _loadSessions() async {
    _sessionArray = StorageService.getSessions();
    notifyListeners();
  }

  /// Public method to reload sessions from storage
  Future<void> reloadSessions() async {
    await _loadSessions();
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

    // Sync to cloud if logged in
    await _syncSessionToCloud(newSession);
  }

  /// Sync a single session to cloud
  Future<void> _syncSessionToCloud(SessionModel session) async {
    if (_cloudService != null && _cloudService!.isLoggedIn) {
      await _cloudService!.saveSession(session);
    }
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
      
      // Sync updated session to cloud
      await _syncSessionToCloud(session);
    }
  }

  /// Update a specific session by reference
  Future<void> updateSessionByModel(SessionModel session) async {
    final index = _sessionArray.indexWhere((s) => 
      s.sessionNumber == session.sessionNumber && 
      s.timestamp == session.timestamp
    );
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
      
      // Sync updated session to cloud
      await _syncSessionToCloud(_sessionArray[index]);
    }
  }

  /// Remove last session
  Future<void> removeLastSession() async {
    if (_sessionArray.isNotEmpty) {
      final session = _sessionArray.last;
      _sessionArray.removeLast();
      notifyListeners();
      await _saveSessions();
      
      // Delete from cloud
      if (_cloudService != null && _cloudService!.isLoggedIn) {
        await _cloudService!.deleteSession(session);
      }
    }
  }

  /// Remove session at index
  Future<void> removeSession(int index) async {
    if (index >= 0 && index < _sessionArray.length) {
      final session = _sessionArray[index];
      _sessionArray.removeAt(index);
      notifyListeners();
      await _saveSessions();
      
      // Delete from cloud
      if (_cloudService != null && _cloudService!.isLoggedIn) {
        await _cloudService!.deleteSession(session);
      }
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
