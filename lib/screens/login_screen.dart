import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
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
        // Get user role from result
        String userRole = result['userRole'] ?? '';
        print('Processing successful login with role: $userRole on screen type - isLeader: ${widget.isLeader}, isMember: ${widget.isMember}');
        
        // Check if login page type matches the user role
        bool isCorrectPage = (widget.isLeader && userRole == 'leader') || 
                             (widget.isMember && userRole == 'member');
        
        if (!isCorrectPage) {
          setState(() {
            if (userRole == 'leader' && !widget.isLeader) {
              _errorMessage = 'These credentials are for a team leader. Please use the leader login page.';
            } else if (userRole == 'member' && !widget.isMember) {
              _errorMessage = 'These credentials are for a team member. Please use the member login page.';
            } else {
              _errorMessage = 'Invalid login credentials for this page.';
            }
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
        
        // Navigate to appropriate screen based on verification status
        if (!result['team'].isVerified) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => QRVerificationScreen(team: result['team']),
            ),
          );
        } else {
          // Navigate to main screen based on role
          if (userRole == 'leader') {
            // TODO: Navigate to leader dashboard
            print('Navigating to leader dashboard');
            // Temporary placeholder until navigation is implemented
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Leader dashboard would open here')),
            );
          } else {
            // TODO: Navigate to member dashboard
            print('Navigating to member dashboard');
            // Temporary placeholder until navigation is implemented
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Member dashboard would open here')),
            );
          }
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
        ],
      ),
    );
  }
} 