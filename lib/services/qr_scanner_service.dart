import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:developer' as developer;
import 'auth_service.dart';

class QRScannerService {
  final AuthService _authService = AuthService();
  
  Future<Map<String, dynamic>> processQRCode(String qrData) async {
    try {
      developer.log('Processing QR code: $qrData');
      
      // Check if QR data is valid for team verification
      if (qrData.startsWith('verify_team:')) {
        // Extract team ID from QR data
        final teamId = qrData.split(':')[1];
        developer.log('Found verify_team format, teamId: $teamId');
        
        // Verify the team
        final result = await _authService.verifyTeam(teamId);
        developer.log('Team verification result: $result');
        return result;
      } 
      // Check if this is an OC verification QR code
      else if (qrData.contains('"id"') && qrData.contains('"ocCode"') && qrData.contains('"timestamp"')) {
        try {
          // Decode the JSON data
          final Map<String, dynamic> jsonData = json.decode(qrData);
          developer.log('Found OC verification QR code: ${jsonData.toString()}');
          
          // Verify OC QR code format
          if (jsonData.containsKey('id') && 
              jsonData.containsKey('ocCode') && 
              jsonData.containsKey('timestamp')) {
            
            // Check if ID matches the expected value
            final String id = jsonData['id'];
            final String ocCode = jsonData['ocCode'];
            final int timestamp = jsonData['timestamp'];
            
            // Check that the QR code is not too old (5 minute expiration)
            final int currentTime = DateTime.now().millisecondsSinceEpoch;
            final bool notExpired = 
                (currentTime - timestamp) < const Duration(minutes: 5).inMilliseconds;
            
            // Check if this is a valid OC verification code
            if (id == "OC_SPECTAPP_2023" && ocCode == "SPECTRUM24" && notExpired) {
              // Simply return success - the QR screen will handle updating the team
              return {
                'success': true,
                'message': 'Valid OC verification code',
              };
            } else if (!notExpired) {
              developer.log('QR code expired');
              return {
                'success': false,
                'message': 'QR code has expired. Please ask for a new code.',
              };
            } else {
              developer.log('Invalid verification code');
              return {
                'success': false,
                'message': 'Invalid verification code',
              };
            }
          }
        } catch (e) {
          developer.log('Error decoding QR JSON: $e');
          return {
            'success': false,
            'message': 'Invalid QR code format',
          };
        }
      }
      
      developer.log('Unrecognized QR code format');
      return {
        'success': false,
        'message': 'Invalid QR code',
      };
    } catch (e) {
      developer.log('Error processing QR code: $e');
      return {
        'success': false,
        'message': 'Error processing QR code: $e',
      };
    }
  }
}

class QRScannerWidget extends StatefulWidget {
  final Function(String) onQRViewCreated;
  final Function()? onCancel;

  const QRScannerWidget({
    super.key,
    required this.onQRViewCreated,
    this.onCancel,
  });

  @override
  _QRScannerWidgetState createState() => _QRScannerWidgetState();
}

class _QRScannerWidgetState extends State<QRScannerWidget> {
  MobileScannerController? controller;
  bool isScanned = false;
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }
  
  Future<void> _initializeCamera() async {
    try {
      developer.log('Initializing QR scanner camera');
      controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
        formats: const [BarcodeFormat.qrCode],
        torchEnabled: false,
      );
      
      // Add a safety timeout to restart camera if it doesn't initialize properly
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && !isScanned && !isProcessing && controller != null) {
          try {
            // If camera isn't working, try restarting it
            controller?.stop().then((_) {
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted && !isScanned && !isProcessing) {
                  controller?.start();
                }
              });
            });
          } catch (e) {
            developer.log('Error in camera restart timeout: $e');
          }
        }
      });
    } catch (e) {
      developer.log('Error initializing scanner controller: $e');
    }
  }

  @override
  void dispose() {
    try {
      controller?.dispose();
    } catch (e) {
      developer.log('Error disposing scanner controller: $e');
    }
    super.dispose();
  }

  // Process the detected QR code with error handling
  Future<void> _processDetectedCode(String? code) async {
    if (code == null || isProcessing) return;
    
    try {
      // Set flags to prevent multiple processing of the same code
      setState(() {
        isProcessing = true;
      });
      
      developer.log('QR code detected: $code');
      
      // Stop the scanner but don't close it yet
      try {
        await controller?.stop();
      } catch (e) {
        developer.log('Error stopping scanner: $e');
      }
      
      // Process the code
      widget.onQRViewCreated(code);
      
      // Set scanned flag to prevent multiple scans
      setState(() {
        isScanned = true;
      });
    } catch (e) {
      developer.log('Error processing detected QR code: $e');
      
      // Reset processing state to allow another attempt
      setState(() {
        isProcessing = false;
      });
      
      // Try to restart the scanner if there was an error
      try {
        await controller?.start();
      } catch (e) {
        developer.log('Error restarting scanner: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (widget.onCancel != null) {
              widget.onCancel!();
            }
            Navigator.of(context).pop();
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 5,
              child: controller != null 
                ? MobileScanner(
                    controller: controller!,
                    onDetect: (capture) {
                      final List<Barcode> barcodes = capture.barcodes;
                      if (barcodes.isNotEmpty && !isScanned && !isProcessing) {
                        final String? code = barcodes.first.rawValue;
                        if (code != null) {
                          _processDetectedCode(code);
                        }
                      }
                    },
                    errorBuilder: (context, error, child) {
                      developer.log('Mobile scanner error: $error');
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 60,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Scanner Error: ${error.errorCode}',
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: const Text('Go Back'),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                : const Center(
                    child: Text('Error initializing camera'),
                  ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Scan the QR code provided by the organizers',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (isProcessing) ...[
                    const SizedBox(height: 16),
                    const CircularProgressIndicator.adaptive(),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 