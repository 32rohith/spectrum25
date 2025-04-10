import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

class OCService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get all teams with their verification status
  Stream<List<DocumentSnapshot>> getTeamsStream() {
    return _firestore
        .collection('teams')
        .orderBy('teamName')
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  // Send food QR code via email
  Future<void> sendFoodQREmail(String teamId, String foodQRCode) async {
    try {
      // Get team data
      final teamDoc = await _firestore.collection('teams').doc(teamId).get();
      final teamData = teamDoc.data();
      if (teamData == null) throw 'Team not found';

      // Get leader's email
      final leaderDoc = await _firestore
          .collection('users')
          .where('teamId', isEqualTo: teamId)
          .where('isLeader', isEqualTo: true)
          .get();

      if (leaderDoc.docs.isEmpty) throw 'Team leader not found';
      final leaderEmail = leaderDoc.docs.first.data()['email'];

      // Create email content
      final emailSubject = 'Food QR Code - ${teamData['teamName']}';
      final emailBody = 'Here is your food QR code: $foodQRCode';
      
      // Launch email client
      final emailUrl = Uri.parse(
        'mailto:$leaderEmail?subject=${Uri.encodeComponent(emailSubject)}&body=${Uri.encodeComponent(emailBody)}',
      );

      if (!await url_launcher.canLaunchUrl(emailUrl)) {
        throw 'Could not launch email client';
      }
      
      await url_launcher.launchUrl(emailUrl);

      // Update team document to mark QR code as sent
      await _firestore.collection('teams').doc(teamId).update({
        'foodQRSent': true,
        'foodQRSentAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Failed to send food QR code: $e';
    }
  }

  // Check if user is OC member
  Future<bool> isOCMember() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      final userDoc = await _firestore.collection('users').doc(userId).get();
      return userDoc.data()?['isOC'] == true;
    } catch (e) {
      return false;
    }
  }

  // Get team verification status
  Future<Map<String, dynamic>> getTeamStatus(String teamId) async {
    try {
      final teamDoc = await _firestore.collection('teams').doc(teamId).get();
      final teamData = teamDoc.data();
      if (teamData == null) throw 'Team not found';

      return {
        'teamName': teamData['teamName'],
        'leaderVerified': teamData['leaderVerified'] ?? false,
        'foodQRSent': teamData['foodQRSent'] ?? false,
        'verifiedAt': teamData['verifiedAt'],
        'foodQRSentAt': teamData['foodQRSentAt'],
      };
    } catch (e) {
      throw 'Failed to get team status: $e';
    }
  }
} 