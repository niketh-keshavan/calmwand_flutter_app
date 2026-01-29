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
  
  // Store Arduino file info: {filename: {sid, mins}}
  final List<Map<String, dynamic>> _arduinoSessions = [];

  @override
  void initState() {
    super.initState();
  }

  Future<void> _fetchArduinoSessions() async {
    final bluetoothService = context.read<BluetoothService>();
    
    if (!bluetoothService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connect to Calmwand first')),
      );
      return;
    }

    setState(() {
      _isLoadingArduinoSessions = true;
      _arduinoSessions.clear();
    });

    // Request file list from Arduino
    await bluetoothService.requestArduinoFileList();

    // Wait for file list to be received (with timeout)
    int waitedMs = 0;
    while (waitedMs < 5000) {
      await Future.delayed(const Duration(milliseconds: 100));
      waitedMs += 100;
      
      // Check if we've received END marker (list complete)
      // The list should stop updating when complete
      if (bluetoothService.arduinoFileList.isNotEmpty) {
        // Wait a bit more to ensure we got all files
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
    // Prevent concurrent imports
    if (_isImportingSession) {
      print('Import already in progress, ignoring request for $filename');
      return;
    }

    final bluetoothService = context.read<BluetoothService>();
    final sessionProvider = context.read<SessionProvider>();

    setState(() {
      _isImportingSession = true;
      _importingFileName = filename;
    });

    print('Importing session $sessionId from $filename');

    // Request file content (Arduino expects uppercase)
    await bluetoothService.requestArduinoFile(filename.toUpperCase());

    // Wait for file content to be received (with timeout)
    // Also check for stalled transfer (EOF packet may be lost over BLE)
    int waitedMs = 0;
    int lastLineCount = 0;
    while (!bluetoothService.fileContentTransferCompleted && waitedMs < 30000) {
      await Future.delayed(const Duration(milliseconds: 100));
      waitedMs += 100;
      
      // Check if transfer is stalled (no new data for 3+ seconds after receiving some data)
      if (bluetoothService.isFileTransferStalled()) {
        print('⚠️ File transfer stalled - EOF likely lost, proceeding with received data');
        bluetoothService.markFileTransferComplete();
        break;
      }
      
      // Log progress every 5 seconds
      final currentCount = bluetoothService.arduinoFileContentLines.length;
      if (waitedMs % 5000 == 0 && currentCount > 0) {
        print('Transfer in progress: $currentCount lines received...');
      }
      lastLineCount = currentCount;
    }

    if (bluetoothService.fileContentTransferCompleted || bluetoothService.arduinoFileContentLines.isNotEmpty) {
      // Parse the file content into a session
      final lines = bluetoothService.arduinoFileContentLines;
      final temperatures = <double>[];

      for (final line in lines) {
        // File format: "timestamp temperature" (space-separated)
        // e.g., "3028 6567.00" -> temperature is 6567.00 / 100 = 65.67°F
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length >= 2) {
          final temp = double.tryParse(parts[1]);
          if (temp != null && temp > 100) {  // Skip invalid readings (temp should be > 100 when multiplied by 100)
            temperatures.add(temp / 100.0); // Convert back to degrees
          }
        } else {
          // Fallback: try parsing as single value
          final temp = double.tryParse(line.trim());
          if (temp != null && temp > 100) {
            temperatures.add(temp / 100.0);
          }
        }
      }

      if (temperatures.isNotEmpty) {
        // Calculate temperature change
        final tempChange = temperatures.isNotEmpty && temperatures.length > 1
            ? temperatures.last - temperatures.first
            : 0.0;

        // Arduino records data approximately every 1 second
        // Duration = number of readings (in seconds)
        final durationSeconds = temperatures.length;
        
        // Create session without regression (Arduino data doesn't need fancy analysis)
        final session = SessionModel(
          sessionNumber: sessionId,
          duration: durationSeconds,
          temperatureChange: tempChange,
          tempSetData: temperatures,
          inhaleTime: 4.5,
          exhaleTime: 9.0,
        );
        
        // Add directly to storage and reload
        print('Saving session $sessionId with ${temperatures.length} readings');
        await StorageService.addSession(session);
        
        // Sync to cloud if logged in (with timeout to prevent hanging)
        try {
          final cloudService = context.read<CloudSessionService>();
          if (cloudService.isLoggedIn) {
            print('Syncing to cloud...');
            await cloudService.saveSession(session).timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                print('Cloud sync timed out');
                return false;
              },
            );
            print('Cloud sync complete');
          }
        } catch (e) {
          print('Cloud sync failed: $e');
        }
        
        // Reload sessions from storage to update the UI
        print('Reloading sessions...');
        await sessionProvider.reloadSessions();
        
        print('Session saved and list updated');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Imported session $sessionId (${durationSeconds ~/ 60} min)')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No temperature data found in session')),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Import timed out')),
        );
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
    
    // Refresh the list
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
      appBar: AppBar(
        title: const Text('Session History'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.blue.shade900,
        actions: [
          if (sessions.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _showClearConfirmation(context, sessionProvider),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: Column(
          children: [
            // 7-day calendar card
            _buildWeekCalendarCard(sessions),

            // Arduino sessions section
            _buildArduinoSessionsCard(bluetoothService),

            const SizedBox(height: 16),

            // Session list
            Expanded(
              child: sessions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No sessions yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start a session to see it here',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    )
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
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
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

  Widget _buildArduinoSessionsCard(BluetoothService bluetoothService) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [AppTheme.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.sd_card,
                    color: bluetoothService.isConnected ? Colors.green : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Calmwand Sessions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _isLoadingArduinoSessions ? null : _fetchArduinoSessions,
                icon: _isLoadingArduinoSessions
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 18),
                label: Text(_isLoadingArduinoSessions ? 'Loading...' : 'Fetch'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
          
          if (_showArduinoSessions) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            
            if (bluetoothService.arduinoFileList.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'No sessions on device',
                    style: TextStyle(color: Colors.grey.shade600),
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
                      // Only show files matching dataN.txt (case-insensitive)
                      final filename = fileInfo['filename'] as String;
                      return RegExp(r'^data\d+\.txt$', caseSensitive: false).hasMatch(filename.toLowerCase());
                    })
                    .map((fileInfo) {
                final filename = fileInfo['filename'] as String;
                final durationMins = fileInfo['durationMins'] as int;
                
                // Extract session ID from filename (e.g., "data5.txt" or "DATA5.TXT" -> 5)
                final match = RegExp(r'data(\d+)\.txt', caseSensitive: false).firstMatch(filename.toLowerCase());
                final sessionId = match != null ? int.tryParse(match.group(1)!) ?? 0 : 0;
                final isImporting = _isImportingSession && _importingFileName == filename;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.insert_drive_file, color: Colors.blue.shade300, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Session $sessionId',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            if (durationMins > 0)
                              Text(
                                '~$durationMins min (estimated)',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            Text(
                              filename,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                      if (isImporting)
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else ...[
                        IconButton(
                          icon: const Icon(Icons.download, color: Colors.green),
                          onPressed: _isImportingSession ? null : () => _importArduinoSession(filename, sessionId),
                          tooltip: 'Import',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _showDeleteArduinoConfirmation(filename),
                          tooltip: 'Delete',
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
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
        title: const Text('Delete from Calmwand?'),
        content: Text('Delete $filename from the device? This cannot be undone.'),
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
    
    // Create a set of dates that have sessions
    final sessionDates = <DateTime>{};
    for (final session in sessions) {
      sessionDates.add(DateTime(
        session.timestamp.year,
        session.timestamp.month,
        session.timestamp.day,
      ));
    }
    
    // Generate last 7 days
    final last7Days = List.generate(7, (index) {
      return today.subtract(Duration(days: 6 - index));
    });

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [AppTheme.strongShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Last 7 Days',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.brown.shade700,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SessionCalendarScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.calendar_month, size: 18),
                label: const Text('See All'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 7-day calendar row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: last7Days.map((date) {
              final hasSession = sessionDates.contains(date);
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
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isToday ? Colors.blue.shade700 : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: hasSession 
                            ? Colors.green.shade400 
                            : (isToday ? Colors.blue.shade50 : Colors.grey.shade100),
                        shape: BoxShape.circle,
                        border: isToday 
                            ? Border.all(color: Colors.blue.shade400, width: 2)
                            : null,
                      ),
                      child: Center(
                        child: hasSession
                            ? const Icon(Icons.check, color: Colors.white, size: 20)
                            : Text(
                                '${date.day}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                  color: isToday ? Colors.blue.shade700 : Colors.grey.shade700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // Summary text
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getSessionCountLastWeek(sessionDates, today) > 0 
                    ? Icons.emoji_events 
                    : Icons.info_outline,
                color: _getSessionCountLastWeek(sessionDates, today) > 0 
                    ? Colors.amber 
                    : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _getWeeklySummaryText(sessionDates, today),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getWeekdayAbbr(int weekday) {
    const abbrs = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return abbrs[weekday - 1];
  }

  int _getSessionCountLastWeek(Set<DateTime> sessionDates, DateTime today) {
    int count = 0;
    for (int i = 0; i < 7; i++) {
      final date = today.subtract(Duration(days: i));
      if (sessionDates.contains(date)) {
        count++;
      }
    }
    return count;
  }

  String _getWeeklySummaryText(Set<DateTime> sessionDates, DateTime today) {
    final count = _getSessionCountLastWeek(sessionDates, today);
    if (count == 0) {
      return 'No sessions this week';
    } else if (count == 1) {
      return '1 session this week';
    } else if (count == 7) {
      return 'Perfect week! 🎉';
    } else {
      return '$count sessions this week';
    }
  }

  Widget _buildSessionCard(session) {
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [AppTheme.cardShadow],
        ),
        child: Row(
          children: [
            // Score
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.yellow.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 20),
                  const SizedBox(height: 4),
                  Text(
                    session.score != null
                        ? session.score!.toStringAsFixed(0)
                        : 'N/A',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 16, color: Colors.blue),
                      const SizedBox(width: 4),
                      Text(
                        'Duration: ${session.duration ~/ 60} min',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Session #${session.sessionNumber}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showClearConfirmation(
      BuildContext context, SessionProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
