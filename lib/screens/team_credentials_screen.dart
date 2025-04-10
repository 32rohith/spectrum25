import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../models/team.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'qr_verification_screen.dart';

class TeamCredentialsScreen extends StatefulWidget {
  final Team team;
  final Map<String, dynamic>? teamAuth;
  final Map<String, dynamic>? leaderAuth;
  final List<Map<String, dynamic>>? membersAuth;

  const TeamCredentialsScreen({
    super.key,
    required this.team,
    this.teamAuth,
    this.leaderAuth,
    this.membersAuth,
  });

  @override
  _TeamCredentialsScreenState createState() => _TeamCredentialsScreenState();
}

class _TeamCredentialsScreenState extends State<TeamCredentialsScreen> {
  bool _showPasswords = false;

  void _copyToClipboard(BuildContext context, String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.accentColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Team Credentials'),
      body: Stack(
        children: [
          // Black Background
          Container(
            color: AppTheme.backgroundColor,
          ),
          
          // Blue Blurred Circle - Top Left
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryColor.withOpacity(0.3),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.transparent,
                  ),
                ),
              ),
            ),
          ),
          
          // Blue Blurred Circle - Bottom Right
          Positioned(
            bottom: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accentColor.withOpacity(0.3),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.transparent,
                  ),
                ),
              ),
            ),
          ),
          
          // Main Content
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(24.0),
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 80,
                ),
                const SizedBox(height: 24),
                Text(
                  'Registration Successful!',
                  style: TextStyle(
                    color: AppTheme.textPrimaryColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Your team "${widget.team.teamName}" has been registered.',
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      icon: Icon(
                        _showPasswords ? Icons.visibility_off : Icons.visibility,
                        color: Colors.white,
                      ),
                      label: Text(
                        _showPasswords ? "Hide Passwords" : "Show Passwords",
                        style: const TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _showPasswords = !_showPasswords;
                        });
                      },
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Team Credentials Card
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Team Information (For Records Only)',
                        style: TextStyle(
                          color: AppTheme.accentColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please save this team information for your records. Team members will use their individual credentials to login.',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Username
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.glassBorderColor),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.alternate_email,
                              color: AppTheme.primaryColor,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Team ID',
                                    style: TextStyle(
                                      color: AppTheme.textSecondaryColor,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.team.username,
                                    style: TextStyle(
                                      color: AppTheme.textPrimaryColor,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.copy,
                                color: AppTheme.accentColor,
                              ),
                              onPressed: () => _copyToClipboard(
                                context,
                                widget.team.username,
                                'Team ID copied to clipboard',
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Password
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.glassBorderColor),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.vpn_key,
                              color: AppTheme.primaryColor,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Team Password',
                                    style: TextStyle(
                                      color: AppTheme.textSecondaryColor,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _showPasswords 
                                      ? widget.team.password
                                      : '••••••••••',
                                    style: TextStyle(
                                      color: AppTheme.textPrimaryColor,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.copy,
                                color: AppTheme.accentColor,
                              ),
                              onPressed: () => _copyToClipboard(
                                context,
                                widget.team.password,
                                'Team password copied to clipboard',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Leader Credentials Card
                if (widget.leaderAuth != null)
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Team Leader Credentials',
                              style: TextStyle(
                                color: AppTheme.accentColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Credentials for ${widget.team.leader.name}',
                          style: TextStyle(
                            color: AppTheme.textSecondaryColor,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Username
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.glassBorderColor),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.alternate_email,
                                color: AppTheme.primaryColor,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Username',
                                      style: TextStyle(
                                        color: AppTheme.textSecondaryColor,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      widget.leaderAuth!['username'],
                                      style: TextStyle(
                                        color: AppTheme.textPrimaryColor,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.copy,
                                  color: AppTheme.accentColor,
                                ),
                                onPressed: () => _copyToClipboard(
                                  context,
                                  widget.leaderAuth!['username'],
                                  'Leader username copied to clipboard',
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Password
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.glassBorderColor),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.vpn_key,
                                color: AppTheme.primaryColor,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Password',
                                      style: TextStyle(
                                        color: AppTheme.textSecondaryColor,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _showPasswords 
                                        ? widget.leaderAuth!['password'] 
                                        : '••••••••••',
                                      style: TextStyle(
                                        color: AppTheme.textPrimaryColor,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.copy,
                                  color: AppTheme.accentColor,
                                ),
                                onPressed: () => _copyToClipboard(
                                  context,
                                  widget.leaderAuth!['password'],
                                  'Leader password copied to clipboard',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // Members Credentials Cards
                if (widget.membersAuth != null && widget.membersAuth!.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Team Members Credentials',
                    style: TextStyle(
                      color: AppTheme.textPrimaryColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ...widget.membersAuth!.asMap().entries.map((entry) {
                    final index = entry.key;
                    final memberAuth = entry.value;
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.person,
                                  color: AppTheme.primaryColor,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Member: ${memberAuth['name']}',
                                    style: TextStyle(
                                      color: AppTheme.accentColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // Username
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.cardColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.glassBorderColor),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.alternate_email,
                                    color: AppTheme.primaryColor,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Username',
                                          style: TextStyle(
                                            color: AppTheme.textSecondaryColor,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          memberAuth['username'],
                                          style: TextStyle(
                                            color: AppTheme.textPrimaryColor,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.copy,
                                      color: AppTheme.accentColor,
                                      size: 20,
                                    ),
                                    onPressed: () => _copyToClipboard(
                                      context,
                                      memberAuth['username'],
                                      'Username copied to clipboard',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 8),
                            
                            // Password
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.cardColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.glassBorderColor),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.vpn_key,
                                    color: AppTheme.primaryColor,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Password',
                                          style: TextStyle(
                                            color: AppTheme.textSecondaryColor,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _showPasswords 
                                            ? memberAuth['password'] 
                                            : '••••••••••',
                                          style: TextStyle(
                                            color: AppTheme.textPrimaryColor,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.copy,
                                      color: AppTheme.accentColor,
                                      size: 20,
                                    ),
                                    onPressed: () => _copyToClipboard(
                                      context,
                                      memberAuth['password'],
                                      'Password copied to clipboard',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
                
                const SizedBox(height: 24),
                
                Text(
                  'Important: Please save these credentials!',
                  style: TextStyle(
                    color: AppTheme.accentColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Each team member must use their own login credentials.',
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 32),
                
                // Proceed Button
                GlassButton(
                  text: 'Proceed to Verification',
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => QRVerificationScreen(team: widget.team),
                      ),
                    );
                  },
                  icon: Icons.arrow_forward,
                ),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 