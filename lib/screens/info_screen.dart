import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Info screen with app information and documentation
/// Ported from Info.swift
class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About Calmwand'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // App info card
            _buildCard(
              icon: Icons.info_outline,
              iconColor: Colors.blue,
              title: 'About Calmwand',
              children: [
                const Text(
                  'Calmwand is a breathing and meditation companion app that connects to your Calmwand device via Bluetooth.',
                  style: TextStyle(fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Version: 1.0.0',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // How it works
            _buildCard(
              icon: Icons.settings_outlined,
              iconColor: Colors.green,
              title: 'How It Works',
              children: [
                _buildBulletPoint(
                  'Connect your Calmwand device via Bluetooth',
                ),
                _buildBulletPoint(
                  'Hold the device and begin your breathing session',
                ),
                _buildBulletPoint(
                  'The device measures temperature changes during meditation',
                ),
                _buildBulletPoint(
                  'Sessions are analyzed using exponential regression',
                ),
                _buildBulletPoint(
                  'Track your progress and view detailed statistics',
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Scoring system
            _buildCard(
              icon: Icons.stars,
              iconColor: Colors.amber,
              title: 'Scoring System',
              children: [
                const Text(
                  'Session scores are calculated based on:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                _buildBulletPoint(
                  'Temperature change during session',
                ),
                _buildBulletPoint(
                  'Exponential regression fit (y = A - B × exp(-k × x))',
                ),
                _buildBulletPoint(
                  'Session duration and consistency',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Scores range from 0-100, with higher scores indicating better relaxation response.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Features
            _buildCard(
              icon: Icons.checklist,
              iconColor: Colors.purple,
              title: 'Features',
              children: [
                _buildFeatureItem(Icons.bluetooth, 'Bluetooth LE device connection'),
                _buildFeatureItem(Icons.timer, 'Real-time session tracking'),
                _buildFeatureItem(Icons.show_chart, 'Temperature visualization with regression curves'),
                _buildFeatureItem(Icons.history, 'Session history with weekly goals'),
                _buildFeatureItem(Icons.share, 'Export sessions to CSV'),
                _buildFeatureItem(Icons.cloud_download, 'Import sessions from Arduino SD card'),
                _buildFeatureItem(Icons.tune, 'Customizable device settings'),
              ],
            ),

            const SizedBox(height: 16),

            // Contact card
            _buildCard(
              icon: Icons.contact_mail,
              iconColor: Colors.teal,
              title: 'Contact & Support',
              children: [
                _buildContactItem(Icons.email, 'Email', 'support@calmwand.com'),
                const SizedBox(height: 12),
                const Text(
                  'For technical support, feature requests, or feedback, please contact us at the email above.',
                  style: TextStyle(fontSize: 13, height: 1.5),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Disclaimer
            _buildCard(
              icon: Icons.warning_amber,
              iconColor: Colors.orange,
              title: 'Disclaimer',
              children: [
                const Text(
                  'Calmwand is designed for relaxation and meditation purposes only. It is not a medical device and should not be used to diagnose, treat, or prevent any medical condition.',
                  style: TextStyle(fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Always consult with a healthcare professional for medical advice.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Copyright
            Center(
              child: Text(
                '© 2024 Calmwand. All rights reserved.',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [AppTheme.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.purple.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.teal.shade700),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, color: Colors.blue),
          ),
        ),
      ],
    );
  }
}
