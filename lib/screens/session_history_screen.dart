import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/session_provider.dart';
import '../services/bluetooth_service.dart';
import '../services/storage_service.dart';
import '../services/cloud_session_service.dart';
import '../models/session_model.dart';
import '../utils/app_theme.dart';
import 'session_detail_screen.dart';
import 'session_calendar_screen.dart';

/// Session history screen
/// Ported from SessionHistoryView.swift
class SessionHistoryScreen extends StatefulWidget {
  const SessionHistoryScreen({super.key});

  @override
  State<SessionHistoryScreen> createState() => _SessionHistoryScreenState();
}

class _SessionHistoryScreenState extends State<SessionHistoryScreen> {
  bool _showArduinoSessions = false;
  bool _isLoadingArduinoSessions = false;
  bool _isImportingSession = false;
  String? _importingFileName;

  final List<Map<String, dynamic>> _arduinoSessions = [];

  // ---JOSEPHINES ADDITION START---
  static const Color _softBlue = Color(0xFF89B4D4);
  static const Color _softPurple = Color(0xFFB39DDB);
  static const Color _softGreen = Color(0xFF81C784);
  static const Color _softAmber = Color(0xFFFFCC80);
  // ---JOSEPHINES ADDITION END---

  @override
  void initState() {
    super.initState();
  }

  Future<void> _fetchArduinoSessions() async {
    final bluetoothService = context.read<BluetoothService>();

    if (!bluetoothService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.bluetooth_disabled, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text('Connect to Calmwand first'),
            ],
          ),
          backgroundColor: _softPurple,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isLoadingArduinoSessions = true;
      _arduinoSessions.clear();
    });

    await bluetoothService.requestArduinoFileList();

    int waitedMs = 0;
    while (waitedMs < 5000) {
      await Future.delayed(const Duration(milliseconds: 100));
      waitedMs += 100;
      if (bluetoothService.arduinoFileList.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 500));
        break;
      }
    }

    setState(() {
      _isLoadingArduinoSessions = false;
      _showArduinoSessions = true;
    });
  }

  Future<void> _importArduinoSession(String filename, int sessionId) async {
    if (_isImportingSession) return;

    final bluetoothService = context.read<BluetoothService>();
    final sessionProvider = context.read<SessionProvider>();

    setState(() {
      _isImportingSession = true;
      _importingFileName = filename;
    });

    await bluetoothService.requestArduinoFile(filename.toUpperCase());

    int waitedMs = 0;
    while (!bluetoothService.fileContentTransferCompleted && waitedMs < 30000) {
      await Future.delayed(const Duration(milliseconds: 100));
      waitedMs += 100;

      if (bluetoothService.isFileTransferStalled()) {
        bluetoothService.markFileTransferComplete();
        break;
      }
    }

    if (bluetoothService.fileContentTransferCompleted ||
        bluetoothService.arduinoFileContentLines.isNotEmpty) {
      final lines = bluetoothService.arduinoFileContentLines;
      final temperatures = <double>[];

      for (final line in lines) {
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length >= 2) {
          final temp = double.tryParse(parts[1]);
          if (temp != null && temp > 100) temperatures.add(temp / 100.0);
        } else {
          final temp = double.tryParse(line.trim());
          if (temp != null && temp > 100) temperatures.add(temp / 100.0);
        }
      }

      if (temperatures.isNotEmpty) {
        final tempChange = temperatures.length > 1
            ? temperatures.last - temperatures.first
            : 0.0;
        final durationSeconds = temperatures.length;

        final session = SessionModel(
          sessionNumber: sessionId,
          duration: durationSeconds,
          temperatureChange: tempChange,
          tempSetData: temperatures,
          inhaleTime: 4.5,
          exhaleTime: 9.0,
        );

        await StorageService.addSession(session);

        try {
          final cloudService = context.read<CloudSessionService>();
          if (cloudService.isLoggedIn) {
            await cloudService
                .saveSession(session)
                .timeout(const Duration(seconds: 10), onTimeout: () => false);
          }
        } catch (e) {
          print('Cloud sync failed: $e');
        }

        await sessionProvider.reloadSessions();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Imported session $sessionId (${durationSeconds ~/ 60} min)',
                  ),
                ],
              ),
              backgroundColor: _softGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No temperature data found in session'),
            ),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Import timed out')));
      }
    }

    setState(() {
      _isImportingSession = false;
      _importingFileName = null;
    });
  }

  Future<void> _deleteArduinoSession(String filename) async {
    final bluetoothService = context.read<BluetoothService>();
    await bluetoothService.deleteArduinoSession(filename);
    await _fetchArduinoSessions();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted $filename from Calmwand')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionProvider = context.watch<SessionProvider>();
    final bluetoothService = context.watch<BluetoothService>();
    final sessions = sessionProvider.sessionArray;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'Session History',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF5C6BC0),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF5C6BC0),
        iconTheme: const IconThemeData(color: Color(0xFF5C6BC0)),
        actions: [
          if (sessions.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: Colors.red.shade300,
              onPressed: () => _showClearConfirmation(context, sessionProvider),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFDCEEFA), Color(0xFFEDE7F6), Color(0xFFF1F8E9)],
          ),
        ),
        child: Column(
          children: [
            _buildWeekCalendarCard(sessions),
            _buildArduinoSessionsCard(bluetoothService),
            const SizedBox(height: 12),
            if (sessions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _softPurple.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('📋', style: TextStyle(fontSize: 14)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${sessions.length} Session${sessions.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5C6BC0),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: sessions.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: sessions.length,
                      itemBuilder: (context, index) {
                        final reversedIndex = sessions.length - 1 - index;
                        final session = sessions[reversedIndex];
                        return Dismissible(
                          key: Key(session.sessionNumber.toString()),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: Colors.red.shade300,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          onDismissed: (_) {
                            sessionProvider.removeSession(reversedIndex);
                          },
                          child: _buildSessionCard(session),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: _softPurple.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🌿', style: TextStyle(fontSize: 52)),
              const SizedBox(height: 16),
              const Text(
                'No sessions yet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5C6BC0),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Complete your first session to\nsee your history here',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArduinoSessionsCard(BluetoothService bluetoothService) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: bluetoothService.isConnected
                          ? _softGreen.withValues(alpha: 0.2)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      Icons.sd_card_outlined,
                      color: bluetoothService.isConnected
                          ? _softGreen
                          : Colors.grey.shade400,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Calmwand Sessions',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5C6BC0),
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _isLoadingArduinoSessions ? null : _fetchArduinoSessions,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _softBlue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _isLoadingArduinoSessions
                          ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _softBlue,
                              ),
                            )
                          : Icon(
                              Icons.refresh_rounded,
                              size: 16,
                              color: _softBlue,
                            ),
                      const SizedBox(width: 6),
                      Text(
                        _isLoadingArduinoSessions ? 'Loading...' : 'Fetch',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _softBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_showArduinoSessions) ...[
            const SizedBox(height: 12),
            Divider(color: Colors.grey.shade200, height: 1),
            const SizedBox(height: 10),
            if (bluetoothService.arduinoFileList.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    'No sessions on device',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView(
                  shrinkWrap: true,
                  children: bluetoothService.arduinoFileList
                      .where((fileInfo) {
                        final filename = fileInfo['filename'] as String;
                        return RegExp(
                          r'^data\d+\.txt$',
                          caseSensitive: false,
                        ).hasMatch(filename.toLowerCase());
                      })
                      .map((fileInfo) {
                        final filename = fileInfo['filename'] as String;
                        final durationMins = fileInfo['durationMins'] as int;
                        final match = RegExp(
                          r'data(\d+)\.txt',
                          caseSensitive: false,
                        ).firstMatch(filename.toLowerCase());
                        final sessionId = match != null
                            ? int.tryParse(match.group(1)!) ?? 0
                            : 0;
                        final isImporting =
                            _isImportingSession &&
                            _importingFileName == filename;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F6FB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _softBlue.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: _softBlue.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.insert_drive_file_outlined,
                                  color: _softBlue,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Session $sessionId',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: Color(0xFF37474F),
                                      ),
                                    ),
                                    if (durationMins > 0)
                                      Text(
                                        '~$durationMins min',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (isImporting)
                                SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _softGreen,
                                  ),
                                )
                              else ...[
                                GestureDetector(
                                  onTap: _isImportingSession
                                      ? null
                                      : () => _importArduinoSession(
                                          filename,
                                          sessionId,
                                        ),
                                  child: Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: _softGreen.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.download_rounded,
                                      color: _softGreen,
                                      size: 18,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () =>
                                      _showDeleteArduinoConfirmation(filename),
                                  child: Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.delete_outline,
                                      color: Colors.red.shade300,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      })
                      .toList(),
                ),
              ),
          ],
        ],
      ),
    );
  }

  void _showDeleteArduinoConfirmation(String filename) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete from Calmwand?'),
        content: Text(
          'Delete $filename from the device? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteArduinoSession(filename);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekCalendarCard(List<SessionModel> sessions) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // ---JOSEPHINES ADDITION START---
    // Build a map from date → total duration (seconds) for that day
    // so we can show partial vs full circles based on session length
    final Map<DateTime, int> sessionDurations = {};
    for (final session in sessions) {
      final date = DateTime(
        session.timestamp.year,
        session.timestamp.month,
        session.timestamp.day,
      );
      // If multiple sessions on same day, use the longest one
      final existing = sessionDurations[date] ?? 0;
      if (session.duration > existing) {
        sessionDurations[date] = session.duration;
      }
    }
    // ---JOSEPHINES ADDITION END---

    final last7Days = List.generate(7, (index) {
      return today.subtract(Duration(days: 6 - index));
    });

    final weekCount = _getSessionCountLastWeek(
      sessionDurations.keys.toSet(),
      today,
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _softPurple.withValues(alpha: 0.15),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: _softAmber.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('📅', style: TextStyle(fontSize: 14)),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'This Week',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5C6BC0),
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SessionCalendarScreen(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _softBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        size: 14,
                        color: _softBlue,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'See All',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _softBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ---JOSEPHINES ADDITION START---
          // 7-day row — shows partial/full circle based on session duration
          // < 10 min = partial arc, >= 10 min = full circle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: last7Days.map((date) {
              final duration = sessionDurations[date]; // null if no session
              final hasSession = duration != null;
              final isToday = date == today;

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SessionCalendarScreen(),
                    ),
                  );
                },
                child: Column(
                  children: [
                    Text(
                      _getWeekdayAbbr(date.weekday),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isToday ? _softBlue : Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Circle container — 36x36 to match original size
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: hasSession
                          ? CustomPaint(
                              // Partial or full arc based on duration
                              painter: _SessionCirclePainter(
                                // 600s = 10 min threshold
                                fraction: (duration >= 600)
                                    ? 1.0
                                    : (duration / 600.0).clamp(0.0, 1.0),
                                color: _softGreen,
                                isToday: isToday,
                              ),
                              child: Center(
                                child: Icon(
                                  // Full circle = checkmark, partial = clock
                                  duration >= 600
                                      ? Icons.check
                                      : Icons.timelapse,
                                  color: Colors.white,
                                  size: duration >= 600 ? 18 : 14,
                                ),
                              ),
                            )
                          : Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isToday
                                    ? _softBlue.withValues(alpha: 0.1)
                                    : Colors.grey.shade100,
                                shape: BoxShape.circle,
                                border: isToday
                                    ? Border.all(color: _softBlue, width: 2)
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  '${date.day}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isToday
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isToday
                                        ? _softBlue
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),

          // ---JOSEPHINES ADDITION END---
          const SizedBox(height: 14),

          // ---JOSEPHINES ADDITION START---
          // Legend for partial vs full circles
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(Icons.timelapse, _softGreen, '< 10 min'),
              const SizedBox(width: 16),
              _buildLegendItem(Icons.check_circle, _softGreen, '≥ 10 min'),
            ],
          ),
          const SizedBox(height: 10),

          // ---JOSEPHINES ADDITION END---
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: weekCount > 0
                    ? _softGreen.withValues(alpha: 0.12)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: weekCount > 0
                      ? _softGreen.withValues(alpha: 0.4)
                      : Colors.grey.shade200,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    weekCount == 7
                        ? '🏆'
                        : weekCount > 0
                        ? '🌿'
                        : '💤',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getWeeklySummaryText(sessionDurations.keys.toSet(), today),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: weekCount > 0
                          ? Colors.green.shade700
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---JOSEPHINES ADDITION START---
  // Small legend item for the partial/full circle key
  Widget _buildLegendItem(IconData icon, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
      ],
    );
  }
  // ---JOSEPHINES ADDITION END---

  String _getWeekdayAbbr(int weekday) {
    const abbrs = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return abbrs[weekday - 1];
  }

  int _getSessionCountLastWeek(Set<DateTime> sessionDates, DateTime today) {
    int count = 0;
    for (int i = 0; i < 7; i++) {
      final date = today.subtract(Duration(days: i));
      if (sessionDates.contains(date)) count++;
    }
    return count;
  }

  String _getWeeklySummaryText(Set<DateTime> sessionDates, DateTime today) {
    final count = _getSessionCountLastWeek(sessionDates, today);
    if (count == 0) return 'No sessions this week';
    if (count == 1) return '1 session this week';
    if (count == 7) return 'Perfect week! 🎉';
    return '$count sessions this week';
  }

  Widget _buildSessionCard(session) {
    final score = session.score as double?;
    Color scoreColor;
    String scoreEmoji;
    Color scoreBg;
    if (score == null) {
      scoreColor = Colors.grey;
      scoreEmoji = '—';
      scoreBg = Colors.grey.shade100;
    } else if (score <= 50) {
      scoreColor = Colors.red.shade400;
      scoreEmoji = '💪';
      scoreBg = Colors.red.shade50;
    } else if (score <= 80) {
      scoreColor = const Color(0xFFFFB300);
      scoreEmoji = '⭐';
      scoreBg = const Color(0xFFFFF8E1);
    } else {
      scoreColor = const Color(0xFF81C784);
      scoreEmoji = '🏆';
      scoreBg = const Color(0xFFF1F8E9);
    }

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SessionDetailScreen(session: session),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: _softPurple.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: scoreBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(scoreEmoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 2),
                  Text(
                    score != null ? score.toStringAsFixed(0) : 'N/A',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: scoreColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Session #${session.sessionNumber}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF37474F),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 13,
                        color: _softBlue,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${session.duration ~/ 60} min',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 13,
                        color: _softPurple,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(session.timestamp),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade300),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  void _showClearConfirmation(BuildContext context, SessionProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete All Sessions?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.removeAllSessions();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ---JOSEPHINES ADDITION START---

/// Paints a circular arc to show session completeness.
/// fraction = 1.0 → full filled circle (>= 10 min)
/// fraction < 1.0 → partial arc (< 10 min), filled proportionally
class _SessionCirclePainter extends CustomPainter {
  final double fraction; // 0.0 → 1.0
  final Color color;
  final bool isToday;

  const _SessionCirclePainter({
    required this.fraction,
    required this.color,
    this.isToday = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;

    if (fraction >= 1.0) {
      // Full session — filled circle with glow
      final fillPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, fillPaint);

      // Subtle glow ring
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawCircle(center, radius + 1.5, glowPaint);
    } else {
      // Partial session — faint background circle + arc
      final bgPaint = Paint()
        ..color = color.withValues(alpha: 0.2)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, bgPaint);

      // Arc fill (pie slice)
      final arcPaint = Paint()
        ..color = color.withValues(alpha: 0.75)
        ..style = PaintingStyle.fill;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -3.14159 / 2, // start at 12 o'clock
        2 * 3.14159 * fraction,
        true, // close to center = pie slice
        arcPaint,
      );

      // Border ring
      final borderPaint = Paint()
        ..color = color.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(center, radius, borderPaint);
    }

    // Today ring overlay
    if (isToday) {
      final todayPaint = Paint()
        ..color = const Color(0xFF89B4D4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(center, radius + 2, todayPaint);
    }
  }

  @override
  bool shouldRepaint(_SessionCirclePainter old) =>
      old.fraction != fraction || old.color != color || old.isToday != isToday;
}

// ---JOSEPHINES ADDITION END---
