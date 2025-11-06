import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/bluetooth_service.dart';
import '../providers/current_session_provider.dart';
import '../providers/session_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/app_theme.dart';
import 'bluetooth_connection_screen.dart';

/// Session summary screen - main session interface
/// Ported from SessionSummary.swift
class SessionSummaryScreen extends StatefulWidget {
  const SessionSummaryScreen({super.key});

  @override
  State<SessionSummaryScreen> createState() => _SessionSummaryScreenState();
}

class _SessionSummaryScreenState extends State<SessionSummaryScreen> {
  bool _sessionCompleted = false;
  double? _lastScore;

  @override
  Widget build(BuildContext context) {
    final bluetoothService = context.watch<BluetoothService>();
    final currentSession = context.watch<CurrentSessionProvider>();
    final sessionProvider = context.read<SessionProvider>();
    final settings = context.read<SettingsProvider>();

    final connectionLabel = _getConnectionLabel(bluetoothService);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Connection button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 50, 20, 0),
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => const BluetoothConnectionScreen(),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.8),
                    foregroundColor: Colors.blue.shade700,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    connectionLabel,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // Main content area
              if (currentSession.isSessionActive)
                _buildActiveSession(currentSession)
              else if (_sessionCompleted)
                _buildSessionResult()
              else
                _buildIdleState(),

              const Spacer(),

              // Start/End button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ElevatedButton(
                  onPressed: () => _toggleSession(
                    context,
                    currentSession,
                    sessionProvider,
                    bluetoothService,
                    settings,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.8),
                    foregroundColor: Colors.blue.shade700,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(currentSession.isSessionActive
                          ? Icons.pause_circle
                          : Icons.play_circle),
                      const SizedBox(width: 8),
                      Text(
                        currentSession.isSessionActive
                            ? 'END SESSION'
                            : 'START SESSION',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _getConnectionLabel(BluetoothService service) {
    if (service.isConnected) {
      final name = service.connectedDeviceName;
      return name != null ? 'CONNECTED to $name' : 'CONNECTED';
    }
    if (service.isConnecting) return 'CONNECTING…';
    return 'CONNECT';
  }

  Widget _buildIdleState() {
    return const Text(
      'Press "Start Session" to begin',
      style: TextStyle(
        fontSize: 18,
        color: Colors.black54,
      ),
    );
  }

  Widget _buildActiveSession(CurrentSessionProvider session) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Timer display
        Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Colors.blue.shade400, Colors.purple.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '${session.timeElapsed ~/ 60} min',
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Temperature readings count
        Text(
          '${session.temperatureSet.length} readings',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildSessionResult() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_lastScore != null) ...[
          Text(
            _getFeedbackMessage(_lastScore!),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _getFeedbackColor(_lastScore!),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade200,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _lastScore!.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 55,
                      fontWeight: FontWeight.w900,
                      color: _getFeedbackColor(_lastScore!),
                    ),
                  ),
                  const Text(
                    'SCORE',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Keep up the great work!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ] else
          const Text(
            'Session data unavailable',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
      ],
    );
  }

  String _getFeedbackMessage(double score) {
    if (score <= 50) return 'Keep going!';
    if (score <= 80) return 'Nice job!';
    return 'Congratulations!';
  }

  Color _getFeedbackColor(double score) {
    if (score <= 50) return Colors.red;
    if (score <= 80) return Colors.orange;
    return Colors.green;
  }

  void _toggleSession(
    BuildContext context,
    CurrentSessionProvider currentSession,
    SessionProvider sessionProvider,
    BluetoothService bluetoothService,
    SettingsProvider settings,
  ) async {
    HapticFeedback.mediumImpact();

    if (currentSession.isSessionActive) {
      // End session
      currentSession.endSession();

      // Calculate temperature change
      final tempSet = currentSession.temperatureSet;
      final tempChange = tempSet.isNotEmpty && tempSet.length > 1
          ? tempSet.last - tempSet.first
          : 0.0;

      // Get session data
      final inhaleTime =
          (double.tryParse(bluetoothService.inhaleData) ?? 4000) / 1000;
      final exhaleTime =
          (double.tryParse(bluetoothService.exhaleData) ?? 9500) / 1000;

      final sessionId = currentSession.sessionId;

      if (sessionId != null) {
        // Add session
        sessionProvider.addSession(
          sessionId: sessionId,
          duration: currentSession.timeElapsed,
          temperatureChange: tempChange,
          inhaleTime: inhaleTime,
          exhaleTime: exhaleTime,
          tempSetData: tempSet,
        );

        // Get latest session score
        final latestSession = sessionProvider.latestSession;
        setState(() {
          _lastScore = latestSession?.score;
          _sessionCompleted = true;
        });
      } else {
        print('❗️No session ID received, cannot add session.');
      }
    } else {
      // Start session
      await bluetoothService.startArduinoSession();

      // Sync SessionID from BluetoothService to CurrentSessionProvider
      final receivedSessionId = bluetoothService.sessionId;
      if (receivedSessionId != null) {
        currentSession.sessionId = receivedSessionId;
        print('✅ Session started with ID: $receivedSessionId');
      } else {
        print('⚠️ Warning: SessionID not received from Arduino');
      }

      currentSession.startSession(
        recordingInterval: settings.interval,
        onTick: () {
          // Record temperature every interval
          final tempData = bluetoothService.temperatureData;
          final temp = (double.tryParse(tempData) ?? 0) / 100;
          currentSession.addTemperatureReading(temp);

          // Print temperature reading to terminal
          print('📊 Reading: ${temp.toStringAsFixed(2)}°F');
        },
      );

      setState(() {
        _sessionCompleted = false;
        _lastScore = null;
      });
    }
  }
}
