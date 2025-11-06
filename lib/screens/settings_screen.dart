import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/bluetooth_service.dart';
import '../utils/app_theme.dart';
import 'arduino_file_import_screen.dart';
import 'info_screen.dart';

/// Settings screen
/// Ported from Setting.swift
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _brightness = 130;
  double _inhaleTime = 4.5;
  double _exhaleTime = 9.0;
  double _motorStrength = 180;

  @override
  Widget build(BuildContext context) {
    final bluetoothService = context.watch<BluetoothService>();

    // Initialize values from Bluetooth service
    if (_brightness == 130) {
      _brightness = double.tryParse(bluetoothService.brightnessData) ?? 130;
    }
    if (_inhaleTime == 4.5) {
      _inhaleTime =
          (double.tryParse(bluetoothService.inhaleData) ?? 4000) / 1000;
    }
    if (_exhaleTime == 9.0) {
      _exhaleTime =
          (double.tryParse(bluetoothService.exhaleData) ?? 9500) / 1000;
    }
    if (_motorStrength == 180) {
      _motorStrength =
          double.tryParse(bluetoothService.motorStrengthData) ?? 255;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.blue.shade900,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Info section
            _buildCard(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.info, color: Colors.blue.shade700),
                ),
                title: const Text(
                  'Contact & About',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const InfoScreen(),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Arduino File Import
            _buildCard(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.cloud_download, color: Colors.green.shade700),
                ),
                title: const Text(
                  'Import from Arduino',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: const Text('Download sessions from device'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const ArduinoFileImportScreen(),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Device settings section
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Text(
                'Device Settings',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),

            // Brightness
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.wb_sunny, color: Colors.yellow.shade700),
                      const SizedBox(width: 12),
                      Text(
                        'Brightness: ${_brightness.toInt()}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _brightness,
                    min: 0,
                    max: 255,
                    divisions: 255,
                    activeColor: Colors.yellow.shade700,
                    onChanged: (value) {
                      setState(() => _brightness = value);
                    },
                    onChangeEnd: (value) {
                      HapticFeedback.selectionClick();
                      bluetoothService.writeBrightness(value.toInt().toString());
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Breathing times
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Inhale time
                  Row(
                    children: [
                      Icon(Icons.arrow_upward, color: Colors.blue.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Inhale Time: ${_inhaleTime.toStringAsFixed(1)} s',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: _inhaleTime > 2.0
                            ? () {
                                HapticFeedback.selectionClick();
                                setState(() => _inhaleTime -= 0.5);
                                _writeInhaleTime(bluetoothService);
                              }
                            : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: _inhaleTime < 15.0
                            ? () {
                                HapticFeedback.selectionClick();
                                setState(() => _inhaleTime += 0.5);
                                _writeInhaleTime(bluetoothService);
                              }
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Exhale time
                  Row(
                    children: [
                      Icon(Icons.arrow_downward, color: Colors.orange.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Exhale Time: ${_exhaleTime.toStringAsFixed(1)} s',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: _exhaleTime > 2.0
                            ? () {
                                HapticFeedback.selectionClick();
                                setState(() => _exhaleTime -= 0.5);
                                _writeExhaleTime(bluetoothService);
                              }
                            : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: _exhaleTime < 15.0
                            ? () {
                                HapticFeedback.selectionClick();
                                setState(() => _exhaleTime += 0.5);
                                _writeExhaleTime(bluetoothService);
                              }
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Motor strength
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.settings_outlined, color: Colors.grey.shade700),
                      const SizedBox(width: 12),
                      Text(
                        'Motor Intensity: ${_motorStrength.toInt()}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _motorStrength,
                    min: 0,
                    max: 255,
                    divisions: 255,
                    activeColor: Colors.grey.shade700,
                    onChanged: (value) {
                      setState(() => _motorStrength = value);
                    },
                    onChangeEnd: (value) {
                      HapticFeedback.selectionClick();
                      bluetoothService
                          .writeMotorStrength(value.toInt().toString());
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // App version
            Center(
              child: Text(
                'Calmwand v1.0.0',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [AppTheme.cardShadow],
      ),
      child: child,
    );
  }

  void _writeInhaleTime(BluetoothService service) {
    Future.delayed(const Duration(milliseconds: 500), () {
      service.writeInhaleTime((_inhaleTime * 1000).toInt().toString());
    });
  }

  void _writeExhaleTime(BluetoothService service) {
    Future.delayed(const Duration(milliseconds: 500), () {
      service.writeExhaleTime((_exhaleTime * 1000).toInt().toString());
    });
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Calmwand'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Calmwand',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text('Version 1.0.0'),
              const SizedBox(height: 16),
              const Text(
                'A breathing and meditation companion app with Bluetooth LE device integration.',
              ),
              const SizedBox(height: 16),
              const Text(
                'Contact:\nsupport@calmwand.com',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
