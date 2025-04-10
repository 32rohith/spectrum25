import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'oc_main_screen.dart';

class OCLoginScreen extends StatefulWidget {
  const OCLoginScreen({super.key});

  @override
  _OCLoginScreenState createState() => _OCLoginScreenState();
}

class _OCLoginScreenState extends State<OCLoginScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;
  bool _showPassword = false;
  
  // OC member data & login security
  List<List<dynamic>> _ocMembersData = [];
  int _loginAttempts = 0;
  int _maxLoginAttempts = 5;
  bool _lockoutActive = false;
  DateTime? _lockoutEndTime;
  final _lockoutDuration = const Duration(minutes: 15);

  @override
  void initState() {
    super.initState();
<<<<<<< Updated upstream
    _loadOCMembersData();
=======
    _loadOCCredentials();
    
    // Pre-fill the credentials for easier testing
    _idController.text = "Spectrum25";
    _passwordController.text = "ospc*csed321";
>>>>>>> Stashed changes
  }
  
  Future<void> _loadOCMembersData() async {
    try {
      // Load the CSV file from assets
      print('Attempting to load OC credentials from assets/octest.csv');
      final String csvData = await rootBundle.loadString('assets/octest.csv', cache: false);
      
      print('CSV data loaded: $csvData');
      
      // Parse the CSV data
      _ocMembersData = const CsvToListConverter().convert(csvData);
      
<<<<<<< Updated upstream
      print('Loaded ${_ocMembersData.length} OC members records');
    } catch (e) {
      print('Error loading OC members data: $e');
      setState(() {
        _errorMessage = 'Error loading OC members data. Please try again.';
=======
      print('Parsed OC credentials: $_ocCredentials');
      
      // Manual check - if empty, use hardcoded credentials as fallback
      if (_ocCredentials.isEmpty || _ocCredentials.length < 2) {
        print('Warning: CSV empty or invalid format, using hardcoded credentials');
        _ocCredentials = [
          ['ID', 'Password'], // Header row
          ['Spectrum25', 'ospc*csed321'] // Default credentials
        ];
      }
    } catch (e) {
      print('Error loading OC credentials: $e');
      
      // Fallback to hardcoded credentials
      _ocCredentials = [
        ['ID', 'Password'], // Header row
        ['Spectrum25', 'ospc*csed321'] // Default credentials
      ];
      
      setState(() {
        _errorMessage = 'Error loading OC credentials. Using default.';
>>>>>>> Stashed changes
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // Verify if user exists in OC members data
  bool _verifyOCMember(String name, String phone) {
    if (_ocMembersData.isEmpty) {
      setState(() {
        _errorMessage = 'OC members data not loaded. Please try again.';
      });
      return false;
    }
    
<<<<<<< Updated upstream
    // Normalize inputs for comparison (trim whitespace, convert to lowercase)
    final normalizedName = name.trim().toLowerCase();
    final normalizedPhone = phone.trim();
    
    // Check if user exists in OC members data
    for (var member in _ocMembersData) {
      if (member.length >= 2) {
        final memberName = member[0].toString().trim().toLowerCase();
        final memberPhone = member[1].toString().trim();
        
        if (memberName == normalizedName && memberPhone == normalizedPhone) {
=======
    // Debug print to check CSV data
    print('Checking credentials. CSV Data: $_ocCredentials');
    print('Entered ID: "$id", Password: "$password"');
    
    // Skip header row (index 0) and check against actual credentials
    for (int i = 1; i < _ocCredentials.length; i++) {
      final credential = _ocCredentials[i];
      if (credential.length >= 2) {
        final validId = credential[0].toString().trim();
        final validPassword = credential[1].toString().trim();
        
        print('Comparing with: ID: "$validId", Password: "$validPassword"');
        
        // Direct exact comparison
        if (id.trim() == validId && password.trim() == validPassword) {
>>>>>>> Stashed changes
          return true;
        }
      }
    }
    
    return false;
  }

  // Check if user is currently locked out
  bool _isLockedOut() {
    if (!_lockoutActive) return false;
    
    if (_lockoutEndTime != null && DateTime.now().isAfter(_lockoutEndTime!)) {
      // Lockout period has ended
      setState(() {
        _lockoutActive = false;
        _loginAttempts = 0;
        _lockoutEndTime = null;
      });
      return false;
    }
    
    return true;
  }

  // Handle lockout after failed attempts
  void _handleFailedAttempt() {
    setState(() {
      _loginAttempts++;
      
      if (_loginAttempts >= _maxLoginAttempts) {
        _lockoutActive = true;
        _lockoutEndTime = DateTime.now().add(_lockoutDuration);
        _errorMessage = 'Too many failed attempts. Please try again after ${_lockoutDuration.inMinutes} minutes.';
      } else {
        _errorMessage = 'Verification failed. Invalid name or phone number. '
            '${_maxLoginAttempts - _loginAttempts} attempts remaining.';
      }
    });
  }

  void _login() {
    if (_formKey.currentState!.validate()) {
      // Check lockout status first
      if (_isLockedOut()) {
        final remaining = _lockoutEndTime!.difference(DateTime.now());
        setState(() {
          _errorMessage = 'Account temporarily locked. Try again in ${remaining.inMinutes} min ${remaining.inSeconds % 60} sec.';
        });
        return;
      }
      
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      Future.delayed(const Duration(milliseconds: 800), () {
<<<<<<< Updated upstream
        final name = _nameController.text;
        final phone = _phoneController.text;
        
        final isVerified = _verifyOCMember(name, phone);
=======
        final id = _idController.text.trim();
        final password = _passwordController.text.trim();
        
        // Try both ways - in case user entered credentials in the wrong order
        bool isVerified = _verifyOCCredentials(id, password);
        
        // If normal order failed, try reversed (in case user swapped fields)
        if (!isVerified && id.contains("*")) { // Likely the password in the ID field
          print("First attempt failed. Trying reversed credentials...");
          isVerified = _verifyOCCredentials(password, id);
          
          // If reversed worked, swap the input fields for clarity
          if (isVerified) {
            _idController.text = password;
            _passwordController.text = id;
          }
        }
>>>>>>> Stashed changes
        
        setState(() {
          _isLoading = false;
        });
        
        if (isVerified) {
          // Reset login attempts on successful login
          setState(() {
            _loginAttempts = 0;
            _errorMessage = null;
          });
          
          // Navigate to OC main screen
          Navigator.pushReplacement(
            context, 
            MaterialPageRoute(
              builder: (context) => const OCMainScreen(),
            ),
          );
          
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Login successful'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          // Handle failed login attempt
          _handleFailedAttempt();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'OC Member Login',
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
                    
                    // OC Logo
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.admin_panel_settings,
                        color: AppTheme.accentColor,
                        size: 80,
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Title
                    Text(
                      'Organizing Committee Login',
                      style: TextStyle(
                        color: AppTheme.textPrimaryColor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Subtitle
                    Text(
                      'Please verify your identity',
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Name Field
                    CustomTextField(
                      label: 'Full Name',
                      hint: 'Enter your full name',
                      controller: _nameController,
                      prefixIcon: Icon(
                        Icons.person_outline,
                        color: AppTheme.textSecondaryColor,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Password Field (Phone Number)
                    CustomTextField(
                      label: 'Password',
                      hint: 'Enter your password (phone number)',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
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
                        // Ensure only numbers are entered
                        if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                          return 'Password must contain only numbers';
                        }
                        
                        // Remove all non-numeric characters for validation
                        final cleanPhone = value.replaceAll(RegExp(r'\D'), '');
                        
                        // Basic phone number validation - can be customized for your country format
                        if (cleanPhone.length < 8 || cleanPhone.length > 15) {
                          return 'Please enter a valid phone number';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Login Button
                    GlassButton(
                      text: 'Verify & Login',
                      onPressed: _login,
                      isLoading: _isLoading,
                      icon: Icons.verified_user,
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Debug button - direct login with hardcoded credentials
                    TextButton(
                      onPressed: () async {
                        print("Debug login attempt with hardcoded credentials");
                        
                        // Force reload CSV to ensure fresh data
                        await _loadOCCredentials();
                        
                        // Directly navigate to main screen
                        Navigator.pushReplacement(
                          context, 
                          MaterialPageRoute(
                            builder: (context) => const OCMainScreen(),
                          ),
                        );
                        
                        // Show success message
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Debug login successful'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Text(
                        'DEBUG: Direct Login',
                        style: TextStyle(
                          color: AppTheme.accentColor,
                          decoration: TextDecoration.underline,
                        ),
                      ),
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
                    
                    const SizedBox(height: 16),
                    
                    // Info text
                    Text(
                      'Only authorized organizing committee members can login',
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
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