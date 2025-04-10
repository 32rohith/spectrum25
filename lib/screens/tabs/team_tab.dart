import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/team_member_credentials.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class TeamTab extends StatefulWidget {
  const TeamTab({super.key});

  @override
  State<TeamTab> createState() => _TeamTabState();
}

class _TeamTabState extends State<TeamTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  List<TeamMemberCredentials> _teamMembers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTeamMembers();
  }

  Future<void> _loadTeamMembers() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final userId = _authService.getCurrentUserId();
      if (userId == null) throw 'User not authenticated';

      // Get the current user's team ID from their user document
      final user = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      
      final teamId = user.data()?['teamId'];
      if (teamId == null) throw 'Team not found';

      // Get all members' credentials for this team
      final membersAuth = await _firestore
          .collection('membersAuth')
          .where('teamId', isEqualTo: teamId)
          .get();

      _teamMembers = membersAuth.docs
          .map((doc) => TeamMemberCredentials.fromMap(doc.data()))
          .toList();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to load team members: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(
        title: 'Team Details',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: TextStyle(color: AppTheme.textPrimaryColor),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Team Members',
                        style: TextStyle(
                          color: AppTheme.textPrimaryColor,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._teamMembers.map((member) => _buildMemberCard(member)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildMemberCard(TeamMemberCredentials member) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: member.isLeader ? Colors.amber : Colors.grey[700]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                member.name,
                style: TextStyle(
                  color: AppTheme.textPrimaryColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (member.isLeader) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.star,
                  color: Colors.amber,
                  size: 20,
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          _buildCredentialRow('Username', member.username),
          const SizedBox(height: 8),
          _buildCredentialRow('Password', member.password),
        ],
      ),
    );
  }

  Widget _buildCredentialRow(String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            color: AppTheme.textSecondaryColor,
            fontSize: 16,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: AppTheme.textPrimaryColor,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
} 