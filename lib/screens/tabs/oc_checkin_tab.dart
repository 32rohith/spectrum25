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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(screenWidth * 0.04),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Team Check-in',
                style: TextStyle(
                  fontSize: screenWidth * 0.06,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              SizedBox(height: screenHeight * 0.01),
              Text(
                'Verify and check in teams for the hackathon',
                style: TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontSize: screenWidth * 0.04,
                ),
              ),
              SizedBox(height: screenHeight * 0.02),
              
              // Action buttons for QR
              ElevatedButton(
                onPressed: _toggleQRCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _showQRCode ? AppTheme.errorColor : AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    vertical: screenHeight * 0.015,
                    horizontal: screenWidth * 0.04,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(screenWidth * 0.03),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _showQRCode ? Icons.close : Icons.qr_code,
                      color: Colors.white,
                      size: screenWidth * 0.05,
                    ),
                    SizedBox(width: screenWidth * 0.02),
                    Text(
                      _showQRCode ? 'Hide QR Code' : 'Show QR Code',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: screenWidth * 0.04,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: screenHeight * 0.02),
              
              // Main content area with Expanded to fill remaining space and scrollable
              Expanded(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // QR Code display section
                      if (_showQRCode)
                        GlassCard(
                          child: Padding(
                            padding: EdgeInsets.all(screenWidth * 0.04),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'OC Verification QR Code',
                                  style: TextStyle(
                                    color: AppTheme.textPrimaryColor,
                                    fontSize: screenWidth * 0.04,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: screenHeight * 0.01),
                                Text(
                                  'Show this QR code to team leaders for verification',
                                  style: TextStyle(
                                    color: AppTheme.textSecondaryColor,
                                    fontSize: screenWidth * 0.035,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: screenHeight * 0.02),
                                Container(
                                  padding: EdgeInsets.all(screenWidth * 0.04),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(screenWidth * 0.04),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 10,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: SizedBox(
                                    // Make QR code responsive
                                    height: screenWidth * 0.6,
                                    width: screenWidth * 0.6,
                                    child: QrImageView(
                                      data: _generateQRData(),
                                      version: QrVersions.auto,
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black,
                                      padding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                                SizedBox(height: screenHeight * 0.02),
                                Text(
                                  'QR Code refreshes automatically',
                                  style: TextStyle(
                                    color: AppTheme.textSecondaryColor,
                                    fontSize: screenWidth * 0.03,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      
                      SizedBox(height: screenHeight * 0.02),
                      
                      // Stats Cards with responsive heights and widths
                      // First row of stats
                      Row(
                        children: [
                          Expanded(
                            child: GlassCard(
                              child: Padding(
                                padding: EdgeInsets.all(screenWidth * 0.03),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.groups,
                                          color: AppTheme.primaryColor,
                                          size: screenWidth * 0.05,
                                        ),
                                        SizedBox(width: screenWidth * 0.02),
                                        Expanded(
                                          child: Text(
                                            'Total Teams',
                                            style: TextStyle(
                                              color: AppTheme.textSecondaryColor,
                                              fontSize: screenWidth * 0.035,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: screenHeight * 0.01),
                                    Text(
                                      '${_teams.length}',
                                      style: TextStyle(
                                        color: AppTheme.textPrimaryColor,
                                        fontSize: screenWidth * 0.055,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: screenWidth * 0.02),
                          Expanded(
                            child: GlassCard(
                              child: Padding(
                                padding: EdgeInsets.all(screenWidth * 0.03),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          color: AppTheme.accentColor,
                                          size: screenWidth * 0.05,
                                        ),
                                        SizedBox(width: screenWidth * 0.02),
                                        Expanded(
                                          child: Text(
                                            'Teams Checked In',
                                            style: TextStyle(
                                              color: AppTheme.textSecondaryColor,
                                              fontSize: screenWidth * 0.035,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: screenHeight * 0.01),
                                    Text(
                                      '${_teams.where((team) {
                                        // For Teams Checked In, we want:
                                        // 1. The team to be marked as verified
                                        // 2. All team members must also be verified
                                      
                                        // First check if the team itself is verified
                                        if (team['isVerified'] != true) return false;

                                        // Then check that all members are verified
                                        bool allMembersVerified = true;
                                        
                                        // Check leader verification
                                        if (team['leader'] != null && team['leader'] is Map) {
                                          if (team['leader']?['isVerified'] != true) {
                                            allMembersVerified = false;
                                          }
                                        }
                                        
                                        // Check all team members' verification
                                        if (allMembersVerified && team['members'] != null) {
                                          if (team['members'] is List) {
                                            for (var member in team['members']) {
                                              if (member is Map && member['isVerified'] != true) {
                                                allMembersVerified = false;
                                                break;
                                              }
                                            }
                                          } else if (team['members'] is Map && team['members']['isVerified'] != true) {
                                            allMembersVerified = false;
                                          }
                                        }
                                        
                                        // Only include fully verified teams
                                        return allMembersVerified;
                                      }).length}',
                                      style: TextStyle(
                                        color: AppTheme.textPrimaryColor,
                                        fontSize: screenWidth * 0.055,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: screenHeight * 0.01),
                      
                      // Second row of stats
                      Row(
                        children: [
                          Expanded(
                            child: GlassCard(
                              child: Padding(
                                padding: EdgeInsets.all(screenWidth * 0.03),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.person,
                                          color: AppTheme.primaryColor,
                                          size: screenWidth * 0.05,
                                        ),
                                        SizedBox(width: screenWidth * 0.02),
                                        Expanded(
                                          child: Text(
                                            'Total Members',
                                            style: TextStyle(
                                              color: AppTheme.textSecondaryColor,
                                              fontSize: screenWidth * 0.035,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: screenHeight * 0.01),
                                    Text(
                                      '${_teams.fold<int>(0, (sum, team) => sum + ((team['members']?.length ?? 0) + 1) as int)}',
                                      style: TextStyle(
                                        color: AppTheme.textPrimaryColor,
                                        fontSize: screenWidth * 0.055,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: screenWidth * 0.02),
                          Expanded(
                            child: GlassCard(
                              child: Padding(
                                padding: EdgeInsets.all(screenWidth * 0.03),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          color: AppTheme.accentColor,
                                          size: screenWidth * 0.05,
                                        ),
                                        SizedBox(width: screenWidth * 0.02),
                                        Expanded(
                                          child: Text(
                                            'Members Checked In',
                                            style: TextStyle(
                                              color: AppTheme.textSecondaryColor,
                                              fontSize: screenWidth * 0.035,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: screenHeight * 0.01),
                                    Text(
                                      '${_teams.where((team) => team['isVerified'] == true).fold<int>(0, (sum, team) {
                                        int checkedIn = 0;
                                        // Count leader if verified
                                        if (team['leader']?['isVerified'] == true) {
                                          checkedIn++;
                                        }
                                        // Count verified members
                                        if (team['members'] != null) {
                                          if (team['members'] is List) {
                                            checkedIn += (team['members'] as List).where((m) => m['isVerified'] == true).length;
                                          } else if (team['members'] is Map && team['members']['isVerified'] == true) {
                                            checkedIn++;
                                          }
                                        }
                                        return sum + checkedIn;
                                      })}',
                                      style: TextStyle(
                                        color: AppTheme.textPrimaryColor,
                                        fontSize: screenWidth * 0.055,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: screenHeight * 0.01),
                      
                      // Third row of stats
                      Row(
                        children: [
                          Expanded(
                            child: GlassCard(
                              child: Padding(
                                padding: EdgeInsets.all(screenWidth * 0.03),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.hourglass_empty,
                                          color: AppTheme.primaryColor,
                                          size: screenWidth * 0.05,
                                        ),
                                        SizedBox(width: screenWidth * 0.02),
                                        Expanded(
                                          child: Text(
                                            'Teams Started Check-in',
                                            style: TextStyle(
                                              color: AppTheme.textSecondaryColor,
                                              fontSize: screenWidth * 0.035,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: screenHeight * 0.01),
                                    Text(
                                      '${_teams.where((team) {
                                        // Teams that have started but not completed check-in
                                        // Check if team itself is verified
                                        bool isTeamFullyVerified = team['isVerified'] == true;
                                        
                                        // Determine if ANY members are verified
                                        bool hasAnyVerifiedMember = false;
                                        bool areAllMembersVerified = true;
                                        
                                        // Check leader verification
                                        if (team['leader'] != null && team['leader'] is Map) {
                                          if (team['leader']?['isVerified'] == true) {
                                            hasAnyVerifiedMember = true;
                                          } else {
                                            areAllMembersVerified = false;
                                          }
                                        }
                                        
                                        // Check all team members' verification
                                        if (team['members'] != null) {
                                          if (team['members'] is List) {
                                            for (var member in team['members']) {
                                              if (member is Map) {
                                                if (member['isVerified'] == true) {
                                                  hasAnyVerifiedMember = true;
                                                } else {
                                                  areAllMembersVerified = false;
                                                }
                                              } else {
                                                areAllMembersVerified = false;
                                              }
                                            }
                                          } else if (team['members'] is Map) {
                                            if (team['members']['isVerified'] == true) {
                                              hasAnyVerifiedMember = true;
                                            } else {
                                              areAllMembersVerified = false;
                                            }
                                          }
                                        }
                                        
                                        // Include teams that have at least one member verified 
                                        // but not all members verified
                                        return hasAnyVerifiedMember && (!areAllMembersVerified || !isTeamFullyVerified);
                                      }).length}',
                                      style: TextStyle(
                                        color: AppTheme.textPrimaryColor,
                                        fontSize: screenWidth * 0.055,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: screenWidth * 0.02),
                          Expanded(
                            child: GlassCard(
                              child: Padding(
                                padding: EdgeInsets.all(screenWidth * 0.03),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.pending_actions,
                                          color: AppTheme.accentColor,
                                          size: screenWidth * 0.05,
                                        ),
                                        SizedBox(width: screenWidth * 0.02),
                                        Expanded(
                                          child: Text(
                                            'Teams Not Checked In',
                                            style: TextStyle(
                                              color: AppTheme.textSecondaryColor,
                                              fontSize: screenWidth * 0.035,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: screenHeight * 0.01),
                                    Text(
                                      '${_teams.where((team) => team['isVerified'] != true).length}',
                                      style: TextStyle(
                                        color: AppTheme.textPrimaryColor,
                                        fontSize: screenWidth * 0.055,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      SizedBox(height: screenHeight * 0.01),
                      
                      // Check-in Progress
                      GlassCard(
                        child: Padding(
                          padding: EdgeInsets.all(screenWidth * 0.03),
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
                                      fontSize: screenWidth * 0.04,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    _teams.isEmpty ? '0%' : 
                                      '${(() {
                                        // Count total members across all teams
                                        int totalMembers = 0;
                                        int verifiedMembers = 0;
                                        
                                        for (var team in _teams) {
                                          // Count leader
                                          totalMembers++;
                                          if (team['leader'] != null && team['leader'] is Map && team['leader']?['isVerified'] == true) {
                                            verifiedMembers++;
                                          }
                                          
                                          // Count team members
                                          if (team['members'] != null) {
                                            if (team['members'] is List) {
                                              totalMembers += (team['members'] as List).length;
                                              for (var member in team['members']) {
                                                if (member is Map && member['isVerified'] == true) {
                                                  verifiedMembers++;
                                                }
                                              }
                                            } else if (team['members'] is Map) {
                                              totalMembers++;
                                              if (team['members']['isVerified'] == true) {
                                                verifiedMembers++;
                                              }
                                            }
                                          }
                                        }
                                        
                                        return totalMembers > 0 ? (verifiedMembers * 100 / totalMembers).round() : 0;
                                      })()}%',
                                    style: TextStyle(
                                      color: AppTheme.accentColor,
                                      fontSize: screenWidth * 0.04,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: screenHeight * 0.01),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(screenWidth * 0.02),
                                child: LinearProgressIndicator(
                                  value: _teams.isEmpty ? 0.0 : 
                                    (() {
                                      // Count total members across all teams
                                      int totalMembers = 0;
                                      int verifiedMembers = 0;
                                      
                                      for (var team in _teams) {
                                        // Count leader
                                        totalMembers++;
                                        if (team['leader'] != null && team['leader'] is Map && team['leader']?['isVerified'] == true) {
                                          verifiedMembers++;
                                        }
                                        
                                        // Count team members
                                        if (team['members'] != null) {
                                          if (team['members'] is List) {
                                            totalMembers += (team['members'] as List).length;
                                            for (var member in team['members']) {
                                              if (member is Map && member['isVerified'] == true) {
                                                verifiedMembers++;
                                              }
                                            }
                                          } else if (team['members'] is Map) {
                                            totalMembers++;
                                            if (team['members']['isVerified'] == true) {
                                              verifiedMembers++;
                                            }
                                          }
                                        }
                                      }
                                      
                                      return totalMembers > 0 ? (verifiedMembers / totalMembers).toDouble() : 0.0;
                                    })(),
                                  minHeight: screenHeight * 0.015,
                                  backgroundColor: AppTheme.cardColor,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppTheme.accentColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      
                      
            ],
          ),
        ),
        ),
      ],
    ),),),);
  }
}
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
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 350,
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