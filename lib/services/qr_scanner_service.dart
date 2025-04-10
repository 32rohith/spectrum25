import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'auth_service.dart';

class QRScannerService {
  final AuthService _authService = AuthService();
  
  Future<Map<String, dynamic>> processQRCode(String qrData) async {
    try {
      // Check if QR data is valid for team verification
      if (qrData.startsWith('verify_team:')) {
        // Extract team ID from QR data
        final teamId = qrData.split(':')[1];
        
        // Verify the team
        return await _authService.verifyTeam(teamId);
      } 
      // Check if this is an OC verification QR code
      else if (qrData.contains('"id"') && qrData.contains('"ocCode"') && qrData.contains('"timestamp"')) {
        try {
          // Decode the JSON data
          final Map<String, dynamic> jsonData = json.decode(qrData);
          
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
              // Get the current user's team ID
              final currentUser = await _authService.getCurrentTeam();
              
              if (currentUser != null) {
                // Verify the team
                return await _authService.verifyTeam(currentUser.teamId);
              } else {
                return {
                  'success': false,
                  'message': 'Could not find your team information',
                };
              }
            } else if (!notExpired) {
              return {
                'success': false,
                'message': 'QR code has expired. Please ask for a new code.',
              };
            } else {
              return {
                'success': false,
                'message': 'Invalid verification code',
              };
            }
          }
        } catch (e) {
          return {
            'success': false,
            'message': 'Invalid QR code format',
          };
        }
      }
      
      return {
        'success': false,
        'message': 'Invalid QR code',
      };
    } catch (e) {
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

  @override
  void initState() {
    super.initState();
    controller = MobileScannerController();
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
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
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: MobileScanner(
              controller: controller,
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isNotEmpty && !isScanned) {
                  final String? code = barcodes.first.rawValue;
                  if (code != null) {
                    isScanned = true;
                    widget.onQRViewCreated(code);
                    controller?.stop();
                  }
                }
              },
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                'Scan the QR code provided by the organizers',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 