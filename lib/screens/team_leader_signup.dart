import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'team_member_details.dart';
import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import 'dart:developer' as developer;

class TeamLeaderSignupScreen extends StatefulWidget {
  const TeamLeaderSignupScreen({super.key});

  @override
  _TeamLeaderSignupScreenState createState() => _TeamLeaderSignupScreenState();
}

class _TeamLeaderSignupScreenState extends State<TeamLeaderSignupScreen> {
  final _teamNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  List<List<dynamic>> _teamsData = [];
  String? _errorMessage;
  bool _isCSVLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadCSV();
  }

  Future<void> _loadCSV() async {
    try {
      final csvString = await rootBundle.loadString('assets/test.csv');
      setState(() {
        _teamsData = const CsvToListConverter().convert(csvString);
        _isCSVLoaded = true;
        developer.log('CSV loaded successfully: $_teamsData');
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load teams data. Please try again later.';
        developer.log('Error loading CSV: $e');
      });
    }
  }

  bool _teamExists(String teamName) {
    developer.log('Checking if team exists: $teamName');
    developer.log('Teams data: $_teamsData');
    
    if (_teamsData.isEmpty) {
      developer.log('Teams data is empty');
      return false;
    }
    
    // Skip header row and check if team name exists
    for (int i = 1; i < _teamsData.length; i++) {
      developer.log('Checking team: ${_teamsData[i]}');
      if (_teamsData[i].isNotEmpty) {
        final csvTeamName = _teamsData[i][0].toString().trim();
        developer.log('Comparing: "$csvTeamName" with "$teamName"');
        
        if (csvTeamName.toLowerCase() == teamName.toLowerCase()) {
          developer.log('Team found!');
          return true;
        }
      }
    }
    developer.log('Team not found');
    return false;
  }

  @override
  void dispose() {
    _teamNameController.dispose();
    super.dispose();
  }

  void _proceedToMemberDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (!_isCSVLoaded) {
      // If CSV is not loaded yet, try loading it again
      await _loadCSV();
      if (!_isCSVLoaded) {
        setState(() {
          _errorMessage = 'Still loading team data. Please try again in a moment.';
          _isLoading = false;
        });
        return;
      }
    }

    if (_formKey.currentState!.validate()) {
      final teamName = _teamNameController.text.trim();
      
      // For testing, allow "Test" team to always pass
      if (teamName.toLowerCase() == "test" || _teamExists(teamName)) {
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryDarkColor.withOpacity(0.8),
              AppTheme.backgroundColor,
              AppTheme.primaryDarkColor.withOpacity(0.6),
            ],
          ),
        ),
        child: SafeArea(
          child: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_isCSVLoaded) 
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.accentColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Loading team data...',
                            style: TextStyle(
                              color: AppTheme.textSecondaryColor,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
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
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a team name';
                      } else if (value.length < 3) {
                        return 'Team name must be at least 3 characters';
                      } else if (value.length > 20) {
                        return 'Team name must be less than 20 characters';
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
                  GlassButton(
                    text: 'Check & Proceed',
                    onPressed: _proceedToMemberDetails,
                    isLoading: _isLoading,
                    icon: Icons.arrow_forward,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 