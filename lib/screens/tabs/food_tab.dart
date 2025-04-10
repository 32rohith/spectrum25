import 'package:flutter/material.dart';
import 'dart:async';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../models/meal_tracking.dart';
import '../../services/meal_service.dart';
import 'dart:developer' as developer;

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
  Timer? _qrRefreshTimer;
  String _qrData = '';
  String _memberName = '';
  String _teamName = '';
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
    
    // Refresh QR code every 2 minutes for security
    _qrRefreshTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      _refreshQRCode();
    });
  }
  
  @override
  void dispose() {
    _qrRefreshTimer?.cancel();
    super.dispose();
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
        } else {
          // Default fallback if no user data found
          setState(() {
            _memberName = 'Spectrum';
            _teamName = 'Organizer';
          });
          
          // Save this default info to Firestore
          _mealService.saveMemberInfo(_memberName, _teamName);
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
      _mealService.saveMemberInfo(_memberName, _teamName);
      await _loadMeals();
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
      
      // Generate QR code if there's an active meal
      if (_activeMeal != null) {
        _refreshQRCode();
      }
    } catch (e) {
      developer.log('Error loading meal data: $e');
      setState(() {
        _errorMessage = 'Error loading meal data: $e';
        _isLoading = false;
      });
    }
  }
  
  void _refreshQRCode() {
    if (_activeMeal != null) {
      // Generate a new QR code with current timestamp
      final qrData = _mealService.generateMealQRCodeWithoutAuth(
        _memberName, 
        _teamName, 
        _activeMeal!.id
      );
      setState(() {
        _qrData = qrData;
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
  
  Widget _buildMealCard(Meal meal) {
    final bool isActive = meal.isCurrentlyActive;
    final bool isPast = DateTime.now().isAfter(meal.endTime);
    
    return FutureBuilder<bool>(
      future: _mealService.hasMemberConsumedMealByName(
        _memberName,
        _teamName,
        meal.id
      ),
      builder: (context, snapshot) {
        final bool hasConsumed = snapshot.data ?? false;
        
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
              
              if (isActive && !hasConsumed) ...[
                const SizedBox(height: 16),
                Text(
                  'Meal QR Code',
                  style: TextStyle(
                    color: AppTheme.textPrimaryColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Show this QR code to the food counter staff to get your meal.',
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
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
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: ElevatedButton(
                    onPressed: _refreshQRCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                    ),
                    child: const Text('Refresh QR Code'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hackathon Meals',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Show your QR code to get your meals',
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            
            if (_isLoading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_errorMessage != null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: AppTheme.errorColor,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loadMeals,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: Column(
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
          ],
        ),
      ),
    );
  }
} 