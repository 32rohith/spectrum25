import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/team.dart';
import 'dart:developer' as developer;

// Extension to capitalize the first letter of a string
extension StringExtension on String {
  String capitalize() {
    if (this.isEmpty) return this;
    return this[0].toUpperCase() + this.substring(1);
  }
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Generate a unique username and password
  Map<String, String> _generateCredentials(String name, String role) {
    final random = Random();
    // Get first 4 letters of name (or use full name if less than 4 chars)
    final namePrefix = name.length > 4 ? name.substring(0, 4).toLowerCase() : name.toLowerCase();
    
    // Generate 4 random digits
    final fourDigits = random.nextInt(9000) + 1000; // Ensures 4 digits
    
    // Create username: first4_digits
    final username = '${namePrefix}_$fourDigits';
    
    // Create password: first4@digits
    final password = '$namePrefix@$fourDigits';
    
    return {
      'username': username,
      'password': password,
    };
  }
  
  // Generate a unique meal QR code for a member
  String _generateMealQRCode(String memberId, String name) {
    final random = Random();
    // Generate 6 random digits
    final sixDigits = random.nextInt(900000) + 100000; // Ensures 6 digits
    
    // Create a unique code with member ID and random digits
    final code = '${memberId.substring(0, 8)}_MEAL_$sixDigits';
    
    return code;
  }
  
  // Initialize meal tracking for a member
  Map<String, dynamic> _initializeMealTracking() {
    // Define meal times
    final lunchTime = DateTime(2025, 4, 11, 11, 0); // April 11, 2025, 11:00 AM
    final dinnerTime = DateTime(2025, 4, 11, 18, 0); // April 11, 2025, 6:00 PM
    final breakfastTime = DateTime(2025, 4, 12, 6, 30); // April 12, 2025, 6:30 AM
    
    return {
      'lunch': {
        'dateTime': lunchTime,
        'served': false,
        'servedAt': null,
        'allowedStartTime': lunchTime,
        'allowedEndTime': DateTime(2025, 4, 11, 16, 0), // April 11, 2025, 4:00 PM
      },
      'dinner': {
        'dateTime': dinnerTime,
        'served': false,
        'servedAt': null,
        'allowedStartTime': dinnerTime,
        'allowedEndTime': DateTime(2025, 4, 11, 22, 30), // April 11, 2025, 10:30 PM
      },
      'breakfast': {
        'dateTime': breakfastTime,
        'served': false,
        'servedAt': null,
        'allowedStartTime': breakfastTime,
        'allowedEndTime': DateTime(2025, 4, 12, 10, 30), // April 12, 2025, 10:30 AM
      },
    };
  }
  
  // Register a new team with team leader and members
  Future<Map<String, dynamic>> registerTeam({
    required String teamName,
    required TeamMember leader,
    required List<TeamMember> members,
  }) async {
    try {
      developer.log('Starting team registration process for: $teamName');
      
      // Generate team credentials
      final teamCredentials = _generateCredentials(teamName, 'team');
      final teamUsername = teamCredentials['username']!;
      final teamPassword = teamCredentials['password']!;
      
      // Create team email for Firebase Auth (internal use only)
      final teamEmail = '$teamUsername@hackathon.app';
      
      // Create team account in Firebase Auth
      developer.log('Creating team account in Firebase Auth');
      final teamUserCredential = await _auth.createUserWithEmailAndPassword(
        email: teamEmail,
        password: teamPassword,
      );
      
      final teamId = teamUserCredential.user!.uid;
      developer.log('Team account created with ID: $teamId');
      
      // Generate leader credentials with specific role
      final leaderCredentials = _generateCredentials(leader.name, 'leader');
      final leaderUsername = leaderCredentials['username']!;
      final leaderPassword = leaderCredentials['password']!;
      final leaderEmail = '$leaderUsername@hackathon.app';
      
      // Create leader account in Firebase Auth
      developer.log('Creating leader account in Firebase Auth');
      final leaderUserCredential = await _auth.createUserWithEmailAndPassword(
        email: leaderEmail,
        password: leaderPassword,
      );
      
      // Update leader with credentials
      final updatedLeader = TeamMember(
        name: leader.name,
        email: leader.email,
        phone: leader.phone,
        device: leader.device,
      );
      
      // Generate leader meal QR code
      final leaderMealQRCode = _generateMealQRCode(leaderUserCredential.user!.uid, leader.name);
      final leaderMealTracking = _initializeMealTracking();
      
      // Store leader auth details
      try {
        developer.log('Storing leader details in Firestore');
        await _firestore.collection('members').doc(leaderEmail).set({
          'username': leaderUsername,
          'password': leaderPassword,
          'email': leaderEmail,
          'originalEmail': leader.email,
          'name': leader.name,
          'phone': leader.phone,
          'device': leader.device,
          'role': 'leader',
          'teamId': teamId,
          'teamName': teamName,
          'isRegistered': true,
          'mealQRCode': leaderMealQRCode,
          'meals': leaderMealTracking,
        });
        developer.log('Leader details stored successfully');
      } catch (e) {
        developer.log('Error storing leader details: $e');
        throw FirebaseException(
          plugin: 'cloud_firestore',
          message: 'Failed to store leader details: $e',
        );
      }
      
      // Generate and store credentials for each member
      List<TeamMember> updatedMembers = [];
      List<Map<String, dynamic>> memberAuthDetails = [];
      
      for (var i = 0; i < members.length; i++) {
        final member = members[i];
        developer.log('Processing member ${i+1}: ${member.name}');
        
        // Generate member credentials with specific role
        final memberCredentials = _generateCredentials(member.name, 'member');
        final memberUsername = memberCredentials['username']!;
        final memberPassword = memberCredentials['password']!;
        final memberEmail = '$memberUsername@hackathon.app';
        
        // Create member account in Firebase Auth
        developer.log('Creating Firebase Auth account for member: ${member.name}');
        final memberUserCredential = await _auth.createUserWithEmailAndPassword(
          email: memberEmail,
          password: memberPassword,
        );
        
        // Generate member meal QR code
        final memberMealQRCode = _generateMealQRCode(memberUserCredential.user!.uid, member.name);
        final memberMealTracking = _initializeMealTracking();
        
        // Add to updated members list
        updatedMembers.add(TeamMember(
          name: member.name,
          email: member.email,
          phone: member.phone,
          device: member.device,
        ));
        
        try {
          // Store member auth details
          developer.log('Storing member details in Firestore');
          await _firestore.collection('members').doc(memberEmail).set({
            'username': memberUsername,
            'password': memberPassword,
            'email': memberEmail,
            'originalEmail': member.email,
            'name': member.name,
            'phone': member.phone,
            'device': member.device,
            'role': 'member',
            'teamId': teamId,
            'teamName': teamName,
            'isRegistered': true,
            'mealQRCode': memberMealQRCode,
            'meals': memberMealTracking,
          });
          developer.log('Member details stored successfully');
        } catch (e) {
          developer.log('Error storing member details: $e');
          throw FirebaseException(
            plugin: 'cloud_firestore',
            message: 'Failed to store member details: $e',
          );
        }
        
        memberAuthDetails.add({
          'name': member.name,
          'username': memberUsername,
          'password': memberPassword,
        });
      }
      
      // Create updated team with credentials
      final team = Team(
        teamName: teamName,
        teamId: teamId,
        username: teamUsername,
        password: teamPassword,
        leader: updatedLeader,
        members: updatedMembers,
        isVerified: false,
        isRegistered: true,
      );
      
      try {
        // Store team credentials and member auth details
        developer.log('Storing team data in Firestore');
        await _firestore.collection('teams').doc(teamId).set({
          ...team.toJson(),
          'leaderAuth': {
            'username': leaderUsername,
            'password': leaderPassword,
          },
          'membersAuth': memberAuthDetails,
          'isRegistered': true,
        });
        developer.log('Team data stored successfully');
      } catch (e) {
        developer.log('Error storing team data: $e');
        throw FirebaseException(
          plugin: 'cloud_firestore',
          message: 'Failed to store team data: $e',
        );
      }
      
      // Sign back out so user can log in with their credentials
      await _auth.signOut();
      
      return {
        'success': true,
        'team': team,
        'message': 'Team registered successfully',
        'teamAuth': {
          'username': leaderUsername,
          'password': leaderPassword,
        },
        'membersAuth': memberAuthDetails,
      };
    } on FirebaseAuthException catch (e) {
      developer.log('Firebase Auth Error: ${e.code} - ${e.message}');
      return {
        'success': false,
        'message': e.message ?? 'An error occurred during registration',
      };
    } on FirebaseException catch (e) {
      developer.log('Firebase Error: ${e.code} - ${e.message}');
      return {
        'success': false,
        'message': e.message ?? 'A database error occurred',
      };
    } catch (e) {
      developer.log('Unexpected Error: $e');
      return {
        'success': false,
        'message': 'An unexpected error occurred: $e',
      };
    }
  }
  
  // Login as team leader or member
  Future<Map<String, dynamic>> loginTeam({
    required String username,
    required String password,
  }) async {
    try {
      developer.log('Attempting login for username: $username');
      
      // Check for members by username first (team leaders and members)
      developer.log('Checking login by username match');
      final memberQuery = await _firestore
          .collection('members')
          .where('username', isEqualTo: username)
          .get();
          
      // If found a member/leader by exact username
      if (memberQuery.docs.isNotEmpty) {
        // We need to check all docs because there might be multiple results
        for (var memberDoc in memberQuery.docs) {
          final memberData = memberDoc.data();
          final userRole = memberData['role'] as String? ?? '';
          
          developer.log('Found user account by username: $userRole');
          
          // Verify password
          if (memberData['password'] != password) {
            developer.log('Password verification failed for this account');
            continue; // Try next account if there are multiple matches
          }

          // Check if registered
          if (memberData['isRegistered'] != true) {
            developer.log('Account not registered');
            continue;
          }
          
          final teamId = memberData['teamId'];
          
          // Get team data
          developer.log('Retrieving team data for $userRole');
          final teamSnapshot = await _firestore.collection('teams').doc(teamId).get();
          
          if (teamSnapshot.exists) {
            developer.log('Team data found');
            final teamData = teamSnapshot.data() as Map<String, dynamic>;
            
            // Check if team is registered
            if (teamData['isRegistered'] != true) {
              developer.log('Team not registered');
              continue;
            }
            
            final team = Team.fromJson(teamData);
            
            // Explicitly log user role for debugging
            developer.log('Login successful with role: $userRole');
            
            return {
              'success': true,
              'team': team,
              'userRole': userRole,
              'userName': memberData['name'],
              'message': 'Login successful as $userRole',
            };
          }
        }
        
        // If we got here, we found matches but none worked
        return {
          'success': false,
          'message': 'Invalid credentials or unregistered account',
        };
      }
      
      // If username not found directly, try fuzzy matching for leaders
      developer.log('Username not found directly, checking for leader with fuzzy match');
      final leadersQuery = await _firestore
          .collection('members')
          .where('role', isEqualTo: 'leader')
          .get();
          
      for (var doc in leadersQuery.docs) {
        final data = doc.data();
        final storedUsername = data['username'] as String? ?? '';
        
        // Check if the stored username contains the input or vice versa
        if (storedUsername.contains(username) || username.contains(storedUsername)) {
          developer.log('Found potential leader match: $storedUsername');
          
          // Verify password
          if (data['password'] == password) {
            developer.log('Password verification successful for leader match');
            
            final teamId = data['teamId'];
            
            // Get team data
            developer.log('Retrieving team data for leader');
            final teamSnapshot = await _firestore.collection('teams').doc(teamId).get();
            
            if (teamSnapshot.exists) {
              developer.log('Team data found');
              final teamData = teamSnapshot.data() as Map<String, dynamic>;
              
              final team = Team.fromJson(teamData);
              return {
                'success': true,
                'team': team,
                'userRole': 'leader',
                'userName': data['name'],
                'message': 'Leader login successful',
              };
            }
          }
        }
      }
      
      // If not found yet, try Firebase auth + email lookup
      // Create email from username for Firebase Auth
      final email = '$username@hackathon.app';
      developer.log('Not found by username query, trying Firebase Auth with email: $email');
      
      try {
        // Attempt to login with Firebase Auth
        await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        
        // Check if this is a member login by email document ID
        developer.log('Firebase Auth successful, checking document by email ID');
        final memberDoc = await _firestore.collection('members').doc(email).get();
        
        if (memberDoc.exists) {
          developer.log('Member found by email document ID');
          final memberData = memberDoc.data() as Map<String, dynamic>;
          
          // Check if registered
          if (memberData['isRegistered'] != true) {
            developer.log('Account not registered');
            await _auth.signOut();
            return {
              'success': false,
              'message': 'This account has not been properly registered',
            };
          }
          
          final teamId = memberData['teamId'];
          
          // Get team data
          developer.log('Retrieving team data for member');
          final teamSnapshot = await _firestore.collection('teams').doc(teamId).get();
          
          if (teamSnapshot.exists) {
            developer.log('Team data found');
            final teamData = teamSnapshot.data() as Map<String, dynamic>;
            
            // Check if team is registered
            if (teamData['isRegistered'] != true) {
              developer.log('Team not registered');
              await _auth.signOut();
              return {
                'success': false,
                'message': 'This team has not been properly registered',
              };
            }
            
            final team = Team.fromJson(teamData);
            return {
              'success': true,
              'team': team,
              'userRole': memberData['role'],
              'userName': memberData['name'],
              'message': 'Login successful',
            };
          } else {
            developer.log('Team not found');
            await _auth.signOut();
          }
        } else {
          developer.log('No member document found by email ID');
          await _auth.signOut();
        }
      } on FirebaseAuthException catch (e) {
        developer.log('Firebase Auth Error: ${e.code} - ${e.message}');
      }
      
      // No matching account found
      developer.log('No matching account found');
      await _auth.signOut();
      return {
        'success': false,
        'message': 'Account not found or invalid credentials',
      };
    } catch (e) {
      developer.log('Unexpected Error: $e');
      return {
        'success': false,
        'message': 'An unexpected error occurred: $e',
      };
    }
  }
  
  // Verify team using QR code
  Future<Map<String, dynamic>> verifyTeam(String teamId) async {
    try {
      developer.log('Verifying team: $teamId');
      
      // First check if the team exists
      final teamDoc = await _firestore.collection('teams').doc(teamId).get();
      
      if (!teamDoc.exists) {
        developer.log('Team not found with ID: $teamId');
        return {
          'success': false,
          'message': 'Team not found',
        };
      }
      
      // Update team verification status
      await _firestore.collection('teams').doc(teamId).update({
        'isVerified': true,
        'verifiedAt': FieldValue.serverTimestamp(),
      });
      
      // Get the updated team data
      final updatedTeamDoc = await _firestore.collection('teams').doc(teamId).get();
      final teamData = updatedTeamDoc.data() as Map<String, dynamic>;
      
      // Create a Team object
      final team = Team.fromJson(teamData);
      
      developer.log('Team verification successful');
      return {
        'success': true,
        'message': 'Team verified successfully',
        'team': team,
      };
    } catch (e) {
      developer.log('Error verifying team: $e');
      return {
        'success': false,
        'message': 'An error occurred during verification: $e',
      };
    }
  }
  
  // Sign out
  Future<void> signOut() async {
    developer.log('Signing out user');
    await _auth.signOut();
  }
  
  // Get current team
  Future<Team?> getCurrentTeam() async {
    try {
      final user = _auth.currentUser;
      
      if (user != null) {
        developer.log('Current user found: ${user.email}');
        final email = user.email;
        
        if (email != null) {
          // Try to get user by email document ID
          developer.log('Checking for member by email document ID');
          final memberDoc = await _firestore.collection('members').doc(email).get();
          
          if (memberDoc.exists) {
            developer.log('Member account found by email');
            final memberData = memberDoc.data() as Map<String, dynamic>;
            final teamId = memberData['teamId'];
            
            // Get team data
            developer.log('Retrieving team data for member');
            final teamSnapshot = await _firestore.collection('teams').doc(teamId).get();
            if (teamSnapshot.exists) {
              developer.log('Team data found');
              return Team.fromJson(teamSnapshot.data() as Map<String, dynamic>);
            }
          }
          
          // If not found by email, try to query by username (for team leaders)
          final username = email.split('@')[0];
          developer.log('Checking for leader by username: $username');
          
          final leaderQuery = await _firestore
              .collection('members')
              .where('username', isEqualTo: username)
              .where('role', isEqualTo: 'leader')
              .limit(1)
              .get();
              
          if (leaderQuery.docs.isNotEmpty) {
            developer.log('Leader account found by username');
            final leaderData = leaderQuery.docs.first.data();
            final teamId = leaderData['teamId'];
            
            // Get team data
            developer.log('Retrieving team data for leader');
            final teamSnapshot = await _firestore.collection('teams').doc(teamId).get();
            if (teamSnapshot.exists) {
              developer.log('Team data found');
              return Team.fromJson(teamSnapshot.data() as Map<String, dynamic>);
            }
          }
        }
      }
      
      developer.log('No current user or team found');
      return null;
    } catch (e) {
      developer.log('Error getting current team: $e');
      return null;
    }
  }
  
  // Verify meal QR code
  Future<Map<String, dynamic>> verifyMealQRCode(String qrCode, String mealType) async {
    try {
      developer.log('Verifying meal QR code: $qrCode for meal: $mealType');
      
      // Validate meal type
      if (!['breakfast', 'lunch', 'dinner'].contains(mealType)) {
        return {
          'success': false,
          'message': 'Invalid meal type. Must be breakfast, lunch, or dinner.',
        };
      }
      
      // Query members collection for the matching QR code
      final memberQuery = await _firestore
          .collection('members')
          .where('mealQRCode', isEqualTo: qrCode)
          .limit(1)
          .get();
      
      if (memberQuery.docs.isEmpty) {
        return {
          'success': false,
          'message': 'Invalid QR code. Member not found.',
        };
      }
      
      // Get member data
      final memberDoc = memberQuery.docs.first;
      final memberData = memberDoc.data();
      final memberName = memberData['name'] ?? 'Unknown Member';
      final teamName = memberData['teamName'] ?? 'Unknown Team';
      
      // Check if member has meal tracking data
      if (!memberData.containsKey('meals') || memberData['meals'] == null) {
        // Initialize meal tracking if it doesn't exist
        await memberDoc.reference.update({
          'meals': _initializeMealTracking(),
        });
        
        return {
          'success': false,
          'message': 'Meal tracking data was missing. Please try again.',
        };
      }
      
      // Get meal tracking data
      final meals = memberData['meals'] as Map<String, dynamic>;
      
      // Check if meal data exists for the specified meal type
      if (!meals.containsKey(mealType)) {
        return {
          'success': false,
          'message': 'Meal data not found for $mealType.',
        };
      }
      
      final mealData = meals[mealType] as Map<String, dynamic>;
      
      // Check if meal has already been served
      final bool alreadyServed = mealData['served'] ?? false;
      
      // Get current time
      final now = DateTime.now();
      
      // Check if current time is within allowed meal time
      final allowedStartTime = (mealData['allowedStartTime'] as Timestamp).toDate();
      final allowedEndTime = (mealData['allowedEndTime'] as Timestamp).toDate();
      
      // Add a temporary override for testing - always allow breakfast during development
      bool isWithinMealTime = now.isAfter(allowedStartTime) && now.isBefore(allowedEndTime);
      
      // TESTING OVERRIDE: Always allow breakfast meal regardless of time for testing
      if (mealType == 'breakfast') {
        isWithinMealTime = true;
        developer.log('TESTING: Overriding meal time restrictions for breakfast');
      }
      
      if (!isWithinMealTime) {
        return {
          'success': false,
          'message': '$mealType is not being served at this time.',
          'memberName': memberName,
          'teamName': teamName,
          'alreadyServed': alreadyServed,
        };
      }
      
      // If already served, return success but indicate it's a duplicate
      if (alreadyServed) {
        final servedAt = (mealData['servedAt'] as Timestamp).toDate();
        return {
          'success': true,
          'message': '$memberName has already been served $mealType at ${_formatTime(servedAt)}.',
          'memberName': memberName,
          'teamName': teamName,
          'alreadyServed': true,
          'servedAt': servedAt,
        };
      }
      
      // Update the meal status
      final updatedMeals = Map<String, dynamic>.from(meals);
      final updatedMealData = Map<String, dynamic>.from(updatedMeals[mealType] as Map<String, dynamic>);
      
      updatedMealData['served'] = true;
      updatedMealData['servedAt'] = FieldValue.serverTimestamp();
      
      updatedMeals[mealType] = updatedMealData;
      
      // Update the document
      await memberDoc.reference.update({
        'meals': updatedMeals,
      });
      
      return {
        'success': true,
        'message': '$mealType served to $memberName successfully.',
        'memberName': memberName,
        'teamName': teamName,
        'alreadyServed': false,
      };
    } catch (e) {
      developer.log('Error verifying meal QR code: $e');
      return {
        'success': false,
        'message': 'An error occurred: $e',
      };
    }
  }
  
  // Get member meal status
  Future<Map<String, dynamic>> getMemberMealStatus(String email) async {
    try {
      developer.log('Getting meal status for member: $email');
      
      // Check if we're using a Firebase Auth email (@hackathon.app)
      if (email.endsWith('@hackathon.app')) {
        // Try to find the member by username first
        final username = email.split('@')[0];
        developer.log('Using username to find member: $username');
        
        final memberQuery = await _firestore
            .collection('members')
            .where('username', isEqualTo: username)
            .limit(1)
            .get();
            
        if (memberQuery.docs.isNotEmpty) {
          final memberData = memberQuery.docs.first.data();
          
          // Check if member has meal tracking data
          if (!memberData.containsKey('meals') || memberData['meals'] == null) {
            // Initialize meal tracking if it doesn't exist
            final mealTracking = _initializeMealTracking();
            await memberQuery.docs.first.reference.update({
              'meals': mealTracking,
            });
            
            return {
              'success': true,
              'mealQRCode': memberData['mealQRCode'] ?? '',
              'meals': mealTracking,
              'name': memberData['name'] ?? 'Unknown',
            };
          }
          
          // Return meal status
          return {
            'success': true,
            'mealQRCode': memberData['mealQRCode'] ?? '',
            'meals': memberData['meals'],
            'name': memberData['name'] ?? 'Unknown',
          };
        }
      }
      
      // If not found by username or not a hackathon.app email, try the original approach
      // Get member document by email directly
      final memberDoc = await _firestore.collection('members').doc(email).get();
      
      if (!memberDoc.exists) {
        return {
          'success': false,
          'message': 'Member not found. Please make sure you are logged in with a team member account.',
        };
      }
      
      final memberData = memberDoc.data() as Map<String, dynamic>;
      
      // Check if member has meal tracking data
      if (!memberData.containsKey('meals') || memberData['meals'] == null) {
        // Initialize meal tracking if it doesn't exist
        final mealTracking = _initializeMealTracking();
        await memberDoc.reference.update({
          'meals': mealTracking,
        });
        
        return {
          'success': true,
          'mealQRCode': memberData['mealQRCode'] ?? '',
          'meals': mealTracking,
          'name': memberData['name'] ?? 'Unknown',
        };
      }
      
      // Return meal status
      return {
        'success': true,
        'mealQRCode': memberData['mealQRCode'] ?? '',
        'meals': memberData['meals'],
        'name': memberData['name'] ?? 'Unknown',
      };
    } catch (e) {
      developer.log('Error getting member meal status: $e');
      return {
        'success': false,
        'message': 'An error occurred: $e',
      };
    }
  }
  
  // Format time for display
  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }
}