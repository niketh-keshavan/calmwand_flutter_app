import 'dart:math';
import '../models/session_model.dart';

/// Regression calculation utilities
/// Ported from SessionViewModel in Classes.swift (lines 135-220)
class RegressionCalculator {
  /// Calculate exponential regression parameters: A, B, k
  /// for the equation: y = A - B * exp(-k * x)
  ///
  /// Returns tuple (A, B, k) or null if calculation fails
  static ({double a, double b, double k})? calculateRegressionParameters({
    required int duration,
    required List<double> tempSet,
    required int interval,
  }) {
    if (tempSet.length < 2) {
      print('Temperature set must contain at least two points.');
      return null;
    }

    // Step 1: Generate time array
    final timeArray = <double>[];
    for (int i = interval; i < duration; i += interval) {
      timeArray.add(i.toDouble());
    }

    // Ensure timeArray and tempSet are aligned in size
    if (timeArray.length != tempSet.length) {
      print('Mismatch between time array and temperature set.');
      return null;
    }

    // Step 2: Calculate A, B, k
    const epsilon = 0.1;
    final a = (tempSet.reduce((a, b) => a > b ? a : b)) + epsilon;

    double sumX = 0.0;
    double sumLnAminusY = 0.0;
    double sumXLnAminusY = 0.0;
    double sumXSquare = 0.0;
    final n = tempSet.length.toDouble();

    for (int index = 0; index < tempSet.length; index++) {
      final temperature = tempSet[index];
      final aMinusY = a - temperature;

      // Ensure A - y > 0
      if (aMinusY <= 0) continue;

      final lnAminusY = log(aMinusY); // ln(A-y) >> y'
      sumX += timeArray[index]; // sum(x)
      sumLnAminusY += lnAminusY; // sum(ln(A-y)) >> sum(y')
      sumXLnAminusY += timeArray[index] * lnAminusY; // sum(x·ln(A-y)) >> sum(x·y')
      sumXSquare += timeArray[index] * timeArray[index]; // sum(x^2)
    }

    // Calculate denominator = n·sum(x^2) - (sumx)^2
    final denominator = n * sumXSquare - sumX * sumX;
    if (denominator == 0) {
      print('Denominator is zero, regression calculation failed.');
      return null;
    }

    final k = -(n * sumXLnAminusY - sumX * sumLnAminusY) / denominator;
    final lnB = (sumLnAminusY + k * sumX) / n;
    final b = exp(lnB);

    return (a: a, b: b, k: k);
  }

  /// Calculate session score based on regression parameters
  ///
  /// Ported from calculateScore in Classes.swift (lines 185-200)
  /// Returns score (0-100) or null if calculation fails
  static double? calculateScore({
    required double a,
    required double b,
    required double k,
    required int sessionDuration,
  }) {
    final kAbs = k.abs(); // use magnitude
    final t = sessionDuration.toDouble();

    // Temperature increase cannot be negative
    final predictedIncrease = max(b * (1 - exp(-kAbs * t)), 0);

    final relaxFactor = min(pow(predictedIncrease / 5.0, 0.15), 1.0);
    final speedFactor = min(pow(kAbs / 0.0050, 0.15), 1.0);

    final maxScore = min((t / 60) * 10, 100.0);

    final score = maxScore * relaxFactor * speedFactor;
    return score.isFinite ? score : null;
  }

  /// Update regression parameters and score for a session
  ///
  /// Returns updated session with calculated values
  static SessionModel updateSessionWithRegressionData({
    required SessionModel session,
    required int interval,
  }) {
    final params = calculateRegressionParameters(
      duration: session.duration,
      tempSet: session.tempSetData,
      interval: interval,
    );

    if (params == null) {
      print('Failed to calculate regression parameters for session ${session.sessionNumber}');
      return session.copyWith(
        regressionA: null,
        regressionB: null,
        regressionK: null,
        score: null,
      );
    }

    final score = calculateScore(
      a: params.a,
      b: params.b,
      k: params.k,
      sessionDuration: session.duration,
    );

    // Make score safe by turning non-finite values into null
    final safeScore = (score?.isFinite ?? false) ? score : null;

    return session.copyWith(
      regressionA: params.a,
      regressionB: params.b,
      regressionK: params.k.abs(),
      score: safeScore,
    );
  }

  /// Calculate predicted temperature at a given time using regression equation
  static double? predictTemperature({
    required double a,
    required double b,
    required double k,
    required double time,
  }) {
    final predicted = a - b * exp(-k * time);
    return predicted.isFinite ? predicted : null;
  }

  /// Generate predicted temperature curve for visualization
  static List<({double x, double y})> generateRegressionCurve({
    required double a,
    required double b,
    required double k,
    required double minX,
    required double maxX,
    int points = 100,
  }) {
    final result = <({double x, double y})>[];

    if (minX == maxX) {
      final predicted = predictTemperature(a: a, b: b, k: k, time: minX);
      if (predicted != null) {
        result.add((x: minX, y: predicted));
      }
      return result;
    }

    final step = (maxX - minX) / points;
    for (double x = minX; x <= maxX; x += step) {
      final predicted = predictTemperature(a: a, b: b, k: k, time: x);
      if (predicted != null) {
        result.add((x: x, y: predicted));
      }
    }

    return result;
  }
}
