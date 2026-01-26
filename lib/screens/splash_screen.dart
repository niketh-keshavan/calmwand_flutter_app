import 'package:flutter/material.dart';
import '../services/preferences_service.dart';
import '../utils/app_theme.dart';
import 'disclaimer_screen.dart';
import 'home_screen.dart';

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

    // Set up fade animation
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    // Navigate after delay
    Future.delayed(const Duration(milliseconds: 1050), () {
      if (mounted) {
        _controller.forward().then((_) {
          _navigateToNextScreen();
        });
      }
    });
  }

  void _navigateToNextScreen() {
    final hasAcceptedDisclaimer = PreferencesService.hasAcceptedDisclaimer();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return hasAcceptedDisclaimer
              ? const HomeScreen()
              : const DisclaimerScreen();
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
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          color: Colors.white,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Spinning app logo
                RotationTransition(
                  turns: Tween(begin: 0.0, end: 1.0).animate(_controller),
                  child: Image.network(
                    'icons/appstore.png',
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
      ),
    );
  }
}
