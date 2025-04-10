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
  bool _isLoading = false;
  String? _errorMessage;
  final _searchController = TextEditingController();
  
  // QR code related properties
  bool _showQRCode = false;
  final String _ocCommonId = "OC_SPECTAPP_2023";  // Common ID for all OC members
  final String _ocSecretCode = "SPECTRUM24"; // Secret code for verification
  
  // Scanner controller
  MobileScannerController? _scannerController;
  bool _isScanning = false;
  
  // Team verification status
  List<TeamData> _teams = [];
  
  // Reference to Firestore and services
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final QRScannerService _qrScannerService = QRScannerService();
  final AuthService _authService = AuthService();
  
  @override
  void initState() {
    super.initState();
    _loadTeamData();
  }
  
  // Load team data from Firestore
  Future<void> _loadTeamData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Get teams collection from Firestore
      final QuerySnapshot teamsSnapshot = await _firestore.collection('teams').get();
      
      final List<TeamData> loadedTeams = [];
      
      // Convert documents to TeamData objects
      for (var doc in teamsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        loadedTeams.add(
          TeamData(
            id: doc.id,
            name: data['teamName'] ?? data['name'] ?? 'Unnamed Team',
            leaderName: data['leader'] != null && data['leader'] is Map ? 
                     (data['leader'] as Map)['name'] ?? 'Unknown Leader' : 
                     data['leaderName'] ?? 'Unknown Leader',
            memberCount: data['members'] != null && data['members'] is List ? 
                       (data['members'] as List).length : 
                       data['memberCount'] ?? 0,
            isVerified: data['isVerified'] ?? false,
          ),
        );
      }
      
      // If there are no teams in the database, create some sample teams
      if (loadedTeams.isEmpty) {
        await _createSampleTeams();
        // Fetch teams again after creating samples
        return _loadTeamData();
      }
      
      // Sort teams by name
      loadedTeams.sort((a, b) => a.name.compareTo(b.name));
      
      setState(() {
        _teams = loadedTeams;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading teams: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load teams: $e';
      });
    }
  }
  
  // Create sample teams in Firestore (only if no teams exist)
  Future<void> _createSampleTeams() async {
    final batch = _firestore.batch();
    
    // Create 5 sample teams with proper Team model structure
    for (var i = 1; i <= 5; i++) {
      final teamRef = _firestore.collection('teams').doc();
      
      // Create a leader for the team
      final Map<String, dynamic> leaderData = {
        'name': 'Leader $i',
        'email': 'leader$i@example.com',
        'phone': '123456789$i',
        'device': 'Device $i',
      };
      
      // Create team members
      final List<Map<String, dynamic>> membersData = List.generate(
        3, // 3 members in addition to the leader
        (index) => {
          'name': 'Member ${i}_${index + 1}',
          'email': 'member${i}_${index + 1}@example.com',
          'phone': '987654321${i}${index + 1}',
          'device': 'Device ${i}_${index + 1}',
        },
      );
      
      batch.set(teamRef, {
        'teamName': 'Team $i',
        'teamId': teamRef.id,
        'username': 'team$i',
        'password': 'password$i',
        'leader': leaderData,
        'members': membersData,
        'isVerified': false,
        'isRegistered': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    
    await batch.commit();
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
      _loadTeamData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Verification failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Manual verification for a specific team
  Future<void> _manuallyVerifyTeam(String teamId, bool isVerified) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      if (isVerified) {
        // Use the existing auth service to verify the team
        final result = await _authService.verifyTeam(teamId);
        _handleVerificationResult(result);
      } else {
        // Unverify the team - direct update since there's no unverify method
        await _firestore.collection('teams').doc(teamId).update({
          'isVerified': false,
          'verifiedAt': null,
        });
        
        // Update local state
        setState(() {
          final teamIndex = _teams.indexWhere((team) => team.id == teamId);
          if (teamIndex != -1) {
            _teams[teamIndex].isVerified = false;
          }
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Team unverified successfully'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating verification status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Search teams by name or ID
  void _searchTeams(String query) {
    if (query.isEmpty) {
      _loadTeamData();
      return;
    }
    
    setState(() {
      final lowercaseQuery = query.toLowerCase();
      _teams = _teams.where((team) => 
          team.name.toLowerCase().contains(lowercaseQuery) || 
          team.id.toLowerCase().contains(lowercaseQuery) ||
          team.leaderName.toLowerCase().contains(lowercaseQuery)
      ).toList();
    });
  }
  
  // Reset all teams' verification status (for testing)
  Future<void> _resetAllTeams() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final batch = _firestore.batch();
      
      // Get all teams
      final QuerySnapshot teamsSnapshot = await _firestore.collection('teams').get();
      
      // Reset verification status for all teams
      for (var doc in teamsSnapshot.docs) {
        batch.update(doc.reference, {
          'isVerified': false,
          'verifiedAt': null,
        });
      }
      
      await batch.commit();
      
      // Reload teams
      await _loadTeamData();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All teams reset successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to reset teams: $e';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reset teams: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _scannerController?.dispose();
    super.dispose();
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
            'Team Check-in',
            style: TextStyle(
              color: AppTheme.textPrimaryColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
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
              // Reset button (for testing)
              TextButton.icon(
                onPressed: _resetAllTeams,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Reset All', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
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
                        '${_teams.where((team) => team.isVerified).length}',
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
                        '${(_teams.where((team) => team.isVerified).length * 100 / _teams.length).round()}%',
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
                      _teams.where((team) => team.isVerified).length / _teams.length,
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
          
          // QR Code or Scanner view
          if (_showQRCode || _isScanning)
            const SizedBox(height: 16),
            
          if (_showQRCode)
            GlassCard(
              child: Column(
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
                        size: 200,
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
            
          if (_isScanning && _scannerController != null)
            GlassCard(
              child: Column(
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
                    height: 250,
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
          
          const SizedBox(height: 24),
          
          // Search bar and action buttons
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  label: 'Search Teams',
                  hint: 'Enter team name or ID',
                  controller: _searchController,
                  onChanged: _searchTeams,
                  prefixIcon: Icon(
                    Icons.search,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // QR Generate Button
              ElevatedButton(
                onPressed: _toggleQRCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _showQRCode ? AppTheme.errorColor : AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Icon(
                  _showQRCode ? Icons.close : Icons.qr_code,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              // Scan QR Button
              ElevatedButton(
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
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Icon(
                  _isScanning ? Icons.close : Icons.qr_code_scanner,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Error message
          if (_errorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red, size: 16),
                    onPressed: () {
                      setState(() {
                        _errorMessage = null;
                      });
                    },
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    padding: EdgeInsets.zero,
                    splashRadius: 20,
                  ),
                ],
              ),
            ),
            
          if (_errorMessage != null) const SizedBox(height: 16),
          
          // Team list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _teams.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.groups_outlined,
                              size: 64,
                              color: AppTheme.textSecondaryColor.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No teams found',
                              style: TextStyle(
                                color: AppTheme.textSecondaryColor,
                                fontSize: 16,
                              ),
                            ),
                            if (_searchController.text.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: () {
                                  _searchController.clear();
                                  _loadTeamData();
                                },
                                icon: const Icon(Icons.refresh),
                                label: const Text('Clear search'),
                              ),
                            ],
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadTeamData,
                        child: ListView.builder(
                          itemCount: _teams.length,
                          itemBuilder: (context, index) {
                            final team = _teams[index];
                            return GlassCard(
                              padding: const EdgeInsets.all(16),
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${index + 1}',
                                          style: TextStyle(
                                            color: AppTheme.primaryColor,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            team.name,
                                            style: TextStyle(
                                              color: AppTheme.textPrimaryColor,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            'Team Leader: ${team.leaderName}',
                                            style: TextStyle(
                                              color: AppTheme.textSecondaryColor,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            'Members: ${team.memberCount}',
                                            style: TextStyle(
                                              color: AppTheme.textSecondaryColor,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Verification status icon and toggle
                                    Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: team.isVerified 
                                                ? Colors.green.withOpacity(0.2) 
                                                : Colors.orange.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                team.isVerified 
                                                    ? Icons.verified_user 
                                                    : Icons.pending,
                                                color: team.isVerified 
                                                    ? Colors.green 
                                                    : Colors.orange,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                team.isVerified ? 'Verified' : 'Pending',
                                                style: TextStyle(
                                                  color: team.isVerified 
                                                      ? Colors.green 
                                                      : Colors.orange,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        // Manual toggle button
                                        SizedBox(
                                          height: 30,
                                          child: TextButton(
                                            onPressed: () => _manuallyVerifyTeam(
                                              team.id, 
                                              !team.isVerified
                                            ),
                                            style: TextButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              backgroundColor: team.isVerified 
                                                  ? Colors.red.withOpacity(0.1) 
                                                  : Colors.green.withOpacity(0.1),
                                            ),
                                            child: Text(
                                              team.isVerified ? 'Unverify' : 'Verify',
                                              style: TextStyle(
                                                color: team.isVerified ? Colors.red : Colors.green,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
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