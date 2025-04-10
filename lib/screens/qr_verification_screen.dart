import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/team.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/qr_scanner_service.dart';
import 'main_app_screen.dart';

class QRVerificationScreen extends StatefulWidget {
  final Team team;
  final String? userRole;
  final String? userId;

  const QRVerificationScreen({
    super.key,
    required this.team,
    this.userRole,
    this.userId,
  });

  @override
  _QRVerificationScreenState createState() => _QRVerificationScreenState();
}

class _QRVerificationScreenState extends State<QRVerificationScreen> {
  final QRScannerService _qrScannerService = QRScannerService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSuccess = false;
  String _successMessage = '';

  @override
  void initState() {
    super.initState();
    // Check if team is already verified
    if (widget.team.isVerified) {
      _handleAlreadyVerified();
    }
  }
  
  // Handle teams that are already verified
  void _handleAlreadyVerified() {
    setState(() {
      _isSuccess = true;
      _successMessage = 'Your team is already verified!';
    });
    
    // Navigate directly to main app after a short delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainAppScreen(
              team: widget.team,
              userRole: widget.userRole,
              userId: widget.userId,
            ),
          ),
        );
      }
    });
  }

  void _startQRScan() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isSuccess = false;
    });

    try {
      developer.log('Starting QR scan');
      
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QRScannerWidget(
            onQRViewCreated: _processQRCode,
            onCancel: () {
              developer.log('QR scan cancelled by user');
              setState(() {
                _isLoading = false;
              });
            },
          ),
        ),
      );
      
      // Check if we got a result and if the widget is still mounted
      if (result == null || !mounted) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      developer.log('QR scan result: $result');
      
      // Check if result is valid and verification was successful
      if (result is Map<String, dynamic> && result['success']) {
        setState(() {
          _isSuccess = true;
          _successMessage = result['message'] ?? 'Verification successful!';
          _isLoading = false;
        });
        
        // Get team with verification flag set
        Team verifiedTeam = result['team'] as Team;
        
        // Add delay before navigation to show success message
        Future.delayed(const Duration(seconds: 2), () {
          // Navigate to main app screen if verification successful
          if (mounted) {
            developer.log('Navigating to MainAppScreen with verified team');
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => MainAppScreen(
                  team: verifiedTeam,
                  userRole: widget.userRole,
                  userId: widget.userId,
                ),
              ),
            );
          }
        });
      } else {
        setState(() {
          _isLoading = false;
          if (result is Map<String, dynamic>) {
            _errorMessage = result['message'] ?? 'Verification failed';
          } else {
            _errorMessage = 'Verification was cancelled or encountered an error';
          }
        });
      }
    } catch (e) {
      developer.log('Error during QR scanning: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'An error occurred during QR scanning: $e';
        });
      }
    }
  }

  Future<Map<String, dynamic>> _processQRCode(String qrData) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      developer.log('Processing QR code data: $qrData');
      
      // Process QR code
      final result = await _qrScannerService.processQRCode(qrData);
      developer.log('QR code processing result: $result');

      // Only update UI if still mounted
      if (!mounted) {
        developer.log('Widget not mounted, returning result without UI update');
        return result;
      }

      // Ensure UI is updated with loading state
      setState(() {
        _isLoading = false;
      });

      if (result['success']) {
        // Create a new team instance with isVerified set to true
        final verifiedTeam = Team(
          teamName: widget.team.teamName,
          teamId: widget.team.teamId,
          username: widget.team.username,
          password: widget.team.password,
          leader: widget.team.leader,
          members: widget.team.members,
          isVerified: true,
          isRegistered: widget.team.isRegistered,
          projectSubmissionUrl: widget.team.projectSubmissionUrl,
        );
        
        // Update isVerified in Firestore database
        try {
          await _updateTeamVerificationInDatabase();
          developer.log('Team verification updated in database');
        } catch (e) {
          developer.log('Error updating database: $e');
          // Continue with local verification even if database update fails
        }
        
        // Return success result with verified team
        final successResult = {
          'success': true,
          'message': 'Team verified successfully',
          'team': verifiedTeam
        };
        
        // Pop with success result
        Navigator.pop(context, successResult);
        return successResult;
      } else {
        setState(() {
          _errorMessage = result['message'];
        });
        return result;
      }
    } catch (e) {
      developer.log('QR Processing error: $e');
      
      // Only update UI if still mounted
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'An error occurred during QR processing: $e';
        });
      }
      
      return {
        'success': false,
        'message': 'An error occurred during QR processing: $e',
      };
    }
  }

  // Function to update team verification status in Firestore
  Future<void> _updateTeamVerificationInDatabase() async {
    try {
      developer.log('Updating isVerified=true in Firestore for team: ${widget.team.teamId}');
      
      // Update the team document in Firestore
      await _firestore.collection('teams').doc(widget.team.teamId).update({
        'isVerified': true,
        'verifiedAt': FieldValue.serverTimestamp(),
      });
      
      developer.log('Successfully updated team verification in database');
    } catch (e) {
      developer.log('Error updating team in database: $e');
      throw e; // Rethrow so the calling function can handle it
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'QR Verification'),
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
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  
                  // Show success UI if verification is successful
                  if (_isSuccess) ...[
                    Icon(
                      Icons.check_circle_outline,
                      color: Colors.green,
                      size: 80,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Verification Successful!',
                      style: TextStyle(
                        color: AppTheme.textPrimaryColor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _successMessage,
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Redirecting to the main app...',
                      style: TextStyle(
                        color: AppTheme.accentColor,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ] else ...[
                    Icon(
                      Icons.qr_code_scanner,
                      color: AppTheme.primaryColor,
                      size: 80,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Team Verification Required',
                      style: TextStyle(
                        color: AppTheme.textPrimaryColor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Please scan the QR code provided by the organizing committee to verify your team and access the hackathon app.',
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    
                    // Instructions Card
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: AppTheme.accentColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Instructions',
                                style: TextStyle(
                                  color: AppTheme.accentColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '1. Find an organizing committee member\n'
                            '2. Ask them to show you the verification QR code\n'
                            '3. Press the "Scan QR Code" button below\n'
                            '4. Scan the OC verification QR code with your camera\n'
                            '5. Once verified, you\'ll get access to the hackathon app',
                            style: TextStyle(
                              color: AppTheme.textSecondaryColor,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Error Message
                    if (_errorMessage != null) ...[
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
                      const SizedBox(height: 20),
                    ],
                    
                    // Scan QR Button
                    GlassButton(
                      text: 'Scan QR Code',
                      onPressed: _startQRScan,
                      isLoading: _isLoading,
                      icon: Icons.qr_code_scanner,
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 