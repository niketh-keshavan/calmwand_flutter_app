import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/session_model.dart';
import '../providers/session_provider.dart';
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
    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text('Session ${widget.session.sessionNumber}'),
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
                    temperatureData: widget.session.tempSetData,
                    duration: widget.session.duration,
                    interval: widget.session.duration ~/
                        (widget.session.tempSetData.length > 1
                            ? widget.session.tempSetData.length - 1
                            : 1),
                    regressionA: widget.session.regressionA,
                    regressionB: widget.session.regressionB,
                    regressionK: widget.session.regressionK,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLegendItem(Colors.blue.shade700, 'Measured Data'),
                      const SizedBox(width: 20),
                      _buildLegendItem(Colors.red.shade600, 'Regression Curve'),
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
                  _buildMetricRow('Date', _formatDateTime(widget.session.timestamp)),
                  _buildMetricRow('Duration', '${widget.session.duration} seconds (${_formatDuration(widget.session.duration)})'),
                  _buildMetricRow('Score', widget.session.score != null
                      ? '${widget.session.score!.toStringAsFixed(2)} / 100'
                      : 'N/A'),
                  _buildMetricRow('Temperature Change', '${widget.session.temperatureChange.toStringAsFixed(2)} °C'),
                  _buildMetricRow('Data Points', '${widget.session.tempSetData.length}'),
                ],
              ),
            ),

            // Regression parameters
            if (widget.session.regressionA != null &&
                widget.session.regressionB != null &&
                widget.session.regressionK != null)
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
                      'Regression Parameters',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'y = A - B × exp(-k × x)',
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildMetricRow('A', widget.session.regressionA!.toStringAsFixed(4)),
                    _buildMetricRow('B', widget.session.regressionB!.toStringAsFixed(4)),
                    _buildMetricRow('k', widget.session.regressionK!.toStringAsFixed(4)),
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
                          widget.session.comment?.isNotEmpty == true
                              ? widget.session.comment!
                              : 'No comment',
                          style: TextStyle(
                            fontSize: 14,
                            color: widget.session.comment?.isNotEmpty == true
                                ? Colors.black87
                                : Colors.grey,
                            fontStyle: widget.session.comment?.isNotEmpty == true
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

  String _formatDateTime(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
           '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes}m ${remainingSeconds}s';
  }

  void _saveComment(SessionProvider sessionProvider) {
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

    sessionProvider.updateSessionByModel(updatedSession);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Comment saved'),
        duration: Duration(seconds: 2),
      ),
    );
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
