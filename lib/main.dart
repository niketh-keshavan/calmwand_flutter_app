import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'services/storage_service.dart';
import 'services/preferences_service.dart';
import 'services/bluetooth_service.dart';
import 'providers/session_provider.dart';
import 'providers/current_session_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize storage services
  await StorageService.initialize();
  await PreferencesService.initialize();

  // Enable wake lock to prevent screen from sleeping during sessions
  await WakelockPlus.enable();

  runApp(const CalmwandApp());
}

class CalmwandApp extends StatelessWidget {
  const CalmwandApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Settings provider (needed first for session provider)
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(),
        ),

        // Bluetooth service
        ChangeNotifierProvider(
          create: (_) => BluetoothService(),
        ),

        // Session provider (depends on settings)
        ChangeNotifierProxyProvider<SettingsProvider, SessionProvider>(
          create: (context) => SessionProvider(
            context.read<SettingsProvider>().settings,
          ),
          update: (_, settings, previous) =>
              previous ?? SessionProvider(settings.settings),
        ),

        // Current session provider
        ChangeNotifierProvider(
          create: (_) => CurrentSessionProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'Calmwand',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          brightness: Brightness.light,
          useMaterial3: true,
          // Force light mode
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
