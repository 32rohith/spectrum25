import 'package:flutter/material.dart';
import 'dart:ui';
import '../theme/app_theme.dart';
import '../utils/glass_morphism.dart';
import '../services/auth_service.dart';
import 'welcome_screen.dart';
import 'tabs/oc_checkin_tab.dart';
import 'tabs/oc_food_tab.dart';
import 'tabs/oc_teams_tab.dart';

class OCMainScreen extends StatefulWidget {
  const OCMainScreen({super.key});

  @override
  _OCMainScreenState createState() => _OCMainScreenState();
}

class _OCMainScreenState extends State<OCMainScreen> {
  int _currentIndex = 0;
  late final List<Widget> _tabs;
  late final List<String> _tabTitles;

  @override
  void initState() {
    super.initState();
    _tabs = [
      const OCCheckinTab(),
      const OCFoodTab(),
      const OCTeamsTab(),
    ];
    
    _tabTitles = [
      'Check-in',
      'Food',
      'Teams',
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size for responsive design
    final Size screenSize = MediaQuery.of(context).size;
    final double screenWidth = screenSize.width;
    final double screenHeight = screenSize.height;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'OC Panel - ${_tabTitles[_currentIndex]}',
          style: TextStyle(
            color: AppTheme.textPrimaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Icons.logout,
              color: AppTheme.accentColor,
            ),
            onPressed: () async {
              // Clear saved credentials and navigate to welcome screen
              final authService = AuthService();
              await authService.clearSavedCredentials();
              
              // Use pushReplacement to prevent going back with back button
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => const WelcomeScreen(),
                ),
              );
            },
          ),
        ],
      ),
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
            child: _tabs[_currentIndex],
          ),
        ],
      ),
      bottomNavigationBar: GlassMorphism(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        opacity: 0.1,
        blur: 10,
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppTheme.primaryColor,
          unselectedItemColor: AppTheme.textSecondaryColor,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.fact_check),
              label: 'Check-in',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.fastfood),
              label: 'Food',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people),
              label: 'Teams',
            ),
          ],
        ),
      ),
    );
  }
} 