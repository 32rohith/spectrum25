import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:developer' as developer;
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';

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
  
  // Initialize plugins first to avoid any delays
  await _initPathProvider();
  await initializeFirebase();
  
  // Set orientation constraints after initialization
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
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
      home: const SplashScreen(),
    );
  }

}
