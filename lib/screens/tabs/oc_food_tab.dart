import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../meal_scanner_screen.dart';  // Import the meal scanner screen

class OCFoodTab extends StatefulWidget {
  const OCFoodTab({super.key});

  @override
  _OCFoodTabState createState() => _OCFoodTabState();
}

class _OCFoodTabState extends State<OCFoodTab> {
  bool _isLoading = true;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  final List<Map<String, dynamic>> _mealTimes = [
    {
      'title': 'Test Meal',
      'time': 'Now - 6 AM Tomorrow',
      'status': 'Active',
      'distributed': 0,
      'total': 100,
      'type': 'breakfast', // Using breakfast type for testing
      'isTest': true,
    },
    {
      'title': 'Breakfast',
      'time': '8:00 AM - 9:30 AM',
      'status': 'Upcoming',
      'distributed': 0,
      'total': 100,
      'type': 'breakfast',
    },
    {
      'title': 'Lunch',
      'time': '1:00 PM - 2:30 PM',
      'status': 'Upcoming',
      'distributed': 0,
      'total': 100,
      'type': 'lunch',
    },
    {
      'title': 'Dinner',
      'time': '7:00 PM - 8:30 PM',
      'status': 'Upcoming',
      'distributed': 0,
      'total': 100,
      'type': 'dinner',
    },
    {
      'title': 'Midnight Snack',
      'time': '12:00 AM - 1:00 AM',
      'status': 'Upcoming',
      'distributed': 0,
      'total': 100,
      'type': 'midnight_snack',
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchMealStats();
    
    // Set active meal based on current time
    _updateActiveMeal();
  }
  
  // Update which meal is currently active based on time
  void _updateActiveMeal() {
    final now = DateTime.now();
    final hour = now.hour;
    
    // Simple logic to determine which meal is active based on time of day
    setState(() {
      // Skip index 0 which is the test meal (always active)
      for (var i = 1; i < _mealTimes.length; i++) {
        _mealTimes[i]['status'] = 'Upcoming';
      }
      
      if (hour >= 6 && hour < 10) {
        // Breakfast time: 6 AM - 10 AM
        _mealTimes[1]['status'] = 'Active';
      } else if (hour >= 12 && hour < 15) {
        // Lunch time: 12 PM - 3 PM
        _mealTimes[2]['status'] = 'Active';
      } else if (hour >= 18 && hour < 22) {
        // Dinner time: 6 PM - 10 PM
        _mealTimes[3]['status'] = 'Active';
      } else if (hour >= 0 && hour < 2) {
        // Midnight snack: 12 AM - 2 AM
        _mealTimes[4]['status'] = 'Active';
      }
    });
  }
  
  // Fetch meal distribution statistics from Firestore
  Future<void> _fetchMealStats() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Query all members
      final membersSnapshot = await _firestore.collection('members').get();
      
      // Initialize counters
      final Map<String, int> mealCounts = {
        'breakfast': 0,
        'lunch': 0,
        'dinner': 0,
        'midnight_snack': 0,
      };
      
      // Count served meals
      for (var doc in membersSnapshot.docs) {
        final memberData = doc.data();
        if (memberData.containsKey('meals')) {
          final meals = memberData['meals'] as Map<String, dynamic>?;
          
          if (meals != null) {
            // Count standard meals
            if (meals.containsKey('breakfast') && 
                (meals['breakfast'] as Map<String, dynamic>)['served'] == true) {
              mealCounts['breakfast'] = mealCounts['breakfast']! + 1;
            }
            
            if (meals.containsKey('lunch') && 
                (meals['lunch'] as Map<String, dynamic>)['served'] == true) {
              mealCounts['lunch'] = mealCounts['lunch']! + 1;
            }
            
            if (meals.containsKey('dinner') && 
                (meals['dinner'] as Map<String, dynamic>)['served'] == true) {
              mealCounts['dinner'] = mealCounts['dinner']! + 1;
            }
            
            // Check for midnight snack if it exists
            if (meals.containsKey('midnight_snack') && 
                (meals['midnight_snack'] as Map<String, dynamic>?)?.containsKey('served') == true &&
                (meals['midnight_snack'] as Map<String, dynamic>)['served'] == true) {
              mealCounts['midnight_snack'] = mealCounts['midnight_snack']! + 1;
            }
          }
        }
      }
      
      // Update meal distributions
      setState(() {
        for (var meal in _mealTimes) {
          final type = meal['type'] as String;
          if (mealCounts.containsKey(type)) {
            meal['distributed'] = mealCounts[type]!;
          }
        }
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching meal stats: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Navigate to meal scanner screen
  void _navigateToMealScanner(String mealType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MealScannerScreen(mealType: mealType.toLowerCase()),
      ),
    ).then((result) {
      // Refresh the screen when returning from the scanner
      if (result != null && result is Map<String, dynamic> && result['refreshNeeded'] == true) {
        _fetchMealStats();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Food Management',
                style: TextStyle(
                  color: AppTheme.textPrimaryColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(Icons.refresh, color: AppTheme.accentColor),
                onPressed: _fetchMealStats,
                tooltip: 'Refresh statistics',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Track and manage food distribution',
            style: TextStyle(
              color: AppTheme.textSecondaryColor,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          
          // Meal time cards
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _mealTimes.length,
                    itemBuilder: (context, index) {
                      final meal = _mealTimes[index];
                      final progress = meal['distributed'] / meal['total'];
                      final isActive = meal['status'] == 'Active';
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    meal['title'],
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
                                          : AppTheme.primaryColor.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      meal['status'],
                                      style: TextStyle(
                                        color: isActive
                                            ? AppTheme.accentColor
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
                                meal['time'],
                                style: TextStyle(
                                  color: AppTheme.textSecondaryColor,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Progress bar
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Food Distribution',
                                        style: TextStyle(
                                          color: AppTheme.textSecondaryColor,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        '${meal['distributed']}/${meal['total']}',
                                        style: TextStyle(
                                          color: AppTheme.textPrimaryColor,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 10,
                                      backgroundColor: AppTheme.cardColor,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        isActive ? AppTheme.accentColor : AppTheme.primaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Action buttons
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    isActive ? 'Ready to scan' : 'Waiting for time slot',
                                    style: TextStyle(
                                      color: isActive ? Colors.green : AppTheme.textSecondaryColor,
                                      fontStyle: isActive ? FontStyle.normal : FontStyle.italic,
                                      fontSize: 14,
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: isActive 
                                      ? () => _navigateToMealScanner(meal['type'])
                                      : null,
                                    icon: Icon(Icons.qr_code_scanner),
                                    label: Text('Scan QR'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor: AppTheme.cardColor,
                                      disabledForegroundColor: AppTheme.textSecondaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
} 