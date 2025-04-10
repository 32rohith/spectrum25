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
                                            'Members: ${(team['members']?.length ?? 0) + 1} (${(team['leader']?['isVerified'] == true ? 1 : 0) + ((team['members'] as List?)?.where((m) => m['isVerified'] == true).length ?? 0)} checked in)',
                                        style: TextStyle(
                                          color: AppTheme.textSecondaryColor,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
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
    
    if (verifiedCount == totalCount && totalCount > 0) {
      return Colors.green.withOpacity(0.2); // All checked in
    } else if (verifiedCount > 0) {
      return Colors.orange.withOpacity(0.2); // Some checked in
    } else {
      return Colors.red.withOpacity(0.2); // None checked in
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
    
    if (verifiedCount == totalCount && totalCount > 0) {
      return 'Checked In';
    } else if (verifiedCount > 0) {
      return 'Started Check-in';
    } else {
      return 'Not Checked In';
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
    
    if (verifiedCount == totalCount && totalCount > 0) {
      return Colors.green;
    } else if (verifiedCount > 0) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}

// Team details dialog with member verification checkboxes
class TeamDetailsDialog extends StatefulWidget {
  final String teamId;
  final String teamName;

  const TeamDetailsDialog({
    Key? key,
    required this.teamId,
    required this.teamName,
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
          ],
        ),
      ),
    );
  }
} 