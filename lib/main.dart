import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:developer' as developer;
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/welcome_screen.dart';
import 'services/auth_service.dart';
import 'screens/main_app_screen.dart';
import 'screens/oc_main_screen.dart';

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
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkSavedCredentials();
  }

  Future<void> _checkSavedCredentials() async {
    try {
      // First check if user is logged in
      final isLoggedIn = await _authService.isLoggedIn();
      
      if (isLoggedIn) {
        developer.log('Found saved credentials, checking credential type');
        
        // Check if it's an OC member login
        final isOCMember = await _authService.isOCLoggedIn();
        
        if (isOCMember) {
          developer.log('Found OC member credentials, retrieving info');
          final ocInfo = await _authService.getOCLoginInfo();
          
          if (ocInfo['success'] == true) {
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => const OCMainScreen(),
                ),
              );
            }
            return;
          }
        }
        
        // If not OC, try regular team login with saved credentials
        final result = await _authService.loginWithSavedCredentials();
        
        if (result['success'] == true && mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => MainAppScreen(
                team: result['team'],
                userRole: result['userRole'],
                userId: result['userId'],
                userName: result['userName'],
              ),
            ),
          );
          return;
        }
      }
    } catch (e) {
      developer.log('Error checking saved credentials: $e');
    }
    
    // Default to welcome screen
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
              ),
            ),
          )
        : const WelcomeScreen();
  }
}
