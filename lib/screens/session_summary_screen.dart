import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../services/bluetooth_service.dart';
import '../providers/current_session_provider.dart';
import '../providers/session_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/app_theme.dart';
import '../widgets/mini_graph_view.dart';
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

    return Stack(
      children: [
        Scaffold(
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
                      onPressed: () async {
                        HapticFeedback.lightImpact();
                        // On Web: skip the device list screen, Chrome handles device selection
                        if (kIsWeb) {
                      // Start scan - this shows Chrome popup
                      // Loading overlay will automatically show when device is found
                      // (via isConnectingToDevice flag in BluetoothService)
                      await bluetoothService.startScan();
                      
                      // Show success message when device becomes ready
                      if (context.mounted && bluetoothService.isDeviceReady) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle, color: Colors.white),
                                const SizedBox(width: 8),
                                Text('Connected to ${bluetoothService.connectedDeviceName ?? "Calmwand"}'),
                              ],
                            ),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    } else {
                      // On native: show device list
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => const BluetoothConnectionScreen(),
                      );
                    }
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
    ),
    // Loading overlay when connecting to device on Web
    if (kIsWeb && bluetoothService.isConnectingToDevice && !bluetoothService.isDeviceReady)
      Container(
        color: Colors.black54,
        child: const _ConnectionLoadingOverlay(),
      ),
    ],
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
        const SizedBox(height: 20),
        // Temperature graph
        Container(
          width: 280,
          height: 120,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300, width: 1),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white.withValues(alpha: 0.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: MiniGraphView(data: session.temperatureSet),
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

/// Loading overlay with spinning appstore.png icon
class _ConnectionLoadingOverlay extends StatefulWidget {
  const _ConnectionLoadingOverlay();

  @override
  State<_ConnectionLoadingOverlay> createState() => _ConnectionLoadingOverlayState();
}

class _ConnectionLoadingOverlayState extends State<_ConnectionLoadingOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Spinning appstore_trans.png icon
          RotationTransition(
            turns: _controller,
            child: Image.network(
              'icons/appstore_trans.png',
              width: 120,
              height: 120,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.spa,
                  size: 120,
                  color: Colors.white,
                );
              },
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Connecting to Calmwand...',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Discovering services (This may take a few seconds)',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
