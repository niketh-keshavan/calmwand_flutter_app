import 'package:flutter/material.dart';

/// Simple polyline chart showing temperature data
/// Ported from MiniGraphView.swift
class MiniGraphView extends StatelessWidget {
  final List<double> data;

  const MiniGraphView({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Container(
        color: Colors.transparent,
        child: const Center(
          child: Text(
            'No data',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
      );
    }

    return CustomPaint(
      painter: _MiniGraphPainter(data: data),
      child: Container(),
    );
  }
}

class _MiniGraphPainter extends CustomPainter {
  final List<double> data;

  _MiniGraphPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    // Calculate min/max for scaling
    final minY = data.reduce((a, b) => a < b ? a : b);
    final maxY = data.reduce((a, b) => a > b ? a : b);
    final range = maxY - minY;

    // Prevent division by zero
    final safeRange = range > 0 ? range : 1.0;

    // Paint for axes
    final axisPaint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Paint for data line
    final linePaint = Paint()
      ..color = Colors.blue.shade700
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw X-axis (bottom)
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      axisPaint,
    );

    // Draw Y-axis (left)
    canvas.drawLine(
      const Offset(0, 0),
      Offset(0, size.height),
      axisPaint,
    );

    // Draw data polyline
    if (data.length > 1) {
      final path = Path();

      for (int i = 0; i < data.length; i++) {
        final x = size.width * i / (data.length - 1);
        final yNorm = (data[i] - minY) / safeRange;
        final y = size.height * (1 - yNorm);

        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      canvas.drawPath(path, linePaint);
    }
  }

  @override
  bool shouldRepaint(_MiniGraphPainter oldDelegate) {
    return oldDelegate.data != data;
  }
}
