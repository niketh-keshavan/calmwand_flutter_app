import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'session_summary_screen.dart';
import 'session_history_screen.dart';
import 'settings_screen.dart';
import 'how_to_use_screen.dart';

/// Main home screen with bottom tab navigation
/// Ported from HomeView.swift
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // Tab screens
  final List<Widget> _screens = const [
    SessionSummaryScreen(),
    SessionHistoryScreen(),
    SettingsScreen(),
    HowToUseScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.blue.shade700,
        unselectedItemColor: Colors.grey.shade600,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events),
            label: 'Session Summary',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.show_chart),
            label: 'Session History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Settings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book),
            label: 'Guide',
          ),
        ],
      ),
    );
  }
}
