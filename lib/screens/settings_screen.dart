import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/bluetooth_service.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import 'info_screen.dart';
import 'login_screen.dart';

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

  // ---JOSEPHINES ADDITION START---
  // Track whether we've already loaded values from Bluetooth so that
  // resetting back to 4.5 / 9.0 doesn't get immediately overwritten
  bool _brightnessInitialized = false;
  bool _inhaleInitialized = false;
  bool _exhaleInitialized = false;
  bool _motorStrengthInitialized = false;
  // ---JOSEPHINES ADDITION END---

  // ---JOSEPHINES ADDITION START---
  // Josephine's soft color palette — matches session_summary_screen.dart
  static const Color _softBlue = Color(0xFF89B4D4);
  static const Color _softPurple = Color(0xFFB39DDB);
  static const Color _softGreen = Color(0xFF81C784);

  // Small helper: formats seconds nicely for display
  String _formatSeconds(double val) => '${val.toStringAsFixed(1)}s';
  // ---JOSEPHINES ADDITION END---

  @override
  Widget build(BuildContext context) {
    final bluetoothService = context.watch<BluetoothService>();

    // ---JOSEPHINES ADDITION START---
    // Only load from Bluetooth once — after that, let the user's changes
    // (including Reset) stick without being overwritten on every rebuild
    if (!_brightnessInitialized) {
      _brightness = double.tryParse(bluetoothService.brightnessData) ?? 130;
      _brightnessInitialized = true;
    }
    if (!_inhaleInitialized) {
      _inhaleTime =
          (double.tryParse(bluetoothService.inhaleData) ?? 4000) / 1000;
      _inhaleInitialized = true;
    }
    if (!_exhaleInitialized) {
      _exhaleTime =
          (double.tryParse(bluetoothService.exhaleData) ?? 9500) / 1000;
      _exhaleInitialized = true;
    }
    if (!_motorStrengthInitialized) {
      _motorStrength =
          double.tryParse(bluetoothService.motorStrengthData) ?? 255;
      _motorStrengthInitialized = true;
    }
    // ---JOSEPHINES ADDITION END---

    return Scaffold(
      // ---JOSEPHINES ADDITION START---
      // Transparent so gradient shows through
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF5C6BC0),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF5C6BC0),
        iconTheme: const IconThemeData(color: Color(0xFF5C6BC0)),
      ),
      // ---JOSEPHINES ADDITION END---
      body: Container(
        // ---JOSEPHINES ADDITION START---
        // Soft gradient background — matches session screen exactly
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFDCEEFA), // soft sky blue
              Color(0xFFEDE7F6), // soft lavender
              Color(0xFFF1F8E9), // soft mint white
            ],
          ),
        ),
        // ---JOSEPHINES ADDITION END---
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          children: [
            // Account section
            _buildAccountCard(),

            const SizedBox(height: 24),

            // ---JOSEPHINES ADDITION START---
            // Section header redesigned with colored pill
            _buildSectionHeader('⚙️', 'Device Settings'),

            // ---JOSEPHINES ADDITION END---
            const SizedBox(height: 12),

            // Brightness
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---JOSEPHINES ADDITION START---
                  _buildSettingLabel(
                    icon: Icons.wb_sunny_rounded,
                    iconColor: const Color(0xFFFFB300),
                    iconBg: const Color(0xFFFFF8E1),
                    label: 'Brightness',
                    value: '${_brightness.toInt()}',
                  ),
                  // ---JOSEPHINES ADDITION END---
                  SliderTheme(
                    // ---JOSEPHINES ADDITION START---
                    // Custom slider styling — soft yellow/amber
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFFFFB300),
                      inactiveTrackColor: const Color(
                        0xFFFFB300,
                      ).withValues(alpha: 0.2),
                      thumbColor: const Color(0xFFFFB300),
                      overlayColor: const Color(
                        0xFFFFB300,
                      ).withValues(alpha: 0.15),
                      trackHeight: 4,
                    ),
                    // ---JOSEPHINES ADDITION END---
                    child: Slider(
                      value: _brightness,
                      min: 0,
                      max: 255,
                      divisions: 255,
                      onChanged: (value) {
                        setState(() => _brightness = value);
                      },
                      onChangeEnd: (value) {
                        HapticFeedback.selectionClick();
                        bluetoothService.writeBrightness(
                          value.toInt().toString(),
                        );
                      },
                    ),
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
                  // ---JOSEPHINES ADDITION START---
                  // Section label for breathing
                  _buildSettingLabel(
                    icon: Icons.air_rounded,
                    iconColor: _softBlue,
                    iconBg: const Color(0xFFE3F2FD),
                    label: 'Breathing Rhythm',
                    value:
                        '${_formatSeconds(_inhaleTime)} in · ${_formatSeconds(_exhaleTime)} out',
                  ),
                  const SizedBox(height: 6),
                  // Reset to defaults button — professor requested
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _inhaleTime = 4.5;
                          _exhaleTime = 9.0;
                        });
                        _writeInhaleTime(bluetoothService);
                        _writeExhaleTime(bluetoothService);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _softBlue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.restart_alt_rounded,
                              size: 14,
                              color: _softBlue,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Reset to default (4.5s / 9s)',
                              style: TextStyle(
                                fontSize: 11,
                                color: _softBlue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // ---JOSEPHINES ADDITION END---

                  // Visual breath ratio bar
                  _buildBreathRatioBar(),
                  const SizedBox(height: 20),
                  // ---JOSEPHINES ADDITION END---

                  // Inhale row
                  _buildTimeRow(
                    label: 'Inhale',
                    icon: Icons.arrow_upward_rounded,
                    // ---JOSEPHINES ADDITION START---
                    iconColor: _softBlue,
                    iconBg: const Color(0xFFE3F2FD),
                    // ---JOSEPHINES ADDITION END---
                    value: _inhaleTime,
                    onDecrement: _inhaleTime > 2.0
                        ? () {
                            HapticFeedback.selectionClick();
                            setState(() => _inhaleTime -= 0.5);
                            _writeInhaleTime(bluetoothService);
                          }
                        : null,
                    onIncrement: _inhaleTime < 15.0
                        ? () {
                            HapticFeedback.selectionClick();
                            setState(() => _inhaleTime += 0.5);
                            _writeInhaleTime(bluetoothService);
                          }
                        : null,
                  ),

                  // ---JOSEPHINES ADDITION START---
                  const SizedBox(height: 12),
                  Divider(color: Colors.grey.shade200, height: 1),
                  const SizedBox(height: 12),
                  // ---JOSEPHINES ADDITION END---

                  // Exhale row
                  _buildTimeRow(
                    label: 'Exhale',
                    icon: Icons.arrow_downward_rounded,
                    // ---JOSEPHINES ADDITION START---
                    iconColor: _softPurple,
                    iconBg: const Color(0xFFEDE7F6),
                    // ---JOSEPHINES ADDITION END---
                    value: _exhaleTime,
                    onDecrement: _exhaleTime > 2.0
                        ? () {
                            HapticFeedback.selectionClick();
                            setState(() => _exhaleTime -= 0.5);
                            _writeExhaleTime(bluetoothService);
                          }
                        : null,
                    onIncrement: _exhaleTime < 15.0
                        ? () {
                            HapticFeedback.selectionClick();
                            setState(() => _exhaleTime += 0.5);
                            _writeExhaleTime(bluetoothService);
                          }
                        : null,
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
                  // ---JOSEPHINES ADDITION START---
                  _buildSettingLabel(
                    icon: Icons.vibration_rounded,
                    iconColor: _softPurple,
                    iconBg: const Color(0xFFEDE7F6),
                    label: 'Vibration Intensity',
                    value: '${_motorStrength.toInt()}',
                  ),
                  // ---JOSEPHINES ADDITION END---
                  SliderTheme(
                    // ---JOSEPHINES ADDITION START---
                    // Custom slider — soft purple
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: _softPurple,
                      inactiveTrackColor: _softPurple.withValues(alpha: 0.2),
                      thumbColor: _softPurple,
                      overlayColor: _softPurple.withValues(alpha: 0.15),
                      trackHeight: 4,
                    ),
                    // ---JOSEPHINES ADDITION END---
                    child: Slider(
                      value: _motorStrength,
                      min: 0,
                      max: 255,
                      divisions: 255,
                      onChanged: (value) {
                        setState(() => _motorStrength = value);
                      },
                      onChangeEnd: (value) {
                        HapticFeedback.selectionClick();
                        bluetoothService.writeMotorStrength(
                          value.toInt().toString(),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ---JOSEPHINES ADDITION START---
            // App info footer — cuter version
            _buildAppFooter(),
            // ---JOSEPHINES ADDITION END---
          ],
        ),
      ),
    );
  }

  // ---JOSEPHINES ADDITION START---
  // Section header with emoji and colored accent
  Widget _buildSectionHeader(String emoji, String label) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: _softPurple.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 16)),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF5C6BC0),
          ),
        ),
      ],
    );
  }

  // Reusable label row with icon bubble + label + current value
  Widget _buildSettingLabel({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF37474F),
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: iconColor,
            ),
          ),
        ),
      ],
    );
  }

  // Visual bar showing the inhale/exhale ratio
  Widget _buildBreathRatioBar() {
    final total = _inhaleTime + _exhaleTime;
    final inhaleFraction = _inhaleTime / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Row(
            children: [
              Flexible(
                flex: (_inhaleTime * 10).toInt(),
                child: Container(height: 8, color: _softBlue),
              ),
              Flexible(
                flex: (_exhaleTime * 10).toInt(),
                child: Container(height: 8, color: _softPurple),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _softBlue,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'Inhale ${(inhaleFraction * 100).round()}%',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(width: 12),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _softPurple,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'Exhale ${((1 - inhaleFraction) * 100).round()}%',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ],
    );
  }

  // Time stepper row (used for both inhale and exhale)
  Widget _buildTimeRow({
    required String label,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required double value,
    required VoidCallback? onDecrement,
    required VoidCallback? onIncrement,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Color(0xFF37474F),
          ),
        ),
        const Spacer(),
        // Minus button
        _buildStepButton(
          icon: Icons.remove,
          color: iconColor,
          onTap: onDecrement,
        ),
        const SizedBox(width: 12),
        // Value display
        SizedBox(
          width: 48,
          child: Center(
            child: Text(
              _formatSeconds(value),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: iconColor,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Plus button
        _buildStepButton(icon: Icons.add, color: iconColor, onTap: onIncrement),
      ],
    );
  }

  // Circular stepper button
  Widget _buildStepButton({
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: enabled ? color.withValues(alpha: 0.15) : Colors.grey.shade100,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? color : Colors.grey.shade400,
        ),
      ),
    );
  }

  // App footer — version + a little branding
  Widget _buildAppFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text('🌿', style: TextStyle(fontSize: 28)),
          const SizedBox(height: 8),
          const Text(
            'Calmwand',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF5C6BC0),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'v1.0.0',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 4),
          Text(
            'A breathing & biofeedback companion',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
  // ---JOSEPHINES ADDITION END---

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // ---JOSEPHINES ADDITION START---
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _softPurple.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        // ---JOSEPHINES ADDITION END---
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
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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

  Widget _buildAccountCard() {
    final authService = context.watch<AuthService>();

    if (authService.isLoggedIn) {
      return _buildCard(
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  // ---JOSEPHINES ADDITION START---
                  color: _softPurple.withValues(alpha: 0.15),
                  // ---JOSEPHINES ADDITION END---
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.account_circle,
                  // ---JOSEPHINES ADDITION START---
                  color: _softPurple,
                ),
                // ---JOSEPHINES ADDITION END---
              ),
              title: const Text(
                'Signed In',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                authService.userEmail ?? 'Unknown',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade200),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.logout, color: Colors.red.shade400),
              ),
              title: const Text(
                'Sign Out',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: const Text(
                'Sessions will remain on device',
                style: TextStyle(fontSize: 12),
              ),
              onTap: () => _showLogoutConfirmation(),
            ),
          ],
        ),
      );
    } else {
      return _buildCard(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              // ---JOSEPHINES ADDITION START---
              color: _softPurple.withValues(alpha: 0.15),
              // ---JOSEPHINES ADDITION END---
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.login,
              // ---JOSEPHINES ADDITION START---
              color: _softPurple,
            ),
            // ---JOSEPHINES ADDITION END---
          ),
          title: const Text(
            'Sign In',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Sync sessions across devices',
            style: TextStyle(fontSize: 12),
          ),
          trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => LoginScreen(
                  onLoginSuccess: () {
                    Navigator.of(context).pop();
                  },
                ),
              ),
            );
          },
        ),
      );
    }
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text(
          'Are you sure you want to sign out?\n\n'
          'Your sessions will remain on this device, but new sessions will not sync to the cloud until you sign in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final authService = context.read<AuthService>();
              await authService.logout();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
