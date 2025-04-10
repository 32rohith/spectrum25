import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/auth_service.dart';
import 'qr_verification_screen.dart';

class LoginScreen extends StatefulWidget {
  final bool isLeader;
  final bool isMember;

  const LoginScreen({
    super.key, 
    this.isLeader = false,
    this.isMember = true, // Default to member login if not specified
  });

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

      print('Attempting login with: Username: $username, IsLeader: ${widget.isLeader}, IsMember: ${widget.isMember}');
      
      final result = await _authService.loginTeam(
        username: username,
        password: password,
      );

      print('Login result: ${result['success']} - ${result['message']}');
      if (result['userRole'] != null) {
        print('User role: ${result['userRole']}');
      }

      setState(() {
        _isLoading = false;
      });

      if (result['success']) {
        // Check if the user role matches the expected role based on login type
        String userRole = result['userRole'] ?? '';
        
        if ((widget.isLeader && userRole != 'leader') || 
            (widget.isMember && userRole != 'member')) {
          setState(() {
            _errorMessage = widget.isLeader 
                ? 'These credentials are for a team member, not a leader. Please use leader login page.'
                : 'These credentials are for a team leader, not a member. Please use leader login page.';
          });
          return;
        }
        
        // Success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Login successful! Welcome ${result['userName'] ?? 'back'}!',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // Navigate to QR verification if not verified yet
        if (!result['team'].isVerified) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => QRVerificationScreen(team: result['team']),
            ),
          );
        } else {
          // Navigate to main screen
          // TODO: Navigate to main screen
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

  String _getTitle() {
    if (widget.isLeader) {
      return 'Team Leader Login';
    } else {
      return 'Team Member Login';
    }
  }

  String _getWelcomeMessage() {
    if (widget.isLeader) {
      return 'Welcome back, Team Leader!';
    } else {
      return 'Welcome, Team Member!';
    }
  }

  String _getSubtitle() {
    if (widget.isLeader) {
      return 'Login to manage your team and hackathon project';
    } else {
      return 'Login to access your team\'s hackathon project';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: _getTitle(),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryDarkColor.withOpacity(0.8),
              AppTheme.backgroundColor,
              AppTheme.primaryDarkColor.withOpacity(0.6),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.05),
                  Icon(
                    widget.isLeader ? Icons.person : Icons.person_outline,
                    color: AppTheme.primaryColor,
                    size: 80,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _getWelcomeMessage(),
                    style: TextStyle(
                      color: AppTheme.textPrimaryColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getSubtitle(),
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
                    hint: widget.isLeader 
                        ? 'Enter leader username' 
                        : 'Enter member username',
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
                    obscureText: true,
                    prefixIcon: Icon(
                      Icons.lock_outline,
                      color: AppTheme.textSecondaryColor,
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
                  GlassButton(
                    text: 'Login',
                    onPressed: _login,
                    isLoading: _isLoading,
                    icon: Icons.login,
                  ),
                  
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.errorColor.withOpacity(0.5),
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
                  if (widget.isLeader) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have a team yet?",
                          style: TextStyle(
                            color: AppTheme.textSecondaryColor,
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
                  ] else ...[
                    Text(
                      'Make sure to use the credentials provided to you',
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 