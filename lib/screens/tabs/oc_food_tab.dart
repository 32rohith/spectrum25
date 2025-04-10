import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/meal_service.dart';
import '../../models/meal_tracking.dart';
import 'dart:developer' as developer;

class OCFoodTab extends StatefulWidget {
  const OCFoodTab({super.key});

  @override
  _OCFoodTabState createState() => _OCFoodTabState();
}

class _OCFoodTabState extends State<OCFoodTab> {
  final MealService _mealService = MealService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  bool _isScanning = false;
  List<Meal> _meals = [];
  Meal? _selectedMeal;
  String? _error;
  List<MealConsumption> _recentConsumptions = [];
  MobileScannerController? _scannerController;
  Map<String, dynamic>? _lastScanResult;
  
  @override
  void initState() {
    super.initState();
    _loadMeals();
  }
  
  @override
  void dispose() {
    _scannerController?.dispose();
    super.dispose();
  }
  
  Future<void> _loadMeals() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      // Initialize meals (first time only)
      await _mealService.initializeMeals();
      
      // Get all meals
      final meals = await _mealService.getMeals();
      
      // Get currently active meal if any
      final activeMeal = await _mealService.getActiveMeal();
      
      // Sort meals by start time
      meals.sort((a, b) => a.startTime.compareTo(b.startTime));
      
      setState(() {
        _meals = meals;
        _selectedMeal = activeMeal ?? (meals.isNotEmpty ? meals.first : null);
        _isLoading = false;
      });
      
      // Load recent consumptions for the selected meal
      if (_selectedMeal != null) {
        _loadRecentConsumptions(_selectedMeal!.id);
      }
      
      // Automatically start QR scanner when tab is opened
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startScanner();
      });
    } catch (e) {
      developer.log('Error loading meals: $e');
      setState(() {
        _error = 'Error loading meals: $e';
        _isLoading = false;
      });
    }
  }
  
  Future<void> _loadRecentConsumptions(String mealId) async {
    try {
      // Use a different query approach that doesn't require the composite index
      final snapshot = await _firestore
          .collection('mealConsumptions')
          .where('mealId', isEqualTo: mealId)
          .get();
      
      // Sort in memory instead of in the query
      final consumptions = snapshot.docs
          .map((doc) => MealConsumption.fromJson(doc.data()))
          .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      // Take only the first 10
      final recentConsumptions = consumptions.take(10).toList();
      
      setState(() {
        _recentConsumptions = recentConsumptions;
      });
    } catch (e) {
      developer.log('Error loading consumptions: $e');
      setState(() {
        _error = 'Error loading recent consumptions: $e';
      });
    }
  }
  
  void _startScanner() {
    setState(() {
      _isScanning = true;
      _lastScanResult = null;
      _scannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
      );
    });
  }
  
  void _stopScanner() {
    setState(() {
      _isScanning = false;
      _scannerController?.dispose();
      _scannerController = null;
    });
  }
  
  Future<void> _processScan(String? qrCode) async {
    if (qrCode == null || _selectedMeal == null) return;
    
    setState(() {
      _isLoading = true;
      _lastScanResult = null;
    });
    
    try {
      // Decode QR data to check if it's our format
      Map<String, dynamic> qrJson;
      try {
        qrJson = json.decode(qrCode);
      } catch (e) {
        setState(() {
          _lastScanResult = {
            'success': false,
            'message': 'Invalid QR code format: Not valid JSON data.',
          };
          _isLoading = false;
          _isScanning = false;
        });
        
        // Stop scanner
        _scannerController?.dispose();
        _scannerController = null;
        return;
      }
      
      // Check if it's a meal QR code
      if (qrJson['type'] != 'meal_qr') {
        setState(() {
          _lastScanResult = {
            'success': false,
            'message': 'Invalid QR code: This is not a meal QR code.',
          };
          _isLoading = false;
          _isScanning = false;
        });
        
        // Stop scanner
        _scannerController?.dispose();
        _scannerController = null;
        return;
      }
      
      // Process the QR code
      final result = await _mealService.processMealQRScan(qrCode);
      
      setState(() {
        _lastScanResult = result;
        _isLoading = false;
        _isScanning = false;
      });
      
      // If successful or already consumed, refresh the recent consumptions
      if (result['success'] == true || result['isSecondAttempt'] == true) {
        _loadRecentConsumptions(_selectedMeal!.id);
      }
      
      // Stop scanner
      _scannerController?.dispose();
      _scannerController = null;
      
    } catch (e) {
      developer.log('Error processing QR code: $e');
      setState(() {
        _lastScanResult = {
          'success': false,
          'message': 'Error processing QR code: $e',
        };
        _isLoading = false;
        _isScanning = false;
      });
      
      // Stop scanner
      _scannerController?.dispose();
      _scannerController = null;
    }
  }
  
  Widget _buildMealStatistics() {
    if (_selectedMeal == null) {
      return const Center(child: Text('No meal selected'));
    }
    
    return FutureBuilder<Map<String, dynamic>>(
      future: _mealService.getMealStatistics(_selectedMeal!.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading statistics: ${snapshot.error}',
              style: TextStyle(color: AppTheme.errorColor),
            ),
          );
        }
        
        if (!snapshot.hasData) {
          return const Center(child: Text('No data available'));
        }
        
        final stats = snapshot.data!;
        final total = stats['total'] as int? ?? 0;
        final consumedCount = stats['uniqueMembers'] as int? ?? 0;
        final totalMembers = stats['totalMembers'] as int? ?? 0;
        final remainingCount = stats['remainingMembers'] as int? ?? 0;
        
        // Get team-based consumption data if available
        Map<String, List<dynamic>>? consumptionsByTeam;
        if (stats.containsKey('consumptionsByTeam')) {
          consumptionsByTeam = {};
          (stats['consumptionsByTeam'] as Map<String, dynamic>).forEach((team, consumptions) {
            consumptionsByTeam![team] = (consumptions as List<dynamic>);
          });
        }
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Meal info header
            Text(
              _selectedMeal!.name,
              style: TextStyle(
                color: AppTheme.textPrimaryColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${DateFormat('EEEE, MMMM d, yyyy').format(_selectedMeal!.startTime)} · ${DateFormat('h:mm a').format(_selectedMeal!.startTime)} - ${DateFormat('h:mm a').format(_selectedMeal!.endTime)}',
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            
            // Stats Cards
            Row(
              children: [
                // Total meals served
                Expanded(
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          total.toString(),
                          style: TextStyle(
                            color: AppTheme.accentColor,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Meals Served',
                          style: TextStyle(
                            color: AppTheme.textSecondaryColor,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                
                // Unique teams
                Expanded(
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          (stats['uniqueTeams'] as int? ?? 0).toString(),
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Teams Served',
                          style: TextStyle(
                            color: AppTheme.textSecondaryColor,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                
                // Remaining members
                Expanded(
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '$consumedCount/$totalMembers',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$remainingCount Left',
                          style: TextStyle(
                            color: AppTheme.textSecondaryColor,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Scan button
            _isScanning
                ? const SizedBox()
                : Center(
                    child: ElevatedButton.icon(
                      onPressed: _startScanner,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Scan Meal QR Code'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
            
            // Consumption by Team
            if (consumptionsByTeam != null && consumptionsByTeam.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Consumption by Team',
                style: TextStyle(
                  color: AppTheme.textPrimaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: consumptionsByTeam.length,
                  itemBuilder: (context, index) {
                    final teamName = consumptionsByTeam!.keys.elementAt(index);
                    final teamConsumptions = consumptionsByTeam[teamName]!;
                    
                    return Container(
                      width: 160,
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              teamName,
                              style: TextStyle(
                                color: AppTheme.textPrimaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Divider(color: AppTheme.textSecondaryColor.withOpacity(0.2)),
                          Expanded(
                            child: Center(
                              child: Text(
                                '${teamConsumptions.length} meals',
                                style: TextStyle(
                                  color: AppTheme.accentColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
            
            // Recent consumptions
            if (_recentConsumptions.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Recent Meals Served',
                style: TextStyle(
                  color: AppTheme.textPrimaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _recentConsumptions.length,
                  itemBuilder: (context, index) {
                    final consumption = _recentConsumptions[index];
                    final timeAgo = _getTimeAgo(consumption.timestamp);
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: GlassCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.person,
                                color: AppTheme.primaryColor,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    consumption.memberName,
                                    style: TextStyle(
                                      color: AppTheme.textPrimaryColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'Team: ${consumption.teamName}',
                                    style: TextStyle(
                                      color: AppTheme.textSecondaryColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              timeAgo,
                              style: TextStyle(
                                color: AppTheme.textSecondaryColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        );
      },
    );
  }
  
  String _getTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    
    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return DateFormat('MMM d, h:mm a').format(dateTime);
    }
  }
  
  Widget _buildScanResult() {
    if (_lastScanResult == null) {
      return const SizedBox();
    }
    
    final bool success = _lastScanResult!['success'] as bool? ?? false;
    final bool isSecondAttempt = _lastScanResult!['isSecondAttempt'] as bool? ?? false;
    final String message = _lastScanResult!['message'] as String? ?? 'Unknown result';
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: success 
            ? Colors.green.withOpacity(0.1) 
            : isSecondAttempt 
                ? Colors.orange.withOpacity(0.1)
                : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: success 
              ? Colors.green 
              : isSecondAttempt 
                  ? Colors.orange
                  : Colors.red,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                success 
                    ? Icons.check_circle 
                    : isSecondAttempt 
                        ? Icons.warning_amber 
                        : Icons.error,
                color: success 
                    ? Colors.green 
                    : isSecondAttempt 
                        ? Colors.orange
                        : Colors.red,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  success 
                      ? 'Success!' 
                      : isSecondAttempt 
                          ? 'Warning'
                          : 'Error',
                  style: TextStyle(
                    color: success 
                        ? Colors.green 
                        : isSecondAttempt 
                            ? Colors.orange
                            : Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              color: AppTheme.textPrimaryColor,
            ),
          ),
          if (success || isSecondAttempt) ...[
            const SizedBox(height: 8),
            Text(
              'Member: ${_lastScanResult!['memberName'] ?? 'Unknown'}',
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
              ),
            ),
            Text(
              'Team: ${_lastScanResult!['teamName'] ?? 'Unknown Team'}',
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _lastScanResult = null;
              });
              _startScanner();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: success 
                  ? Colors.green 
                  : isSecondAttempt 
                      ? Colors.orange
                      : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Scan Again'),
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
              'Track and manage meal distribution',
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            
            // Main content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: AppTheme.errorColor,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _error!,
                                style: TextStyle(
                                  color: AppTheme.textSecondaryColor,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: _loadMeals,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.accentColor,
                                ),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _isScanning
                          ? Column(
                              children: [
                                // Show active meal text when scanning
                                if (_selectedMeal != null) ...[
                                  Text(
                                    'Active Meal: ${_selectedMeal!.name}',
                                    style: TextStyle(
                                      color: AppTheme.accentColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: MobileScanner(
                                      controller: _scannerController!,
                                      onDetect: (capture) {
                                        final barcodes = capture.barcodes;
                                        if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                                          _processScan(barcodes.first.rawValue);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Center(
                                  child: Text(
                                    'Scanning for meal QR codes...',
                                    style: TextStyle(
                                      color: AppTheme.textSecondaryColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _stopScanner,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Cancel'),
                                ),
                              ],
                            )
                          : _lastScanResult != null
                              ? Column(
                                  children: [
                                    _buildScanResult(),
                                    
                                    // Meal selection tabs after scan result
                                    if (_meals.isNotEmpty) ...[
                                      const SizedBox(height: 16),
                                      Text(
                                        'Select Meal',
                                        style: TextStyle(
                                          color: AppTheme.textPrimaryColor,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        height: 48,
                                        child: ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: _meals.length,
                                          itemBuilder: (context, index) {
                                            final meal = _meals[index];
                                            final isSelected = _selectedMeal?.id == meal.id;
                                            
                                            return Padding(
                                              padding: const EdgeInsets.only(right: 8),
                                              child: InkWell(
                                                onTap: () {
                                                  setState(() {
                                                    _selectedMeal = meal;
                                                  });
                                                  _loadRecentConsumptions(meal.id);
                                                },
                                                borderRadius: BorderRadius.circular(24),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 8,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: isSelected
                                                        ? AppTheme.primaryColor
                                                        : AppTheme.primaryColor.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(24),
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      meal.name,
                                                      style: TextStyle(
                                                        color: isSelected
                                                            ? Colors.white
                                                            : AppTheme.textPrimaryColor,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                    
                                    Expanded(child: _buildMealStatistics()),
                                  ],
                                )
                              : Column(
                                  children: [
                                    // Meal selection tabs
                                    if (_meals.isNotEmpty) ...[
                                      const SizedBox(height: 16),
                                      Text(
                                        'Select Meal',
                                        style: TextStyle(
                                          color: AppTheme.textPrimaryColor,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        height: 48,
                                        child: ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: _meals.length,
                                          itemBuilder: (context, index) {
                                            final meal = _meals[index];
                                            final isSelected = _selectedMeal?.id == meal.id;
                                            
                                            return Padding(
                                              padding: const EdgeInsets.only(right: 8),
                                              child: InkWell(
                                                onTap: () {
                                                  setState(() {
                                                    _selectedMeal = meal;
                                                  });
                                                  _loadRecentConsumptions(meal.id);
                                                },
                                                borderRadius: BorderRadius.circular(24),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 8,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: isSelected
                                                        ? AppTheme.primaryColor
                                                        : AppTheme.primaryColor.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(24),
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      meal.name,
                                                      style: TextStyle(
                                                        color: isSelected
                                                            ? Colors.white
                                                            : AppTheme.textPrimaryColor,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                    
                                    // Start QR scan button prominently displayed
                                    const SizedBox(height: 24),
                                    Center(
                                      child: ElevatedButton.icon(
                                        onPressed: _startScanner,
                                        icon: const Icon(Icons.qr_code_scanner, size: 28),
                                        label: const Text('Scan Meal QR Code', style: TextStyle(fontSize: 16)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.accentColor,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 32,
                                            vertical: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    
                                    Expanded(child: _buildMealStatistics()),
                                  ],
                                ),
            ),
          ],
        ),
      ),
    );
  }
} 