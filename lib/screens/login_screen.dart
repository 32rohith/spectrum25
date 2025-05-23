import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:developer' as developer;
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/auth_service.dart';
import 'qr_verification_screen.dart';
import 'main_app_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;
  final AuthService _authService = AuthService();
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    // Check if there's any existing session and sign out
    _clearPreviousSession();
  }

  Future<void> _clearPreviousSession() async {
    try {
      await _authService.signOut();
      developer.log('Previous session cleared on login screen init');
    } catch (e) {
      developer.log('Error clearing previous session: $e');
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (_formKey.currentState!.validate()) {
      final username = _usernameController.text.trim();
      final password = _passwordController.text.trim();

      developer.log('Attempting login with: Username: $username');
      
      final result = await _authService.loginTeam(
        username: username,
        password: password,
      );

      developer.log('Login result: ${result['success']} - ${result['message']}');
      if (result['userRole'] != null) {
        developer.log('User role: ${result['userRole']}');
      }
      if (result['userId'] != null) {
        developer.log('User ID: ${result['userId']}');
      }
      if (result['userEmail'] != null) {
        developer.log('User Email: ${result['userEmail']}');
      }

      setState(() {
        _isLoading = false;
      });

      if (result['success']) {
        // Get user role from result
        String userRole = result['userRole'] ?? '';
        String userName = result['userName'] ?? '';
        String userEmail = result['userEmail'] ?? '';
        
        developer.log('Processing successful login with role: $userRole, name: $userName, email: $userEmail');
        
        // Navigate to appropriate screen based on verification status
        if (!result['team'].isVerified) {
          developer.log('Team not verified, navigating to QR verification');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => QRVerificationScreen(
                team: result['team'],
                userRole: userRole,
                userId: result['userId'],
              ),
            ),
          );
        } else {
          // Navigate to main screen
          developer.log('Team verified, navigating to main app screen');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MainAppScreen(
                team: result['team'],
                userRole: userRole,
                userName: userName,
                userId: result['userId'],
              ),
            ),
          );
          
          // Show welcome message based on role
          String roleMessage = 'Welcome $userName! Logged in as ${userRole == 'leader' ? 'Team Leader' : 'Team Member'}';
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(roleMessage),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = result['message'];
        });
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Team Login',
      ),
      body: Stack(
        children: [
          // Black Background
          Container(
            color: AppTheme.backgroundColor,
          ),
          
          // Blue Blurred Circle - Top Left
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryColor.withOpacity(0.3),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.transparent,
                  ),
                ),
              ),
            ),
          ),
          
          // Blue Blurred Circle - Bottom Right
          Positioned(
            bottom: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accentColor.withOpacity(0.3),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.transparent,
                  ),
                ),
              ),
            ),
          ),
          
          // Main Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width - 48,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.05),
                      Icon(
                        Icons.login_rounded,
                        color: AppTheme.primaryColor,
                        size: 80,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Welcome to Spectrum Hackathon!',
                        style: TextStyle(
                          color: AppTheme.textPrimaryColor,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Login with your team credentials',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),
                      
                      // Username field
                      CustomTextField(
                        label: 'Username',
                        hint: 'Enter your username',
                        controller: _usernameController,
                        prefixIcon: Icon(
                          Icons.alternate_email,
                          color: AppTheme.textSecondaryColor,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your username';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      
                      // Password field
                      CustomTextField(
                        label: 'Password',
                        hint: 'Enter password',
                        controller: _passwordController,
                        obscureText: !_showPassword,
                        prefixIcon: Icon(
                          Icons.lock_outline,
                          color: AppTheme.textSecondaryColor,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showPassword ? Icons.visibility_off : Icons.visibility,
                            color: AppTheme.accentColor,
                          ),
                          onPressed: () {
                            setState(() {
                              _showPassword = !_showPassword;
                            });
                          },
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 40),
                      
                      // Login button
                      SizedBox(
                        width: double.infinity,
                        child: GlassButton(
                          text: 'Login',
                          onPressed: _login,
                          isLoading: _isLoading,
                          icon: Icons.login,
                        ),
                      ),
                      
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Color.fromRGBO(
                              AppTheme.errorColor.red,
                              AppTheme.errorColor.green,
                              AppTheme.errorColor.blue,
                              0.1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Color.fromRGBO(
                                AppTheme.errorColor.red, 
                                AppTheme.errorColor.green, 
                                AppTheme.errorColor.blue,
                                0.5,
                              ),
                            ),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: AppTheme.errorColor,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 20),
                      
                      // Additional info
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              "Don't have a team yet?",
                              style: TextStyle(
                                color: AppTheme.textSecondaryColor,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              // Navigate to signup
                              // This is handled in the welcome screen
                            },
                            child: Text(
                              'Register Now',
                              style: TextStyle(
                                color: AppTheme.accentColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Login system will automatically detect if you are a team leader or member',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 