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
      
      // Extract QR data from JSON string - don't modify the original data
      developer.log('Parsing QR code data');
      final originalQrData = qrCodeData; // Keep the original data untouched
      
      // Create email message with the QR data text directly
      developer.log('Creating email message with QR data text');
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
                $originalQrData
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
          $originalQrData
          
          Thank you,
          Spectrum Team
        ''';
      
      // Generate a backup text file with QR data
      final qrFileName = 'spectrum_meal_qr_${memberName.replaceAll(' ', '_')}.txt';
      final qrFile = await _generateQRCodeFile(originalQrData, qrFileName, memberName, teamName);
      
      // Attach the backup file if it was created successfully
      if (qrFile != null) {
        message.attachments.add(FileAttachment(qrFile));
        developer.log('QR data text file attached to email');
      }
      
      developer.log('Email message created with direct QR data text, attempting to send');
      
      // Send the email
      final sendReport = await send(message, smtpServer);
      developer.log('Email sent successfully: ${sendReport.toString()}');
      return true;
    } catch (e) {
      developer.log('Error sending QR code email to $recipientEmail: $e', error: e, stackTrace: StackTrace.current);
      return false;
    }
  }
  
  // Generate a QR code text file
  Future<File?> _generateQRCodeFile(String qrData, String fileName, String memberName, String teamName) async {
    try {
      developer.log('Generating QR code text file');
      
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
      developer.log('Error generating QR file: $e', error: e);
      return null;
    }
  }
  
  // Check if the device is iOS
  bool isIOS() {
    return Platform.isIOS;
  }
} 