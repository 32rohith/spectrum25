import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../models/meal_tracking.dart';
import '../../services/meal_service.dart';
import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

class FoodTab extends StatefulWidget {
  const FoodTab({super.key});

  @override
  _FoodTabState createState() => _FoodTabState();
}

class _FoodTabState extends State<FoodTab> {
  final MealService _mealService = MealService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<Meal> _meals = [];
  Meal? _activeMeal;
  String? _errorMessage;
  String _qrData = '';
  String _memberName = '';
  String _teamName = '';
  String _memberId = '';
  Map<String, dynamic> _memberData = {};
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  // Load user data from Firebase
  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Try to get the member info from Firestore
      final membersSnapshot = await _firestore.collection('members').limit(1).get();
      
      if (membersSnapshot.docs.isNotEmpty) {
        final memberDoc = membersSnapshot.docs.first;
        final memberData = memberDoc.data();
        _memberId = memberDoc.id;
        _memberData = memberData;
        
        String name = memberData['name'] ?? '';
        String teamId = memberData['teamId'] ?? '';
        String teamName = '';
        
        // Get team name if teamId exists
        if (teamId.isNotEmpty) {
          final teamDoc = await _firestore.collection('teams').doc(teamId).get();
          if (teamDoc.exists) {
            final teamData = teamDoc.data();
            teamName = teamData?['teamName'] ?? teamData?['name'] ?? '';
          }
        }
        
        setState(() {
          _memberName = name;
          _teamName = teamName;
        });
        
        developer.log('Loaded user data: $_memberName from $_teamName');
        
        // Check if member has a QR secret, if not create one
        await _ensureMemberHasQRCode();
      } else {
        // If no members exist, fetch member info from memberInfo collection
        final memberInfoSnapshot = await _firestore.collection('memberInfo').limit(1).get();
        
        if (memberInfoSnapshot.docs.isNotEmpty) {
          final memberInfoDoc = memberInfoSnapshot.docs.first;
          final memberInfoData = memberInfoDoc.data();
          
          setState(() {
            _memberName = memberInfoData['name'] ?? '';
            _teamName = memberInfoData['team'] ?? '';
          });
          
          developer.log('Loaded member info: $_memberName from $_teamName');
          
          // Create a proper member document with QR code
          await _createMemberWithQRCode();
        } else {
          // Default fallback if no user data found
          setState(() {
            _memberName = 'Spectrum';
            _teamName = 'Organizer';
          });
          
          // Save this default info to Firestore and create QR
          await _mealService.saveMemberInfo(_memberName, _teamName);
          await _createMemberWithQRCode();
          developer.log('Created default user info: $_memberName from $_teamName');
        }
      }
      
      // Continue to load meals
      await _loadMeals();
    } catch (e) {
      developer.log('Error loading user data: $e');
      setState(() {
        _memberName = 'Spectrum';
        _teamName = 'Participant';
        _isLoading = false;
      });
      
      // Save this default info and continue
      await _mealService.saveMemberInfo(_memberName, _teamName);
      await _createMemberWithQRCode();
      await _loadMeals();
    }
  }
  
  // Ensure the member has a permanent QR code
  Future<void> _ensureMemberHasQRCode() async {
    try {
      if (_memberId.isEmpty) {
        developer.log('Member ID is empty, cannot ensure QR code');
        return;
      }
      
      final memberDoc = await _firestore.collection('members').doc(_memberId).get();
      if (!memberDoc.exists) {
        developer.log('Member document not found');
        return;
      }
      
      final memberData = memberDoc.data()!;
      
      // Check if member already has a QR secret
      if (memberData['qrSecret'] == null) {
        // Generate and store a new QR secret
        final String qrData = await _mealService.generateAndStoreMemberQR(
          _memberId,
          _memberName,
          _teamName
        );
        
        setState(() {
          _qrData = qrData;
        });
        
        developer.log('Generated new permanent QR code for member');
      } else {
        // Use existing QR secret to generate QR code
        final String qrData = await _mealService.generateQRWithStoredSecret(
          _memberId,
          _memberName,
          _teamName
        );
        
        setState(() {
          _qrData = qrData;
        });
        
        developer.log('Using existing QR code with stored secret for member');
      }
      
      // Check if this is an iOS user without an email
      if (Platform.isIOS && 
          memberData['device'] == 'iOS' && 
          (memberData['email'] == null || memberData['email'] == '') &&
          memberData['qrSentByEmail'] != true) {
        // Show dialog to collect email after a short delay
        Future.delayed(Duration(milliseconds: 500), () {
          if (mounted) {
            _showEmailDialog();
          }
        });
      }
    } catch (e) {
      developer.log('Error ensuring member has QR code: $e');
      
      // Fallback to generate a temporary QR code
      final String qrData = _mealService.generateQRCode(
        _memberName,
        _teamName
      );
      
      setState(() {
        _qrData = qrData;
      });
    }
  }
  
  // Create a new member document with QR code
  Future<void> _createMemberWithQRCode() async {
    try {
      // First find if member document already exists
      final membersSnapshot = await _firestore
          .collection('members')
          .where('name', isEqualTo: _memberName)
          .where('teamName', isEqualTo: _teamName)
          .limit(1)
          .get();
      
      if (membersSnapshot.docs.isNotEmpty) {
        // Member exists, use existing ID
        _memberId = membersSnapshot.docs.first.id;
        _memberData = membersSnapshot.docs.first.data();
        
        // Check if QR secret exists, if not create one
        await _ensureMemberHasQRCode();
      } else {
        // Create a new member document
        final newMemberRef = _firestore.collection('members').doc();
        _memberId = newMemberRef.id;
        
        // Create base member data
        final Map<String, dynamic> memberData = {
          'name': _memberName,
          'teamName': _teamName,
          'isBreakfastConsumed': false,
          'isLunchConsumed': false,
          'isDinnerConsumed': false,
          'isTestMealConsumed': false,
          'createdAt': FieldValue.serverTimestamp(),
          'device': Platform.isIOS ? 'iOS' : 'Android',
          'email': '', // Will be populated if iOS user
        };
        
        // Save initial document
        await newMemberRef.set(memberData);
        _memberData = memberData;
        
        // Generate and store QR code
        final String qrData = await _mealService.generateAndStoreMemberQR(
          _memberId,
          _memberName,
          _teamName
        );
        
        setState(() {
          _qrData = qrData;
        });
        
        // If iOS device, ask for email and send QR code
        if (Platform.isIOS) {
          // Show dialog to collect email
          _showEmailDialog();
        }
        
        developer.log('Created new member with QR code');
      }
    } catch (e) {
      developer.log('Error creating member with QR code: $e');
      
      // Fallback to generate a temporary QR code
      final String qrData = _mealService.generateQRCode(
        _memberName,
        _teamName
      );
      
      setState(() {
        _qrData = qrData;
      });
    }
  }
  
  // Show email collection dialog for iOS users
  void _showEmailDialog() {
    final TextEditingController emailController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Email Required'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'For iOS users, we need your email to send your permanent QR code.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  hintText: 'Enter your email',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Skip'),
            ),
            ElevatedButton(
              onPressed: () {
                if (emailController.text.isNotEmpty) {
                  _saveEmailAndSendQR(emailController.text);
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }
  
  // Save member email and send QR code
  Future<void> _saveEmailAndSendQR(String email) async {
    try {
      // Update member document with email
      await _firestore.collection('members').doc(_memberId).update({
        'email': email,
      });
      
      // Send QR code via email
      await _mealService.sendQRCodeByEmail(
        _memberId,
        _memberName,
        _teamName,
        email,
        _qrData
      );
      
      setState(() {
        _memberData = {..._memberData, 'email': email};
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QR code sent to your email'),
          backgroundColor: Colors.green,
        ),
      );
      
      developer.log('Email saved and QR code sent: $email');
    } catch (e) {
      developer.log('Error saving email or sending QR: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending QR code: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _loadMeals() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Try to initialize meals (will only work the first time)
      await _mealService.initializeMeals();
      
      // Get all meals
      final meals = await _mealService.getMeals();
      
      // Get active meal if any
      final activeMeal = await _mealService.getActiveMeal();
      
      setState(() {
        _meals = meals;
        _activeMeal = activeMeal;
        _isLoading = false;
      });
    } catch (e) {
      developer.log('Error loading meal data: $e');
      setState(() {
        _errorMessage = 'Error loading meal data: $e';
        _isLoading = false;
      });
    }
  }
  
  String _formatMealTime(DateTime start, DateTime end) {
    final startTime = '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
    final endTime = '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
    return '$startTime - $endTime';
  }
  
  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
  
  // Check if member has consumed the given meal
  bool _hasMemberConsumedMeal(String mealId) {
    if (_memberData.isEmpty) return false;
    
    switch (mealId) {
      case 'breakfast':
        return _memberData['isBreakfastConsumed'] == true;
      case 'lunch':
        return _memberData['isLunchConsumed'] == true;
      case 'dinner':
        return _memberData['isDinnerConsumed'] == true;
      case 'test_meal':
        return _memberData['isTestMealConsumed'] == true;
      default:
        return false;
    }
  }
  
  Widget _buildMealCard(Meal meal) {
    final DateTime now = DateTime.now();
    final bool isActive = now.isAfter(meal.startTime) && now.isBefore(meal.endTime);
    final bool isPast = now.isAfter(meal.endTime);
    final bool isUpcoming = now.isBefore(meal.startTime);
    final bool hasConsumed = _hasMemberConsumedMeal(meal.id);
    
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                meal.name,
                style: TextStyle(
                  color: AppTheme.textPrimaryColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppTheme.accentColor.withOpacity(0.2)
                      : isPast
                          ? Colors.grey.withOpacity(0.2)
                          : AppTheme.primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isActive
                      ? 'Now Serving'
                      : isPast
                          ? 'Completed'
                          : 'Upcoming',
                  style: TextStyle(
                    color: isActive
                        ? AppTheme.accentColor
                        : isPast
                            ? Colors.grey
                            : AppTheme.primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_formatDate(meal.startTime)}',
            style: TextStyle(
              color: AppTheme.textSecondaryColor,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatMealTime(meal.startTime, meal.endTime),
            style: TextStyle(
              color: AppTheme.textSecondaryColor,
              fontSize: 14,
            ),
          ),
          
          if (hasConsumed) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.green.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You have already checked in for this meal.',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  // Refresh meal status without resetting
  Future<void> _refreshMealStatus() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get all meals
      final meals = await _mealService.getMeals();
      
      // Get active meal if any
      final activeMeal = await _mealService.getActiveMeal();
      
      setState(() {
        _meals = meals;
        _activeMeal = activeMeal;
        _isLoading = false;
      });
      
      // Show confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Meal status refreshed'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      developer.log('Error refreshing meals: $e');
      setState(() {
        _errorMessage = 'Error refreshing meals: $e';
        _isLoading = false;
      });
    }
  }
  
  // Resend QR code email
  Future<void> _resendQRCodeEmail() async {
    try {
      // Check if we have an email on file
      if (_memberData['email'] == null || _memberData['email'] == '') {
        _showEmailDialog();
        return;
      }
      
      // Resend the QR code to the existing email
      final email = _memberData['email'];
      
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sending QR code to your email...'),
          duration: Duration(seconds: 1),
        ),
      );
      
      // Send QR code via email
      final success = await _mealService.sendQRCodeByEmail(
        _memberId,
        _memberName,
        _teamName,
        email,
        _qrData
      );
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QR code resent to your email'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send QR code email'),
            backgroundColor: Colors.red,
          ),
        );
      }
      
      developer.log('QR code resent to email: $email');
    } catch (e) {
      developer.log('Error resending QR code email: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending QR code: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Your QR Code (Always visible)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Your QR Code',
                              style: TextStyle(
                                color: AppTheme.textPrimaryColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.refresh),
                              tooltip: 'Refresh meal status',
                              onPressed: _refreshMealStatus,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Show this QR code to the food counter staff to get your meal.',
                          style: TextStyle(
                            color: AppTheme.textSecondaryColor,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  spreadRadius: 1,
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    '$_memberName - $_teamName',
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                QrImageView(
                                  data: _qrData,
                                  version: QrVersions.auto,
                                  size: 200,
                                  backgroundColor: Colors.white,
                                  errorStateBuilder: (context, error) {
                                    return const Center(
                                      child: Text(
                                        'Error generating QR code',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'This is your permanent meal QR code',
                                  style: TextStyle(
                                    color: AppTheme.textSecondaryColor,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                if (Platform.isIOS && (_memberData['email'] == null || _memberData['email'] == '')) ...[
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: _showEmailDialog,
                                    child: const Text('Send QR code to my email'),
                                  ),
                                ],
                                if (Platform.isIOS && _memberData['email'] != null && _memberData['email'] != '') ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.email, size: 14, color: Colors.blue),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Sent to: ${_memberData['email']}',
                                        style: TextStyle(
                                          color: AppTheme.textSecondaryColor,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  TextButton(
                                    onPressed: _resendQRCodeEmail,
                                    child: const Text('Resend to my email'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Active and All Meals
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_activeMeal != null) ...[
                            Text(
                              'Active Meal',
                              style: TextStyle(
                                color: AppTheme.textPrimaryColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_activeMeal != null)
                              _buildMealCard(_activeMeal!),
                          ] else ...[
                            const Text(
                              'No active meals at the moment',
                              style: TextStyle(fontSize: 16),
                            ),
                          ],
                          
                          const SizedBox(height: 24),
                          Text(
                            'All Meals',
                            style: TextStyle(
                              color: AppTheme.textPrimaryColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _meals.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _buildMealCard(_meals[index]),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
} 