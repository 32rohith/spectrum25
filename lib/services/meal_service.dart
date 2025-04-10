import 'dart:convert';
import 'dart:math';
import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import '../models/meal_tracking.dart';
import './email_service.dart';

class MealService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final EmailService _emailService = EmailService();
  
  // Initialize the meals in the database - typically called once during app setup
  Future<void> initializeMeals() async {
    try {
      // Check if meals are already initialized
      final mealsSnapshot = await _firestore.collection('meals').get();
      if (mealsSnapshot.docs.isNotEmpty) {
        developer.log('Meals already initialized');
        return;
      }
      
      // Calculate times for test meal
      final now = DateTime.now();
      final oneHourFromNow = now.add(Duration(hours: 1));
      
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
          name: 'Test Meal (1 hour)',
          startTime: now,
          endTime: oneHourFromNow,
          isActive: true,
        ),
      ];
      
      // Add meals to database
      final batch = _firestore.batch();
      for (var meal in meals) {
        batch.set(_firestore.collection('meals').doc(meal.id), meal.toJson());
      }
      
      await batch.commit();
      developer.log('Meals initialized successfully with test meal that lasts 1 hour');
    } catch (e) {
      developer.log('Error initializing meals: $e');
      throw Exception('Failed to initialize meals: $e');
    }
  }
  
  // Helper method to create a DateTime for today at a specific hour and minute
  DateTime _createTimeToday(int hour, int minute) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }
  
  
  // Generate QR code using stored secret if available
  String generateQRCode(String memberName, String teamName, {String? qrSecret}) {
    // Use the provided secret or generate a new one
    final secret = qrSecret ?? _generateQRSecret();
    
    developer.log('Generating QR code for: $memberName from $teamName');
    
    // Create a valid JSON format for QR code to ensure compatibility
    final Map<String, dynamic> qrData = {
      'type': 'member_qr',
      'memberName': memberName,
      'teamName': teamName,
      'secret': secret
    };
    
    // Convert to JSON string
    return json.encode(qrData);
  }
  
  // Send QR code via email
  Future<bool> sendQRCodeEmail({
    required String recipientEmail,
    required String memberName,
    required String teamName,
    required String qrCodeData,
  }) async {
    try {
      developer.log('MealService: Starting QR code email process for $memberName to $recipientEmail');
      
      // Use email service to send the email
      developer.log('MealService: Delegating to EmailService for sending email');
      final result = await _emailService.sendQRCodeEmail(
        recipientEmail: recipientEmail,
        memberName: memberName,
        teamName: teamName,
        qrCodeData: qrCodeData,
      );
      
      // Log the result
      if (result) {
        developer.log('MealService: Successfully sent QR code email to $recipientEmail for $memberName from $teamName');
      } else {
        developer.log('MealService: Failed to send QR code email to $recipientEmail for $memberName from $teamName');
      }
      
      return result;
    } catch (e) {
      developer.log('MealService: Error in sendQRCodeEmail for $memberName ($recipientEmail): $e', 
                   error: e, 
                   stackTrace: StackTrace.current);
      return false;
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
  
  // Process a member QR code scan
  Future<Map<String, dynamic>> processMemberQRScan(String qrData) async {
    try {
      // Log the raw QR data for debugging
      developer.log('Processing member QR scan with data: ${qrData}');
      
      // Trim any whitespace that might have been added during email transmission
      String trimmedQrData = qrData.trim();
      
      // Try to parse as JSON first (our new format)
      try {
        Map<String, dynamic> qrJson = json.decode(trimmedQrData);
        
        // Check if it's our member QR format with all expected fields
        if (qrJson['type'] == 'member_qr' && 
            qrJson['memberName'] != null && 
            qrJson['teamName'] != null &&
            qrJson['secret'] != null) {
          
          developer.log('Found new format QR with valid fields');
          
          final String memberName = qrJson['memberName'];
          final String teamName = qrJson['teamName'];
          final String secret = qrJson['secret'];
          
          // First try to find member by secret
          final membersSnapshot = await _firestore
              .collection('members')
              .where('qrSecret', isEqualTo: secret)
              .limit(1)
              .get();
          
          if (membersSnapshot.docs.isNotEmpty) {
            // Found by secret, proceed with meal service
            final memberDoc = membersSnapshot.docs.first;
            final memberId = memberDoc.id;
            final memberData = memberDoc.data();
            
            // Check if we have an active meal
            final activeMeal = await getActiveMeal();
            if (activeMeal == null) {
              return {
                'success': false,
                'message': 'No active meal at this time',
              };
            }
            
            // Check if member has already consumed this meal
            bool hasConsumed = false;
            
            // Check which meal is active and if it has been consumed
            switch (activeMeal.id) {
              case 'breakfast':
                hasConsumed = memberData['isBreakfastConsumed'] == true;
                break;
              case 'lunch':
                hasConsumed = memberData['isLunchConsumed'] == true;
                break;
              case 'dinner':
                hasConsumed = memberData['isDinnerConsumed'] == true;
                break;
              case 'test_meal':
                hasConsumed = memberData['isTestMealConsumed'] == true;
                break;
            }
            
            if (hasConsumed) {
              return {
                'success': false,
                'isSecondAttempt': true,
                'message': 'Member $memberName has already consumed this meal',
                'memberName': memberName,
                'teamName': teamName,
              };
            }
            
            // Record consumption
            final timestamp = DateTime.now();
            
            // Create a new consumption record
            await _firestore.collection('mealConsumptions').add({
              'mealId': activeMeal.id,
              'memberId': memberId,
              'memberName': memberName,
              'teamName': teamName,
              'timestamp': timestamp,
            });
            
            // Update member document to mark meal as consumed
            await _updateMemberMealConsumption(memberId, activeMeal.id);
            
            return {
              'success': true,
              'message': 'Meal recorded successfully: ${activeMeal.name}',
              'memberName': memberName,
              'teamName': teamName,
              'mealName': activeMeal.name,
            };
          }
          
          // If not found by secret, try finding by name and team
          final membersByNameSnapshot = await _firestore
              .collection('members')
              .where('name', isEqualTo: memberName)
              .where('teamName', isEqualTo: teamName)
              .limit(1)
              .get();
          
          if (membersByNameSnapshot.docs.isNotEmpty) {
            // Found by name/team, update the secret and proceed
            final memberDoc = membersByNameSnapshot.docs.first;
            final memberId = memberDoc.id;
            
            // Update the secret
            await _firestore.collection('members').doc(memberId).update({
              'qrSecret': secret
            });
            
            // Continue with the meal consumption...
            // Check if we have an active meal
            final activeMeal = await getActiveMeal();
            if (activeMeal == null) {
              return {
                'success': false,
                'message': 'No active meal at this time',
              };
            }
            
            // Record consumption
            final timestamp = DateTime.now();
            
            // Create a new consumption record
            await _firestore.collection('mealConsumptions').add({
              'mealId': activeMeal.id,
              'memberId': memberId,
              'memberName': memberName,
              'teamName': teamName,
              'timestamp': timestamp,
            });
            
            // Update member document to mark meal as consumed
            await _updateMemberMealConsumption(memberId, activeMeal.id);
            
            return {
              'success': true,
              'message': 'Meal recorded successfully: ${activeMeal.name}',
              'memberName': memberName,
              'teamName': teamName,
              'mealName': activeMeal.name,
            };
          }
        }
      } catch (jsonError) {
        // If JSON parsing fails, we'll try the old formats below
        developer.log('Not a valid JSON format or missing required fields, trying legacy formats');
      }
      
      // Try legacy format (simple secret key)
      if (trimmedQrData.length >= 16 && trimmedQrData.length <= 64) {
        // This appears to be just a QR secret - look up the member by secret
        final membersSnapshot = await _firestore
            .collection('members')
            .where('qrSecret', isEqualTo: trimmedQrData)
            .limit(1)
            .get();
            
        if (membersSnapshot.docs.isNotEmpty) {
          // Process using legacy method (remaining code stays the same)
          // Found a member with this secret
          final memberDoc = membersSnapshot.docs.first;
          final memberId = memberDoc.id;
          final memberData = memberDoc.data();
          final String memberName = memberData['name'] ?? 'Unknown';
          final String teamName = memberData['teamName'] ?? 'Unknown';
          
          developer.log('Found member by QR secret: $memberName from $teamName');
          
          // Check if we have an active meal
          final activeMeal = await getActiveMeal();
          if (activeMeal == null) {
            return {
              'success': false,
              'message': 'No active meal at this time',
            };
          }
          
          // Check if member has already consumed this meal
          bool hasConsumed = false;
          
          // Check which meal is active and if it has been consumed
          switch (activeMeal.id) {
            case 'breakfast':
              hasConsumed = memberData['isBreakfastConsumed'] == true;
              break;
            case 'lunch':
              hasConsumed = memberData['isLunchConsumed'] == true;
              break;
            case 'dinner':
              hasConsumed = memberData['isDinnerConsumed'] == true;
              break;
            case 'test_meal':
              hasConsumed = memberData['isTestMealConsumed'] == true;
              break;
          }
          
          if (hasConsumed) {
            return {
              'success': false,
              'isSecondAttempt': true,
              'message': 'Member $memberName has already consumed this meal',
              'memberName': memberName,
              'teamName': teamName,
            };
          }
          
          // Record consumption
          final timestamp = DateTime.now();
          
          // Create a new consumption record
          await _firestore.collection('mealConsumptions').add({
            'mealId': activeMeal.id,
            'memberId': memberId,
            'memberName': memberName,
            'teamName': teamName,
            'timestamp': timestamp,
          });
          
          // Update member document to mark meal as consumed
          await _updateMemberMealConsumption(memberId, activeMeal.id);
          
          return {
            'success': true,
            'message': 'Meal recorded successfully: ${activeMeal.name}',
            'memberName': memberName,
            'teamName': teamName,
            'mealName': activeMeal.name,
          };
        }
      }
      
      // Try the old JSON format (legacy fallback)
      try {
        Map<String, dynamic> qrJson = json.decode(trimmedQrData);
        
        // Check for both old and new field names (for backward compatibility)
        final String qrType = qrJson['type'] ?? qrJson['t'] ?? '';
        
        // Verify this is a member QR code
        if (qrType != 'member_qr') {
          developer.log('Invalid QR type: $qrType');
          return {
            'success': false,
            'message': 'Invalid QR code: Not a member QR code',
          };
        }
        
        // Extract member data using both old and new field names
        final String memberName = qrJson['memberName'] ?? qrJson['n'] ?? '';
        final String teamName = qrJson['teamName'] ?? qrJson['tm'] ?? '';
        
        // Verify required fields exist
        if (memberName.isEmpty || teamName.isEmpty) {
          developer.log('Missing required fields in QR data');
          return {
            'success': false,
            'message': 'Invalid QR code: Missing required member information',
          };
        }
        
        // Rest of the old JSON format handling remains the same
        // ... (the existing code for the old JSON format)
      } catch (jsonError) {
        // Not valid JSON and not a valid secret key
        developer.log('Error decoding QR data: $jsonError');
        return {
          'success': false,
          'message': 'Invalid QR code format. Please scan a valid meal QR code.',
        };
      }
      
      // If we get here, no valid QR code was found
      return {
        'success': false,
        'message': 'Invalid QR code. Please scan a valid member QR code.',
      };
    } catch (e) {
      developer.log('Error processing member QR scan: $e');
      return {
        'success': false,
        'message': 'Error processing QR code: $e',
      };
    }
  }
  
  // Helper method to update member's meal consumption status
  Future<void> _updateMemberMealConsumption(String memberId, String mealId) async {
    // Update meal flags in member document
    bool isBreakfast = false;
    bool isLunch = false;
    bool isDinner = false;
    bool isTest = false;
    
    switch (mealId) {
      case 'breakfast':
        isBreakfast = true;
        break;
      case 'lunch':
        isLunch = true;
        break;
      case 'dinner':
        isDinner = true;
        break;
      case 'test_meal':
        isTest = true;
        break;
    }
    
    // Update member document with the corresponding meal flag
    await _firestore.collection('members').doc(memberId).update({
      if (isBreakfast) 'isBreakfastConsumed': true,
      if (isLunch) 'isLunchConsumed': true,
      if (isDinner) 'isDinnerConsumed': true,
      if (isTest) 'isTestMealConsumed': true,
    });
  }
  
  // Generate QR code and update member document
  Future<String> generateAndStoreMemberQR(String memberId, String memberName, String teamName) async {
    try {
      // Generate a unique QR secret
      final qrSecret = _generateQRSecret();
      
      developer.log('Generating and storing new QR secret for member: $memberName (ID: $memberId)');
      
      try {
        // Update member document with the QR secret and device info
        await _firestore.collection('members').doc(memberId).update({
          'qrSecret': qrSecret,
          'device': Platform.isIOS ? 'iOS' : 'Android',
          'lastQRUpdate': FieldValue.serverTimestamp(),
        });
        developer.log('Successfully stored QR secret for member: $memberName');
      } catch (e) {
        developer.log('Error updating member QR secret: $e - attempting to create document instead');
        
        // If update fails because document doesn't exist, try to create it
        await _firestore.collection('members').doc(memberId).set({
          'qrSecret': qrSecret,
          'device': Platform.isIOS ? 'iOS' : 'Android',
          'lastQRUpdate': FieldValue.serverTimestamp(),
          'name': memberName,
          'teamName': teamName,
          'isBreakfastConsumed': false,
          'isLunchConsumed': false,
          'isDinnerConsumed': false,
          'isTestMealConsumed': false,
        }, SetOptions(merge: true));
        
        developer.log('Created/updated member document with QR secret for: $memberName');
      }
      
      // Generate QR code using the member information and the secret
      return generateQRCode(memberName, teamName, qrSecret: qrSecret);
    } catch (e) {
      developer.log('Error in generateAndStoreMemberQR: $e');
      // If all else fails, fall back to a temporary QR code
      return generateQRCode(memberName, teamName);
    }
  }
  
  // Get a member's stored QR secret
  Future<String?> getMemberQRSecret(String memberId) async {
    try {
      developer.log('Fetching QR secret for member ID: $memberId');
      final memberDoc = await _firestore.collection('members').doc(memberId).get();
      
      if (!memberDoc.exists) {
        developer.log('Member document not found for ID: $memberId');
        return null;
      }
      
      final memberData = memberDoc.data()!;
      final String? qrSecret = memberData['qrSecret'] as String?;
      
      if (qrSecret == null || qrSecret.isEmpty) {
        developer.log('No QR secret found in document for member ID: $memberId');
        return null;
      }
      
      developer.log('Successfully retrieved QR secret for member ID: $memberId');
      return qrSecret;
    } catch (e) {
      developer.log('Error getting member QR secret: $e');
      return null;
    }
  }
  
  // Generate QR code for a member using their stored secret
  Future<String> generateQRWithStoredSecret(String memberId, String memberName, String teamName) async {
    // Get stored QR secret
    final qrSecret = await getMemberQRSecret(memberId);
    
    // If no secret is found, generate and store a new one
    if (qrSecret == null || qrSecret.isEmpty) {
      developer.log('No QR secret found for $memberName, generating new one');
      return await generateAndStoreMemberQR(memberId, memberName, teamName);
    }
    
    developer.log('Using existing QR secret for $memberName');
    // Generate QR code using the secret
    return generateQRCode(memberName, teamName, qrSecret: qrSecret);
  }
  
  // Get meal consumption statistics
  Future<Map<String, dynamic>> getMealStatistics(String mealId) async {
    try {
      // Get all meal consumptions for this meal
      final consumptionsSnapshot = await _firestore
          .collection('mealConsumptions')
          .where('mealId', isEqualTo: mealId)
          .get();
      
      final consumptions = consumptionsSnapshot.docs.map((doc) {
        return MealConsumption.fromJson(doc.data());
      }).toList();
      
      // Get unique teams and members
      final Set<String> uniqueTeams = {};
      final Set<String> uniqueMembers = {};
      final Map<String, List<MealConsumption>> consumptionsByTeam = {};
      
      for (var consumption in consumptions) {
        // Only add if it has a valid teamId and memberId
        if (consumption.teamId.isNotEmpty) {
          uniqueTeams.add(consumption.teamId);
        }
        
        if (consumption.memberId.isNotEmpty) {
          uniqueMembers.add(consumption.memberId);
        }
        
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
  
  // Process a meal QR code scan
  Future<Map<String, dynamic>> processMealQRScan(String qrData) async {
    try {
      // Decode QR data
      Map<String, dynamic> qrJson = json.decode(qrData);
      
      // Verify this is a meal QR code
      if (qrJson['type'] != 'meal_qr') {
        return {
          'success': false,
          'message': 'Invalid QR code: Not a meal QR code',
        };
      }
      
      // Check if we have an active meal
      final activeMeal = await getActiveMeal();
      if (activeMeal == null) {
        return {
          'success': false,
          'message': 'No active meal at this time',
        };
      }
      
      // Extract data from QR code
      final String memberId = qrJson['memberId'];
      final String mealId = qrJson['mealId'];
      
      // Verify the meal ID matches the active meal
      if (mealId != activeMeal.id) {
        return {
          'success': false,
          'message': 'This QR code is for a different meal: ${mealId}',
        };
      }
      
      // Check if already consumed
      final memberDoc = await _firestore.collection('members').doc(memberId).get();
      if (!memberDoc.exists) {
        return {
          'success': false,
          'message': 'Member not found',
        };
      }
      
      final memberData = memberDoc.data()!;
      final String memberName = memberData['name'] ?? 'Unknown';
      final String teamName = memberData['teamName'] ?? 'Unknown';
      final String teamId = memberData['teamId'] ?? '';
      
      // Check if member has already consumed this meal
      final existingConsumption = await hasMemberConsumedMeal(memberId, activeMeal.id);
      if (existingConsumption) {
        return {
          'success': false,
          'isSecondAttempt': true,
          'message': 'Member $memberName has already consumed this meal',
          'memberName': memberName,
          'teamName': teamName,
        };
      }
      
      // Record the consumption
      final consumptionId = '$memberId-${activeMeal.id}';
      await _firestore.collection('mealConsumptions').doc(consumptionId).set({
        'id': consumptionId,
        'memberId': memberId,
        'memberName': memberName,
        'teamId': teamId,
        'teamName': teamName,
        'mealId': activeMeal.id,
        'mealName': activeMeal.name,
        'timestamp': FieldValue.serverTimestamp(),
        'isConsumed': true,
      });
      
      // Update meal flags in member document based on meal type
      bool isBreakfast = false;
      bool isLunch = false;
      bool isDinner = false;
      bool isTest = false;
      
      switch (activeMeal.id) {
        case 'breakfast':
          isBreakfast = true;
          break;
        case 'lunch':
          isLunch = true;
          break;
        case 'dinner':
          isDinner = true;
          break;
        case 'test_meal':
          isTest = true;
          break;
      }
      
      // Update member document
      await updateMemberDocument(
        memberId,
        isTest: isTest,
        isLunch: isLunch,
        isBreakfast: isBreakfast,
        isDinner: isDinner
      );
      
      return {
        'success': true,
        'message': 'Meal recorded successfully',
        'memberName': memberName,
        'teamName': teamName,
        'mealName': activeMeal.name,
      };
    } catch (e) {
      developer.log('Error processing meal QR scan: $e');
      return {
        'success': false,
        'message': 'Error processing QR code: $e',
      };
    }
  }
  
  // Update member document with meal status or QR secret
  Future<void> updateMemberDocument(
    String memberId, {
    bool? isBreakfast,
    bool? isLunch,
    bool? isDinner,
    bool? isTest,
    String? qrSecret,
  }) async {
    try {
      final memberRef = _firestore.collection('members').doc(memberId);
      final Map<String, dynamic> updateData = {};
      
      if (isBreakfast != null) updateData['isBreakfastConsumed'] = isBreakfast;
      if (isLunch != null) updateData['isLunchConsumed'] = isLunch;
      if (isDinner != null) updateData['isDinnerConsumed'] = isDinner;
      if (isTest != null) updateData['isTestMealConsumed'] = isTest;
      if (qrSecret != null) updateData['qrSecret'] = qrSecret;
      
      await memberRef.update(updateData);
    } catch (e) {
      developer.log('Error updating member document: $e');
      throw Exception('Failed to update member document: $e');
    }
  }
  
  // Generate a secure QR secret
  String _generateQRSecret() {
    final Random random = Random.secure();
    final List<int> values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(values);
  }
  
  // Reset and reinitialize meals for testing purposes
  Future<void> resetAndReinitializeMeals() async {
    try {
      // Get all existing meals
      final mealsSnapshot = await _firestore.collection('meals').get();
      
      // Delete all existing meals
      final batch = _firestore.batch();
      for (var doc in mealsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      developer.log('All existing meals deleted successfully, including any previous test meals');
      
      // Reinitialize meals
      await initializeMeals();
      developer.log('Meals reinitialized successfully with new 1-hour test meal');
    } catch (e) {
      developer.log('Error resetting and reinitializing meals: $e');
      throw Exception('Failed to reset and reinitialize meals: $e');
    }
  }

  // Send QR codes to all iOS members in a team using team collection emails
  Future<Map<String, dynamic>> sendQRCodeToAllTeamIOSMembers(String teamId) async {
    try {
      developer.log('Starting QR code delivery for iOS members in team: $teamId');
      
      // Get the team data
      final teamDoc = await _firestore.collection('teams').doc(teamId).get();
      if (!teamDoc.exists) {
        return {
          'success': false,
          'message': 'Team not found',
          'sent': 0,
          'failed': 0,
        };
      }
      
      // Get team data
      final teamData = teamDoc.data()!;
      final String teamName = teamData['teamName'] ?? '';
      
      // Get all team members (both leader and regular members)
      final List<Map<String, dynamic>> allMembers = [];
      
      // Add leader to list
      if (teamData['leader'] != null) {
        allMembers.add(teamData['leader'] as Map<String, dynamic>);
      }
      
      // Add other members
      if (teamData['members'] != null) {
        final membersList = teamData['members'] as List<dynamic>;
        for (var member in membersList) {
          allMembers.add(member as Map<String, dynamic>);
        }
      }
      
      // Track results
      int sentCount = 0;
      int failedCount = 0;
      List<String> processed = [];
      
      // Process each member with an iOS device
      for (var member in allMembers) {
        // Focus on iOS users only and check if email exists
        if (member['device'] == 'iOS' && 
            member['email'] != null && 
            member['email'].toString().isNotEmpty) {
          
          final String memberName = member['name'] ?? '';
          final String email = member['email'];
          
          // Skip already processed emails
          if (processed.contains(email)) continue;
          processed.add(email);
          
          developer.log('Processing iOS member: $memberName with email: $email');
          
          // Find or create member document
          String memberId = '';
          String qrData = '';
          
          // Look for existing member in members collection
          final membersSnapshot = await _firestore
            .collection('members')
            .where('name', isEqualTo: memberName)
            .where('teamName', isEqualTo: teamName)
            .limit(1)
            .get();
            
          if (membersSnapshot.docs.isNotEmpty) {
            // Use existing member
            memberId = membersSnapshot.docs.first.id;
            final memberData = membersSnapshot.docs.first.data();
            
            // Update member with email if not already set
            if (memberData['email'] == null || memberData['email'].toString().isEmpty) {
              await _firestore.collection('members').doc(memberId).update({
                'email': email,
                'device': 'iOS'
              });
              developer.log('Updated member document with email: $email');
            }
            
            // Check if member needs QR code
            if (memberData['qrSecret'] == null) {
              // Generate and store QR
              qrData = await generateAndStoreMemberQR(memberId, memberName, teamName);
            } else {
              // Use existing QR
              qrData = await generateQRWithStoredSecret(memberId, memberName, teamName);
            }
          } else {
            // Create new member document
            final newMemberRef = _firestore.collection('members').doc();
            memberId = newMemberRef.id;
            
            // Create member data
            await newMemberRef.set({
              'name': memberName,
              'teamName': teamName,
              'teamId': teamId,
              'isBreakfastConsumed': false,
              'isLunchConsumed': false,
              'isDinnerConsumed': false,
              'isTestMealConsumed': false,
              'device': 'iOS',
              'email': email,
              'createdAt': FieldValue.serverTimestamp(),
            });
            
            developer.log('Created new member document for: $memberName');
            
            // Generate QR code
            qrData = await generateAndStoreMemberQR(memberId, memberName, teamName);
          }
          
          // Send email with QR code
          developer.log('Sending QR code email to: $email');
          final success = await sendQRCodeEmail(
            recipientEmail: email,
            memberName: memberName,
            teamName: teamName,
            qrCodeData: qrData
          );
          
          if (success) {
            sentCount++;
            developer.log('Successfully sent QR code to: $email');
          } else {
            failedCount++;
            developer.log('Failed to send QR code to: $email');
          }
        }
      }
      
      developer.log('Team QR code delivery complete. Sent: $sentCount, Failed: $failedCount');
      
      return {
        'success': true,
        'message': 'Automatic QR code delivery complete for iOS users',
        'sent': sentCount,
        'failed': failedCount,
      };
    } catch (e) {
      developer.log('Error in team iOS QR code delivery: $e');
      return {
        'success': false,
        'message': 'Error: $e',
        'sent': 0,
        'failed': 0,
      };
    }
  }
} 