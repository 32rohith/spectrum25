import 'package:flutter/material.dart';
import 'dart:ui';
import '../models/team.dart';
import '../theme/app_theme.dart';
import '../utils/glass_morphism.dart';
import 'tabs/home_tab.dart';
import 'tabs/leaderboard_tab.dart';
import 'tabs/food_tab.dart';
import 'tabs/team_details_tab.dart';
import 'tabs/project_submission_tab.dart';

class MainAppScreen extends StatefulWidget {
  final Team team;

  const MainAppScreen({
    super.key,
    required this.team,
  });

  @override
  _MainAppScreenState createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  int _currentIndex = 0;
  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      HomeTab(team: widget.team),
      LeaderboardTab(),
      FoodTab(),
      TeamDetailsTab(team: widget.team),
      ProjectSubmissionTab(team: widget.team),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.leaderboard),
              label: 'Leaderboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.fastfood),
              label: 'Food',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people),
              label: 'Team',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.upload_file),
              label: 'Submit',
            ),
          ],
        ),
      ),
    );
  }
} 