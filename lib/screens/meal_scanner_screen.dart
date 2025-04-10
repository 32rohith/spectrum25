import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/qr_scanner_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class MealScannerScreen extends StatefulWidget {
  final String mealType;

  const MealScannerScreen({
    Key? key,
    required this.mealType,
  }) : super(key: key);

  @override
  State<MealScannerScreen> createState() => _MealScannerScreenState();
}

class _MealScannerScreenState extends State<MealScannerScreen> {
  final QRScannerService _qrScannerService = QRScannerService();
  final MobileScannerController cameraController = MobileScannerController();
  
  String _scanResult = '';
  bool _isProcessing = false;
  bool _scanComplete = false;
  bool _scanSuccess = false;
  String _memberName = '';
  String _teamName = '';

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  void _resetScan() {
    setState(() {
      _scanResult = '';
      _isProcessing = false;
      _scanComplete = false;
      _scanSuccess = false;
      _memberName = '';
      _teamName = '';
    });
  }

  Future<void> _onQRCodeDetected(String qrCode) async {
    if (_isProcessing || _scanComplete) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await _qrScannerService.processQRCode(qrCode, mealType: widget.mealType);
      
      // Check if member data is included in the result
      if (result.containsKey('memberName')) {
        setState(() {
          _memberName = result['memberName'] as String;
        });
      }
      
      if (result.containsKey('teamName')) {
        setState(() {
          _teamName = result['teamName'] as String;
        });
      }
      
      setState(() {
        _scanResult = result['message'] as String;
        _scanComplete = true;
        _scanSuccess = result['success'] as bool;
        _isProcessing = false;
      });
      
      // Play sound feedback (could be implemented if needed)
      // Vibrate for feedback (could be implemented if needed)
    } catch (e) {
      setState(() {
        _scanResult = 'Error: ${e.toString()}';
        _isProcessing = false;
        _scanComplete = true;
        _scanSuccess = false;
      });
    }
  }

  void _finishScanning() {
    Navigator.pop(context, {'refreshNeeded': true});
  }

  @override
  Widget build(BuildContext context) {
    String capitalizedMealType = widget.mealType.isEmpty 
        ? '' 
        : '${widget.mealType[0].toUpperCase()}${widget.mealType.substring(1)}';
        
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        title: Text('$capitalizedMealType Scanner'),
        actions: [
          if (_scanComplete)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _finishScanning,
              tooltip: 'Finish Scanning',
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 5,
              child: _scanComplete
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: GlassCard(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _scanSuccess 
                                      ? Icons.check_circle_outline 
                                      : Icons.error_outline,
                                  size: 80,
                                  color: _scanSuccess 
                                      ? Colors.green 
                                      : Colors.orange,
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  _memberName.isNotEmpty ? _memberName : 'Member',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimaryColor,
                                  ),
                                ),
                                if (_teamName.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      'Team: $_teamName',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: AppTheme.textSecondaryColor,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 16),
                                Text(
                                  _scanResult,
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: AppTheme.textPrimaryColor,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  : Stack(
                      alignment: Alignment.center,
                      children: [
                        // Scanner
                        MobileScanner(
                          controller: cameraController,
                          onDetect: (capture) {
                            final List<Barcode> barcodes = capture.barcodes;
                            for (final barcode in barcodes) {
                              if (barcode.rawValue != null) {
                                _onQRCodeDetected(barcode.rawValue!);
                                break;
                              }
                            }
                          },
                        ),
                        // Scanning overlay
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppTheme.accentColor.withOpacity(0.5),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          width: 250,
                          height: 250,
                        ),
                        // Scan line animation (simplified)
                        Positioned(
                          top: 0,
                          left: MediaQuery.of(context).size.width * 0.5 - 125,
                          child: Container(
                            width: 250,
                            height: 2,
                            color: AppTheme.accentColor,
                          ),
                        ),
                      ],
                    ),
            ),
            Container(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  if (_isProcessing)
                    Column(
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentColor),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Processing QR Code...',
                          style: TextStyle(
                            color: AppTheme.textSecondaryColor,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    )
                  else if (_scanComplete)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _resetScan,
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('Scan Next'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _finishScanning,
                          icon: const Icon(Icons.check),
                          label: const Text('Done'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        Text(
                          'Scan $capitalizedMealType QR Code',
                          style: TextStyle(
                            color: AppTheme.textPrimaryColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Center the QR code in the scanning area',
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
        ),
      ),
    );
  }
} 