import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/auth_service.dart';

class ParticipantTeamsTab extends StatefulWidget {
  const ParticipantTeamsTab({super.key});

  @override
  _ParticipantTeamsTabState createState() => _ParticipantTeamsTabState();
}

class _ParticipantTeamsTabState extends State<ParticipantTeamsTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? _teamData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTeamData();
  }

  Future<void> _loadTeamData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get current user's email
      final authService = AuthService();
      final currentUser = await authService.getCurrentUser();
      final currentUserEmail = currentUser?.email;
      
      if (currentUserEmail == null) {
        throw Exception('User not logged in');
      }

      // First try to find the user in the members collection to get their credentials
      final memberDoc = await _firestore.collection('members').doc(currentUserEmail).get();
      
      if (memberDoc.exists) {
        final memberData = memberDoc.data() as Map<String, dynamic>;
        final teamId = memberData['teamId'];
        final userRole = memberData['role'];
        
        // Get team data
        final teamDoc = await _firestore.collection('teams').doc(teamId).get();
        if (teamDoc.exists) {
          final data = teamDoc.data() as Map<String, dynamic>;
          final leaderAuth = data['leaderAuth'] ?? {};
          final membersAuth = data['membersAuth'] ?? [];
          
          setState(() {
            _teamData = {
              'id': teamId,
              'name': data['teamName'] ?? data['name'] ?? 'Unknown Team',
              'leader': {
                ...data['leader'] ?? {},
                'username': userRole == 'leader' ? memberData['username'] : null,
                'password': userRole == 'leader' ? memberData['password'] : null,
              },
              'members': List.from(data['members'] ?? []).asMap().map((i, member) {
                final auth = membersAuth.firstWhere(
                  (auth) => auth['name'] == member['name'],
                  orElse: () => {},
                );
                return MapEntry(i, {
                  ...member,
                  'username': auth['username'],
                  'password': auth['password'],
                });
              }).values.toList(),
              'isLeader': userRole == 'leader',
            };
          });
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error loading team data: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'My Team',
            style: TextStyle(
              color: AppTheme.textPrimaryColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'View your team details and members',
            style: TextStyle(
              color: AppTheme.textSecondaryColor,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _error!,
                    style: TextStyle(color: AppTheme.errorColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadTeamData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentColor,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else if (_teamData == null)
            Center(
              child: Text(
                'No team found',
                style: TextStyle(color: AppTheme.textSecondaryColor),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _teamData!['name'],
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimaryColor,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Team Leader',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildMemberCard(_teamData!['leader'], isLeader: true),
                          const SizedBox(height: 16),
                          Text(
                            'Team Members',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._buildMembersList(_teamData!['members'] as List),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member, {bool isLeader = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isLeader ? Icons.star : Icons.person,
                    color: AppTheme.accentColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    member['name'] ?? 'Unknown',
                    style: TextStyle(
                      color: AppTheme.textPrimaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (member['username'] != null && member['password'] != null)
                Icon(
                  Icons.verified_user,
                  color: AppTheme.accentColor,
                  size: 20,
                ),
            ],
          ),
          if (member['username'] != null && member['password'] != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.accentColor.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Login Credentials',
                    style: TextStyle(
                      color: AppTheme.accentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        color: AppTheme.textSecondaryColor,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Username: ${member['username']}',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.key,
                        color: AppTheme.textSecondaryColor,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Password: ${member['password']}',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.email_outlined,
                color: AppTheme.textSecondaryColor,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                member['email'] ?? 'Not set',
                style: TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.phone_outlined,
                color: AppTheme.textSecondaryColor,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                member['phone'] ?? 'Not set',
                style: TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.devices,
                color: AppTheme.textSecondaryColor,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                member['device'] ?? 'Not set',
                style: TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMembersList(List members) {
    return members.map<Widget>((member) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _buildMemberCard(member),
      );
    }).toList();
  }
} 