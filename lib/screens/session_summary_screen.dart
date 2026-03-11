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

class _SessionSummaryScreenState extends State<SessionSummaryScreen>
    with TickerProviderStateMixin {
  bool _sessionCompleted = false;
  double? _lastScore;

  // ---JOSEPHINES ADDITION START---

  // ── Temperature thresholds matching Arduino ColorArray (70–98°F) ──────────
  static const double _greenLow = 82.9;
  static const double _greenHigh = 85.2;
  static const double _blueLow = 85.2;
  static const double _blueHigh = 87.5;
  static const double _purpleLow = 87.5;
  static const double _purpleHigh = 89.8;
  static const double _whiteLow = 89.8;

  // ── Milestone tracking (fires once per session per zone) ─────────────────
  bool _celebratedGreen = false;
  bool _celebratedBlue = false;
  bool _celebratedPurple = false;
  bool _celebratedWhite = false;
  int _streakCount = 0;

  // ---JOSEPHINES ADDITION START---
  // ── Zone time tracking — seconds spent in each zone ──────────────────────
  int _secondsInGreen = 0;
  int _secondsInBlue = 0;
  int _secondsInPurple = 0;
  int _secondsInWhite = 0;
  // Saved at end of session for results screen
  int _lastSecondsInGreen = 0;
  int _lastSecondsInBlue = 0;
  int _lastSecondsInPurple = 0;
  int _lastSecondsInWhite = 0;
  // ---JOSEPHINES ADDITION END---

  // ---JOSEPHINES ADDITION START---
  // ── Daily inspirational quote ─────────────────────────────────────────────
  // One quote per day — cycles through the list based on day of year
  static const List<String> _quotes = [
    '"Calm is a superpower." ✨',
    '"Breathe. You are exactly where you need to be." 🌿',
    '"Peace begins with a single breath." 💙',
    '"Your body knows how to calm itself — trust it." 🏆',
    '"Every exhale is a release. Every inhale, a new start." 🌸',
    '"Stillness is not emptiness. It is presence." 🌙',
    '"You don\'t have to control your thoughts. Just don\'t let them control you." 🧘',
    '"The quieter you become, the more you can hear." 🌊',
    '"This moment is enough." 🌿',
    '"Tension is who you think you should be. Relaxation is who you are." 💛',
    '"Almost everything will work again if you unplug it for a few minutes." 🔌',
    '"Within you, there is a stillness and a sanctuary." 🕊️',
    '"Breathe deeply, until sweet air extinguishes the burn of fear." 🌬️',
    '"The present moment is the only moment available to us." 🌅',
  ];

  String get _dailyQuote {
    final dayOfYear = DateTime.now()
        .difference(DateTime(DateTime.now().year))
        .inDays;
    return _quotes[dayOfYear % _quotes.length];
  }
  // ---JOSEPHINES ADDITION END---

  // ── Live wand color for breathing circle ─────────────────────────────────
  Color _wandColor = const Color(0xFFBDBDBD);

  // ── Temperature history for color bar graph ───────────────────────────────
  // ---JOSEPHINES ADDITION START---
  // Now stores fractional color position (e.g. 7.4) instead of integer index
  // so the EQ graph can show smooth partial-bar highlighting
  final List<double> _tempHistory = [];
  List<double> _lastTempHistory = [];
  // ---JOSEPHINES ADDITION END---
  // Also save raw temps for the results MiniGraphView
  List<double> _lastTempSet = [];

  // ── Breathing animation (4500ms inhale, 9000ms exhale = 13500ms cycle) ───
  static const int _inhaleMs = 4500;
  static const int _exhaleMs = 9000;
  late AnimationController _breathController;
  late Animation<double> _breathAnim;

  // ── Other animations ──────────────────────────────────────────────────────

  // ── Josephine's soft palette ──────────────────────────────────────────────
  static const Color _softBlue = Color(0xFF89B4D4);
  static const Color _softPurple = Color(0xFFB39DDB);
  static const Color _softGreen = Color(0xFF81C784);
  static const Color _softWhite = Color(0xFFF3F6FB);

  // ── 14 rainbow colors matching the Arduino ColorArray exactly ────────────
  static const List<Color> _rainbowColors = [
    Color(0xFF9E9E9E), // 0  grey
    Color(0xFF7B1FA2), // 1  dark purple
    Color(0xFFF44336), // 2  red
    Color(0xFFFF5722), // 3  red-orange
    Color(0xFFFF9800), // 4  orange
    Color(0xFFFFEB3B), // 5  yellow
    Color(0xFF8BC34A), // 6  yellow-green
    Color(0xFF4CAF50), // 7  green
    Color(0xFF00E676), // 8  bright green
    Color(0xFF00BCD4), // 9  cyan
    Color(0xFF2196F3), // 10 blue
    Color(0xFF3F51B5), // 11 indigo
    Color(0xFF9C27B0), // 12 purple
    Color(0xFFFFFFFF), // 13 white
  ];

  // ---JOSEPHINES ADDITION END---

  @override
  void initState() {
    super.initState();

    // ---JOSEPHINES ADDITION START---
    // Breathing circle — inhale is 1/3 of cycle, exhale is 2/3
    _breathController = AnimationController(
      duration: const Duration(milliseconds: _inhaleMs + _exhaleMs),
      vsync: this,
    );
    _breathAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.55,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1, // inhale — 1/3 of cycle
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.55,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 2, // exhale — 2/3 of cycle
      ),
    ]).animate(_breathController);

    // ---JOSEPHINES ADDITION END---
  }

  @override
  void dispose() {
    // ---JOSEPHINES ADDITION START---
    _breathController.dispose();
    // ---JOSEPHINES ADDITION END---
    super.dispose();
  }

  // ---JOSEPHINES ADDITION START---

  // ── Maps temperature to a 0–13 color index (used for the bar graph) ──────
  int _tempToColorIndex(double temp) {
    const double lower = 70.0;
    const double upper = 98.0;
    const int count = 14;
    if (temp <= lower) return 0;
    if (temp >= upper) return count - 1;
    return ((temp - lower) / (upper - lower) * (count - 1)).round();
  }

  // ---JOSEPHINES ADDITION START---
  // ── Smooth color interpolation — blends between the 14 rainbow colors ─────
  // Instead of snapping to 1 of 14 colors, this lerps smoothly between
  // neighbors so the circle transitions gradually as temperature changes.
  Color _tempToSmoothColor(double temp) {
    const double lower = 70.0;
    const double upper = 98.0;
    if (temp <= lower) return _rainbowColors[0];
    if (temp >= upper) return _rainbowColors[13];
    // fractional position e.g. 7.4 means 40% between color 7 and color 8
    final double fraction = (temp - lower) / (upper - lower) * 13.0;
    final int lo = fraction.floor().clamp(0, 12);
    final double t = fraction - lo; // 0.0 → 1.0
    return Color.lerp(_rainbowColors[lo], _rainbowColors[lo + 1], t)!;
  }

  // ── Also returns fractional index for the EQ graph ────────────────────────
  double _tempToColorFraction(double temp) {
    const double lower = 70.0;
    const double upper = 98.0;
    if (temp <= lower) return 0.0;
    if (temp >= upper) return 13.0;
    return (temp - lower) / (upper - lower) * 13.0;
  }
  // ---JOSEPHINES ADDITION END---

  // ── Zone time accumulator — called every tick ────────────────────────────
  // No popups during session; just quietly counts seconds in each zone.
  void _accumulateZoneTime(double temp, int intervalSeconds) {
    if (temp >= _whiteLow) {
      _secondsInWhite += intervalSeconds;
    } else if (temp >= _purpleLow) {
      _secondsInPurple += intervalSeconds;
    } else if (temp >= _blueLow) {
      _secondsInBlue += intervalSeconds;
    } else if (temp >= _greenLow) {
      _secondsInGreen += intervalSeconds;
    }
  }

  // ── Called every tick — updates color, logs history, checks milestones ────
  void _checkColorZone(double temp, int intervalSeconds) {
    setState(() {
      // Smooth color for the breathing circle
      _wandColor = _tempToSmoothColor(temp);
      // Fractional position for the gradient slider dot
      _tempHistory.add(_tempToColorFraction(temp));
    });
    // Quietly accumulate time in each zone — no popups
    _accumulateZoneTime(temp, intervalSeconds);
    // Track which zones were reached for results achievements
    if (temp >= _greenLow && temp < _greenHigh && !_celebratedGreen) {
      _celebratedGreen = true;
      _streakCount++;
    }
    if (temp >= _blueLow && temp < _blueHigh && !_celebratedBlue) {
      _celebratedBlue = true;
      _streakCount++;
    }
    if (temp >= _purpleLow && temp < _purpleHigh && !_celebratedPurple) {
      _celebratedPurple = true;
      _streakCount++;
    }
    if (temp >= _whiteLow && !_celebratedWhite) {
      _celebratedWhite = true;
      _streakCount++;
    }
  }
  // ---JOSEPHINES ADDITION END---

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
          backgroundColor: _softWhite,
          body: Container(
            decoration: const BoxDecoration(
              // ---JOSEPHINES ADDITION START---
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFDCEEFA), // soft sky blue
                  Color(0xFFEDE7F6), // soft lavender
                  Color(0xFFF1F8E9), // soft mint white
                ],
              ),
              // ---JOSEPHINES ADDITION END---
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // ── Connection button ───────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 50, 20, 0),
                    child: ElevatedButton(
                      onPressed: () async {
                        HapticFeedback.lightImpact();
                        if (kIsWeb) {
                          await bluetoothService.startScan();
                          if (context.mounted &&
                              bluetoothService.isDeviceReady) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Connected to ${bluetoothService.connectedDeviceName ?? "Calmwand"}',
                                    ),
                                  ],
                                ),
                                // ---JOSEPHINES ADDITION START---
                                backgroundColor: _softGreen,
                                // ---JOSEPHINES ADDITION END---
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        } else {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) =>
                                const BluetoothConnectionScreen(),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        // ---JOSEPHINES ADDITION START---
                        backgroundColor: _softBlue.withValues(alpha: 0.85),
                        foregroundColor: Colors.white,
                        // ---JOSEPHINES ADDITION END---
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
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

                  // ── Main content ────────────────────────────────────────
                  if (currentSession.isSessionActive)
                    _buildActiveSession(currentSession)
                  else if (_sessionCompleted)
                    _buildSessionResult()
                  else
                    _buildIdleState(),

                  const Spacer(),

                  // ── Start / End button ──────────────────────────────────
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
                        // ---JOSEPHINES ADDITION START---
                        backgroundColor: currentSession.isSessionActive
                            ? _softGreen.withValues(alpha: 0.9)
                            : _softPurple.withValues(alpha: 0.9),
                        foregroundColor: Colors.white,
                        // ---JOSEPHINES ADDITION END---
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            currentSession.isSessionActive
                                ? Icons.pause_circle
                                : Icons.play_circle,
                          ),
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

        // ── Loading overlay ─────────────────────────────────────────────────
        if (kIsWeb &&
            bluetoothService.isConnectingToDevice &&
            !bluetoothService.isDeviceReady)
          Container(
            color: Colors.black54,
            child: const _ConnectionLoadingOverlay(),
          ),

        // ---JOSEPHINES ADDITION END---
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

  // ---JOSEPHINES ADDITION START---
  // Formats elapsed seconds as a plain readable string e.g. '1 min 23s'
  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m == 0) return '${s}s';
    return "$m min ${s.toString().padLeft(2, "0")}s";
  }
  // ---JOSEPHINES ADDITION END---

  Widget _buildIdleState() {
    // ---JOSEPHINES ADDITION START---
    // Shows a daily inspirational quote — changes every day automatically
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('🌿', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 16),
        // Daily quote card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: _softPurple.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            _dailyQuote,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF5C6BC0),
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Press "Start Session" to begin',
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
    // ---JOSEPHINES ADDITION END---
  }

  Widget _buildActiveSession(CurrentSessionProvider session) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ---JOSEPHINES ADDITION START---

        // ── Tiny plain timer — just a subtle number, no circle ───────────
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            _formatTime(session.timeElapsed),
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF9E9E9E),
              fontWeight: FontWeight.w400,
            ),
          ),
        ),

        // ── Big breathing circle — the centrepiece ─────────────────────────
        // Color matches live wand temperature. Inhale/Exhale text inside.
        // Pulses in sync with wand breath pacer: 4.5s in, 9s out.
        AnimatedBuilder(
          animation: _breathAnim,
          builder: (context, child) {
            final scale = _breathAnim.value;
            final isInhale = _breathController.value < (1 / 3);
            return Stack(
              alignment: Alignment.center,
              children: [
                // Outer soft glow ring
                Container(
                  width: 230 * scale,
                  height: 230 * scale,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _wandColor.withValues(alpha: 0.12),
                  ),
                ),
                // Main circle
                Container(
                  width: 190 * scale,
                  height: 190 * scale,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _wandColor.withValues(alpha: 0.9),
                        _wandColor.withValues(alpha: 0.5),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _wandColor.withValues(alpha: 0.35),
                        blurRadius: 30,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                ),
                // Inhale / Exhale text inside the circle
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isInhale ? 'Inhale' : 'Exhale',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: Colors.black26, blurRadius: 6)],
                      ),
                    ),
                    Text(
                      isInhale ? '4.5s' : '9s',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 16),

        // ---JOSEPHINES ADDITION START---
        // ── Smooth gradient slider — replaces the busy bar graph ─────────────
        _GradientSliderDot(
          fraction: _tempHistory.isNotEmpty
              ? (_tempHistory.last / 13.0).clamp(0.0, 1.0)
              : 0.0,
        ),

        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'least calm',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
            Text(
              '${session.temperatureSet.length} readings',
              style: const TextStyle(fontSize: 10, color: _softBlue),
            ),
            Text(
              'most calm',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
          ],
        ),
        // ---JOSEPHINES ADDITION END---
      ],
    );
  }

  Widget _buildSessionResult() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_lastScore != null) ...[
          // ---JOSEPHINES ADDITION START---
          // ── Compact score row — no "SCORE" label, just number + message ──
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Colors.white, Color(0xFFEDE7F6)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _softPurple.withValues(alpha: 0.3),
                      blurRadius: 12,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _lastScore!.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: _getFeedbackColor(_lastScore!),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                _getFeedbackMessage(_lastScore!),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _getFeedbackColor(_lastScore!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Zone achievements card ─────────────────────────────────────
          _buildAchievementsCard(),
          const SizedBox(height: 12),
          // ---JOSEPHINES ADDITION END---

          // ---JOSEPHINES ADDITION START---
          // ── Results: two labeled graph cards ──────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                // Card 1 — Rainbow zone history bar
                Container(
                  width: 300,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _softPurple.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🌈  Zone History',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _RainbowEQGraph(
                        currentColorFraction: _lastTempHistory.isNotEmpty
                            ? _lastTempHistory.last
                            : 0.0,
                        rainbowColors: _rainbowColors,
                        height: 70,
                        width: 268,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'least calm',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey.shade400,
                            ),
                          ),
                          Text(
                            'most calm',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Card 2 — Temperature line graph
                Container(
                  width: 300,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _softBlue.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📈  Temperature over time',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 90,
                        width: 268,
                        child: MiniGraphView(data: _lastTempSet),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ---JOSEPHINES ADDITION END---
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

  // ---JOSEPHINES ADDITION START---
  // ── Achievements card — shown at end of session ───────────────────────────
  // Shows how long you spent in each calm zone this session.
  Widget _buildAchievementsCard() {
    // Only show zones that were actually reached
    final zones = [
      if (_lastSecondsInGreen > 0)
        ('🌿', 'Green zone', _softGreen, _lastSecondsInGreen),
      if (_lastSecondsInBlue > 0)
        ('💙', 'Blue zone', _softBlue, _lastSecondsInBlue),
      if (_lastSecondsInPurple > 0)
        ('✨', 'Purple zone', _softPurple, _lastSecondsInPurple),
      if (_lastSecondsInWhite > 0)
        ('🏆', 'White zone', const Color(0xFFB39DDB), _lastSecondsInWhite),
    ];

    if (zones.isEmpty) {
      return Container(
        width: 300,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'Keep practicing — try to warm your hand up to reach the first zone! 🌿',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
      );
    }

    return Container(
      width: 300,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _softPurple.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🎯  Zone Achievements',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 10),
          ...zones.map((z) {
            final emoji = z.$1;
            final label = z.$2;
            final color = z.$3;
            final secs = z.$4;
            final mins = secs ~/ 60;
            final remSecs = secs % 60;
            final timeStr = mins > 0 ? '${mins}m ${remSecs}s' : '${secs}s';
            // Bar fill as fraction of total session (rough)
            final total =
                (_lastSecondsInGreen +
                        _lastSecondsInBlue +
                        _lastSecondsInPurple +
                        _lastSecondsInWhite)
                    .clamp(1, 999999);
            final fill = (secs / total).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Proportional fill bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: fill,
                      minHeight: 6,
                      backgroundColor: color.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        color.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
  // ---JOSEPHINES ADDITION END---

  String _getFeedbackMessage(double score) {
    if (score <= 50) return 'Keep going!';
    if (score <= 80) return 'Nice job!';
    return 'Congratulations!';
  }

  Color _getFeedbackColor(double score) {
    if (score <= 50) return Colors.red;
    if (score <= 80) return Colors.orange;
    // ---JOSEPHINES ADDITION START---
    return _softGreen;
    // ---JOSEPHINES ADDITION END---
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
      currentSession.endSession();

      // ---JOSEPHINES ADDITION START---
      // Stop breathing circle, save history and zone times, then reset
      _breathController.stop();
      _breathController.reset();
      _lastTempHistory = List.from(_tempHistory);
      _lastTempSet = List.from(currentSession.temperatureSet);
      _lastSecondsInGreen = _secondsInGreen;
      _lastSecondsInBlue = _secondsInBlue;
      _lastSecondsInPurple = _secondsInPurple;
      _lastSecondsInWhite = _secondsInWhite;
      _streakCount = 0;
      setState(() {
        _celebratedGreen = false;
        _celebratedBlue = false;
        _celebratedPurple = false;
        _celebratedWhite = false;
        _wandColor = const Color(0xFFBDBDBD);
        _tempHistory.clear();
        _secondsInGreen = 0;
        _secondsInBlue = 0;
        _secondsInPurple = 0;
        _secondsInWhite = 0;
      });
      // ---JOSEPHINES ADDITION END---

      final tempSet = currentSession.temperatureSet;
      final tempChange = tempSet.isNotEmpty && tempSet.length > 1
          ? tempSet.last - tempSet.first
          : 0.0;

      final inhaleTime =
          (double.tryParse(bluetoothService.inhaleData) ?? 4000) / 1000;
      final exhaleTime =
          (double.tryParse(bluetoothService.exhaleData) ?? 9500) / 1000;

      final sessionId = currentSession.sessionId;

      if (sessionId != null) {
        sessionProvider.addSession(
          sessionId: sessionId,
          duration: currentSession.timeElapsed,
          temperatureChange: tempChange,
          inhaleTime: inhaleTime,
          exhaleTime: exhaleTime,
          tempSetData: tempSet,
        );
        final latestSession = sessionProvider.latestSession;
        setState(() {
          _lastScore = latestSession?.score;
          _sessionCompleted = true;
        });
      } else {
        print('❗No session ID received, cannot add session.');
      }
    } else {
      await bluetoothService.startArduinoSession();

      final receivedSessionId = bluetoothService.sessionId;
      if (receivedSessionId != null) {
        currentSession.sessionId = receivedSessionId;
        print('✅ Session started with ID: $receivedSessionId');
      } else {
        print('⚠️ Warning: SessionID not received from Arduino');
      }

      // ---JOSEPHINES ADDITION START---
      _breathController.repeat();
      // ---JOSEPHINES ADDITION END---

      currentSession.startSession(
        recordingInterval: settings.interval,
        onTick: () {
          final tempData = bluetoothService.temperatureData;
          final temp = (double.tryParse(tempData) ?? 0) / 100;
          currentSession.addTemperatureReading(temp);

          // ---JOSEPHINES ADDITION START---
          _checkColorZone(temp, settings.interval);
          // ---JOSEPHINES ADDITION END---

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

// ---JOSEPHINES ADDITION START---

/// Smooth gradient spectrum bar with a white glowing dot that slides along it.
/// [fraction] is 0.0 (least calm) → 1.0 (most calm).
/// Uses TweenAnimationBuilder so the dot glides smoothly between readings
/// instead of jumping.
class _GradientSliderDot extends StatelessWidget {
  final double fraction; // 0.0 – 1.0

  const _GradientSliderDot({required this.fraction});

  static const List<Color> _spectrum = [
    Color(0xFF9E9E9E), // grey       — coldest
    Color(0xFF7B1FA2), // dark purple
    Color(0xFFF44336), // red
    Color(0xFFFF5722), // red-orange
    Color(0xFFFF9800), // orange
    Color(0xFFFFEB3B), // yellow
    Color(0xFF8BC34A), // yellow-green
    Color(0xFF4CAF50), // green
    Color(0xFF00E676), // bright green
    Color(0xFF00BCD4), // cyan
    Color(0xFF2196F3), // blue
    Color(0xFF3F51B5), // indigo
    Color(0xFF9C27B0), // purple
    Color(0xFFFFFFFF), // white      — calmest
  ];

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: fraction),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeInOut,
      builder: (context, animFraction, _) {
        return SizedBox(
          width: 260,
          height: 36,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // ── Gradient track ──────────────────────────────────────────
              Positioned.fill(
                top: 12,
                bottom: 12,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: _spectrum),
                    ),
                  ),
                ),
              ),

              // ── Glowing dot ─────────────────────────────────────────────
              Positioned(
                left: (animFraction * (260 - 24)).clamp(0.0, 260 - 24),
                top: 4,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: _spectrumColorAt(
                          animFraction,
                        ).withValues(alpha: 0.6),
                        blurRadius: 12,
                        spreadRadius: 3,
                      ),
                      const BoxShadow(
                        color: Colors.white,
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _spectrumColorAt(double f) {
    final double pos = f * (_spectrum.length - 1);
    final int lo = pos.floor().clamp(0, _spectrum.length - 2);
    final double t = pos - lo;
    return Color.lerp(_spectrum[lo], _spectrum[lo + 1], t)!;
  }
}

// ---JOSEPHINES ADDITION END---
/// All 14 color bars always visible as a soft faint baseline.
/// Uses a fractional index (e.g. 7.4) so the two neighbouring bars
/// both light up proportionally — giving a smooth gradual effect
/// instead of snapping hard to one bar at a time.
class _RainbowEQGraph extends StatelessWidget {
  final double currentColorFraction; // fractional 0.0–13.0
  final List<Color> rainbowColors;
  final double height;
  final double width;

  const _RainbowEQGraph({
    required this.currentColorFraction,
    required this.rainbowColors,
    this.height = 60,
    this.width = 260,
  });

  @override
  Widget build(BuildContext context) {
    final int lo = currentColorFraction.floor().clamp(0, 13);
    final int hi = (lo + 1).clamp(0, 13);
    final double t = currentColorFraction - lo; // blend amount 0→1

    return SizedBox(
      width: width,
      height: height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(rainbowColors.length, (i) {
          double activity = 0.0;
          if (i == lo) activity = 1.0 - t;
          if (i == hi) activity = t;

          final bool isPast = i < lo;
          final color = rainbowColors[i];

          final double barH = i == lo || i == hi
              ? (height * 0.18) + (height - 4 - height * 0.18) * activity
              : isPast
              ? height * 0.28
              : height * 0.10;

          final double opacity = i == lo || i == hi
              ? 0.35 + 0.65 * activity
              : isPast
              ? 0.55
              : 0.20;

          final bool glowing = activity > 0.3;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              width: glowing ? 10 : 7,
              height: barH,
              decoration: BoxDecoration(
                color: color.withValues(alpha: opacity),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(3),
                ),
                boxShadow: glowing
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.45 * activity),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ---JOSEPHINES ADDITION END---

/// Loading overlay with spinning appstore.png icon
class _ConnectionLoadingOverlay extends StatefulWidget {
  const _ConnectionLoadingOverlay();

  @override
  State<_ConnectionLoadingOverlay> createState() =>
      _ConnectionLoadingOverlayState();
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
          RotationTransition(
            turns: _controller,
            child: Image.network(
              'icons/appstore_trans.png',
              width: 120,
              height: 120,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.spa, size: 120, color: Colors.white),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              // ---JOSEPHINES ADDITION START---
              color: const Color(0xFFB39DDB).withValues(alpha: 0.85),
              // ---JOSEPHINES ADDITION END---
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
