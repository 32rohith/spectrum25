import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';

class EmailService {
  // SMTP configuration
  final String _smtpHost = 'smtp.example.com'; // Replace with your SMTP server
  final int _smtpPort = 587; // Standard SMTP port
  final String _username = 'notifications@yourapp.com'; // Replace with your email
  final String _password = 'your_password'; // Replace with your password
  final String _fromName = 'Spectrum App'; // Name shown in the email
  
  // Send QR code via email
  Future<bool> sendQRCodeEmail({
    required String recipientEmail,
    required String memberName,
    required String teamName,
    required String qrCodeData,
  }) async {
    try {
      // Create SMTP server configuration
      final smtpServer = SmtpServer(
        _smtpHost,
        port: _smtpPort,
        username: _username,
        password: _password,
        ssl: false,
        allowInsecure: true,
      );
      
      // Extract QR data from JSON string
      Map<String, dynamic> qrJson = json.decode(qrCodeData);
      
      // Create email message
      final message = Message()
        ..from = Address(_username, _fromName)
        ..recipients.add(recipientEmail)
        ..subject = 'Your Spectrum App Meal QR Code'
        ..html = '''
          <div style="font-family: Arial, sans-serif; padding: 20px; max-width: 600px; margin: 0 auto;">
            <h2 style="color: #333;">Your Spectrum App Meal QR Code</h2>
            <p>Hello $memberName,</p>
            <p>Here is your permanent QR code for meal tracking at Spectrum events. Please save this email or take a screenshot of the QR code to present at meal service.</p>
            <div style="background-color: #f5f5f5; padding: 20px; text-align: center; border-radius: 8px; margin: 20px 0;">
              <p style="font-weight: bold; margin-bottom: 10px;">$memberName - $teamName</p>
              <img src="cid:qr_code" alt="Meal QR Code" style="width: 250px; height: 250px;">
              <p style="font-size: 12px; color: #666; margin-top: 10px;">This is your permanent meal QR code</p>
            </div>
            <p>When you arrive at a meal service, just show this QR code to the counter staff.</p>
            <p>If you have any questions, please contact the organizers.</p>
            <p>Thank you,<br>Spectrum Team</p>
          </div>
        ''';
      
      // For testing purposes, we'll use a text-based QR representation
      // In a production app, you'd generate an actual PNG image
      message.text = '''
        Your QR Code for $memberName from $teamName:
        
        ${qrCodeData.substring(0, 50)}...
        
        Please show this QR code at the meal counter.
      ''';
      
      // Send the email
      final sendReport = await send(message, smtpServer);
      developer.log('Email sent: ${sendReport.toString()}');
      return true;
    } catch (e) {
      developer.log('Error sending QR code email: $e');
      return false;
    }
  }
  
  // Check if the device is iOS
  bool isIOS() {
    return Platform.isIOS;
  }
} 