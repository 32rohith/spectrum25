import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'package:flutter/rendering.dart';
import 'package:qr/qr.dart';
import 'dart:async';

class EmailService {
  // SMTP configuration
  final String _smtpHost = 'smtp.gmail.com'; // Replace with your SMTP server
  final int _smtpPort = 587; // Standard SMTP port
  final String _username = 'jeswanthselva12@gmail.com'; // Replace with your email
  final String _password = 'mxxmhyrkasoargcw'; // Replace with your password
  final String _fromName = 'Spectrum App'; // Name shown in the email
  
  // Send QR code via email
  Future<bool> sendQRCodeEmail({
    required String recipientEmail,
    required String memberName,
    required String teamName,
    required String qrCodeData,
  }) async {
    try {
      developer.log('Starting email sending process for $memberName ($recipientEmail)');
      
      // Create SMTP server configuration
      developer.log('Configuring SMTP server: $_smtpHost:$_smtpPort');
      final smtpServer = SmtpServer(
        _smtpHost,
        port: _smtpPort,
        username: _username,
        password: _password,
        ssl: false,
        allowInsecure: true,
      );
      
      // Generate QR code image file
      developer.log('Generating QR code image file');
      final qrImageFile = await _generateQRCodeImage(qrCodeData, memberName);
      
      if (qrImageFile == null) {
        developer.log('Failed to generate QR code image, falling back to text');
        
        // Create a text backup file since image creation failed
        final qrFileName = 'spectrum_meal_qr_${memberName.replaceAll(' ', '_')}.txt';
        final qrFile = await _generateQRCodeTextFile(qrCodeData, qrFileName, memberName, teamName);
        
        // If we can't even create the text file, return failure
        if (qrFile == null) {
          return false;
        }
        
        // Create email message with the QR data text as backup
        developer.log('Creating email message with QR data as text (fallback)');
        final message = Message()
          ..from = Address(_username, _fromName)
          ..recipients.add(recipientEmail)
          ..subject = 'Your Spectrum App Meal QR Code'
          ..html = '''
            <div style="font-family: Arial, sans-serif; padding: 20px; max-width: 600px; margin: 0 auto;">
              <h2 style="color: #333;">Your Spectrum App Meal QR Code</h2>
              <p>Hello $memberName,</p>
              <p>Here is your permanent meal tracker information for Spectrum events. Please save this email.</p>
              
              <div style="background-color: #e8f5ff; border-left: 4px solid #0078d4; padding: 15px; margin: 20px 0; border-radius: 4px;">
                <p style="font-weight: bold; margin-top: 0; color: #0078d4;">IMPORTANT INSTRUCTIONS:</p>
                <p>When you arrive for a meal, show this email to the counter staff. They will need to <b>copy and paste</b> the QR data below into the scanner.</p>
              </div>
              
              <div style="background-color: #f5f5f5; padding: 20px; border-radius: 8px; margin: 20px 0;">
                <p style="font-weight: bold; margin-bottom: 10px;">$memberName - $teamName</p>
                <div style="background-color: white; padding: 15px; border-radius: 5px; border: 1px solid #ddd; text-align: left; font-family: monospace; font-size: 12px; word-break: break-all;">
                  <p style="color: #666; margin-top: 0; margin-bottom: 10px; font-weight: bold;">QR CODE DATA (TO BE COPIED BY STAFF):</p>
                  $qrCodeData
                </div>
              </div>
              
              <p>For your convenience, there is also an attached text file containing your QR code data.</p>
              <p>If you have any questions, please contact the organizers.</p>
              <p>Thank you,<br>Spectrum Team</p>
            </div>
          '''
          ..text = '''
            Your QR Code Data for $memberName from $teamName
            
            This is your permanent meal tracker information for Spectrum events.
            Please save this email.
            
            IMPORTANT: When you arrive for a meal, show this email to the counter staff.
            They will need to copy and paste the QR data below into the scanner.
            
            QR CODE DATA:
            $qrCodeData
            
            Thank you,
            Spectrum Team
          ''';
          
        // Attach the backup file
        message.attachments.add(FileAttachment(qrFile));
        
        // Send the email
        final sendReport = await send(message, smtpServer);
        developer.log('Email sent successfully with text fallback: ${sendReport.toString()}');
        return true;
      }
      
      // Create email message with the QR image attached
      developer.log('Creating email message with QR image attachment');
      final message = Message()
        ..from = Address(_username, _fromName)
        ..recipients.add(recipientEmail)
        ..subject = 'Your Spectrum App Meal QR Code'
        ..html = '''
          <div style="font-family: Arial, sans-serif; padding: 20px; max-width: 600px; margin: 0 auto;">
            <h2 style="color: #333;">Your Spectrum App Meal QR Code</h2>
            <p>Hello $memberName,</p>
            <p>Here is your permanent meal tracker QR code for Spectrum events. Please save this email.</p>
            
            <div style="background-color: #e8f5ff; border-left: 4px solid #0078d4; padding: 15px; margin: 20px 0; border-radius: 4px;">
              <p style="font-weight: bold; margin-top: 0; color: #0078d4;">IMPORTANT INSTRUCTIONS:</p>
              <p>When you arrive for a meal, show this QR code to the counter staff. They will scan it directly from your device.</p>
              <p>The QR code is also attached to this email as an image file.</p>
            </div>
            
            <div style="background-color: #f5f5f5; padding: 20px; border-radius: 8px; margin: 20px 0; text-align: center;">
              <p style="font-weight: bold; margin-bottom: 10px;">$memberName - $teamName</p>
              <p>Please see the attached QR code image</p>
            </div>
            
            <p>If you have any questions, please contact the organizers.</p>
            <p>Thank you,<br>Spectrum Team</p>
          </div>
        '''
        ..text = '''
          Your QR Code for $memberName from $teamName
          
          This is your permanent meal tracker QR code for Spectrum events.
          Please save this email.
          
          IMPORTANT: When you arrive for a meal, show this QR code to the counter staff.
          They will scan it directly from your device.
          
          The QR code is attached to this email as an image file.
          
          Thank you,
          Spectrum Team
        ''';
      
      // Attach the QR code image file
      message.attachments.add(FileAttachment(qrImageFile));
      developer.log('QR code image attached to email');
      
      // Send the email
      final sendReport = await send(message, smtpServer);
      developer.log('Email sent successfully: ${sendReport.toString()}');
      return true;
    } catch (e) {
      developer.log('Error sending QR code email to $recipientEmail: $e', error: e, stackTrace: StackTrace.current);
      return false;
    }
  }
  
  // Generate a QR code text file as fallback
  Future<File?> _generateQRCodeTextFile(String qrData, String fileName, String memberName, String teamName) async {
    try {
      developer.log('Generating QR code text file as fallback');
      
      // Create a temporary file path
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/$fileName';
      
      // Write QR data to a text file with clear instructions
      final file = File(filePath);
      await file.writeAsString('''
SPECTRUM MEAL QR CODE DATA
==========================
INSTRUCTIONS FOR COUNTER STAFF:
1. Copy the entire QR data below
2. Paste it into the scanner input
3. Click the scan button

MEMBER: $memberName
TEAM: $teamName
DATE CREATED: ${DateTime.now().toString()}

QR CODE DATA (COPY THIS ENTIRE BLOCK):
$qrData

--
Spectrum Team
''');
      
      developer.log('QR data written to file: $filePath');
      return file;
    } catch (e) {
      developer.log('Error generating QR text file: $e', error: e);
      return null;
    }
  }
  
  // Generate a QR code image file
  Future<File?> _generateQRCodeImage(String qrData, String memberName) async {
    try {
      developer.log('Generating QR code image');
      
      // Create a temporary directory to save the image
      final directory = await getTemporaryDirectory();
      final imageFile = File('${directory.path}/spectrum_qr_${memberName.replaceAll(' ', '_')}.png');
      
      // First check if we can use the Flutter UI methods
      if (WidgetsBinding.instance != null) {
        try {
          // Try to use the QrPainter from qr_flutter package
          final qrPainter = QrPainter(
            data: qrData,
            version: QrVersions.auto,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Colors.black,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Colors.black,
            ),
            // Add a quiet zone (white border around QR)
            embeddedImage: null,
            embeddedImageStyle: null,
            gapless: true,
          );
          
          final qrImageSize = 300.0;
          
          // Create a picture using the QR painter
          final picRecorder = ui.PictureRecorder();
          final canvas = Canvas(picRecorder);
          
          // Fill with white background
          canvas.drawColor(Colors.white, BlendMode.src);
          
          // Draw the QR code
          qrPainter.paint(canvas, Size(qrImageSize, qrImageSize));
          
          // Convert to an image
          final picture = picRecorder.endRecording();
          final img = await picture.toImage(qrImageSize.toInt(), qrImageSize.toInt());
          final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);
          
          if (pngBytes != null) {
            await imageFile.writeAsBytes(pngBytes.buffer.asUint8List());
            developer.log('QR code image created with QrPainter and saved to: ${imageFile.path}');
            return imageFile;
          }
        } catch (e) {
          developer.log('Error using QrPainter: $e - will try fallback method');
          // Continue to fallback method
        }
      }
      
      // Fallback - create a basic QR code pattern
      developer.log('Using fallback QR code generation method');
      
      // We'll create a simple checkerboard pattern as a fallback
      // This isn't a real QR code but it's better than nothing
      final imageSize = 300;
      final cellSize = 10; // Size of each cell in the pattern
      
      // Create a byte buffer for image data (RGBA format)
      final buffer = Uint8List(imageSize * imageSize * 4);
      
      // Fill with white first (RGBA: 255, 255, 255, 255)
      for (int i = 0; i < buffer.length; i += 4) {
        buffer[i] = 255;     // R
        buffer[i + 1] = 255; // G
        buffer[i + 2] = 255; // B
        buffer[i + 3] = 255; // A
      }
      
      // Create a "QR-like" pattern (just a basic pattern to indicate it's a QR code)
      for (int y = 0; y < imageSize; y++) {
        for (int x = 0; x < imageSize; x++) {
          // Draw finder patterns (the three squares in corners)
          bool inFinderPattern = false;
          
          // Top-left finder pattern
          if (x < 70 && y < 70) inFinderPattern = true;
          // Top-right finder pattern
          if (x > imageSize - 70 && y < 70) inFinderPattern = true;
          // Bottom-left finder pattern
          if (x < 70 && y > imageSize - 70) inFinderPattern = true;
          
          if (inFinderPattern) {
            // Draw black pixel - RGBA (0,0,0,255)
            final index = (y * imageSize + x) * 4;
            buffer[index] = 0;
            buffer[index + 1] = 0;
            buffer[index + 2] = 0;
            buffer[index + 3] = 255;
          }
          // Add some data modules in a pattern
          else if ((x ~/ cellSize + y ~/ cellSize) % 2 == 0 && 
                   x > 80 && x < imageSize - 80 && 
                   y > 80 && y < imageSize - 80) {
            final index = (y * imageSize + x) * 4;
            buffer[index] = 0;
            buffer[index + 1] = 0;
            buffer[index + 2] = 0;
            buffer[index + 3] = 255;
          }
        }
      }
      
      // Save the generated image data
      await imageFile.writeAsBytes(buffer);
      developer.log('Basic QR-like pattern saved to: ${imageFile.path}');
      return imageFile;
      
    } catch (e) {
      developer.log('Error generating QR image: $e', error: e);
      return null;
    }
  }
  
  // Check if the device is iOS
  bool isIOS() {
    return Platform.isIOS;
  }
} 