import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:developer' as developer;
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/welcome_screen.dart';

// Initialize path_provider plugin to ensure it's available for google_fonts
Future<void> _initPathProvider() async {
  try {
    // Call any path_provider method to force plugin registration
    await getApplicationSupportDirectory();
    developer.log('Path provider initialized successfully');
  } catch (e) {
    developer.log('Error initializing path provider: $e');
  }
}

// Simplify Firebase initialization to avoid channel errors
Future<void> initializeFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    developer.log('Firebase initialized successfully');
  } catch (e) {
    developer.log('Error initializing Firebase: $e');
    // Don't rethrow so the app can continue to function
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set orientation constraints
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Initialize plugins
  await _initPathProvider();
  await initializeFirebase();  
  // Note: Impeller settings should be configured in the app's native settings
  // rather than through code, as FlutterView.useImpeller is not available
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spectrum Hackathon',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const WelcomeScreen(),
    );
  }

}
