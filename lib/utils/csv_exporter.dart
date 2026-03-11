// lib/utils/csv_exporter.dart
import '../models/session_model.dart';

// ---JOSEPHINES ADDITION START---
// Conditional import — Flutter automatically picks the right one:
// On Chrome/web → csv_downloader_web.dart (browser download)
// On iPhone/Android → csv_downloader.dart (share sheet)
import 'csv_downloader.dart' if (dart.library.html) 'csv_downloader_web.dart';
// ---JOSEPHINES ADDITION END---

class CSVExporter {
  static Future<void> exportSession(SessionModel session) async {
    try {
      final csv = _generateCSV(session);
      final fileName =
          'session_${session.sessionNumber}_${_formatDate(session.timestamp)}.csv';
      await downloadCSV(csv, fileName);
    } catch (e) {
      print('Error exporting session: $e');
      rethrow;
    }
  }

  static Future<void> exportSessions(List<SessionModel> sessions) async {
    try {
      final csv = _generateMultiSessionCSV(sessions);
      final fileName = 'calmwand_sessions_${_formatDate(DateTime.now())}.csv';
      await downloadCSV(csv, fileName);
    } catch (e) {
      print('Error exporting sessions: $e');
      rethrow;
    }
  }

  static String _generateCSV(SessionModel session) {
    final buffer = StringBuffer();
    buffer.writeln('Calmwand Session Data');
    buffer.writeln('Session Number,${session.sessionNumber}');
    buffer.writeln('Date,${_formatDateTime(session.timestamp)}');
    buffer.writeln('Duration (seconds),${session.duration}');
    buffer.writeln('Score,${session.score?.toStringAsFixed(2) ?? "N/A"}');
    buffer.writeln(
      'Temperature Change (°F),${session.temperatureChange.toStringAsFixed(2)}',
    );
    buffer.writeln('');
    buffer.writeln('Regression Parameters');
    buffer.writeln('A,${session.regressionA?.toStringAsFixed(4) ?? "N/A"}');
    buffer.writeln('B,${session.regressionB?.toStringAsFixed(4) ?? "N/A"}');
    buffer.writeln('k,${session.regressionK?.toStringAsFixed(4) ?? "N/A"}');
    buffer.writeln('');
    if (session.comment != null && session.comment!.isNotEmpty) {
      buffer.writeln('Comment');
      buffer.writeln('"${session.comment}"');
      buffer.writeln('');
    }
    buffer.writeln('Temperature Data');
    buffer.writeln('Time (seconds),Temperature (°F)');
    final interval =
        session.duration ~/
        (session.tempSetData.length > 1 ? session.tempSetData.length - 1 : 1);
    for (int i = 0; i < session.tempSetData.length; i++) {
      buffer.writeln(
        '${i * interval},${session.tempSetData[i].toStringAsFixed(2)}',
      );
    }
    return buffer.toString();
  }

  static String _generateMultiSessionCSV(List<SessionModel> sessions) {
    final buffer = StringBuffer();
    buffer.writeln('Calmwand Session History');
    buffer.writeln('Exported,${_formatDateTime(DateTime.now())}');
    buffer.writeln('');
    buffer.writeln(
      'Session #,Date,Duration (sec),Score,Temp Change (°F),Comment',
    );
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

  static String _formatDate(DateTime date) {
    return '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
  }

  static String _formatDateTime(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
  }
}
