import 'package:flutter/material.dart';
import 'dart:ui';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'team_member_details.dart';
import 'package:flutter/services.dart';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../models/team.dart';
import 'team_credentials_screen.dart';
import '../services/team_service.dart';

class TeamLeaderSignupScreen extends StatefulWidget {
  const TeamLeaderSignupScreen({super.key});

  @override
  State<TeamLeaderSignupScreen> createState() => _TeamLeaderSignupScreenState();
}

class _TeamLeaderSignupScreenState extends State<TeamLeaderSignupScreen> {
  final _teamNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TeamService _teamService = TeamService();
  bool _isLoading = false;
  String? _errorMessage;
  bool _isCheckingTeamName = false;
  bool _teamNameAlreadyRegistered = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _teamNameController.addListener(_onTeamNameChanged);
  }

  void _onTeamNameChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      // Only perform check if team name has reasonable length
      if (_teamNameController.text.length > 2) {
        _checkTeamNameExistence(_teamNameController.text);
      }
    });
  }

  Future<void> _checkTeamNameExistence(String teamName) async {
    setState(() {
      _isCheckingTeamName = true;
      _teamNameAlreadyRegistered = false;
      _errorMessage = null;
    });
    
    try {
      // Check if team name exists in Firebase
      final isRegistered = await _isTeamRegistered(teamName);
      
      setState(() {
        _isCheckingTeamName = false;
        _teamNameAlreadyRegistered = isRegistered;
        
        if (isRegistered) {
          _errorMessage = 'This team has already been registered. Each team can only register once.';
        }
      });
    } catch (e) {
      setState(() {
        _isCheckingTeamName = false;
        _errorMessage = null;
      });
    }
  }

  // Check if team name exists in the teamNames collection
  Future<bool> _teamExists(String teamName) async {
    developer.log('Checking if team exists: $teamName');
    
    if (teamName.trim().isEmpty) {
      developer.log('Team name is empty');
      return false;
    }
    
    // Use TeamService to check if team exists in Firestore
    final exists = await _teamService.teamNameExists(teamName);
    
    if (exists) {
      developer.log('Team found in teamNames collection!');
    } else {
      developer.log('Team not found in teamNames collection');
    }
    
    return exists;
  }

  // Check if team is already registered in Firebase
  Future<bool> _isTeamRegistered(String teamName) async {
    try {
      developer.log('Checking if team is already registered: $teamName');
      
      if (teamName.trim().isEmpty) {
        return false;
      }
      
      // Normalize the team name by trimming spaces and converting to lowercase for comparison
      final normalizedTeamName = teamName.trim().toLowerCase();
      
      // Query teams collection by both fields that could contain the team name
      final queryByTeamName = await _firestore
          .collection('teams')
          .where('teamName', isEqualTo: teamName)
          .limit(1)
          .get();
      
      if (queryByTeamName.docs.isNotEmpty) {
        developer.log('Team found by exact teamName match: $teamName');
        return true;
      }
      
      // Try a case-insensitive search (requires Firestore index for this field)
      final allTeams = await _firestore
          .collection('teams')
          .get();
      
      // Manually check all team names for case-insensitive matches
      for (var doc in allTeams.docs) {
        final data = doc.data();
        
        // Check both teamName and name fields
        final docTeamName = (data['teamName'] ?? '').toString().trim().toLowerCase();
        final docName = (data['name'] ?? '').toString().trim().toLowerCase();
        
        if (docTeamName == normalizedTeamName || docName == normalizedTeamName) {
          developer.log('Team found by case-insensitive match: $teamName');
          return true;
        }
      }
      
      // No matching team found
      developer.log('Team not registered in database: $teamName');
      return false;
    } catch (e) {
      developer.log('Error checking team registration: $e');
      // Show error in UI instead of silently failing
      setState(() {
        _errorMessage = 'Error checking team registration status: $e';
      });
      // Default to false if there's an error
      return false;
    }
  }
  
  // Get team data by name from Firestore
  Future<Map<String, dynamic>?> _getTeamDataByName(String teamName) async {
    try {
      developer.log('Getting team data for: $teamName');
      
      if (teamName.trim().isEmpty) {
        return null;
      }
      
      // Query teams collection by teamName
      final queryByTeamName = await _firestore
          .collection('teams')
          .where('teamName', isEqualTo: teamName)
          .limit(1)
          .get();
      
      if (queryByTeamName.docs.isNotEmpty) {
        developer.log('Team data found by exact teamName match');
        return queryByTeamName.docs.first.data();
      }
      
      // Try a case-insensitive search if exact match fails
      final normalizedTeamName = teamName.trim().toLowerCase();
      final allTeams = await _firestore
          .collection('teams')
          .get();
      
      // Manually check all team names for case-insensitive matches
      for (var doc in allTeams.docs) {
        final data = doc.data();
        final docTeamName = (data['teamName'] ?? '').toString().trim().toLowerCase();
        
        if (docTeamName == normalizedTeamName) {
          developer.log('Team data found by case-insensitive match');
          return data;
        }
      }
      
      developer.log('No team data found for: $teamName');
      return null;
    } catch (e) {
      developer.log('Error getting team data: $e');
      setState(() {
        _errorMessage = 'Error retrieving team data: $e';
      });
      return null;
    }
  }

  @override
  void dispose() {
    _teamNameController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _proceedToMemberDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (_formKey.currentState!.validate()) {
      final teamName = _teamNameController.text.trim();
      
      // First check if team is already registered in database
      final isAlreadyRegistered = await _isTeamRegistered(teamName);
      
      if (isAlreadyRegistered) {
        // Check if the team is verified or not
        final teamData = await _getTeamDataByName(teamName);
        
        if (teamData != null) {
          // If team exists but is not verified, show credentials instead of error
          if (teamData['isVerified'] == false) {
            developer.log('Team found but not verified, showing credentials');
            
            // Navigate to credentials screen with limited info
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TeamCredentialsScreen(
                  team: Team.fromJson(teamData),
                  showLimitedInfo: true,
                ),
              ),
            );
            setState(() {
              _isLoading = false;
            });
            return;
          } else {
            // Team is already registered and verified
            setState(() {
              _teamNameAlreadyRegistered = true;
              _errorMessage = 'This team has already been registered. Each team can only register once.';
              _isLoading = false;
            });
            return;
          }
        } else {
          // Team is registered but data couldn't be retrieved
          setState(() {
            _teamNameAlreadyRegistered = true;
            _errorMessage = 'This team has already been registered. Each team can only register once.';
            _isLoading = false;
          });
          return;
        }
      }
      
      // Check if team exists in approved teams list
      final teamExists = await _teamExists(teamName);
      
      // For testing, allow "Test" team to always pass
      if (teamName.toLowerCase() == "test" || teamExists) {
        // Navigate to team member details screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TeamMemberDetailsScreen(teamName: teamName),
          ),
        );
      } else {
        setState(() {
          _errorMessage = 'Team not found. Please enter a valid team name.';
        });
      }
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Create Team'),
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
            child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width - 48,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.05),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.group_add,
                          color: AppTheme.primaryColor,
                          size: 60,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Let\'s Start Your Hackathon Journey!',
                        style: TextStyle(
                          color: AppTheme.textPrimaryColor,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter your registered team name',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),
                      
                      // Team name field
                      CustomTextField(
                        label: 'Team Name',
                        hint: 'Enter your team name',
                        controller: _teamNameController,
                        prefixIcon: Icon(
                          Icons.groups,
                          color: AppTheme.textSecondaryColor,
                        ),
                        suffixIcon: _isCheckingTeamName 
                          ? SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.accentColor,
                              ),
                            ) 
                          : _teamNameAlreadyRegistered
                            ? Icon(
                                Icons.error,
                                color: Colors.red,
                              )
                            : _teamNameController.text.isNotEmpty && _teamNameController.text.length >= 3
                              ? Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                )
                              : null,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a team name';
                          } else if (value.length < 3) {
                            return 'Team name must be at least 3 characters';
                          } else if (value.length > 20) {
                            return 'Team name must be less than 20 characters';
                          } else if (_teamNameAlreadyRegistered) {
                            return 'This team has already been registered';
                          }
                          return null;
                        },
                      ),
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      const SizedBox(height: 40),
                      
                      // Next button
                      SizedBox(
                        width: double.infinity,
                        child: GlassButton(
                          text: 'Check & Proceed',
                          onPressed: _proceedToMemberDetails,
                          isLoading: _isLoading,
                          icon: Icons.arrow_forward,
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Info text
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.cardColor.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.glassBorderColor),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: AppTheme.accentColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Team Authentication:',
                                    style: TextStyle(
                                      color: AppTheme.accentColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Please enter your pre-registered team name exactly as provided. Only registered teams can proceed to the next step.',
                              style: TextStyle(
                                color: AppTheme.textSecondaryColor,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Add extra padding at the bottom to ensure scrollability
                      const SizedBox(height: 40),
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