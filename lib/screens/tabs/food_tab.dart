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
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _teamController = TextEditingController();
  bool _isLoading = true;
  List<Meal> _meals = [];
  Meal? _activeMeal;
  String? _errorMessage;
  Timer? _qrRefreshTimer;
  String _qrData = '';
  bool _hasUserInfo = false;
  
  @override
  void initState() {
    super.initState();
    _loadMeals();
    // Refresh QR code every 2 minutes for security
    _qrRefreshTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      _refreshQRCode();
    });
  }
  
  @override
  void dispose() {
    _qrRefreshTimer?.cancel();
    _nameController.dispose();
    _teamController.dispose();
    super.dispose();
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
  
  void _refreshQRCode() {
    if (_activeMeal != null && _hasUserInfo) {
      // Generate a new QR code with current timestamp
      final qrData = _mealService.generateMealQRCodeWithoutAuth(
        _nameController.text.trim(), 
        _teamController.text.trim(), 
        _activeMeal!.id
      );
      setState(() {
        _qrData = qrData;
      });
    }
  }
  
  void _submitUserInfo() {
    final name = _nameController.text.trim();
    final team = _teamController.text.trim();
    
    if (name.isEmpty || team.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both your name and team name')),
      );
      return;
    }
    
    setState(() {
      _hasUserInfo = true;
    });
    
    _refreshQRCode();
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
      future: _hasUserInfo ? _mealService.hasMemberConsumedMealByName(
        _nameController.text.trim(),
        _teamController.text.trim(),
        meal.id
      ) : Future.value(false),
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
              
              if (isActive && !hasConsumed && _hasUserInfo) ...[
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
                const SizedBox(height: 16),
                Center(
                  child: QrImageView(
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
  
  Widget _buildUserInfoForm() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter Your Information',
            style: TextStyle(
              color: AppTheme.textPrimaryColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Your Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _teamController,
            decoration: const InputDecoration(
              labelText: 'Your Team Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton(
              onPressed: _submitUserInfo,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
              child: const Text('Generate QR Code'),
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
                    if (!_hasUserInfo) ...[
                      _buildUserInfoForm(),
                    ] else if (_activeMeal != null) ...[
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
                    
                    if (_hasUserInfo) ...[
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
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
} 