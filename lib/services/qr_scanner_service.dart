import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/material.dart';
import 'auth_service.dart';

class QRScannerService {
  final AuthService _authService = AuthService();
  
  Future<Map<String, dynamic>> processQRCode(String qrData) async {
    try {
      // Check if QR data is valid (it should contain a team verification token)
      if (qrData.startsWith('verify_team:')) {
        // Extract team ID from QR data
        final teamId = qrData.split(':')[1];
        
        // Verify the team
        return await _authService.verifyTeam(teamId);
      } else {
        return {
          'success': false,
          'message': 'Invalid QR code',
        };
      }
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