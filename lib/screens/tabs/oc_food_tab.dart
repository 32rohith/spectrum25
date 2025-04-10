import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class OCFoodTab extends StatefulWidget {
  const OCFoodTab({super.key});

  @override
  _OCFoodTabState createState() => _OCFoodTabState();
}

class _OCFoodTabState extends State<OCFoodTab> {
  bool _isLoading = false;
  final List<Map<String, dynamic>> _mealTimes = [
    {
      'title': 'Breakfast',
      'time': '8:00 AM - 9:30 AM',
      'status': 'Active',
      'distributed': 54,
      'total': 100,
    },
    {
      'title': 'Lunch',
      'time': '1:00 PM - 2:30 PM',
      'status': 'Upcoming',
      'distributed': 0,
      'total': 100,
    },
    {
      'title': 'Dinner',
      'time': '7:00 PM - 8:30 PM',
      'status': 'Upcoming',
      'distributed': 0,
      'total': 100,
    },
    {
      'title': 'Midnight Snack',
      'time': '12:00 AM - 1:00 AM',
      'status': 'Upcoming',
      'distributed': 0,
      'total': 100,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Food Management',
            style: TextStyle(
              color: AppTheme.textPrimaryColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
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
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: isActive ? () {} : null,
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