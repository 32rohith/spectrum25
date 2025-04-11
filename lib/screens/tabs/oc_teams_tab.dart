import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/meal_service.dart';

class OCTeamsTab extends StatefulWidget {
  const OCTeamsTab({super.key});

  @override
  _OCTeamsTabState createState() => _OCTeamsTabState();
}

class _OCTeamsTabState extends State<OCTeamsTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _teams = [];
  List<Map<String, dynamic>> _filteredTeams = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  
  // Filter options
  String _selectedFilter = 'all';
  final List<String> _filterOptions = [
    'all',
    'started_checkin',
    'checked_in',
    'not_checked_in'
  ];
  
  @override
  void initState() {
    super.initState();
    _loadTeams();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  Future<void> _loadTeams() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final teamsCollection = await _firestore.collection('teams').get();
      
      final teams = teamsCollection.docs.map((doc) {
        final data = doc.data();
        // Check if team has completed signup
        bool hasCompletedSignup = data['leader'] != null && 
                                data['leader'] is Map && 
                                (data['leader'] as Map).isNotEmpty &&
                                data['members'] != null;

        return {
          'id': doc.id,
          'name': data['teamName'] ?? data['name'] ?? 'Unknown Team',
          'leader': hasCompletedSignup ? (data['leader'] ?? {}) : {},
          'members': hasCompletedSignup ? (data['members'] ?? []) : [],
          'isVerified': hasCompletedSignup ? (data['isVerified'] ?? false) : false,
          'checkInStarted': hasCompletedSignup ? (data['checkInStarted'] ?? false) : false,
          'hasCompletedSignup': hasCompletedSignup,
        };
      }).toList();
      
      setState(() {
        _teams = teams;
        _filteredTeams = teams;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error loading teams: $e';
      });
    }
  }
  
  void _filterTeams() {
    setState(() {
      // First filter by search query
      List<Map<String, dynamic>> searchFiltered = _teams;
      if (_searchController.text.isNotEmpty) {
        searchFiltered = _teams.where((team) {
          final teamName = team['name'].toString().toLowerCase();
          return teamName.contains(_searchController.text.toLowerCase());
        }).toList();
      }
      
      // Then filter by status
      _filteredTeams = searchFiltered.where((team) {
        if (!team['hasCompletedSignup']) {
          // For incomplete teams, only show in "Not Checked In" or "All"
          return _selectedFilter == 'not_checked_in' || _selectedFilter == 'all';
        }

        // Helper function to count verified members
        int verifiedMemberCount() {
          int count = 0;
          
          // Check leader
          if (team['leader']?['isVerified'] == true) {
            count++;
          }
          
          // Check members
          if (team['members'] != null) {
            if (team['members'] is List) {
              count += (team['members'] as List).where((m) => m['isVerified'] == true).length;
            } else if (team['members'] is Map && team['members']['isVerified'] == true) {
              count++;
            }
          }
          
          return count;
        }
        
        // Helper function to count total members (including leader)
        int totalMemberCount() {
          int count = 1; // Leader
          
          // Count members
          if (team['members'] != null) {
            if (team['members'] is List) {
              count += (team['members'] as List).length;
            } else if (team['members'] is Map) {
              count++;
            }
          }
          
          return count;
        }
        
        // Get counts
        final verified = verifiedMemberCount();
        final total = totalMemberCount();
        
        switch (_selectedFilter) {
          case 'started_checkin':
            // Some but not all members checked in
            return verified > 0 && verified < total;
          case 'checked_in':
            // All members checked in
            return verified == total && total > 0;
          case 'not_checked_in':
            // No members checked in
            return verified == 0;
          default:
            return true; // 'all' filter
        }
      }).toList();
    });
  }

  void _showTeamDetailsDialog(String teamId, String teamName) {
    showDialog(
      context: context,
      builder: (context) => TeamDetailsDialog(
        teamId: teamId,
        teamName: teamName,
        onTeamUpdated: () {
          // Refresh teams list when a team member's verification status changes
          _loadTeams();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Team Management',
            style: TextStyle(
              color: AppTheme.textPrimaryColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'View and manage all registered teams',
            style: TextStyle(
              color: AppTheme.textSecondaryColor,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          
          // Search and Filter Row
          Row(
            children: [
              Expanded(
                child: CustomTextField(
            label: 'Search Teams',
            hint: 'Search by team name or leader',
            controller: _searchController,
            prefixIcon: Icon(
              Icons.search,
              color: AppTheme.textSecondaryColor,
            ),
                  onChanged: (_) => _filterTeams(),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButton<String>(
                  value: _selectedFilter,
                  dropdownColor: AppTheme.backgroundColor,
                            style: TextStyle(
                    color: AppTheme.textPrimaryColor,
                              fontSize: 14,
                            ),
                  underline: const SizedBox(),
                  items: [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text('All Teams'),
                    ),
                    DropdownMenuItem(
                      value: 'started_checkin',
                      child: Text('Started Check-in'),
                    ),
                    DropdownMenuItem(
                      value: 'checked_in',
                      child: Text('Checked In'),
                    ),
                    DropdownMenuItem(
                      value: 'not_checked_in',
                      child: Text('Not Checked In'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedFilter = value;
                        _filterTeams();
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Teams List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
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
                              onPressed: _loadTeams,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentColor,
                              ),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _filteredTeams.isEmpty
                        ? Center(
                            child: Text(
                              'No teams found',
                              style: TextStyle(color: AppTheme.textSecondaryColor),
                            ),
                          )
                : ListView.builder(
                            itemCount: _filteredTeams.length,
                    itemBuilder: (context, index) {
                              final team = _filteredTeams[index];
                              List<dynamic> members = [];
                              if (team['members'] != null) {
                                if (team['members'] is List) {
                                  members = team['members'] as List;
                                } else if (team['members'] is Map) {
                                  members = [team['members']];
                                }
                              }
                              
                              // Get team verification status
                              final bool isTeamVerified = team['isVerified'] ?? false;
                              
                              // Calculate check-in statistics
                              int totalMembers = 1 + members.length; // Leader + members
                              int verifiedCount = 0;
                              
                              // Only count verified members if the team itself is verified
                              if (isTeamVerified) {
                                // Count leader
                                if (team['leader']?['isVerified'] == true) {
                                  verifiedCount++;
                                }
                                
                                // Count members
                                verifiedCount += members.where((m) => m['isVerified'] == true).length;
                              }
                              
                              // Calculate percentage
                              double checkinPercentage = totalMembers > 0 ? verifiedCount / totalMembers : 0;
                              
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                        child: GlassCard(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  child: InkWell(
                                    onTap: () => _showTeamDetailsDialog(
                                      team['id'],
                                      team['name'],
                                    ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                              team['name'],
                                        style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                          color: AppTheme.textPrimaryColor,
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: _getTeamStatusColor(team),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                _getTeamStatusText(team),
                                                style: TextStyle(
                                                  color: _getTeamStatusTextColor(team),
                                          fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (team['hasCompletedSignup']) ...[
                                          const SizedBox(height: 12),
                                          Text(
                                            'Leader: ${team['leader'] is Map ? (team['leader']['name'] ?? 'Unknown') : 'Unknown'}',
                                            style: TextStyle(
                                              color: AppTheme.textSecondaryColor,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                      Text(
                                            'Members: $totalMembers (${isTeamVerified ? verifiedCount : 0} checked in)',
                                        style: TextStyle(
                                          color: AppTheme.textSecondaryColor,
                                            ),
                                          ),
                                          // Add progress bar for check-in status
                                          const SizedBox(height: 10),
                                          Stack(
                                            children: [
                                              // Background
                                              Container(
                                                height: 8,
                                                width: double.infinity,
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.withOpacity(0.3),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                              ),
                                              // Progress - only show progress for verified teams
                                              if (isTeamVerified)
                                                Container(
                                                  height: 8,
                                                  width: MediaQuery.of(context).size.width * 0.8 * checkinPercentage,
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        checkinPercentage < 0.5 ? Colors.red : Colors.orange,
                                                        checkinPercentage == 1.0 ? Colors.green : 
                                                          (checkinPercentage > 0.7 ? Colors.lightGreen : Colors.yellow),
                                                      ],
                                                    ),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            isTeamVerified 
                                                ? 'Check-in Progress: ${(checkinPercentage * 100).toInt()}%'
                                                : 'Team not verified - 0% checked in',
                                            style: TextStyle(
                                              color: isTeamVerified ? AppTheme.accentColor : Colors.red,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Tap to view member details',
                                            style: TextStyle(
                                              color: AppTheme.accentColor,
                                          fontSize: 12,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ] else ...[
                                          const SizedBox(height: 12),
                                          Text(
                                            'Not Signed Up',
                                            style: TextStyle(
                                              color: AppTheme.textSecondaryColor,
                                              fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                                  ),
                                ),
                              ],
                            ),
    );
  }

  Color _getTeamStatusColor(Map<String, dynamic> team) {
    // Check if team has completed signup
    bool hasCompletedSignup = team['leader'] != null && 
                            team['leader'] is Map && 
                            (team['leader'] as Map).isNotEmpty &&
                            team['members'] != null;

    if (!hasCompletedSignup) {
      return Colors.red.withOpacity(0.2);
    }

    // Get overall team verification status
    bool isTeamVerified = team['isVerified'] ?? false;
    
    // If team is not verified, always show red regardless of individual member status
    if (!isTeamVerified) {
      return Colors.red.withOpacity(0.2); // Not verified
    }
    
    // If team is verified, calculate check-in progress for display purposes
    int verifiedCount = 0;
    int totalCount = 1; // Leader
    
    // Count leader
    if (team['leader']?['isVerified'] == true) {
      verifiedCount++;
    }
    
    // Count members
    if (team['members'] != null) {
      if (team['members'] is List) {
        final membersList = team['members'] as List;
        totalCount += membersList.length;
        verifiedCount += membersList.where((m) => m['isVerified'] == true).length;
      } else if (team['members'] is Map) {
        totalCount++;
        if (team['members']['isVerified'] == true) {
          verifiedCount++;
        }
      }
    }
    
    // Calculate check-in percentage
    double checkinPercentage = totalCount > 0 ? verifiedCount / totalCount : 0;
    
    // For verified teams, show color based on individual member status
    if (checkinPercentage == 1.0) {
      return Colors.green.withOpacity(0.2); // All individual members checked in
    } else if (checkinPercentage >= 0.7) {
      return Colors.lightGreen.withOpacity(0.2); // Mostly checked in (≥70%)
    } else if (checkinPercentage >= 0.3) {
      return Colors.orange.withOpacity(0.2); // Partially checked in (≥30%)
    } else {
      return Colors.deepOrange.withOpacity(0.2); // Few checked in (<30%)
    }
  }
  
  String _getTeamStatusText(Map<String, dynamic> team) {
    // Check if team has completed signup
    bool hasCompletedSignup = team['leader'] != null && 
                            team['leader'] is Map && 
                            (team['leader'] as Map).isNotEmpty &&
                            team['members'] != null;

    if (!hasCompletedSignup) {
      return 'Not Signed Up';
    }

    // Get overall team verification status
    bool isTeamVerified = team['isVerified'] ?? false;
    
    // If team is not verified, always show "Not Checked In" regardless of individual member status
    if (!isTeamVerified) {
      return 'Not Verified';
    }
    
    // If team is verified, calculate check-in progress for display purposes
    int verifiedCount = 0;
    int totalCount = 1; // Leader
    
    // Count leader
    if (team['leader']?['isVerified'] == true) {
      verifiedCount++;
    }
    
    // Count members
    if (team['members'] != null) {
      if (team['members'] is List) {
        final membersList = team['members'] as List;
        totalCount += membersList.length;
        verifiedCount += membersList.where((m) => m['isVerified'] == true).length;
      } else if (team['members'] is Map) {
        totalCount++;
        if (team['members']['isVerified'] == true) {
          verifiedCount++;
        }
      }
    }
    
    // Calculate check-in percentage
    double checkinPercentage = totalCount > 0 ? verifiedCount / totalCount : 0;
    final percentText = '${(checkinPercentage * 100).toInt()}%';
    
    // For verified teams, show text based on individual member status
    if (checkinPercentage == 1.0) {
      return 'All Checked In';
    } else {
      return '$percentText Checked In';
    }
  }
  
  Color _getTeamStatusTextColor(Map<String, dynamic> team) {
    // Check if team has completed signup
    bool hasCompletedSignup = team['leader'] != null && 
                            team['leader'] is Map && 
                            (team['leader'] as Map).isNotEmpty &&
                            team['members'] != null;

    if (!hasCompletedSignup) {
      return Colors.red;
    }

    // Get overall team verification status
    bool isTeamVerified = team['isVerified'] ?? false;
    
    // If team is not verified, always show red regardless of individual member status
    if (!isTeamVerified) {
      return Colors.red; // Not verified
    }
    
    // If team is verified, calculate check-in progress for display purposes
    int verifiedCount = 0;
    int totalCount = 1; // Leader
    
    // Count leader
    if (team['leader']?['isVerified'] == true) {
      verifiedCount++;
    }
    
    // Count members
    if (team['members'] != null) {
      if (team['members'] is List) {
        final membersList = team['members'] as List;
        totalCount += membersList.length;
        verifiedCount += membersList.where((m) => m['isVerified'] == true).length;
      } else if (team['members'] is Map) {
        totalCount++;
        if (team['members']['isVerified'] == true) {
          verifiedCount++;
        }
      }
    }
    
    // Calculate check-in percentage
    double checkinPercentage = totalCount > 0 ? verifiedCount / totalCount : 0;
    
    // For verified teams, show color based on individual member status
    if (checkinPercentage == 1.0) {
      return Colors.green; // All individual members checked in
    } else if (checkinPercentage >= 0.7) {
      return Colors.lightGreen; // Mostly checked in (≥70%)
    } else if (checkinPercentage >= 0.3) {
      return Colors.orange; // Partially checked in (≥30%)
    } else {
      return Colors.deepOrange; // Few checked in (<30%)
    }
  }
}

// Team details dialog with member verification checkboxes
class TeamDetailsDialog extends StatefulWidget {
  final String teamId;
  final String teamName;
  final VoidCallback onTeamUpdated;

  const TeamDetailsDialog({
    Key? key,
    required this.teamId,
    required this.teamName,
    required this.onTeamUpdated,
  }) : super(key: key);

  @override
  _TeamDetailsDialogState createState() => _TeamDetailsDialogState();
}

class _TeamDetailsDialogState extends State<TeamDetailsDialog> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MealService _mealService = MealService();
  bool _isLoading = true;
  bool _isSendingQR = false;
  Map<String, dynamic>? _teamData;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTeamDetails();
  }

  Future<void> _loadTeamDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final teamDoc = await _firestore.collection('teams').doc(widget.teamId).get();
      if (teamDoc.exists) {
        setState(() {
          _teamData = teamDoc.data();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Team not found';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading team: $e';
        _isLoading = false;
      });
    }
  }
  
  // Function to send QR codes to all iOS team members
  Future<void> _sendQRCodesToIOSUsers() async {
    setState(() {
      _isSendingQR = true;
    });
    
    try {
      final result = await _mealService.sendQRCodeToAllTeamIOSMembers(widget.teamId);
      
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('QR codes sent to ${result['sent']} iOS users. Failed: ${result['failed']}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${result['message']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending QR codes: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSendingQR = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.backgroundColor,
      title: Text(
        widget.teamName,
                                style: TextStyle(
                                  color: AppTheme.textPrimaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
      content: Container(
        width: double.maxFinite,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
            : _error != null
                ? Center(
                    child: Text(
                      _error!,
                      style: TextStyle(color: AppTheme.errorColor),
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                                    children: [
                        // Team Leaders Section
                        const SizedBox(height: 16),
                                      Text(
                          'Team Leader',
                                        style: TextStyle(
                            color: AppTheme.accentColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Display leader info
                        if (_teamData?['leader'] != null) ...[
                          _buildMemberCard(_teamData!['leader'] as Map<String, dynamic>, isLeader: true),
                        ] else ...[
                                      Text(
                            'No leader information',
                            style: TextStyle(color: AppTheme.textSecondaryColor),
                          ),
                        ],

                        // Team Members Section
                        const SizedBox(height: 24),
                        Text(
                          'Team Members',
                          style: TextStyle(
                            color: AppTheme.accentColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                                  ),
                                ),
                              const SizedBox(height: 8),
                        // Display members info
                        if (_teamData?['members'] != null &&
                            _teamData!['members'] is List &&
                            (_teamData!['members'] as List).isNotEmpty) ...[
                          ...(_teamData!['members'] as List).map((member) => _buildMemberCard(member as Map<String, dynamic>)),
                        ] else ...[
                          Text(
                            'No team members',
                            style: TextStyle(color: AppTheme.textSecondaryColor),
                          ),
                        ],
                        
                        // Actions section
                        const SizedBox(height: 20),
                        Divider(color: AppTheme.glassBorderColor),
                        const SizedBox(height: 12),
                        
                        // Team verification toggle switch
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Team Verification Status:',
                              style: TextStyle(
                                color: AppTheme.textPrimaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Switch(
                              value: _teamData?['isVerified'] ?? false,
                              activeColor: Colors.green,
                              activeTrackColor: Colors.green.withOpacity(0.5),
                              inactiveThumbColor: Colors.red,
                              inactiveTrackColor: Colors.red.withOpacity(0.5),
                              onChanged: (value) {
                                _updateTeamVerificationStatus(value);
                              },
                            ),
                          ],
                        ),
                        Center(
                          child: Text(
                            _teamData?['isVerified'] == true 
                                ? 'Team is officially verified' 
                                : 'Team needs official verification',
                            style: TextStyle(
                              color: _teamData?['isVerified'] == true 
                                  ? Colors.green 
                                  : Colors.orange,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Send QR codes to iOS users button
                        Center(
                          child: ElevatedButton.icon(
                            icon: Icon(_isSendingQR ? Icons.hourglass_empty : Icons.qr_code),
                            label: Text(_isSendingQR ? 'Sending...' : 'Send QR to iOS Users'),
                            onPressed: _isSendingQR ? null : _sendQRCodesToIOSUsers,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentColor,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: AppTheme.accentColor.withOpacity(0.5),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      ),
                                    ),
                                  ),
                                ],
                    ),
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Close',
            style: TextStyle(color: AppTheme.primaryColor),
          ),
        ),
      ],
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member, {bool isLeader = false}) {
    final name = member['name'] ?? 'Unknown';
    final email = member['email'] ?? 'No email';
    final phone = member['phone'] ?? 'No phone';
    final isIOS = member['device'] == 'iOS';
    
    // Get team verification status to determine if checkboxes should be enabled
    final isTeamVerified = _teamData?['isVerified'] ?? false;
    
    // If team is not verified, all members are shown as not verified regardless of their individual status
    // If team is verified, use their actual verification status
    final isVerified = isTeamVerified ? (member['isVerified'] ?? false) : false;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppTheme.cardColor.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.glassBorderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isLeader ? Icons.star : Icons.person,
                  color: isLeader ? Colors.amber : AppTheme.accentColor,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      color: AppTheme.textPrimaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // iOS badge
                if (isIOS)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.phone_iphone,
                          color: Colors.blue,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'iOS',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                // Added checkbox for verification status - only enabled if team is verified
                const SizedBox(width: 8),
                Checkbox(
                  value: isVerified,
                  activeColor: AppTheme.accentColor,
                  onChanged: isTeamVerified 
                      ? (bool? newValue) {
                          if (newValue != null) {
                            _updateMemberVerificationStatus(isLeader, name, newValue);
                          }
                        } 
                      : null, // Disable checkbox if team is not verified
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Email: $email',
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Phone: $phone',
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 14,
              ),
            ),
            // Added verification status indicator
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  isVerified ? Icons.check_circle : Icons.cancel,
                  color: isVerified ? Colors.green : Colors.red,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  isVerified ? 'Checked In' : 'Not Checked In',
                  style: TextStyle(
                    color: isVerified ? Colors.green : Colors.red,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Add method to update member verification status
  Future<void> _updateMemberVerificationStatus(bool isLeader, String memberName, bool isVerified) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final DocumentReference teamRef = _firestore.collection('teams').doc(widget.teamId);
      
      if (isLeader) {
        // Update leader's verification status
        await teamRef.update({
          'leader.isVerified': isVerified,
        });
        setState(() {
          if (_teamData != null && _teamData!['leader'] != null) {
            (_teamData!['leader'] as Map<String, dynamic>)['isVerified'] = isVerified;
          }
        });
      } else {
        // Find member in members array
        final members = _teamData!['members'] as List;
        final memberIndex = members.indexWhere((m) => m['name'] == memberName);
        
        if (memberIndex != -1) {
          // Create a copy of the member with updated verification status
          final updatedMember = Map<String, dynamic>.from(members[memberIndex]);
          updatedMember['isVerified'] = isVerified;
          
          // Create a new members list with the updated member
          final updatedMembers = List.from(members);
          updatedMembers[memberIndex] = updatedMember;
          
          // Update the entire members array in Firestore
          await teamRef.update({
            'members': updatedMembers,
          });
          
          // Update local state
          setState(() {
            _teamData!['members'] = updatedMembers;
          });
        }
      }
      
      // Notify parent that updates were made
      widget.onTeamUpdated();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${isLeader ? 'Leader' : 'Member'} verification status updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating verification status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Add method to update team verification status
  Future<void> _updateTeamVerificationStatus(bool isVerified) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final DocumentReference teamRef = _firestore.collection('teams').doc(widget.teamId);
      
      if (isVerified) {
        // When team is verified, verify all members
        
        // Update leader verification
        Map<String, dynamic> updatedLeader = Map<String, dynamic>.from(_teamData!['leader']);
        updatedLeader['isVerified'] = true;
        
        // Update all members verification
        List<dynamic> members = _teamData!['members'] as List;
        List<dynamic> updatedMembers = [];
        
        for (var member in members) {
          Map<String, dynamic> updatedMember = Map<String, dynamic>.from(member);
          updatedMember['isVerified'] = true;
          updatedMembers.add(updatedMember);
        }
        
        // Update team and all members at once
        await teamRef.update({
          'isVerified': true,
          'leader': updatedLeader,
          'members': updatedMembers,
        });
        
        // Update local state
        setState(() {
          _teamData!['isVerified'] = true;
          _teamData!['leader'] = updatedLeader;
          _teamData!['members'] = updatedMembers;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Team verified and all members marked as checked in'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Just update team verification status (without changing member status)
        await teamRef.update({
          'isVerified': false,
        });
        
        // Update local state
        setState(() {
          _teamData!['isVerified'] = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Team verification status updated to unverified'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      
      // Notify parent that updates were made
      widget.onTeamUpdated();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating team verification status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
} 