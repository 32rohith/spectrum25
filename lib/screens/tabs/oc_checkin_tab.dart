import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:qr/qr.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

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
  
  @override
  void initState() {
    super.initState();
    _loadTeamData();
  }
  
  // Load team data (replace with actual data loading)
  void _loadTeamData() {
    setState(() {
      _isLoading = true;
    });
    
    // In a real app, this would load from database or API
    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        _teams = List.generate(5, (index) => 
          TeamData(
            id: 'TEAM${index + 1}',
            name: 'Team ${index + 1}',
            leaderName: 'Leader ${index + 1}',
            memberCount: 4,
            isVerified: false,
          )
        );
        _isLoading = false;
      });
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
  
  // Process scanned QR code
  void _processScannedCode(String? code) {
    if (code == null) return;
    
    try {
      final Map<String, dynamic> jsonData = json.decode(code);
      final OCVerificationData data = OCVerificationData.fromJson(jsonData);
      
      // Validate the QR code data
      final bool isValid = _validateQRData(data);
      
      if (isValid) {
        // Find the selected team (assuming the first one for now)
        if (_teams.isNotEmpty) {
          setState(() {
            // In a real app, you would select a specific team
            _teams[0].isVerified = true;
            _isScanning = false;
            _scannerController?.dispose();
            _scannerController = null;
            
            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Team verification successful!'),
                backgroundColor: Colors.green,
              ),
            );
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid or expired QR code'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error processing QR code: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid QR code format'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Validate QR data (check ID, code, and timestamp)
  bool _validateQRData(OCVerificationData data) {
    // Check if ID and code match
    final bool correctCredentials = 
        data.id == _ocCommonId && data.ocCode == _ocSecretCode;
    
    // Check if QR code is not too old (5 minute expiration)
    final int currentTime = DateTime.now().millisecondsSinceEpoch;
    final bool notExpired = 
        (currentTime - data.timestamp) < const Duration(minutes: 5).inMilliseconds;
    
    return correctCredentials && notExpired;
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
          Text(
            'Verify and check in teams for the hackathon',
            style: TextStyle(
              color: AppTheme.textSecondaryColor,
              fontSize: 16,
            ),
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
          
          const SizedBox(height: 24),
          
          // Team list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _teams.length,
                    itemBuilder: (context, index) {
                      final team = _teams[index];
                      return GlassCard(
                        padding: const EdgeInsets.all(16),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
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
                              // Verification status icon
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
                            ],
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