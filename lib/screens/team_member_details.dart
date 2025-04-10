import 'package:flutter/material.dart';
import 'dart:ui';
import '../models/team.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/auth_service.dart';
import 'team_credentials_screen.dart';

class TeamMemberDetailsScreen extends StatefulWidget {
  final String teamName;

  const TeamMemberDetailsScreen({
    super.key,
    required this.teamName,
  });

  @override
  _TeamMemberDetailsScreenState createState() => _TeamMemberDetailsScreenState();
}

class _TeamMemberDetailsScreenState extends State<TeamMemberDetailsScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;
  
  // Leader details controllers
  final TextEditingController _leaderNameController = TextEditingController();
  final TextEditingController _leaderEmailController = TextEditingController();
  final TextEditingController _leaderPhoneController = TextEditingController();
  String _leaderDeviceValue = 'Android'; // Default device value for leader
  
  // List of members
  final List<MemberForm> _memberForms = [];
  final int _minMembers = 3; // For a total of 4 with the leader
  final int _maxMembers = 5; // For a total of 6 with the leader
  
  // Available device options
  final List<String> _deviceOptions = ['Android', 'iOS'];
  
  @override
  void initState() {
    super.initState();
    // Add initial empty member forms
    for (int i = 0; i < _minMembers; i++) {
      _memberForms.add(MemberForm(
        index: i,
        onRemove: _removeMember,
        deviceOptions: _deviceOptions,
      ));
    }
  }
  
  @override
  void dispose() {
    _leaderNameController.dispose();
    _leaderEmailController.dispose();
    _leaderPhoneController.dispose();
    for (var form in _memberForms) {
      form.dispose();
    }
    super.dispose();
  }

  void _addMemberForm() {
    if (_memberForms.length < _maxMembers) {
      setState(() {
        _memberForms.add(MemberForm(
          index: _memberForms.length,
          onRemove: _removeMember,
          deviceOptions: _deviceOptions,
        ));
      });
    }
  }

  void _removeMember(int index) {
    if (_memberForms.length > 1) {
      setState(() {
        _memberForms.removeAt(index);
        // Update indices for remaining forms
        for (int i = 0; i < _memberForms.length; i++) {
          // Replace with new instance with updated index
          _memberForms[i] = MemberForm.withNewIndex(_memberForms[i], i);
        }
      });
    }
  }

  Future<void> _registerTeam() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        // Create team leader
        final leader = TeamMember(
          name: _leaderNameController.text.trim(),
          email: _leaderEmailController.text.trim(),
          phone: _leaderPhoneController.text.trim(),
          device: _leaderDeviceValue,
        );

        // Create team members
        final members = _memberForms.map((form) => form.getMember()).toList();

        // Register team with Firebase
        final result = await _authService.registerTeam(
          teamName: widget.teamName,
          leader: leader,
          members: members,
        );

        setState(() {
          _isLoading = false;
        });

        if (result['success']) {
          // Navigate to credentials screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => TeamCredentialsScreen(
                team: result['team'],
                teamAuth: result['teamAuth'],
                leaderAuth: result['leaderAuth'],
                membersAuth: result['membersAuth'],
              ),
            ),
          );
        } else {
          setState(() {
            _errorMessage = result['message'];
          });
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'An error occurred: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Team Details'),
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
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(24.0),
                children: [
                  Text(
                    'Team "${widget.teamName}"',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter details for all team members',
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  
                  // Team Leader Section
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.star,
                              color: AppTheme.accentColor,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Team Leader',
                              style: TextStyle(
                                color: AppTheme.accentColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Leader Name
                        CustomTextField(
                          label: 'Full Name',
                          hint: 'Enter your full name',
                          controller: _leaderNameController,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Leader Email
                        CustomTextField(
                          label: 'Email',
                          hint: 'Enter your email address',
                          controller: _leaderEmailController,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Leader Phone
                        CustomTextField(
                          label: 'Phone Number',
                          hint: 'Enter your phone number',
                          controller: _leaderPhoneController,
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your phone number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Leader Device
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Text(
                                'Device',
                                style: TextStyle(
                                  color: AppTheme.textSecondaryColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: AppTheme.cardColor.withOpacity(0.5),
                                border: Border.all(
                                  color: AppTheme.glassBorderColor,
                                  width: 1,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  dropdownColor: AppTheme.cardColor,
                                  isExpanded: true,
                                  value: _leaderDeviceValue,
                                  icon: Icon(
                                    Icons.arrow_drop_down,
                                    color: AppTheme.textSecondaryColor,
                                  ),
                                  iconSize: 24,
                                  elevation: 16,
                                  style: TextStyle(
                                    color: AppTheme.textPrimaryColor,
                                    fontSize: 16,
                                  ),
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      _leaderDeviceValue = newValue!;
                                    });
                                  },
                                  items: _deviceOptions
                                      .map<DropdownMenuItem<String>>((String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Row(
                                        children: [
                                          Icon(
                                            value == 'Android' 
                                                ? Icons.android 
                                                : Icons.apple,
                                            color: value == 'Android'
                                                ? Colors.green
                                                : AppTheme.textPrimaryColor,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(value),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Team Members Section
                  Text(
                    'Team Members (${_memberForms.length})',
                    style: TextStyle(
                      color: AppTheme.textPrimaryColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Member Forms
                  ...List.generate(_memberForms.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: _memberForms[index],
                    );
                  }),
                  
                  // Add Member Button (if less than max members)
                  if (_memberForms.length < _maxMembers)
                    TextButton.icon(
                      onPressed: _addMemberForm,
                      icon: Icon(
                        Icons.add_circle,
                        color: AppTheme.accentColor,
                      ),
                      label: Text(
                        'Add Team Member',
                        style: TextStyle(
                          color: AppTheme.accentColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: AppTheme.accentColor.withOpacity(0.1),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 24),
                  
                  // Error Message
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.errorColor.withOpacity(0.5),
                        ),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: AppTheme.errorColor,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  // Register Button
                  GlassButton(
                    text: 'Register Team',
                    onPressed: _registerTeam,
                    isLoading: _isLoading,
                    icon: Icons.how_to_reg,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MemberForm extends StatefulWidget {
  final int index;
  final Function(int) onRemove;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final List<String> deviceOptions;
  final String initialDevice;
  // Store the current device value
  String _currentDevice = 'Android';
  
  // Store current values in the state
  MemberForm({
    super.key,
    required this.index,
    required this.onRemove,
    required this.deviceOptions,
    this.initialDevice = 'Android',
  }) {
    _currentDevice = initialDevice;
  }
  
  // Use a static method to create a new form with updated index
  static MemberForm withNewIndex(MemberForm oldForm, int newIndex) {
    return MemberForm(
      index: newIndex,
      onRemove: oldForm.onRemove,
      deviceOptions: oldForm.deviceOptions,
      initialDevice: oldForm.getMember().device,
    );
  }

  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
  }

  TeamMember getMember() {
    return TeamMember(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      device: _currentDevice, // Use the current device value
    );
  }

  @override
  _MemberFormState createState() => _MemberFormState();
}

class _MemberFormState extends State<MemberForm> {
  bool _isExpanded = false;
  late String _selectedDevice;
  
  @override
  void initState() {
    super.initState();
    _selectedDevice = widget.initialDevice;
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with expand/collapse functionality
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Row(
              children: [
                Icon(
                  Icons.person,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Member ${widget.index + 1}',
                  style: TextStyle(
                    color: AppTheme.textPrimaryColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppTheme.textSecondaryColor,
                  ),
                  onPressed: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                ),
                IconButton(
                  icon: Icon(
                    Icons.remove_circle,
                    color: AppTheme.errorColor.withOpacity(0.7),
                  ),
                  onPressed: () => widget.onRemove(widget.index),
                ),
              ],
            ),
          ),
          
          // Form fields (shown when expanded)
          if (_isExpanded) ...[
            const SizedBox(height: 16),
            
            // Member Name
            CustomTextField(
              label: 'Full Name',
              hint: 'Enter member\'s full name',
              controller: widget._nameController,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter member\'s name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Member Email
            CustomTextField(
              label: 'Email',
              hint: 'Enter member\'s email address',
              controller: widget._emailController,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter member\'s email';
                } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Member Phone
            CustomTextField(
              label: 'Phone Number',
              hint: 'Enter member\'s phone number',
              controller: widget._phoneController,
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter member\'s phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Member Device Dropdown
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    'Device',
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AppTheme.cardColor.withOpacity(0.5),
                    border: Border.all(
                      color: AppTheme.glassBorderColor,
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      dropdownColor: AppTheme.cardColor,
                      isExpanded: true,
                      value: _selectedDevice,
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: AppTheme.textSecondaryColor,
                      ),
                      iconSize: 24,
                      elevation: 16,
                      style: TextStyle(
                        color: AppTheme.textPrimaryColor,
                        fontSize: 16,
                      ),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedDevice = newValue!;
                          widget._currentDevice = newValue;
                        });
                      },
                      items: widget.deviceOptions
                          .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Row(
                            children: [
                              Icon(
                                value == 'Android' 
                                    ? Icons.android 
                                    : Icons.apple,
                                color: value == 'Android'
                                    ? Colors.green
                                    : AppTheme.textPrimaryColor,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Text(value),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
} 