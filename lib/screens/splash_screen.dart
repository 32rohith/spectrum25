import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:lottie/lottie.dart';
import 'welcome_screen.dart';
import '../services/auth_service.dart';
import '../models/team.dart';
import 'dart:developer' as developer;
import 'main_app_screen.dart';
import 'oc_main_screen.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _controller;
  final AuthService _authService = AuthService();
  bool _isFirebaseInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
    _setupAnimation();
  }

  Future<void> _initializeFirebase() async {
    try {
      await Firebase.initializeApp();
      setState(() {
        _isFirebaseInitialized = true;
      });
      _checkSavedCredentials();
    } catch (e) {
      developer.log('Failed to initialize Firebase: $e');
      // Fall back to welcome screen if Firebase fails
      Timer(const Duration(seconds: 3), () {
        _navigateToWelcomeScreen();
      });
    }
  }

  void _setupAnimation() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && _isFirebaseInitialized) {
        // Animation is complete and Firebase is ready
        // Note: Only navigate if we haven't already checked credentials
        if (!_credentialsChecked) {
          _checkSavedCredentials();
        }
      }
    });
    
    _controller.forward();
  }

  bool _credentialsChecked = false;

  Future<void> _checkSavedCredentials() async {
    if (_credentialsChecked) return;
    _credentialsChecked = true;
    
    developer.log('Checking for saved login credentials');
    
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
            developer.log('OC auto-login successful, navigating to OC screen');
            
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const OCMainScreen(),
              ),
            );
            return;
          } else {
            developer.log('OC auto-login failed: ${ocInfo['message']}');
            _navigateToWelcomeScreen();
            return;
          }
        }
        
        // If not OC, try regular team login with saved credentials
        developer.log('Found team credentials, attempting to log in');
        final result = await _authService.loginWithSavedCredentials();
        
        if (result['success'] == true) {
          developer.log('Auto-login successful, navigating to home screen');
          
          // Navigate to home screen with the loaded data
          final Team team = result['team'] as Team;
          final String userRole = result['userRole'] as String;
          final String userId = result['userId'] as String;
          final String userName = result['userName'] as String;
          
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => MainAppScreen(
                team: team,
                userRole: userRole,
                userId: userId,
                userName: userName,
              ),
            ),
          );
          return;
        } else {
          developer.log('Auto-login failed: ${result['message']}');
          // If auto-login failed, go to welcome screen
          _navigateToWelcomeScreen();
        }
      } else {
        developer.log('No saved credentials found');
        _navigateToWelcomeScreen();
      }
    } catch (e) {
      developer.log('Error checking saved credentials: $e');
      _navigateToWelcomeScreen();
    }
  }

  void _navigateToWelcomeScreen() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const WelcomeScreen(),
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LottieBuilder.asset(
              'assets/animations/splash.json',
              controller: _controller,
              onLoaded: (composition) {
                _controller.duration = composition.duration;
                _controller.forward();
              },
              width: 300,
              height: 300,
            ),
            const SizedBox(height: 20),
            const Text(
              'Spectrumatix',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6C63FF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}