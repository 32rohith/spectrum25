import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/team.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class TeamDetailsTab extends StatefulWidget {
  final Team team;

  const TeamDetailsTab({
    super.key,
    required this.team,
  });

  @override
  State<TeamDetailsTab> createState() => _TeamDetailsTabState();
}

class _TeamDetailsTabState extends State<TeamDetailsTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  bool _showPasswords = false;
  Map<String, dynamic>? _leaderAuth;
  List<Map<String, dynamic>> _membersAuth = [];

  @override
  void initState() {
    super.initState();
    _fetchCredentials();
  }

  Future<void> _fetchCredentials() async {
    try {
      // Get credentials info from team document
      final teamDoc = await _firestore.collection('teams').doc(widget.team.teamId).get();
      if (teamDoc.exists) {
        final data = teamDoc.data();
        setState(() {
          _leaderAuth = data?['leaderAuth'] as Map<String, dynamic>? ?? {};
          _membersAuth = List<Map<String, dynamic>>.from(data?['membersAuth'] ?? []);
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching credentials: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _copyToClipboard(BuildContext context, String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.accentColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
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
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Team Info Card
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.groups,
                                color: AppTheme.primaryColor,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.team.teamName,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimaryColor,
                                  ),
                                ),
                                Text(
                                  '${widget.team.members.length + 1} Members',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.textSecondaryColor,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            // Password toggle button
                            IconButton(
                              icon: Icon(
                                _showPasswords ? Icons.visibility_off : Icons.visibility,
                                color: AppTheme.accentColor,
                              ),
                              onPressed: () {
                                setState(() {
                                  _showPasswords = !_showPasswords;
                                });
                              },
                              tooltip: _showPasswords ? 'Hide Passwords' : 'Show Passwords',
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Team Leader Section
                  Text(
                    'Team Leader',
                    style: TextStyle(
                      color: AppTheme.textPrimaryColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Team Leader Card
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.accentColor.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.star,
                                color: AppTheme.accentColor,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.team.leader.name,
                                    style: TextStyle(
                                      color: AppTheme.textPrimaryColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Leader',
                                    style: TextStyle(
                                      color: AppTheme.accentColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Leader credentials grid
                        _buildCredentialsGrid(
                          username: _leaderAuth != null && _leaderAuth!.containsKey('username') 
                              ? _leaderAuth!['username'] 
                              : 'Not available',
                          password: _leaderAuth != null && _leaderAuth!.containsKey('password')
                              ? _leaderAuth!['password']
                              : 'Not available',
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Team Members Section
                  Text(
                    'Team Members',
                    style: TextStyle(
                      color: AppTheme.textPrimaryColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Team Members Cards
                  ...widget.team.members.asMap().entries.map((entry) {
                    final index = entry.key;
                    final member = entry.value;
                    
                    // Find matching member auth data
                    Map<String, dynamic>? memberAuth;
                    if (index < _membersAuth.length) {
                      memberAuth = _membersAuth.firstWhere(
                        (auth) => auth['name'] == member.name,
                        orElse: () => _membersAuth[index],
                      );
                    }
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: _buildMemberCard(
                        member, 
                        memberAuth != null ? memberAuth['username'] : 'Not available',
                        memberAuth != null ? memberAuth['password'] : 'Not available',
                      ),
                    );
                  }),
                  
                  const SizedBox(height: 24),
                  
                  // Project Status
                  widget.team.projectSubmissionUrl != null
                      ? _buildProjectSubmittedCard()
                      : _buildNoProjectCard(),
                      
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }
  
  Widget _buildCredentialsGrid({
    required String username,
    required String password,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Username row
          Row(
            children: [
              Icon(
                Icons.alternate_email,
                color: AppTheme.textSecondaryColor,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Username:',
                style: TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  username,
                  style: TextStyle(
                    color: AppTheme.textPrimaryColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.copy,
                  color: AppTheme.accentColor,
                  size: 16,
                ),
                onPressed: () => _copyToClipboard(
                  context,
                  username,
                  'Username copied to clipboard',
                ),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Password row
          Row(
            children: [
              Icon(
                Icons.vpn_key,
                color: AppTheme.textSecondaryColor,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Password:',
                style: TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _showPasswords ? password : '••••••••••',
                  style: TextStyle(
                    color: AppTheme.textPrimaryColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.copy,
                  color: AppTheme.accentColor,
                  size: 16,
                ),
                onPressed: () => _copyToClipboard(
                  context,
                  password,
                  'Password copied to clipboard',
                ),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildMemberCard(TeamMember member, String username, String password) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  member.name,
                  style: TextStyle(
                    color: AppTheme.textPrimaryColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Member credentials grid
          _buildCredentialsGrid(
            username: username,
            password: password,
          ),
        ],
      ),
    );
  }
  
  Widget _buildProjectSubmittedCard() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Project Submitted',
                      style: TextStyle(
                        color: AppTheme.textPrimaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your team has submitted the project',
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              // Open project URL
            },
            style: TextButton.styleFrom(
              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.link,
                  color: AppTheme.primaryColor,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'View Project',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildNoProjectCard() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.info_outline,
                  color: Colors.orange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No Project Submitted',
                      style: TextStyle(
                        color: AppTheme.textPrimaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your team has not submitted a project yet',
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
} 