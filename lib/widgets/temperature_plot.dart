import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;

/// Temperature plot with scatter points and regression curve overlay
/// Ported from Plot.swift
class TemperaturePlot extends StatelessWidget {
  final List<double> temperatureData;
  final int duration; // Total session duration in seconds
  final int interval; // Recording interval in seconds
  final double? regressionA;
  final double? regressionB;
  final double? regressionK;

  const TemperaturePlot({
    super.key,
    required this.temperatureData,
    required this.duration,
    required this.interval,
    this.regressionA,
    this.regressionB,
    this.regressionK,
  });

  @override
  Widget build(BuildContext context) {
    if (temperatureData.isEmpty) {
      return Container(
        height: 300,
        alignment: Alignment.center,
        child: const Text(
          'No temperature data',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      );
    }

    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      child: LineChart(
        _buildChartData(),
        duration: const Duration(milliseconds: 150),
      ),
    );
  }

  LineChartData _buildChartData() {
    // Calculate min/max for Y-axis scaling
    final minTemp = temperatureData.reduce((a, b) => a < b ? a : b);
    final maxTemp = temperatureData.reduce((a, b) => a > b ? a : b);
    final tempRange = maxTemp - minTemp;
    final padding = tempRange * 0.1; // 10% padding

    final minY = (minTemp - padding).floorToDouble();
    final maxY = (maxTemp + padding).ceilToDouble();

    // Calculate X-axis max (duration in seconds)
    final maxX = duration.toDouble();

    return LineChartData(
      minX: 0,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
      lineBarsData: [
        // Scatter plot of actual temperature data
        _buildScatterPlot(),
        // Regression curve (if parameters available)
        if (regressionA != null && regressionB != null && regressionK != null)
          _buildRegressionCurve(maxX),
      ],
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          axisNameWidget: const Text(
            'Temperature (°C)',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 45,
            getTitlesWidget: (value, meta) {
              return Text(
                value.toStringAsFixed(1),
                style: const TextStyle(fontSize: 10),
              );
            },
          ),
        ),
        bottomTitles: AxisTitles(
          axisNameWidget: const Text(
            'Time (seconds)',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: _calculateTimeInterval(maxX),
            getTitlesWidget: (value, meta) {
              return Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 10),
              );
            },
          ),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        drawHorizontalLine: true,
        horizontalInterval: (maxY - minY) / 5,
        verticalInterval: _calculateTimeInterval(maxX),
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: Colors.grey.withValues(alpha: 0.2),
            strokeWidth: 1,
          );
        },
        getDrawingVerticalLine: (value) {
          return FlLine(
            color: Colors.grey.withValues(alpha: 0.2),
            strokeWidth: 1,
          );
        },
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: Colors.grey.shade400, width: 1),
      ),
      lineTouchData: LineTouchData(
        enabled: true,
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              if (spot.barIndex == 0) {
                // Actual temperature point
                return LineTooltipItem(
                  'Time: ${spot.x.toInt()}s\nTemp: ${spot.y.toStringAsFixed(2)}°C',
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                );
              } else {
                // Regression curve point
                return LineTooltipItem(
                  'Regression: ${spot.y.toStringAsFixed(2)}°C',
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }
            }).toList();
          },
        ),
      ),
    );
  }

  /// Build scatter plot line (using dots)
  LineChartBarData _buildScatterPlot() {
    final spots = <FlSpot>[];

    for (int i = 0; i < temperatureData.length; i++) {
      final time = i * interval.toDouble();
      final temp = temperatureData[i];
      spots.add(FlSpot(time, temp));
    }

    return LineChartBarData(
      spots: spots,
      isCurved: false,
      color: Colors.blue.shade700,
      barWidth: 0, // No connecting line, just dots
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          return FlDotCirclePainter(
            radius: 4,
            color: Colors.blue.shade700,
            strokeWidth: 0,
          );
        },
      ),
      belowBarData: BarAreaData(show: false),
    );
  }

  /// Build regression curve line
  LineChartBarData _buildRegressionCurve(double maxX) {
    final spots = <FlSpot>[];

    // Generate curve points (sample at reasonable intervals)
    final numPoints = math.min(100, duration ~/ interval);
    final step = maxX / numPoints;

    for (int i = 0; i <= numPoints; i++) {
      final x = i * step;
      final y = _calculateRegressionValue(x);
      spots.add(FlSpot(x, y));
    }

    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: Colors.red.shade600,
      barWidth: 2,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }

  /// Calculate regression value: y = A - B × exp(-k × x)
  double _calculateRegressionValue(double x) {
    if (regressionA == null || regressionB == null || regressionK == null) {
      return 0;
    }
    return regressionA! - regressionB! * math.exp(-regressionK! * x);
  }

  /// Calculate appropriate time interval for axis labels
  double _calculateTimeInterval(double maxX) {
    if (maxX <= 60) return 10; // 10 second intervals
    if (maxX <= 120) return 20; // 20 second intervals
    if (maxX <= 300) return 30; // 30 second intervals
    if (maxX <= 600) return 60; // 1 minute intervals
    return 120; // 2 minute intervals
  }
}
