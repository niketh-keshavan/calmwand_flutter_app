import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// How to use / guide screen
/// Ported from HowToUseView.swift
class HowToUseScreen extends StatelessWidget {
  const HowToUseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('How to Use Calmwand'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.blue.shade900,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildSection(
              icon: Icons.bluetooth,
              title: '1. Connect Your Device',
              description:
                  'Go to Settings and tap "Connect" to pair with your Calmwand device via Bluetooth.',
            ),
            const SizedBox(height: 24),
            _buildSection(
              icon: Icons.settings,
              title: '2. Adjust Settings',
              description:
                  'Customize brightness, inhale/exhale times, and motor intensity to your preference.',
            ),
            const SizedBox(height: 24),
            _buildSection(
              icon: Icons.play_circle,
              title: '3. Start a Session',
              description:
                  'Tap "Start Session" on the Session Summary tab. Follow the breathing guide with your Calmwand device.',
            ),
            const SizedBox(height: 24),
            _buildSection(
              icon: Icons.show_chart,
              title: '4. Track Progress',
              description:
                  'View your session history, scores, and temperature data. Export sessions as CSV for analysis.',
            ),
            const SizedBox(height: 24),
            _buildSection(
              icon: Icons.emoji_events,
              title: '5. Set Goals',
              description:
                  'Set weekly session goals in the History tab to stay consistent with your practice.',
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Pro Tips',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '• Find a quiet, comfortable space\n'
                    '• Start with shorter sessions (5-10 minutes)\n'
                    '• Focus on slow, deep breaths\n'
                    '• Keep your device at a comfortable temperature\n'
                    '• Practice regularly for best results',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [AppTheme.cardShadow],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 32,
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
