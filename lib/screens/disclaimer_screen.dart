import 'package:flutter/material.dart';
import '../services/preferences_service.dart';
import '../utils/app_theme.dart';
import 'home_screen.dart';

/// Disclaimer screen shown on first launch
/// Ported from DisclaimerView.swift
class DisclaimerScreen extends StatelessWidget {
  const DisclaimerScreen({super.key});

  void _acceptDisclaimer(BuildContext context) async {
    await PreferencesService.setDisclaimerAccepted(true);

    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 40),
                // Icon
                Icon(
                  Icons.info_outline,
                  size: 80,
                  color: Colors.blue.shade700,
                ),
                const SizedBox(height: 24),
                // Title
                Text(
                  'Important Notice',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
                const SizedBox(height: 32),
                // Disclaimer text
                Expanded(
                  child: SingleChildScrollView(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [AppTheme.cardShadow],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Medical Disclaimer',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Calmwand is a wellness device designed to support relaxation and breathing exercises. It is NOT a medical device and should NOT be used as a substitute for professional medical advice, diagnosis, or treatment.\n\n'
                            'Important Points:\n\n'
                            '• This device is not intended to diagnose, treat, cure, or prevent any disease\n\n'
                            '• Always seek the advice of your physician or other qualified health provider with any questions you may have regarding a medical condition\n\n'
                            '• Never disregard professional medical advice or delay in seeking it because of information provided by this app\n\n'
                            '• If you experience any discomfort, dizziness, or adverse effects while using this device, discontinue use immediately and consult a healthcare professional\n\n'
                            '• This app and device are intended for general wellness purposes only',
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.6,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Privacy & Data',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'All session data is stored locally on your device. We do not collect, transmit, or share your personal health information with any third parties.',
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.6,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Accept button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => _acceptDisclaimer(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: const Text(
                      'I Understand and Accept',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
