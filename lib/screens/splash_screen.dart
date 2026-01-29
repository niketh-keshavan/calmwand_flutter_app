import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/preferences_service.dart';
import '../services/auth_service.dart';
import 'disclaimer_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';

/// Splash screen shown on app launch
/// Ported from SplashScreenView.swift
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Set up spinning animation (continuous)
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(); // Continuous spinning

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    // Navigate after delay
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        _navigateToNextScreen();
      }
    });
  }

  void _navigateToNextScreen() {
    final hasAcceptedDisclaimer = PreferencesService.hasAcceptedDisclaimer();
    final authService = context.read<AuthService>();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          // If not accepted disclaimer, show disclaimer first
          if (!hasAcceptedDisclaimer) {
            return const DisclaimerScreen();
          }
          // If not logged in, show login screen
          if (!authService.isLoggedIn) {
            return const LoginScreen();
          }
          // Otherwise go to home
          return const HomeScreen();
        },
        transitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        color: Colors.white,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Spinning app logo
              RotationTransition(
                turns: _controller,
                child: Image.asset(
                  'web/icons/appstore.png',
                  width: 100,
                  height: 100,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback to icon if image not found
                    return Icon(
                      Icons.air,
                      size: 100,
                      color: Colors.blue.shade700,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
