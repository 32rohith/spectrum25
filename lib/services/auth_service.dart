import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
}