import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/session_provider.dart';
import '../services/auth_service.dart';
import '../services/cloud_session_service.dart';
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
  void initState() {
    super.initState();
    // Fetch cloud sessions after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchCloudSessions();
    });
  }

  Future<void> _fetchCloudSessions() async {
    final authService = context.read<AuthService>();
    if (authService.isLoggedIn) {
      final sessionProvider = context.read<SessionProvider>();
      await sessionProvider.fetchAndMergeCloudSessions();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionProvider = context.watch<SessionProvider>();
    
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          // Show loading overlay when fetching from cloud
          if (sessionProvider.isLoadingFromCloud)
            Container(
              color: Colors.black26,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.blue.shade700),
                        const SizedBox(height: 16),
                        const Text('Loading sessions from cloud...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
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
