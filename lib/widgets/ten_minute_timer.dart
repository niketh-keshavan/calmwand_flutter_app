import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Ten minute circular timer with gradient rings
/// Ported from TenMinuteTimerView.swift
class TenMinuteTimer extends StatelessWidget {
  final int timeElapsed; // Time elapsed in seconds

  const TenMinuteTimer({
    super.key,
    required this.timeElapsed,
  });

  // Total duration for a full cycle: 10 minutes = 600 seconds
  static const int totalDuration = 600;

  // Number of complete 10-minute cycles
  int get fullCycles => timeElapsed ~/ totalDuration;

  // Fraction (0.0-1.0) of the current cycle that has elapsed
  double get fraction => (timeElapsed % totalDuration) / totalDuration;

  // Gradient for even cycles
  Gradient get gradientEven => const LinearGradient(
        colors: [Color(0xFF42A5F5), Color(0xFF9C27B0)], // Blue to Purple
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  // Gradient for odd cycles
  Gradient get gradientOdd => const LinearGradient(
        colors: [Color(0xFF66BB6A), Color(0xFF26C6DA)], // Green to Teal
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  // Current gradient based on cycle count
  Gradient get currentGradient =>
      fullCycles % 2 == 0 ? gradientEven : gradientOdd;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background track
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.grey.withValues(alpha: 0.3),
                width: 10,
              ),
            ),
          ),

          // Draw complete cycles
          for (int i = 0; i < fullCycles; i++)
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  width: 10,
                  color: Colors.transparent,
                ),
                gradient: i % 2 == 0
                    ? const SweepGradient(
                        colors: [Color(0xFF42A5F5), Color(0xFF9C27B0)],
                        startAngle: -math.pi / 2,
                        endAngle: 3 * math.pi / 2,
                      )
                    : const SweepGradient(
                        colors: [Color(0xFF66BB6A), Color(0xFF26C6DA)],
                        startAngle: -math.pi / 2,
                        endAngle: 3 * math.pi / 2,
                      ),
              ),
            ),

          // Current partial cycle
          CustomPaint(
            size: const Size(200, 200),
            painter: _TimerArcPainter(
              fraction: fraction,
              gradient: currentGradient,
            ),
          ),

          // Center label showing total minutes
          Text(
            '${timeElapsed ~/ 60} min',
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for the arc showing current cycle progress
class _TimerArcPainter extends CustomPainter {
  final double fraction;
  final Gradient gradient;

  _TimerArcPainter({
    required this.fraction,
    required this.gradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Start angle at top (-90 degrees = -π/2)
    const startAngle = -math.pi / 2;
    final sweepAngle = fraction * 2 * math.pi;

    final rect = Rect.fromCircle(center: center, radius: radius);

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_TimerArcPainter oldDelegate) {
    return oldDelegate.fraction != fraction;
  }
}
