import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:qr/qr.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/qr_scanner_service.dart';
import '../../services/auth_service.dart';

// Common OC verification data model
class OCVerificationData {
  final String id;
  final String ocCode;
  final int timestamp;

  OCVerificationData({
    required this.id,
    required this.ocCode,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ocCode': ocCode,
      'timestamp': timestamp,
    };
  }

  factory OCVerificationData.fromJson(Map<String, dynamic> json) {
    return OCVerificationData(
      id: json['id'],
      ocCode: json['ocCode'],
      timestamp: json['timestamp'],
    );
  }
}

class OCCheckinTab extends StatefulWidget {
  const OCCheckinTab({super.key});

  @override
  _OCCheckinTabState createState() => _OCCheckinTabState();
}

class _OCCheckinTabState extends State<OCCheckinTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _teams = [];
  List<Map<String, dynamic>> _filteredTeams = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  
  // QR code related properties
  bool _showQRCode = false;
  final String _ocCommonId = "OC_SPECTAPP_2023";  // Common ID for all OC members
  final String _ocSecretCode = "SPECTRUM24"; // Secret code for verification
  
  // Scanner controller
  MobileScannerController? _scannerController;
  bool _isScanning = false;
  
  // Services
  final QRScannerService _qrScannerService = QRScannerService();
  final AuthService _authService = AuthService();
  
  @override
  void initState() {
    super.initState();
    _loadTeams();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }
  
  Future<void> _loadTeams() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get all teams from Firestore
      final teamsCollection = await _firestore.collection('teams').get();
      
      final teams = teamsCollection.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['teamName'] ?? data['name'] ?? 'Unknown Team',
          'leader': data['leader'] ?? {},
          'members': data['members'] ?? [],
          'isVerified': data['isVerified'] ?? false,
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
  
  void _filterTeams(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredTeams = _teams;
      } else {
        _filteredTeams = _teams.where((team) {
          final teamName = team['name'].toString().toLowerCase();
          
          // Check in leader name
          final leaderName = (team['leader'] != null && team['leader'] is Map ? 
                           (team['leader']['name'] ?? '') : '').toString().toLowerCase();
          
          // Check in member names - safely handle different types
          List<dynamic> members = [];
          if (team['members'] != null) {
            if (team['members'] is List) {
              members = team['members'] as List;
            } else if (team['members'] is Map) {
              members = [team['members']];
            }
          }
          
          final memberNames = members.map((member) => 
            (member is Map && member['name'] != null ? member['name'] : '').toString().toLowerCase()
          ).toList();
          
          return teamName.contains(query.toLowerCase()) || 
                 leaderName.contains(query.toLowerCase()) ||
                 memberNames.any((name) => name.contains(query.toLowerCase()));
        }).toList();
      }
    });
  }
  
  // Generate QR code data with timestamp for security
  String _generateQRData() {
    final OCVerificationData data = OCVerificationData(
      id: _ocCommonId,
      ocCode: _ocSecretCode,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    
    return json.encode(data.toJson());
  }
  
  // Handle the QR code button press
  void _toggleQRCode() {
    setState(() {
      _showQRCode = !_showQRCode;
      _isScanning = false;
      if (_scannerController != null) {
        _scannerController!.dispose();
        _scannerController = null;
      }
    });
  }
  
  // Start the QR scanner
  void _startScanner() {
    setState(() {
      _isScanning = true;
      _showQRCode = false;
      _scannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
      );
    });
  }
  
  // Process scanned QR code using the existing QRScannerService
  Future<void> _processScannedCode(String? code) async {
    if (code == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Process using QRScannerService for compatibility
      if (code.startsWith('verify_team:')) {
        // Already formatted for verification
        final result = await _qrScannerService.processQRCode(code);
        _handleVerificationResult(result);
      } else {
        // This is a team's QR code
        try {
          // Try to extract teamId from the QR code
          final Map<String, dynamic> qrData = json.decode(code);
          
          if (qrData.containsKey('teamId')) {
            // Format it for the QR service
            final formattedCode = 'verify_team:${qrData['teamId']}';
            final result = await _qrScannerService.processQRCode(formattedCode);
            _handleVerificationResult(result);
          } else {
            // Try direct verification with QRScannerService
            final result = await _qrScannerService.processQRCode(code);
            _handleVerificationResult(result);
          }
        } catch (e) {
          // Try direct verification with QRScannerService
          final result = await _qrScannerService.processQRCode(code);
          _handleVerificationResult(result);
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing QR code: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Handle the verification result
  void _handleVerificationResult(Map<String, dynamic> result) {
    setState(() {
      _isLoading = false;
      _isScanning = false;
      if (_scannerController != null) {
        _scannerController!.dispose();
        _scannerController = null;
      }
    });
    
    if (result['success']) {
      // Show success message and reload teams to update UI
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Team verified successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Reload team data to reflect changes
      _loadTeams();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Verification failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Team Check-in',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Verify and check in teams for the hackathon',
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Stats Cards
            Row(
              children: [
                Expanded(
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: AppTheme.accentColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Teams Checked In',
                              style: TextStyle(
                                color: AppTheme.textSecondaryColor,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          // Count of verified teams
                          '${_teams.where((team) => team['isVerified'] == true).length}',
                          style: TextStyle(
                            color: AppTheme.textPrimaryColor,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.groups,
                              color: AppTheme.primaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Total Teams',
                              style: TextStyle(
                                color: AppTheme.textSecondaryColor,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_teams.length}',
                          style: TextStyle(
                            color: AppTheme.textPrimaryColor,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            // Check-in Progress
            const SizedBox(height: 16),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Check-in Progress',
                        style: TextStyle(
                          color: AppTheme.textPrimaryColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _teams.isEmpty ? '0%' : 
                          '${(_teams.where((team) => team['isVerified'] == true).length * 100 / _teams.length).round()}%',
                      style: TextStyle(
                        color: AppTheme.accentColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                      value: _teams.isEmpty ? 0 : 
                        _teams.where((team) => team['isVerified'] == true).length / _teams.length,
                    minHeight: 10,
                    backgroundColor: AppTheme.cardColor,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTheme.accentColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
            // QR Code display section
            if (_showQRCode)
              Container(
                margin: const EdgeInsets.only(top: 16),
                child: GlassCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        'OC Verification QR Code',
                        style: TextStyle(
                          color: AppTheme.textPrimaryColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Show this QR code to team leaders for verification',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: QrImageView(
                            data: _generateQRData(),
                            version: QrVersions.auto,
                            size: MediaQuery.of(context).size.width > 600 ? 250 : 180,
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'QR Code refreshes automatically',
                        style: TextStyle(
              color: AppTheme.textSecondaryColor,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              
            // Scanner UI
            if (_isScanning && _scannerController != null)
              Container(
                margin: const EdgeInsets.only(top: 16),
                child: GlassCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        'Scan Team Leader\'s QR Code',
                        style: TextStyle(
                          color: AppTheme.textPrimaryColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: MediaQuery.of(context).size.width > 600 ? 300 : 200,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: MobileScanner(
                            controller: _scannerController!,
                            onDetect: (capture) {
                              final List<Barcode> barcodes = capture.barcodes;
                              if (barcodes.isNotEmpty) {
                                final Barcode barcode = barcodes.first;
                                _processScannedCode(barcode.rawValue);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Position the QR code in the camera frame',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            
            const SizedBox(height: 16),
            // Search bar and action buttons
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _searchController,
                    onChanged: _filterTeams,
                    decoration: InputDecoration(
                      hintText: 'Search teams or members...',
                      hintStyle: TextStyle(color: AppTheme.textSecondaryColor),
                      prefixIcon: Icon(Icons.search, color: AppTheme.textSecondaryColor),
                      filled: true,
                      fillColor: AppTheme.cardColor.withOpacity(0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    ),
                    style: TextStyle(color: AppTheme.textPrimaryColor),
                  ),
                ),
                const SizedBox(width: 8),
                // QR Generate Button
                Container(
                  width: 48,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _toggleQRCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _showQRCode ? AppTheme.errorColor : AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Icon(
                      _showQRCode ? Icons.close : Icons.qr_code,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Scan QR Button
                Container(
                  width: 48,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isScanning ? () {
                      setState(() {
                        _isScanning = false;
                        _scannerController?.dispose();
                        _scannerController = null;
                      });
                    } : _startScanner,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isScanning ? AppTheme.errorColor : AppTheme.accentColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Icon(
                      _isScanning ? Icons.close : Icons.qr_code_scanner,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
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
                                
                                // Safely handle members data
                                List<dynamic> members = [];
                                if (team['members'] != null) {
                                  if (team['members'] is List) {
                                    members = team['members'] as List;
                                  } else if (team['members'] is Map) {
                                    members = [team['members']];
                                  }
                                }
                                
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: GlassCard(
                                    padding: const EdgeInsets.all(16),
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
                                                  color: team['isVerified'] == true
                                                      ? Colors.green.withOpacity(0.2)
                                                      : Colors.orange.withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  team['isVerified'] == true ? 'Verified' : 'Not Verified',
                                                  style: TextStyle(
                                                    color: team['isVerified'] == true
                                                        ? Colors.green
                                                        : Colors.orange,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'Leader: ${team['leader'] is Map ? (team['leader']['name'] ?? 'Unknown') : 'Unknown'}',
                                            style: TextStyle(
                                              color: AppTheme.textSecondaryColor,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Members: ${members.length + 1}', // +1 for leader
                                            style: TextStyle(
                                              color: AppTheme.textSecondaryColor,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'Tap to view member details and verify individual members',
                                            style: TextStyle(
                                              color: AppTheme.accentColor,
                                              fontSize: 12,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
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
      ),
    );
  }
}

// Team data model
class TeamData {
  final String id;
  final String name;
  final String leaderName;
  final int memberCount;
  bool isVerified;

  TeamData({
    required this.id,
    required this.name,
    required this.leaderName,
    required this.memberCount,
    required this.isVerified,
  });
}

// Team details dialog with member verification checkboxes
class TeamDetailsDialog extends StatefulWidget {
  final String teamId;
  final String teamName;

  const TeamDetailsDialog({
    super.key,
    required this.teamId,
    required this.teamName,
  });

  @override
  _TeamDetailsDialogState createState() => _TeamDetailsDialogState();
}

class _TeamDetailsDialogState extends State<TeamDetailsDialog> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  Map<String, dynamic>? _teamData;
  List<Map<String, dynamic>> _membersList = [];
  bool _hasChanges = false;
  
  @override
  void initState() {
    super.initState();
    _loadTeamDetails();
  }
  
  Future<void> _loadTeamDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Get team document from Firestore
      final teamDoc = await _firestore.collection('teams').doc(widget.teamId).get();
      
      if (!teamDoc.exists) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Team not found';
        });
        return;
      }
      
      // Get team data - safely convert to Map
      final Map<String, dynamic> teamData = Map<String, dynamic>.from(teamDoc.data() ?? {});
      
      // Extract members and leader with safer type handling
      Map<String, dynamic> leader = {};
      List<dynamic> members = [];
      
      // Extract leader data safely
      if (teamData.containsKey('leader')) {
        if (teamData['leader'] is Map) {
          // Try to safely convert from Map to Map<String, dynamic>
          try {
            leader = Map<String, dynamic>.from(teamData['leader'] as Map);
          } catch (e) {
            // If conversion fails, create a basic map with any available name
            leader = {
              'name': teamData['leader'] is Map ? 
                     (teamData['leader'] as Map)['name'] ?? 'Unknown' : 'Unknown',
            };
          }
        }
      }
      
      // Extract members data safely
      if (teamData.containsKey('members')) {
        if (teamData['members'] is List) {
          // Process each member individually to avoid cast errors
          final rawMembers = teamData['members'] as List;
          for (final rawMember in rawMembers) {
            if (rawMember is Map) {
              try {
                members.add(Map<String, dynamic>.from(rawMember));
              } catch (e) {
                // If conversion fails, add a basic member
                members.add({'name': rawMember is Map ? rawMember['name'] ?? 'Unknown' : 'Unknown'});
              }
            } else if (rawMember != null) {
              // Add non-null, non-Map members as basic maps
              members.add({'name': 'Unknown Member'});
            }
          }
        } else if (teamData['members'] is Map) {
          // If members is a Map, convert it to a list with one member
          try {
            members = [Map<String, dynamic>.from(teamData['members'] as Map)];
          } catch (e) {
            members = [{'name': 'Unknown Member'}];
          }
        }
      }
      
      // Convert to list of members including the leader
      final membersList = <Map<String, dynamic>>[];
      
      // Add leader with role
      leader['role'] = 'Team Leader';
      if (!leader.containsKey('isVerified')) {
        leader['isVerified'] = false;
      }
      membersList.add(leader);
      
      // Add members with roles
      for (var i = 0; i < members.length; i++) {
        // Ensure member is a Map<String, dynamic>
        final Map<String, dynamic> member = members[i] is Map ? 
                                      Map<String, dynamic>.from(members[i]) : 
                                      {'name': 'Unknown Member ${i+1}'};
        
        member['role'] = 'Member ${i + 1}';
        if (!member.containsKey('isVerified')) {
          member['isVerified'] = false;
        }
        membersList.add(member);
      }
      
      setState(() {
        _teamData = teamData;
        _membersList = membersList;
        _isLoading = false;
        _hasChanges = false;
      });
    } catch (e) {
      print('Error loading team details: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading team details: $e';
      });
    }
  }
  
  // Only update the local state when checkbox is toggled
  void _updateMemberVerification(int index, bool value) {
    setState(() {
      _membersList[index]['isVerified'] = value;
      _hasChanges = true;
    });
  }
  
  // Save all changes to Firestore
  Future<void> _saveChanges() async {
    if (!_hasChanges) return;
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      // Get the current team document to update with correct data structure
      final teamDoc = await _firestore.collection('teams').doc(widget.teamId).get();
      if (!teamDoc.exists) {
        throw Exception('Team document not found');
      }
      
      final teamData = Map<String, dynamic>.from(teamDoc.data() ?? {});
      
      // Update leader verification status
      final leaderVerified = _membersList[0]['isVerified'] ?? false;
      
      if (teamData.containsKey('leader') && teamData['leader'] is Map) {
        // Keep all leader data intact, only update isVerified field
        final leaderData = Map<String, dynamic>.from(teamData['leader'] as Map);
        leaderData['isVerified'] = leaderVerified;
        teamData['leader'] = leaderData;
      }
      
      // Update members verification status while keeping all other data intact
      if (teamData.containsKey('members') && teamData['members'] is List) {
        final existingMembers = List<dynamic>.from(teamData['members'] as List);
        
        // Update each member's verification status
        for (int i = 0; i < existingMembers.length && i + 1 < _membersList.length; i++) {
          if (existingMembers[i] is Map) {
            final memberData = Map<String, dynamic>.from(existingMembers[i] as Map);
            // Only update the isVerified field
            memberData['isVerified'] = _membersList[i + 1]['isVerified'] ?? false;
            existingMembers[i] = memberData;
          }
        }
        
        teamData['members'] = existingMembers;
      }
      
      // Set overall team verification status
      final bool allVerified = leaderVerified && 
                               (teamData['members'] is List ? 
                                (teamData['members'] as List).every((m) => 
                                  m is Map && m['isVerified'] == true) : 
                                true);
      
      teamData['isVerified'] = allVerified;
      
      // Update the entire document with the modified data
      await _firestore.collection('teams').doc(widget.teamId).set(teamData);
      
      setState(() {
        _isSaving = false;
        _hasChanges = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Team verification status updated'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error updating verification status: $e');
      setState(() {
        _isSaving = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating verification status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.backgroundColor,
      title: Text(
        widget.teamName, 
        style: TextStyle(color: AppTheme.textPrimaryColor),
        overflow: TextOverflow.ellipsis,
      ),
      content: Container(
        width: double.maxFinite,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: AppTheme.errorColor),
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Team Members',
                        style: TextStyle(
                          color: AppTheme.textPrimaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Verify individual team members by checking/unchecking the boxes.',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 12,
                        ),
                      ),
                      if (_hasChanges)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Click update button to save changes',
                            style: TextStyle(
                              color: AppTheme.accentColor,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _membersList.length,
                          itemBuilder: (context, index) {
                            final member = _membersList[index];
                            final isLeader = member['role'] == 'Team Leader';
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: GlassCard(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                member['name'] ?? 'Unknown',
                                                style: TextStyle(
                                                  color: AppTheme.textPrimaryColor,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: isLeader 
                                                      ? AppTheme.primaryColor.withOpacity(0.2)
                                                      : AppTheme.accentColor.withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  member['role'],
                                                  style: TextStyle(
                                                    color: isLeader 
                                                        ? AppTheme.primaryColor
                                                        : AppTheme.accentColor,
                                                    fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                    Text(
                                            member['email'] ?? 'No email',
                                      style: TextStyle(
                                        color: AppTheme.textSecondaryColor,
                                              fontSize: 12,
                                            ),
                                          ),
                                          Text(
                                            'Phone: ${member['phone'] ?? 'Not provided'}',
                                      style: TextStyle(
                                        color: AppTheme.textSecondaryColor,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Verification checkbox
                                    Checkbox(
                                      value: member['isVerified'] ?? false,
                                      onChanged: (value) {
                                        if (value != null) {
                                          _updateMemberVerification(index, value);
                                        }
                                      },
                                      activeColor: AppTheme.accentColor,
                                      checkColor: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      ),
      actions: [
        if (_isSaving)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (_hasChanges)
          ElevatedButton(
            onPressed: _saveChanges,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentColor,
            ),
            child: const Text('Update'),
          ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(
            'Close',
            style: TextStyle(color: _hasChanges ? AppTheme.textSecondaryColor : AppTheme.accentColor),
          ),
        ),
      ],
    );
  }
} 