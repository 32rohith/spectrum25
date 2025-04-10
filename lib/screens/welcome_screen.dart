import 'package:flutter/material.dart';
import 'dart:ui';
import '../theme/app_theme.dart';
import '../utils/glass_morphism.dart';
import '../widgets/common_widgets.dart';
import 'team_leader_signup.dart';
import 'login_screen.dart';
import 'oc_login_screen.dart';
import 'package:flutter/rendering.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Get screen size for responsive design
    final Size screenSize = MediaQuery.of(context).size;
    final double screenWidth = screenSize.width;
    final double screenHeight = screenSize.height;
    
    // Calculate responsive sizes
    final double titleFontSize = screenWidth * 0.11 > 40 ? 40 : screenWidth * 0.11;
    final double subtitleFontSize = screenWidth * 0.055 > 22 ? 22 : screenWidth * 0.055;
    final double cardIconSize = screenWidth * 0.07 > 28 ? 28 : screenWidth * 0.07;
    final double cardTitleSize = screenWidth * 0.045 > 18 ? 18 : screenWidth * 0.045;
    final double cardSubtitleSize = screenWidth * 0.035 > 14 ? 14 : screenWidth * 0.035;
    
    return Scaffold(
      body: Stack(
        children: [
          // Black Background
          Container(
            color: AppTheme.backgroundColor,
          ),
          
          // Blue Blurred Circle - Top Left
          Positioned(
            top: -screenHeight * 0.15,
            left: -screenWidth * 0.25,
            child: Container(
              width: screenWidth * 0.8,
              height: screenWidth * 0.8,
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
            bottom: -screenHeight * 0.15,
            right: -screenWidth * 0.25,
            child: Container(
              width: screenWidth * 0.8,
              height: screenWidth * 0.8,
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
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: screenHeight - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: screenHeight * 0.08),
                      // App Logo and Title
                      Text(
                        'SPECTRUM',
                        style: TextStyle(
                          color: AppTheme.textPrimaryColor,
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      Text(
                        'HACKATHON',
                        style: TextStyle(
                          color: AppTheme.accentColor,
                          fontSize: subtitleFontSize,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 4,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.06),
                      
                      // Team Leader Signup
                      GlassCard(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const TeamLeaderSignupScreen(),
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(screenWidth * 0.03),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.person_add,
                                color: AppTheme.primaryColor,
                                size: cardIconSize,
                              ),
                            ),
                            SizedBox(width: screenWidth * 0.04),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Team Leader Signup',
                                    style: TextStyle(
                                      fontSize: cardTitleSize,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimaryColor,
                                    ),
                                  ),
                                  Text(
                                    'Register your team for the hackathon',
                                    style: TextStyle(
                                      fontSize: cardSubtitleSize,
                                      color: AppTheme.textSecondaryColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: screenWidth * 0.02),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: AppTheme.textSecondaryColor,
                              size: screenWidth * 0.04,
                            ),
                          ],
                        ),
                      ),
                      
                      SizedBox(height: screenHeight * 0.02),
                      
                      // Combined Login for Team Leaders and Members
                      GlassCard(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(screenWidth * 0.03),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryLightColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.login,
                                color: AppTheme.primaryLightColor,
                                size: cardIconSize,
                              ),
                            ),
                            SizedBox(width: screenWidth * 0.04),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Team Login',
                                    style: TextStyle(
                                      fontSize: cardTitleSize,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimaryColor,
                                    ),
                                  ),
                                  Text(
                                    'Login as team leader or member',
                                    style: TextStyle(
                                      fontSize: cardSubtitleSize,
                                      color: AppTheme.textSecondaryColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: screenWidth * 0.02),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: AppTheme.textSecondaryColor,
                              size: screenWidth * 0.04,
                            ),
                          ],
                        ),
                      ),
                      
                      SizedBox(height: screenHeight * 0.08),
                      
                      // OC Member Access with Login text
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Are you an Organizing Committee member?',
                            style: TextStyle(
                              color: AppTheme.textSecondaryColor,
                              fontSize: cardSubtitleSize,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const OCLoginScreen(),
                                ),
                              );
                            },
                            child: Text(
                              'Log in',
                              style: TextStyle(
                                color: AppTheme.accentColor,
                                fontSize: cardSubtitleSize,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: screenHeight * 0.03),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}