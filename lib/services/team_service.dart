import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;

class TeamService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Method to get all registered team names
  Future<List<String>> getAllTeamNames() async {
    try {
      // Get all documents from the teamNames collection
      final snapshot = await _firestore.collection('teamNames').get();
      
      // Extract the team names from the documents
      final teamNames = snapshot.docs.map((doc) {
        final data = doc.data();
        return data['name'] as String;
      }).toList();
      
      developer.log('Retrieved ${teamNames.length} team names from Firestore');
      return teamNames;
    } catch (e) {
      developer.log('Error retrieving team names: $e');
      return [];
    }
  }

  // Check if a team name exists in the teamNames collection
  Future<bool> teamNameExists(String teamName) async {
    try {
      if (teamName.trim().isEmpty) {
        return false;
      }

      // Normalize the team name by trimming spaces for comparison
      final normalizedTeamName = teamName.trim();
      
      // Query for exact match first (case-sensitive)
      final exactMatchQuery = await _firestore
          .collection('teamNames')
          .where('name', isEqualTo: normalizedTeamName)
          .limit(1)
          .get();
      
      if (exactMatchQuery.docs.isNotEmpty) {
        developer.log('Team found by exact name match: $teamName');
        return true;
      }
      
      // If no exact match, perform a case-insensitive search
      final allTeamNames = await getAllTeamNames();
      
      // Check for a case-insensitive match
      for (var name in allTeamNames) {
        if (name.toLowerCase() == normalizedTeamName.toLowerCase()) {
          developer.log('Team found by case-insensitive match: $teamName');
          return true;
        }
      }
      
      developer.log('Team not found in teamNames collection: $teamName');
      return false;
    } catch (e) {
      developer.log('Error checking team name existence: $e');
      return false;
    }
  }

  // Add a new team name to the collection (for admin use)
  Future<bool> addTeamName(String teamName) async {
    try {
      if (teamName.trim().isEmpty) {
        return false;
      }

      // Check if team name already exists
      final exists = await teamNameExists(teamName);
      if (exists) {
        developer.log('Team name already exists, not adding: $teamName');
        return false;
      }

      // Add the team name to the collection
      await _firestore.collection('teamNames').add({
        'name': teamName.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      developer.log('Added team name to collection: $teamName');
      return true;
    } catch (e) {
      developer.log('Error adding team name: $e');
      return false;
    }
  }

  // Remove a team name from the collection (for admin use)
  Future<bool> removeTeamName(String teamName) async {
    try {
      // Query for the team name
      final querySnapshot = await _firestore
          .collection('teamNames')
          .where('name', isEqualTo: teamName.trim())
          .get();
      
      if (querySnapshot.docs.isEmpty) {
        developer.log('Team name not found for removal: $teamName');
        return false;
      }
      
      // Delete all matching documents
      for (var doc in querySnapshot.docs) {
        await doc.reference.delete();
      }
      
      developer.log('Removed team name from collection: $teamName');
      return true;
    } catch (e) {
      developer.log('Error removing team name: $e');
      return false;
    }
  }
} 