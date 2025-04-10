import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/team.dart';
import 'dart:developer' as developer;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Generate a unique username and password
  Map<String, String> _generateCredentials(String prefix) {
    final random = Random();
    final username = '${prefix.toLowerCase().replaceAll(' ', '')}_${random.nextInt(10000)}';
    final password = 'Pass${random.nextInt(10000)}'; // Simple password format with random number
    
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
      final teamCredentials = _generateCredentials(teamName);
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
      
      // Generate leader credentials
      final leaderCredentials = _generateCredentials(leader.name);
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
        
        // Generate member credentials
        final memberCredentials = _generateCredentials(member.name);
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
          'username': teamUsername,
          'password': teamPassword,
        },
        'leaderAuth': {
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
      
      // Create email from username for Firebase Auth
      final email = '$username@hackathon.app';
      
      try {
        // Attempt to login with Firebase Auth
        developer.log('Authenticating with Firebase');
        await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        
        // Check if this is a member or leader login
        developer.log('Checking if member/leader login');
        final memberDoc = await _firestore.collection('members').doc(email).get();
        
        if (memberDoc.exists) {
          final memberData = memberDoc.data() as Map<String, dynamic>;
          
          // Check if registered
          if (memberData['isRegistered'] != true) {
            await _auth.signOut();
            return {
              'success': false,
              'message': 'This account has not been properly registered',
            };
          }
          
          final teamId = memberData['teamId'];
          
          // Get team data
          developer.log('Retrieving team data for member/leader');
          final teamSnapshot = await _firestore.collection('teams').doc(teamId).get();
          
          if (teamSnapshot.exists) {
            developer.log('Team data found');
            final teamData = teamSnapshot.data() as Map<String, dynamic>;
            
            // Check if team is registered
            if (teamData['isRegistered'] != true) {
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
          }
        }
        
        // No matching account found
        developer.log('No matching account found');
        await _auth.signOut();
        return {
          'success': false,
          'message': 'Account not found or invalid credentials',
        };
      } on FirebaseAuthException catch (e) {
        developer.log('Firebase Auth Error during login: ${e.code} - ${e.message}');
        
        if (e.code == 'user-not-found' || e.code == 'wrong-password') {
          return {
            'success': false,
            'message': 'Invalid username or password',
          };
        }
        
        return {
          'success': false,
          'message': e.message ?? 'Authentication failed',
        };
      }
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
      
      // Update team verification status
      await _firestore.collection('teams').doc(teamId).update({
        'isVerified': true,
      });
      
      developer.log('Team verification successful');
      return {
        'success': true,
        'message': 'Team verified successfully',
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
        
        // Check if this is a member login
        if (email != null) {
          developer.log('Checking if member account');
          final memberDoc = await _firestore.collection('members').doc(email).get();
          if (memberDoc.exists) {
            developer.log('Member account found');
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