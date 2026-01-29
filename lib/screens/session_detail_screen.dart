import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/session_model.dart';
import '../providers/session_provider.dart';
import '../services/auth_service.dart';
import '../widgets/temperature_plot.dart';
import '../utils/csv_exporter.dart';
import '../utils/app_theme.dart';

/// Detailed view of a single session with chart, stats, and export
/// Ported from SessionDetailView.swift
class SessionDetailScreen extends StatefulWidget {
  final SessionModel session;

  const SessionDetailScreen({
    super.key,
    required this.session,
  });

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  late TextEditingController _commentController;
  bool _isEditingComment = false;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController(text: widget.session.comment ?? '');
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionProvider = context.watch<SessionProvider>();
    
    // Find the current session from provider to get latest updates
    // Use sessionNumber only since timestamp may have been updated
    final currentSession = sessionProvider.sessionArray.firstWhere(
      (s) => s.sessionNumber == widget.session.sessionNumber,
      orElse: () => widget.session,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Session ${currentSession.sessionNumber}'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          // Export button
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Export to CSV',
            onPressed: () => _exportSession(context),
          ),
          // Delete button
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Delete Session',
            onPressed: () => _deleteSession(context, sessionProvider),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Temperature plot
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [AppTheme.cardShadow],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Temperature vs Time',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TemperaturePlot(
                    temperatureData: currentSession.tempSetData,
                    duration: currentSession.duration,
                    interval: currentSession.duration ~/
                        (currentSession.tempSetData.length > 1
                            ? currentSession.tempSetData.length - 1
                            : 1),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLegendItem(Colors.blue.shade700, 'Measured Data'),
                    ],
                  ),
                ],
              ),
            ),

            // Session metrics
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [AppTheme.cardShadow],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Session Metrics',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildEditableDateRow(context, 'Date', currentSession, sessionProvider),
                  _buildMetricRow('Duration', '${currentSession.duration} seconds (${_formatDuration(currentSession.duration)})'),
                  _buildMetricRow('Score', currentSession.score != null
                      ? '${currentSession.score!.toStringAsFixed(2)} / 100'
                      : 'N/A'),
                  _buildMetricRow('Temperature Change', '${currentSession.temperatureChange.toStringAsFixed(2)} °F'),
                  _buildMetricRow('Data Points', '${currentSession.tempSetData.length}'),
                ],
              ),
            ),

            // Comment section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [AppTheme.cardShadow],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Comment',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          if (_isEditingComment) {
                            _saveComment(sessionProvider);
                          }
                          setState(() {
                            _isEditingComment = !_isEditingComment;
                          });
                        },
                        icon: Icon(_isEditingComment ? Icons.save : Icons.edit),
                        label: Text(_isEditingComment ? 'Save' : 'Edit'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _isEditingComment
                      ? TextField(
                          controller: _commentController,
                          decoration: const InputDecoration(
                            hintText: 'Add your thoughts about this session...',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 4,
                        )
                      : Text(
                          currentSession.comment.isNotEmpty
                              ? currentSession.comment
                              : 'No comment',
                          style: TextStyle(
                            fontSize: 14,
                            color: currentSession.comment.isNotEmpty
                                ? Colors.black87
                                : Colors.grey,
                            fontStyle: currentSession.comment.isNotEmpty
                                ? FontStyle.normal
                                : FontStyle.italic,
                          ),
                        ),
                ],
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 3,
          color: color,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildEditableDateRow(BuildContext context, String label, SessionModel session, SessionProvider sessionProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          GestureDetector(
            onTap: () => _showDatePicker(context, session, sessionProvider),
            child: Row(
              children: [
                Text(
                  _formatDateTime(session.timestamp),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.edit, size: 16, color: Colors.blue),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDatePicker(BuildContext context, SessionModel session, SessionProvider sessionProvider) async {
    final authService = context.read<AuthService>();
    final oldTimestamp = session.timestamp;
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: session.timestamp,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      // Check if date actually changed (ignoring time)
      final oldDate = DateTime(oldTimestamp.year, oldTimestamp.month, oldTimestamp.day);
      final newDate = DateTime(picked.year, picked.month, picked.day);
      
      if (oldDate == newDate) {
        return; // No change
      }
      
      // Preserve the time component from original timestamp
      final newTimestamp = DateTime(
        picked.year,
        picked.month,
        picked.day,
        session.timestamp.hour,
        session.timestamp.minute,
        session.timestamp.second,
      );

      final updatedSession = SessionModel(
        sessionNumber: session.sessionNumber,
        duration: session.duration,
        temperatureChange: session.temperatureChange,
        tempSetData: session.tempSetData,
        inhaleTime: session.inhaleTime,
        exhaleTime: session.exhaleTime,
        regressionA: session.regressionA,
        regressionB: session.regressionB,
        regressionK: session.regressionK,
        score: session.score,
        comment: session.comment,
        timestamp: newTimestamp,
      );

      // Pass old timestamp so we can find and update the correct session
      await sessionProvider.updateSessionWithTimestampChange(
        oldTimestamp: oldTimestamp,
        updatedSession: updatedSession,
      );

      if (mounted) {
        final message = authService.isLoggedIn 
          ? 'Date updated and synced to cloud' 
          : 'Date updated locally';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  authService.isLoggedIn ? Icons.cloud_done : Icons.check,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(message)),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  String _formatDateTime(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes}m ${remainingSeconds}s';
  }

  void _saveComment(SessionProvider sessionProvider) async {
    final authService = context.read<AuthService>();
    
    final updatedSession = SessionModel(
      sessionNumber: widget.session.sessionNumber,
      duration: widget.session.duration,
      temperatureChange: widget.session.temperatureChange,
      tempSetData: widget.session.tempSetData,
      inhaleTime: widget.session.inhaleTime,
      exhaleTime: widget.session.exhaleTime,
      regressionA: widget.session.regressionA,
      regressionB: widget.session.regressionB,
      regressionK: widget.session.regressionK,
      score: widget.session.score,
      comment: _commentController.text,
      timestamp: widget.session.timestamp,
    );

    await sessionProvider.updateSessionByModel(updatedSession);

    if (mounted) {
      final message = authService.isLoggedIn 
        ? 'Comment saved and synced to cloud' 
        : 'Comment saved locally';
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                authService.isLoggedIn ? Icons.cloud_done : Icons.check,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _exportSession(BuildContext context) async {
    try {
      await CSVExporter.exportSession(widget.session);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session exported successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting session: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _deleteSession(BuildContext context, SessionProvider sessionProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Session'),
        content: Text('Are you sure you want to delete Session ${widget.session.sessionNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      sessionProvider.deleteSession(widget.session);
      if (mounted) {
        Navigator.of(context).pop(); // Return to history screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session deleted'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
