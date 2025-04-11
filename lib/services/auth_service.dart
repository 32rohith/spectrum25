import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/team.dart';
import 'dart:developer' as developer;

// Extension to capitalize the first letter of a string
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Shared Preferences Keys
  static const String _userIdKey = 'user_id';
  static const String _userEmailKey = 'user_email';
  static const String _userPasswordKey = 'user_password';
  static const String _userRoleKey = 'user_role';
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _isOCMemberKey = 'is_oc_member';
  static const String _ocNameKey = 'oc_name';
  static const String _ocPhoneKey = 'oc_phone';
  
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
  
  // Register a new team with team leader and members
  Future<Map<String, dynamic>> registerTeam({
    required String teamName,
    required TeamMember leader,
    required List<TeamMember> members,
  }) async {
    try {
      developer.log('Starting team registration process for: $teamName');
      
      // Check if a team with this name already exists but is not verified
      developer.log('Checking if team already exists: $teamName');
      final existingTeamQuery = await _firestore
          .collection('teams')
          .where('teamName', isEqualTo: teamName)
          .get();
      
      // If team exists, check verification status
      if (existingTeamQuery.docs.isNotEmpty) {
        final existingTeamData = existingTeamQuery.docs.first.data();
        final existingTeamId = existingTeamQuery.docs.first.id;
        final bool isVerified = existingTeamData['isVerified'] ?? false;
        
        developer.log('Found existing team: $teamName, verified: $isVerified');
        
        // If team exists but is not verified, return only the credentials
        if (!isVerified) {
          developer.log('Team exists but is not verified, returning credentials only');
          
          // Get existing team credentials
          final existingUsername = existingTeamData['username'] as String;
          final existingPassword = existingTeamData['password'] as String;
          
          // Get leader auth details
          final leaderAuthData = existingTeamData['leaderAuth'] as Map<String, dynamic>;
          final leaderUsername = leaderAuthData['username'] as String;
          final leaderPassword = leaderAuthData['password'] as String;
          
          // Create team object from existing data
          final team = Team.fromJson(existingTeamData);
          
          return {
            'success': true,
            'team': team,
            'message': 'Team already registered but not verified. Please use these credentials.',
            'teamAuth': {
              'username': existingUsername,
              'password': existingPassword,
            },
            'leaderAuth': {
              'username': leaderUsername,
              'password': leaderPassword,
            },
          };
        }
      }
      
      // If team doesn't exist or is already verified, proceed with normal registration
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
      await _auth.createUserWithEmailAndPassword(
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
        await _auth.createUserWithEmailAndPassword(
          email: memberEmail,
          password: memberPassword,
        );
        
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
      // Ensure any previous session is cleared first
      await signOut();
      
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
          developer.log('Retrieving team data for $userRole with teamId: $teamId');
          final teamSnapshot = await _firestore.collection('teams').doc(teamId).get();
          
          if (teamSnapshot.exists) {
            developer.log('Team data found for team: ${teamSnapshot.id}');
            final teamData = teamSnapshot.data() as Map<String, dynamic>;
            
            // Check if team is registered
            if (teamData['isRegistered'] != true) {
              developer.log('Team not registered');
              continue;
            }
            
            // Create Firebase Auth session for this user
            final userEmail = memberData['email'] as String;
            developer.log('Setting up Firebase Auth session for: $userEmail');
            
            try {
              // Log in with Firebase Auth to establish the session
              await _auth.signInWithEmailAndPassword(
                email: userEmail,
                password: memberData['password'] as String,
              );
              developer.log('Firebase Auth session established for: ${_auth.currentUser?.email}');
              
              // Save login credentials for persistent login
              await _saveLoginCredentials(
                userId: memberDoc.id,
                userEmail: userEmail,
                password: memberData['password'] as String,
                userRole: userRole,
              );
            } catch (authError) {
              developer.log('Failed to establish Firebase Auth session: $authError');
              // Continue with Firestore data anyway since we've verified credentials
            }
            
            final team = Team.fromJson(teamData);
            
            // Explicitly log user role for debugging
            developer.log('Login successful with role: $userRole');
            developer.log('Loaded user data: ${memberData['name']} (${memberData['email']}) from ${teamData['teamName']}');
            
            return {
              'success': true,
              'team': team,
              'userRole': userRole,
              'userId': memberDoc.id,
              'userName': memberData['name'],
              'userEmail': memberData['email'],
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
        
        developer.log('Firebase Auth successful, checking document by email ID: $email');
        
        // Check if this is a member login by email document ID
        final memberDoc = await _firestore.collection('members').doc(email).get();
        
        if (memberDoc.exists) {
          developer.log('Member found by email document ID: ${memberDoc.id}');
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
          developer.log('Retrieving team data for member with teamId: $teamId');
          final teamSnapshot = await _firestore.collection('teams').doc(teamId).get();
          
          if (teamSnapshot.exists) {
            developer.log('Team data found for team: ${teamSnapshot.id}');
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
            
            // Save login credentials for persistent login
            await _saveLoginCredentials(
              userId: memberDoc.id,
              userEmail: email,
              password: password,
              userRole: memberData['role'],
            );
            
            final team = Team.fromJson(teamData);
            
            developer.log('Loaded user data: ${memberData['name']} (${memberData['email']}) from ${teamData['teamName']}');
            
            return {
              'success': true,
              'team': team,
              'userRole': memberData['role'],
              'userId': memberDoc.id,
              'userName': memberData['name'],
              'userEmail': memberData['email'],
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
      await _auth.signOut();
      return {
        'success': false,
        'message': 'An unexpected error occurred: $e',
      };
    }
  }
  
  // Save login credentials for persistent login
  Future<void> _saveLoginCredentials({
    required String userId,
    required String userEmail,
    required String password,
    required String userRole,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userIdKey, userId);
      await prefs.setString(_userEmailKey, userEmail);
      await prefs.setString(_userPasswordKey, password);
      await prefs.setString(_userRoleKey, userRole);
      await prefs.setBool(_isLoggedInKey, true);
      
      developer.log('Saved login credentials for persistent login');
    } catch (e) {
      developer.log('Error saving login credentials: $e');
    }
  }
  
  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_isLoggedInKey) ?? false;
    } catch (e) {
      developer.log('Error checking login status: $e');
      return false;
    }
  }
  
  // Try to login with saved credentials
  Future<Map<String, dynamic>> loginWithSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;
      
      if (!isLoggedIn) {
        developer.log('No saved login credentials found');
        return {
          'success': false,
          'message': 'No saved login credentials found',
        };
      }
      
      final userEmail = prefs.getString(_userEmailKey);
      final password = prefs.getString(_userPasswordKey);
      
      if (userEmail == null || password == null) {
        developer.log('Incomplete saved login credentials');
        return {
          'success': false,
          'message': 'Incomplete saved login credentials',
        };
      }
      
      // Try to login with Firebase Auth first
      try {
        await _auth.signInWithEmailAndPassword(
          email: userEmail,
          password: password,
        );
        
        developer.log('Firebase Auth successful with saved credentials for: $userEmail');
        
        // Get member data
        final memberDoc = await _firestore.collection('members').doc(userEmail).get();
        
        if (memberDoc.exists) {
          developer.log('Member found by email document ID: ${memberDoc.id}');
          final memberData = memberDoc.data() as Map<String, dynamic>;
          
          // Check if registered
          if (memberData['isRegistered'] != true) {
            developer.log('Account not registered');
            await signOut();
            return {
              'success': false,
              'message': 'This account has not been properly registered',
            };
          }
          
          final teamId = memberData['teamId'];
          
          // Get team data
          developer.log('Retrieving team data for member with teamId: $teamId');
          final teamSnapshot = await _firestore.collection('teams').doc(teamId).get();
          
          if (teamSnapshot.exists) {
            developer.log('Team data found for team: ${teamSnapshot.id}');
            final teamData = teamSnapshot.data() as Map<String, dynamic>;
            
            // Check if team is registered
            if (teamData['isRegistered'] != true) {
              developer.log('Team not registered');
              await signOut();
              return {
                'success': false,
                'message': 'This team has not been properly registered',
              };
            }
            
            final team = Team.fromJson(teamData);
            final userRole = memberData['role'] as String? ?? '';
            
            developer.log('Successfully logged in with saved credentials');
            developer.log('Loaded user data: ${memberData['name']} (${memberData['email']}) from ${teamData['teamName']}');
            
            return {
              'success': true,
              'team': team,
              'userRole': userRole,
              'userId': memberDoc.id,
              'userName': memberData['name'],
              'userEmail': memberData['email'],
              'message': 'Login successful with saved credentials',
            };
          }
        }
      } catch (e) {
        developer.log('Error logging in with saved credentials: $e');
      }
      
      // If we got here, something went wrong with the saved credentials
      await clearSavedCredentials();
      return {
        'success': false,
        'message': 'Failed to login with saved credentials',
      };
    } catch (e) {
      developer.log('Unexpected error during saved credentials login: $e');
      return {
        'success': false,
        'message': 'An unexpected error occurred',
      };
    }
  }
  
  // Clear saved credentials
  Future<void> clearSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userIdKey);
      await prefs.remove(_userEmailKey);
      await prefs.remove(_userPasswordKey);
      await prefs.remove(_userRoleKey);
      await prefs.remove(_isLoggedInKey);
      await prefs.remove(_isOCMemberKey);
      await prefs.remove(_ocNameKey);
      await prefs.remove(_ocPhoneKey);
      
      developer.log('Cleared saved login credentials');
    } catch (e) {
      developer.log('Error clearing saved credentials: $e');
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
      
      // Also update verification status for all team members
      developer.log('Updating verification status for team members');
      
      // Get team leader email
      final leaderAuth = teamData['leaderAuth'] as Map<String, dynamic>?;
      if (leaderAuth != null && leaderAuth.containsKey('username')) {
        final leaderUsername = leaderAuth['username'] as String;
        final leaderEmail = '$leaderUsername@hackathon.app';
        
        // Update leader verification status
        await _firestore.collection('members').doc(leaderEmail).update({
          'isVerified': true,
        });
        developer.log('Updated leader verification status');
      }
      
      // Get team members emails and update their verification status
      final membersAuth = teamData['membersAuth'] as List<dynamic>?;
      if (membersAuth != null) {
        for (var memberAuth in membersAuth) {
          if (memberAuth is Map<String, dynamic> && memberAuth.containsKey('username')) {
            final memberUsername = memberAuth['username'] as String;
            final memberEmail = '$memberUsername@hackathon.app';
            
            // Update member verification status
            await _firestore.collection('members').doc(memberEmail).update({
              'isVerified': true,
            });
          }
        }
        developer.log('Updated all team members verification status');
      }
      
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
    await clearSavedCredentials();
  }
  
  // Get current Firebase user
  Future<User?> getCurrentUser() async {
    return _auth.currentUser;
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

  // Get current user ID
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  // Login as OC member
  Future<Map<String, dynamic>> loginOCMember({
    required String name,
    required String phone,
    required bool isVerified,
  }) async {
    try {
      developer.log('OC member login for: $name');
      
      if (isVerified) {
        // Save OC member login credentials
        await _saveOCLoginCredentials(
          name: name,
          phone: phone,
        );
        
        return {
          'success': true,
          'message': 'OC login successful',
          'name': name,
        };
      } else {
        return {
          'success': false,
          'message': 'OC verification failed',
        };
      }
    } catch (e) {
      developer.log('Error during OC login: $e');
      return {
        'success': false,
        'message': 'An error occurred during OC login: $e',
      };
    }
  }
  
  // Save OC member login credentials
  Future<void> _saveOCLoginCredentials({
    required String name,
    required String phone,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_ocNameKey, name);
      await prefs.setString(_ocPhoneKey, phone);
      await prefs.setBool(_isOCMemberKey, true);
      await prefs.setBool(_isLoggedInKey, true);
      await prefs.setString(_userRoleKey, 'oc'); // Set role as 'oc'
      
      developer.log('Saved OC login credentials for persistent login');
    } catch (e) {
      developer.log('Error saving OC login credentials: $e');
    }
  }
  
  // Check if logged in as OC member
  Future<bool> isOCLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_isOCMemberKey) ?? false;
    } catch (e) {
      developer.log('Error checking OC login status: $e');
      return false;
    }
  }
  
  // Get OC member login info
  Future<Map<String, dynamic>> getOCLoginInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isOCMember = prefs.getBool(_isOCMemberKey) ?? false;
      
      if (!isOCMember) {
        return {
          'success': false,
          'message': 'Not logged in as OC member',
        };
      }
      
      final name = prefs.getString(_ocNameKey);
      final phone = prefs.getString(_ocPhoneKey);
      
      if (name == null || phone == null) {
        return {
          'success': false,
          'message': 'Incomplete OC login information',
        };
      }
      
      return {
        'success': true,
        'name': name,
        'phone': phone,
      };
    } catch (e) {
      developer.log('Error getting OC login info: $e');
      return {
        'success': false,
        'message': 'Error getting OC login info: $e',
      };
    }
  }
}