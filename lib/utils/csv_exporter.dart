import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/session_model.dart';

/// CSV export utility for session data
/// Ported from CSVExporter.swift
class CSVExporter {
  /// Export single session to CSV file
  static Future<void> exportSession(SessionModel session) async {
    try {
      final csv = _generateCSV(session);
      final fileName = 'session_${session.sessionNumber}_${_formatDate(session.timestamp)}.csv';

      await _saveAndShareCSV(csv, fileName);
    } catch (e) {
      print('Error exporting session: $e');
      rethrow;
    }
  }

  /// Export multiple sessions to CSV file
  static Future<void> exportSessions(List<SessionModel> sessions) async {
    try {
      final csv = _generateMultiSessionCSV(sessions);
      final fileName = 'calmwand_sessions_${_formatDate(DateTime.now())}.csv';

      await _saveAndShareCSV(csv, fileName);
    } catch (e) {
      print('Error exporting sessions: $e');
      rethrow;
    }
  }

  /// Generate CSV content for a single session
  static String _generateCSV(SessionModel session) {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('Calmwand Session Data');
    buffer.writeln('Session Number,${session.sessionNumber}');
    buffer.writeln('Date,${_formatDateTime(session.timestamp)}');
    buffer.writeln('Duration (seconds),${session.duration}');
    buffer.writeln('Score,${session.score?.toStringAsFixed(2) ?? "N/A"}');
    buffer.writeln('Temperature Change (°C),${session.temperatureChange.toStringAsFixed(2)}');
    buffer.writeln('');

    // Regression parameters
    buffer.writeln('Regression Parameters');
    buffer.writeln('A,${session.regressionA?.toStringAsFixed(4) ?? "N/A"}');
    buffer.writeln('B,${session.regressionB?.toStringAsFixed(4) ?? "N/A"}');
    buffer.writeln('k,${session.regressionK?.toStringAsFixed(4) ?? "N/A"}');
    buffer.writeln('');

    // Comment
    if (session.comment != null && session.comment!.isNotEmpty) {
      buffer.writeln('Comment');
      buffer.writeln('"${session.comment}"');
      buffer.writeln('');
    }

    // Temperature data
    buffer.writeln('Temperature Data');
    buffer.writeln('Time (seconds),Temperature (°C)');

    final interval = session.duration ~/ (session.tempSetData.length > 1 ? session.tempSetData.length - 1 : 1);

    for (int i = 0; i < session.tempSetData.length; i++) {
      final time = i * interval;
      final temp = session.tempSetData[i];
      buffer.writeln('$time,${temp.toStringAsFixed(2)}');
    }

    return buffer.toString();
  }

  /// Generate CSV content for multiple sessions (summary format)
  static String _generateMultiSessionCSV(List<SessionModel> sessions) {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('Calmwand Session History');
    buffer.writeln('Exported,${_formatDateTime(DateTime.now())}');
    buffer.writeln('');

    // Session summary table
    buffer.writeln('Session #,Date,Duration (sec),Score,Temp Change (°C),Comment');

    for (final session in sessions) {
      buffer.write('${session.sessionNumber},');
      buffer.write('${_formatDateTime(session.timestamp)},');
      buffer.write('${session.duration},');
      buffer.write('${session.score?.toStringAsFixed(2) ?? "N/A"},');
      buffer.write('${session.temperatureChange.toStringAsFixed(2)},');
      buffer.writeln('"${session.comment ?? ""}"');
    }

    return buffer.toString();
  }

  /// Save CSV to temporary file and share using system share dialog
  static Future<void> _saveAndShareCSV(String csv, String fileName) async {
    try {
      // Get temporary directory
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/$fileName';

      // Write file
      final file = File(path);
      await file.writeAsString(csv);

      // Share file
      await Share.shareXFiles(
        [XFile(path)],
        subject: 'Calmwand Session Data',
      );
    } catch (e) {
      print('Error saving/sharing CSV: $e');
      rethrow;
    }
  }

  /// Format date for filename (YYYYMMDD)
  static String _formatDate(DateTime date) {
    return '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
  }

  /// Format datetime for display (YYYY-MM-DD HH:MM:SS)
  static String _formatDateTime(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
           '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
  }
}
