import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/leaderboard_entry.dart';

class LeaderboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'leaderboard';

  // Stream of top 10 teams
  Stream<List<LeaderboardEntry>> getTopTeams() {
    return _firestore
        .collection(_collection)
        .orderBy('score', descending: true)
        .limit(10)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.asMap().entries.map((entry) {
        final data = entry.value.data();
        return LeaderboardEntry.fromMap({
          ...data,
          'rank': entry.key + 1, // Add rank based on position
        });
      }).toList();
    });
  }

  // Update team score
  Future<void> updateTeamScore(String teamName, int score) async {
    await _firestore.collection(_collection).doc(teamName).set({
      'teamName': teamName,
      'score': score,
    }, SetOptions(merge: true));
  }
} 