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
  
  // Generate and save QR code to local storage
  Future<File?> generateAndSaveQRCode(String qrData, String memberName) async {
    try {
      // IMPORTANT: Use the exact QR data, no modifications
      developer.log('Saving high-quality QR code from existing key. Length: ${qrData.length}');
      
      // Get the app's document directory
      final directory = await getApplicationDocumentsDirectory();
      final qrFilename = 'QR_${memberName.replaceAll(' ', '_')}.png';
      final qrFilePath = '${directory.path}/$qrFilename';
      
      // Use QrPainter with specific settings that match the successful example
      final qrPainter = QrPainter(
        data: qrData,
        version: QrVersions.auto,
        // Use low error correction for better scanning
        errorCorrectionLevel: QrErrorCorrectLevel.L,
        // Use square eye style that matches sample
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Colors.black,
        ),
        // Use square modules that match sample
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Colors.black,
        ),
        // Not gapless to match sample image
        gapless: false,
        embeddedImage: null,
        embeddedImageStyle: null,
      );
      
      // Use 300px for good quality
      final imageSize = 300.0;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      
      // Pure white background
      canvas.drawColor(Colors.white, BlendMode.src);
      
      // Draw QR with padding
      qrPainter.paint(canvas, Size(imageSize, imageSize));
      
      // Generate high resolution image (3x quality)
      final picture = recorder.endRecording();
      final img = await picture.toImage(
        (imageSize * 3).toInt(), 
        (imageSize * 3).toInt()
      );
      final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);
      
      if (pngBytes != null) {
        final file = File(qrFilePath);
        await file.writeAsBytes(pngBytes.buffer.asUint8List());
        developer.log('QR code saved successfully: $qrFilePath');
        return file;
      }
      
      developer.log('Failed to generate QR code image');
      return null;
    } catch (e) {
      developer.log('Error generating QR code: $e', error: e);
      return null;
    }
  }
  
  // Send QR code via email
  Future<bool> sendQRCodeEmail({
    required String recipientEmail,
    required String memberName,
    required String teamName,
    required String qrCodeData,
  }) async {
    try {
      developer.log('Starting email process for $memberName with key length: ${qrCodeData.length}');
      
      // Create SMTP server configuration
      final smtpServer = SmtpServer(
        _smtpHost,
        port: _smtpPort,
        username: _username,
        password: _password,
        ssl: false,
        allowInsecure: true,
      );
      
      // Generate and save QR code to local storage before sending
      final qrImageFile = await generateAndSaveQRCode(qrCodeData, memberName);
      
      // Create email message with simplified content
      final message = Message()
        ..from = Address(_username, _fromName)
        ..recipients.add(recipientEmail)
        ..subject = 'Spectrum Meal QR Code - $memberName'
        ..html = '''
          <div style="font-family: Arial, sans-serif; padding: 15px; max-width: 600px; margin: 0 auto;">
            <h2 style="color: #333;">Spectrum Meal QR Code</h2>
            
            <div style="background-color: #f8f9fa; border: 1px solid #ddd; padding: 15px; margin: 15px 0; border-radius: 4px; text-align: center;">
              <p style="font-weight: bold; font-size: 16px; margin-top: 0;">PLEASE DOWNLOAD THE ATTACHED QR CODE</p>
              <p>Save it to your device for scanning at meal service</p>
            </div>
            
            <p><strong>Name:</strong> $memberName</p>
            <p><strong>Team:</strong> $teamName</p>
            
            <div style="margin-top: 20px; border-top: 1px solid #ddd; padding-top: 15px;">
              <p style="font-weight: bold; color: #333;">INSTRUCTIONS:</p>
              <ol>
                <li>Download and save the attached QR code image</li>
                <li>When you arrive for a meal, show the QR code from your gallery/photos</li>
              </ol>
            </div>
          </div>
        '''
        ..text = '''
          SPECTRUM MEAL QR CODE - $memberName
          
          Name: $memberName
          Team: $teamName
          
          INSTRUCTIONS:
          1. Download and save the attached QR code image
          2. When you arrive for a meal, show the QR code from your gallery/photos
          
          Spectrum Team
        ''';
      
      // Attach the QR image if available
      if (qrImageFile != null) {
        message.attachments.add(FileAttachment(qrImageFile));
        developer.log('Attached QR code: ${qrImageFile.path}');
      }
      
      // Send the email
      final sendReport = await send(message, smtpServer);
      developer.log('Email sent successfully: ${sendReport.toString()}');
      return true;
    } catch (e) {
      developer.log('Error sending email: $e', error: e, stackTrace: StackTrace.current);
      return false;
    }
  }
  
  // Check if the device is iOS
  bool isIOS() {
    return Platform.isIOS;
  }
} 