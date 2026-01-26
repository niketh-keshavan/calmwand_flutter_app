import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'services/storage_service.dart';
import 'services/preferences_service.dart';
import 'services/bluetooth_service.dart';
import 'services/auth_service.dart';
import 'services/cloud_session_service.dart';
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

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
        // Auth service (needed first for cloud sync)
        ChangeNotifierProvider(
          create: (_) => AuthService()..initialize(),
        ),

        // Settings provider (needed first for session provider)
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(),
        ),

        // Bluetooth service
        ChangeNotifierProvider(
          create: (_) => BluetoothService(),
        ),

        // Cloud session service (depends on auth)
        ProxyProvider<AuthService, CloudSessionService>(
          update: (_, auth, __) => CloudSessionService(auth),
        ),

        // Session provider (depends on settings and cloud service)
        ChangeNotifierProxyProvider2<SettingsProvider, CloudSessionService, SessionProvider>(
          create: (context) => SessionProvider(
            context.read<SettingsProvider>().settings,
          ),
          update: (context, settings, cloudService, previous) {
            final provider = previous ?? SessionProvider(settings.settings);
            provider.setCloudService(cloudService);
            return provider;
          },
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
