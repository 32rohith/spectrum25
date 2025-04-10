import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import '../models/meal_tracking.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'dart:developer' as developer;

class MealService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Initialize the meals in the database - typically called once during app setup
  Future<void> initializeMeals() async {
    try {
      // Check if meals are already initialized
      final mealsSnapshot = await _firestore.collection('meals').get();
      if (mealsSnapshot.docs.isNotEmpty) {
        developer.log('Meals already initialized');
        return;
      }
      
      // Define the hackathon meal schedule
      final meals = [
        Meal(
          id: 'lunch',
          name: 'Lunch',
          startTime: DateTime(2025, 4, 11, 11, 0), // April 11, 2025, 11:00 AM
          endTime: DateTime(2025, 4, 11, 16, 0),   // April 11, 2025, 4:00 PM
          isActive: false,
        ),
        Meal(
          id: 'dinner',
          name: 'Dinner',
          startTime: DateTime(2025, 4, 11, 18, 0), // April 11, 2025, 6:00 PM
          endTime: DateTime(2025, 4, 11, 22, 30),  // April 11, 2025, 10:30 PM
          isActive: false,
        ),
        Meal(
          id: 'breakfast',
          name: 'Breakfast',
          startTime: DateTime(2025, 4, 12, 6, 30), // April 12, 2025, 6:30 AM
          endTime: DateTime(2025, 4, 12, 10, 30),  // April 12, 2025, 10:30 AM
          isActive: false,
        ),
        Meal(
          id: 'test_meal',
          name: 'Test Meal',
          startTime: DateTime.now(), // Start from now
          endTime: DateTime.now().add(Duration(days: 1, hours: 6)), // Until tomorrow 6 hours from now
          isActive: true,
        ),
      ];
      
      // Add meals to database
      final batch = _firestore.batch();
      for (var meal in meals) {
        batch.set(_firestore.collection('meals').doc(meal.id), meal.toJson());
      }
      
      await batch.commit();
      developer.log('Meals initialized successfully');
    } catch (e) {
      developer.log('Error initializing meals: $e');
      throw Exception('Failed to initialize meals: $e');
    }
  }
  
  // Generate a unique QR code for a member and meal
  String generateMealQRCode(String memberId, String mealId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final secret = 'SPECTRUM_MEALS_2025'; // Secret key for QR code generation
    
    // Create a unique string by combining member ID, meal ID, timestamp, and secret
    final data = '$memberId:$mealId:$timestamp:$secret';
    
    // Generate a SHA-256 hash for security
    final bytes = utf8.encode(data);
    final hash = sha256.convert(bytes).toString();
    
    // Create the QR data
    final qrData = {
      'memberId': memberId,
      'mealId': mealId,
      'timestamp': timestamp,
      'hash': hash,
      'type': 'meal_qr',
    };
    
    return json.encode(qrData);
  }
  
  // Generate a unique QR code for a member and meal without requiring authentication
  String generateMealQRCodeWithoutAuth(String memberName, String teamName, String mealId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final secret = 'SPECTRUM_MEALS_2025'; // Secret key for QR code generation
    
    // Create a unique string by combining member name, team name, meal ID, timestamp, and secret
    final data = '$memberName:$teamName:$mealId:$timestamp:$secret';
    
    // Generate a SHA-256 hash for security
    final bytes = utf8.encode(data);
    final hash = sha256.convert(bytes).toString();
    
    // Generate a unique ID for this QR code
    final qrId = '$memberName-$mealId-${timestamp.substring(timestamp.length - 6)}';
    
    // Create the QR data
    final qrData = {
      'qrId': qrId,
      'memberName': memberName,
      'teamName': teamName,
      'mealId': mealId,
      'timestamp': timestamp,
      'hash': hash,
      'type': 'meal_qr',
    };
    
    // Store this QR code in Firestore for validation
    _storeQRCode(qrData);
    
    return json.encode(qrData);
  }
  
  // Store QR code data in Firestore
  Future<void> _storeQRCode(Map<String, dynamic> qrData) async {
    try {
      final String qrId = qrData['qrId'];
      await _firestore.collection('mealQRCodes').doc(qrId).set({
        ...qrData,
        'isUsed': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      developer.log('QR code stored successfully: $qrId');
    } catch (e) {
      developer.log('Error storing QR code: $e');
      // Don't throw an exception here, as we want the QR to be generated even if storage fails
    }
  }
  
  // Save member info to Firestore
  Future<void> saveMemberInfo(String name, String team) async {
    try {
      final String memberId = '$name-$team';
      
      await _firestore.collection('memberInfo').doc(memberId).set({
        'name': name,
        'team': team,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      developer.log('Member info saved to Firestore: $name from $team');
    } catch (e) {
      developer.log('Error saving member info: $e');
    }
  }
  
  // Get stored member info from Firestore
  Future<Map<String, String>> getStoredMemberInfo(String name, String team) async {
    try {
      final String memberId = '$name-$team';
      final doc = await _firestore.collection('memberInfo').doc(memberId).get();
      
      if (doc.exists) {
        final data = doc.data()!;
        return {
          'name': data['name'] as String? ?? '',
          'team': data['team'] as String? ?? '',
        };
      }
      
      return {'name': '', 'team': ''};
    } catch (e) {
      developer.log('Error getting member info: $e');
      return {'name': '', 'team': ''};
    }
  }
  
  // Get all meals
  Future<List<Meal>> getMeals() async {
    try {
      final mealsSnapshot = await _firestore.collection('meals').get();
      
      return mealsSnapshot.docs.map((doc) {
        return Meal.fromJson(doc.data());
      }).toList();
    } catch (e) {
      developer.log('Error getting meals: $e');
      throw Exception('Failed to get meals: $e');
    }
  }
  
  // Get currently active meal
  Future<Meal?> getActiveMeal() async {
    try {
      final now = DateTime.now();
      final mealsSnapshot = await _firestore.collection('meals').get();
      
      for (var doc in mealsSnapshot.docs) {
        final meal = Meal.fromJson(doc.data());
        if (now.isAfter(meal.startTime) && now.isBefore(meal.endTime)) {
          return meal;
        }
      }
      
      return null; // No active meal
    } catch (e) {
      developer.log('Error getting active meal: $e');
      throw Exception('Failed to get active meal: $e');
    }
  }
  
  // Process a meal QR code scan
  Future<Map<String, dynamic>> processMealQRScan(String qrData) async {
    try {
      // Decode QR data
      Map<String, dynamic> qrJson = json.decode(qrData);
      
      // Verify this is a meal QR code
      if (qrJson['type'] != 'meal_qr') {
        return {
          'success': false,
          'message': 'Invalid QR code. This is not a meal QR code.',
        };
      }
      
      // Check if this is the old format or new format QR code
      if (qrJson.containsKey('qrId')) {
        // New format
        return await _processNewFormatQR(qrJson);
      } else if (qrJson.containsKey('memberId')) {
        // Old format
        return await _processOldFormatQR(qrJson);
      } else {
        return {
          'success': false,
          'message': 'Invalid QR code format.',
        };
      }
    } catch (e) {
      developer.log('Error processing meal QR scan: $e');
      return {
        'success': false,
        'message': 'Error processing QR code: $e',
      };
    }
  }

  // Process new format QR code
  Future<Map<String, dynamic>> _processNewFormatQR(Map<String, dynamic> qrJson) async {
    final String qrId = qrJson['qrId'];
    final String memberName = qrJson['memberName'];
    final String teamName = qrJson['teamName'];
    final String mealId = qrJson['mealId'];
    
    // Check if this QR code has been used before
    final qrDoc = await _firestore.collection('mealQRCodes').doc(qrId).get();
    if (qrDoc.exists) {
      final bool isUsed = qrDoc.data()?['isUsed'] ?? false;
      if (isUsed) {
        return {
          'success': false,
          'message': 'This QR code has already been used.',
          'memberName': memberName,
          'teamName': teamName,
          'isSecondAttempt': true,
        };
      }
    }
    
    // Check if the meal is active
    final mealDoc = await _firestore.collection('meals').doc(mealId).get();
    if (!mealDoc.exists) {
      return {
        'success': false,
        'message': 'Meal not found.',
      };
    }
    
    final meal = Meal.fromJson(mealDoc.data()!);
    final now = DateTime.now();
    
    if (!(now.isAfter(meal.startTime) && now.isBefore(meal.endTime))) {
      return {
        'success': false,
        'message': 'This meal is not currently being served.',
        'mealName': meal.name,
        'startTime': meal.startTime,
        'endTime': meal.endTime,
      };
    }
    
    // Check if this member has already consumed this meal
    final consumptionSnapshot = await _firestore
        .collection('mealConsumptions')
        .where('memberName', isEqualTo: memberName)
        .where('teamName', isEqualTo: teamName)
        .where('mealId', isEqualTo: mealId)
        .where('isConsumed', isEqualTo: true)
        .get();
    
    if (consumptionSnapshot.docs.isNotEmpty) {
      final lastConsumption = MealConsumption.fromJson(
        consumptionSnapshot.docs.first.data()
      );
      
      return {
        'success': false,
        'message': 'This person has already consumed this meal.',
        'previousConsumption': lastConsumption.toJson(),
        'mealName': meal.name,
        'memberName': memberName,
        'teamName': teamName,
        'isSecondAttempt': true,
      };
    }
    
    // Record the meal consumption
    final consumptionId = _firestore.collection('mealConsumptions').doc().id;
    final consumption = MealConsumption(
      id: consumptionId,
      memberId: qrId, // Use QR ID as member ID
      memberName: memberName,
      teamId: teamName, // Use team name as team ID
      teamName: teamName,
      mealId: mealId,
      mealName: meal.name,
      timestamp: now,
      isConsumed: true,
    );
    
    await _firestore.collection('mealConsumptions').doc(consumptionId).set(
      consumption.toJson()
    );
    
    // Mark QR code as used
    await _firestore.collection('mealQRCodes').doc(qrId).update({
      'isUsed': true,
      'usedAt': FieldValue.serverTimestamp(),
    });
    
    return {
      'success': true,
      'message': 'Meal recorded successfully.',
      'memberName': memberName,
      'teamName': teamName,
      'mealName': meal.name,
    };
  }
  
  // Process old format QR code
  Future<Map<String, dynamic>> _processOldFormatQR(Map<String, dynamic> qrJson) async {
    final String memberId = qrJson['memberId'];
    final String mealId = qrJson['mealId'];
    
    // Check if the meal is active
    final mealDoc = await _firestore.collection('meals').doc(mealId).get();
    if (!mealDoc.exists) {
      return {
        'success': false,
        'message': 'Meal not found.',
      };
    }
    
    final meal = Meal.fromJson(mealDoc.data()!);
    final now = DateTime.now();
    
    if (!(now.isAfter(meal.startTime) && now.isBefore(meal.endTime))) {
      return {
        'success': false,
        'message': 'This meal is not currently being served.',
        'mealName': meal.name,
        'startTime': meal.startTime,
        'endTime': meal.endTime,
      };
    }
    
    // Check if this member has already consumed this meal
    final consumptionSnapshot = await _firestore
        .collection('mealConsumptions')
        .where('memberId', isEqualTo: memberId)
        .where('mealId', isEqualTo: mealId)
        .where('isConsumed', isEqualTo: true)
        .get();
    
    if (consumptionSnapshot.docs.isNotEmpty) {
      final lastConsumption = MealConsumption.fromJson(
        consumptionSnapshot.docs.first.data()
      );
      
      return {
        'success': false,
        'message': 'This person has already consumed this meal.',
        'previousConsumption': lastConsumption.toJson(),
        'mealName': meal.name,
        'isSecondAttempt': true,
      };
    }
    
    // Get member details
    final memberDoc = await _firestore.collection('members').doc(memberId).get();
    if (!memberDoc.exists) {
      return {
        'success': false,
        'message': 'Member not found.',
      };
    }
    
    final memberData = memberDoc.data()!;
    final teamId = memberData['teamId'] ?? '';
    final memberName = memberData['name'] ?? 'Unknown';
    
    // Get team details
    final teamDoc = await _firestore.collection('teams').doc(teamId).get();
    final teamData = teamDoc.exists ? teamDoc.data()! : {'teamName': 'Unknown Team'};
    final teamName = teamData['teamName'] ?? teamData['name'] ?? 'Unknown Team';
    
    // Record the meal consumption
    final consumptionId = _firestore.collection('mealConsumptions').doc().id;
    final consumption = MealConsumption(
      id: consumptionId,
      memberId: memberId,
      memberName: memberName,
      teamId: teamId,
      teamName: teamName,
      mealId: mealId,
      mealName: meal.name,
      timestamp: now,
      isConsumed: true,
    );
    
    await _firestore.collection('mealConsumptions').doc(consumptionId).set(
      consumption.toJson()
    );
    
    return {
      'success': true,
      'message': 'Meal recorded successfully.',
      'memberName': memberName,
      'teamName': teamName,
      'mealName': meal.name,
    };
  }
  
  // Get meal consumption statistics
  Future<Map<String, dynamic>> getMealStatistics(String mealId) async {
    try {
      // Get all meal consumptions for this meal
      final consumptionsSnapshot = await _firestore
          .collection('mealConsumptions')
          .where('mealId', isEqualTo: mealId)
          .where('isConsumed', isEqualTo: true)
          .get();
      
      final consumptions = consumptionsSnapshot.docs.map((doc) {
        return MealConsumption.fromJson(doc.data());
      }).toList();
      
      // Get unique teams and members
      final Set<String> uniqueTeams = {};
      final Set<String> uniqueMembers = {};
      final Map<String, List<MealConsumption>> consumptionsByTeam = {};
      
      for (var consumption in consumptions) {
        uniqueTeams.add(consumption.teamId);
        uniqueMembers.add(consumption.memberId);
        
        // Group by team
        if (!consumptionsByTeam.containsKey(consumption.teamName)) {
          consumptionsByTeam[consumption.teamName] = [];
        }
        consumptionsByTeam[consumption.teamName]!.add(consumption);
      }
      
      // Sort consumptions by time (latest first) within each team
      for (var team in consumptionsByTeam.keys) {
        consumptionsByTeam[team]!.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      }
      
      // Get total expected members for this event
      final membersSnapshot = await _firestore.collection('members').get();
      final totalMembers = membersSnapshot.docs.length;
      final remainingMembers = totalMembers - uniqueMembers.length;
      
      return {
        'total': consumptions.length,
        'uniqueTeams': uniqueTeams.length,
        'uniqueMembers': uniqueMembers.length,
        'totalMembers': totalMembers,
        'remainingMembers': remainingMembers,
        'consumptionsByTeam': consumptionsByTeam,
        'consumptions': consumptions.map((c) => c.toJson()).toList(),
      };
    } catch (e) {
      developer.log('Error getting meal statistics: $e');
      throw Exception('Failed to get meal statistics: $e');
    }
  }
  
  // Check if a member has consumed a meal
  Future<bool> hasMemberConsumedMeal(String memberId, String mealId) async {
    try {
      final consumptionSnapshot = await _firestore
          .collection('mealConsumptions')
          .where('memberId', isEqualTo: memberId)
          .where('mealId', isEqualTo: mealId)
          .where('isConsumed', isEqualTo: true)
          .get();
      
      return consumptionSnapshot.docs.isNotEmpty;
    } catch (e) {
      developer.log('Error checking if member has consumed meal: $e');
      throw Exception('Failed to check meal consumption: $e');
    }
  }
  
  // Check if a member has consumed a meal by name and team
  Future<bool> hasMemberConsumedMealByName(String memberName, String teamName, String mealId) async {
    try {
      final consumptionSnapshot = await _firestore
          .collection('mealConsumptions')
          .where('memberName', isEqualTo: memberName)
          .where('teamName', isEqualTo: teamName)
          .where('mealId', isEqualTo: mealId)
          .where('isConsumed', isEqualTo: true)
          .get();
      
      return consumptionSnapshot.docs.isNotEmpty;
    } catch (e) {
      developer.log('Error checking if member has consumed meal: $e');
      return false; // Default to not consumed in case of error
    }
  }
} 