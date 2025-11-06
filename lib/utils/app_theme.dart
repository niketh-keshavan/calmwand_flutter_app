import 'package:flutter/material.dart';

/// App theme utilities
/// Ported from ViewModifier.swift - applyBackgroundGradient()
class AppTheme {
  // App gradient colors
  static const Color gradientStart = Color(0xFFE3F2FD); // Light blue
  static const Color gradientEnd = Color(0xFFBBDEFB); // Lighter blue

  // App gradient
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [gradientStart, gradientEnd],
  );

  // Card colors
  static const Color cardBackground = Colors.white;
  static const double cardOpacity = 0.8;

  // Shadow
  static BoxShadow cardShadow = BoxShadow(
    color: Colors.black.withValues(alpha: 0.1),
    blurRadius: 5,
    offset: const Offset(0, 2),
  );

  static BoxShadow strongShadow = BoxShadow(
    color: Colors.black.withValues(alpha: 0.3),
    blurRadius: 5,
    offset: const Offset(0, 3),
  );
}

/// Extension for applying gradient background to widgets
extension GradientBackground on Widget {
  Widget applyBackgroundGradient() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.backgroundGradient,
      ),
      child: this,
    );
  }
}

/// Card style modifier
/// Ported from .cardStyle() in Swift
extension CardStyle on Widget {
  Widget cardStyle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground.withValues(alpha: AppTheme.cardOpacity),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [AppTheme.cardShadow],
      ),
      child: this,
    );
  }
}
