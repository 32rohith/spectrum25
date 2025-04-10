import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class QRService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> handleQRScan(String teamId) async {
    try {
      // Get the current user's document
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw 'User not authenticated';

      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();
      
      if (userData == null) throw 'User data not found';
      
      // Only update verification if the user is the team leader
      if (userData['isLeader'] == true) {
        await _firestore.collection('teams').doc(teamId).update({
          'leaderVerified': true,
          'verifiedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      throw 'Failed to process QR scan: $e';
    }
  }
} 