import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/auth_service.dart';
import 'dart:async';

class FoodTab extends StatefulWidget {
  const FoodTab({super.key});

  @override
  _FoodTabState createState() => _FoodTabState();
}

class _FoodTabState extends State<FoodTab> {
  final AuthService _authService = AuthService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool _isLoading = true;
  String? _errorMessage;
  
  String _mealQRCode = '';
  Map<String, dynamic> _meals = {};
  String _memberName = '';
  
  // Refresh timer to keep QR code up to date
  Timer? _refreshTimer;
  
  @override
  void initState() {
    super.initState();
    _loadMealData();
    
    // Set up a timer to refresh the QR code every minute
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _loadMealData();
    });
  }
  
  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _loadMealData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final user = _auth.currentUser;
      
      if (user == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'You need to be logged in to view meal information.';
        });
        return;
      }
      
      print('Food Tab - Attempting to load meal data for: ${user.email}');
      
      // Get meal status from the AuthService
      final result = await _authService.getMemberMealStatus(user.email!);
      
      if (result['success']) {
        setState(() {
          _mealQRCode = result['mealQRCode'] ?? '';
          _meals = Map<String, dynamic>.from(result['meals'] ?? {});
          _memberName = result['name'] ?? '';
          _isLoading = false;
        });
        print('Food Tab - Successfully loaded meal data for: $_memberName');
      } else {
        // Try a direct lookup by querying the members collection
        print('Food Tab - Initial lookup failed, trying direct Firestore query');
        
        try {
          // Try to find by username if using Firebase Auth format
          String username = '';
          if (user.email!.contains('@hackathon.app')) {
            username = user.email!.split('@')[0];
            print('Food Tab - Extracted username: $username');
            
            // Query by username
            final membersQuery = await _firestore
                .collection('members')
                .where('username', isEqualTo: username)
                .limit(1)
                .get();
                
            if (membersQuery.docs.isNotEmpty) {
              final memberData = membersQuery.docs.first.data();
              
              setState(() {
                _mealQRCode = memberData['mealQRCode'] ?? '';
                _meals = Map<String, dynamic>.from(memberData['meals'] ?? {});
                _memberName = memberData['name'] ?? '';
                _isLoading = false;
                _errorMessage = null;
              });
              
              print('Food Tab - Successfully loaded data directly for: $_memberName');
              return;
            }
          }
          
          // If we got here, direct lookup failed too
          setState(() {
            _isLoading = false;
            _errorMessage = result['message'] ?? 'Failed to load meal information.';
          });
          print('Food Tab - All lookup methods failed: ${result['message']}');
        } catch (directError) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Error during direct lookup: $directError';
          });
          print('Food Tab - Error during direct lookup: $directError');
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading meal information: $e';
      });
      print('Food Tab - Error loading meal data: $e');
    }
  }
  
  String _formatDateTime(dynamic dateTime) {
    if (dateTime == null) return 'Not scheduled';
    if (dateTime is Timestamp) {
      return _formatDate(dateTime.toDate());
    } else if (dateTime is DateTime) {
      return _formatDate(dateTime);
    }
    return 'Unknown';
  }
  
  String _formatDate(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year;
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    
    return '$day/$month/$year, $hour:$minute $period';
  }
  
  Widget _buildMealCard(String mealType, Map<String, dynamic> mealData) {
    final bool served = mealData['served'] ?? false;
    final dynamic servedAt = mealData['servedAt'];
    final dynamic mealDateTime = mealData['dateTime'];
    
    // Capitalize the first letter directly
    final String capitalizedMealType = mealType.isNotEmpty 
        ? mealType[0].toUpperCase() + mealType.substring(1) 
        : mealType;
    
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.restaurant,
                color: served ? Colors.green : AppTheme.accentColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                capitalizedMealType,
                style: TextStyle(
                  color: AppTheme.textPrimaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: served ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  served ? 'Served' : 'Not Served',
                  style: TextStyle(
                    color: served ? Colors.green : Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Scheduled: ${_formatDateTime(mealDateTime)}',
            style: TextStyle(
              color: AppTheme.textSecondaryColor,
              fontSize: 14,
            ),
          ),
          if (served && servedAt != null)
            Text(
              'Served at: ${_formatDateTime(servedAt)}',
              style: TextStyle(
                color: Colors.green,
                fontSize: 14,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: AppTheme.errorColor),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadMealData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentColor,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadMealData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Meal Information',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Show this QR code to the organizers during meal time',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // QR Code Section
                        Center(
                          child: GlassCard(
                            child: Column(
                              children: [
                                Text(
                                  'Your Meal QR Code',
                                  style: TextStyle(
                                    color: AppTheme.textPrimaryColor,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Scan once per meal',
                                  style: TextStyle(
                                    color: AppTheme.textSecondaryColor,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: QrImageView(
                                    data: _mealQRCode,
                                    version: QrVersions.auto,
                                    size: 200,
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _memberName,
                                  style: TextStyle(
                                    color: AppTheme.textPrimaryColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'QR code updates automatically',
                                  style: TextStyle(
                                    color: AppTheme.textSecondaryColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        // Meals Section
                        const SizedBox(height: 24),
                        Text(
                          'Meal Schedule',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimaryColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        if (_meals.containsKey('lunch'))
                          _buildMealCard('lunch', _meals['lunch']),
                        
                        const SizedBox(height: 12),
                        
                        if (_meals.containsKey('dinner'))
                          _buildMealCard('dinner', _meals['dinner']),
                        
                        const SizedBox(height: 12),
                        
                        if (_meals.containsKey('breakfast'))
                          _buildMealCard('breakfast', _meals['breakfast']),
                        
                        // Info Card
                        const SizedBox(height: 24),
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
                                    'Important Information',
                                    style: TextStyle(
                                      color: AppTheme.accentColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '• Your QR code is unique to you. Do not share it with others.',
                                style: TextStyle(
                                  color: AppTheme.textSecondaryColor,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '• Each QR code can only be scanned once per meal.',
                                style: TextStyle(
                                  color: AppTheme.textSecondaryColor,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '• Meals are only available during the specified times.',
                                style: TextStyle(
                                  color: AppTheme.textSecondaryColor,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '• If you have dietary restrictions, please inform the organizers.',
                                style: TextStyle(
                                  color: AppTheme.textSecondaryColor,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
} 