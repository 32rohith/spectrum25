import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;
import '../../models/team.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class ProjectSubmissionTab extends StatefulWidget {
  final Team team;
  final String? userId;

  const ProjectSubmissionTab({
    super.key,
    required this.team,
    this.userId,
  });

  @override
  _ProjectSubmissionTabState createState() => _ProjectSubmissionTabState();
}

class _ProjectSubmissionTabState extends State<ProjectSubmissionTab> {
  final _formKey = GlobalKey<FormState>();
  final _projectNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _repoUrlController = TextEditingController();
  final _demoUrlController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  bool _isCheckingSubmission = true;
  bool _hasTeamSubmitted = false;
  String? _errorMessage;
  String? _selectedTrack;
  Map<String, dynamic>? _submissionData;
  List<String> _trackOptions = ['AI & ML', 'Web3 & Blockchain', 'AR/VR', 'FinTech', 'Healthcare', 'Open Innovation'];

  @override
  void initState() {
    super.initState();
    // Log the user who is accessing the project submission
    if (widget.userId != null) {
      developer.log('Project submission accessed by user ID: ${widget.userId}');
    }
    
    // Check if the team has already submitted a project
    _checkExistingSubmission();
  }

  Future<void> _checkExistingSubmission() async {
    setState(() {
      _isCheckingSubmission = true;
    });
    
    try {
      // Check if this team has already submitted a project
      final submissionSnapshot = await _firestore
          .collection('projectSubmissions')
          .where('teamId', isEqualTo: widget.team.teamId)
          .limit(1)
          .get();
      
      if (submissionSnapshot.docs.isNotEmpty) {
        final submissionDoc = submissionSnapshot.docs.first;
        final submissionData = submissionDoc.data();
        
        setState(() {
          _hasTeamSubmitted = true;
          _submissionData = submissionData;
        });
        
        developer.log('Team has already submitted a project: ${submissionData['projectName']}');
      } else {
        // Also check if the team object has a submission URL
        if (widget.team.projectSubmissionUrl != null && 
            widget.team.projectSubmissionUrl!.isNotEmpty) {
          setState(() {
            _hasTeamSubmitted = true;
          });
          developer.log('Team has a submission URL: ${widget.team.projectSubmissionUrl}');
        } else {
          setState(() {
            _hasTeamSubmitted = false;
          });
          developer.log('Team has not submitted a project yet');
        }
      }
    } catch (e) {
      developer.log('Error checking existing submission: $e');
    } finally {
      setState(() {
        _isCheckingSubmission = false;
      });
    }
  }

  @override
  void dispose() {
    _projectNameController.dispose();
    _descriptionController.dispose();
    _repoUrlController.dispose();
    _demoUrlController.dispose();
    super.dispose();
  }

  Future<void> _submitProject() async {
    if (_formKey.currentState!.validate()) {
      // Validate track selection
      if (_selectedTrack == null) {
        setState(() {
          _errorMessage = 'Please select a project track';
        });
        return;
      }
      
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        // Check one more time if the team has already submitted
        final submissionSnapshot = await _firestore
            .collection('projectSubmissions')
            .where('teamId', isEqualTo: widget.team.teamId)
            .limit(1)
            .get();
            
        if (submissionSnapshot.docs.isNotEmpty) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Your team has already submitted a project. Only one submission per team is allowed.';
            _hasTeamSubmitted = true;
          });
          return;
        }
        
        // Prepare submission data
        final timestamp = FieldValue.serverTimestamp();
        final projectData = {
          'projectName': _projectNameController.text.trim(),
          'description': _descriptionController.text.trim(),
          'repoUrl': _repoUrlController.text.trim(),
          'demoUrl': _demoUrlController.text.trim() ?? '',
          'track': _selectedTrack,
          'teamId': widget.team.teamId,
          'teamName': widget.team.teamName,
          'submittedBy': widget.userId,
          'submitterName': '', // This could be populated if you have access to the user's name
          'submittedAt': timestamp,
          'updatedAt': timestamp,
        };
        
        developer.log('Submitting project: $projectData');
        
        // Create a new document in the projectSubmissions collection
        final submissionRef = await _firestore.collection('projectSubmissions').add(projectData);
        final submissionId = submissionRef.id;
        
        developer.log('Created new submission with ID: $submissionId');
        
        // Update the team document with the submission URL
        await _firestore.collection('teams').doc(widget.team.teamId).update({
          'projectSubmissionUrl': _repoUrlController.text.trim(),
          'projectSubmissionId': submissionId,
          'projectSubmittedAt': timestamp,
          'projectSubmittedBy': widget.userId,
          'projectName': _projectNameController.text.trim(),
          'projectTrack': _selectedTrack,
        });
        
        developer.log('Updated team document with submission details');
        
        // We can't modify the team object directly since projectSubmissionUrl is final
        // Instead, we'll just set the flag that submission is complete
        setState(() {
          _isLoading = false;
          _hasTeamSubmitted = true;
          _submissionData = projectData;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Project submitted successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      } catch (e) {
        developer.log('Error submitting project: $e');
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error submitting project: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingSubmission) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const CustomAppBar(
          title: 'Project Submission',
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(
        title: 'Project Submission',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Project Submission Status
            _hasTeamSubmitted || widget.team.projectSubmissionUrl != null
                ? _buildSubmittedProject()
                : _buildSubmissionForm(),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmittedProject() {
    // If we have submission data from Firestore, use that, otherwise use team data
    final projectName = _submissionData?['projectName'] ?? 'Your Project';
    final repoUrl = _submissionData?['repoUrl'] ?? widget.team.projectSubmissionUrl ?? 'N/A';
    final track = _submissionData?['track'] ?? 'Not specified';
    final description = _submissionData?['description'] ?? 'No description provided';
    final submittedAt = _submissionData?['submittedAt'] ?? 'Recent submission';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Success card
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Project Submitted!',
                          style: TextStyle(
                            color: AppTheme.textPrimaryColor,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your team has successfully submitted the project.',
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
              const SizedBox(height: 20),
              
              // Submitted project details
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Project Details',
                      style: TextStyle(
                        color: AppTheme.accentColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Project Name
                    Row(
                      children: [
                        Icon(
                          Icons.title,
                          color: AppTheme.accentColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Project Name:',
                          style: TextStyle(
                            color: AppTheme.textSecondaryColor,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      projectName,
                      style: TextStyle(
                        color: AppTheme.textPrimaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Track
                    Row(
                      children: [
                        Icon(
                          Icons.category,
                          color: AppTheme.accentColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Track:',
                          style: TextStyle(
                            color: AppTheme.textSecondaryColor,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      track,
                      style: TextStyle(
                        color: AppTheme.textPrimaryColor,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Repository URL
                    Row(
                      children: [
                        Icon(
                          Icons.link,
                          color: AppTheme.accentColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Repository URL:',
                          style: TextStyle(
                            color: AppTheme.textSecondaryColor,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      repoUrl,
                      style: TextStyle(
                        color: AppTheme.textPrimaryColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      // Open submission URL
                      // TODO: Implement URL launcher
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('View Repository'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Information card
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppTheme.accentColor,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Submission Information',
                    style: TextStyle(
                      color: AppTheme.accentColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Your project has been successfully submitted. The judges will review your project and announce the results during the closing ceremony.',
                style: TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'If you need to make changes to your submission, please contact the organizing committee.',
                style: TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubmissionForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.upload_file,
                        color: AppTheme.primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Submit Your Project',
                            style: TextStyle(
                              color: AppTheme.textPrimaryColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Team: ${widget.team.teamName}',
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
                const SizedBox(height: 16),
                Text(
                  'Please provide the following information about your project. Make sure to include all necessary details for the judges to evaluate your work.',
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Project details form
          Text(
            'Project Details',
            style: TextStyle(
              color: AppTheme.textPrimaryColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Project Name
          CustomTextField(
            label: 'Project Name',
            hint: 'Enter your project name',
            controller: _projectNameController,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter project name';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          
          // Project Description
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'Project Description',
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
                child: TextFormField(
                  controller: _descriptionController,
                  keyboardType: TextInputType.multiline,
                  maxLines: 6, // Textarea with 6 lines
                  minLines: 4, // Minimum 4 lines
                  decoration: InputDecoration(
                    hintText: 'Describe your project in detail',
                    hintStyle: TextStyle(
                      color: AppTheme.textSecondaryColor.withOpacity(0.7),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(16),
                    fillColor: Colors.transparent,
                    filled: true,
                  ),
                  style: TextStyle(
                    color: AppTheme.textPrimaryColor,
                    fontSize: 16,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter project description';
                    } else if (value.length < 30) {
                      return 'Description should be at least 30 characters';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Track Selection
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'Track',
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
                    value: _selectedTrack,
                    isExpanded: true,
                    hint: Text(
                      'Select project track',
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor.withOpacity(0.7),
                      ),
                    ),
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: AppTheme.textSecondaryColor,
                    ),
                    dropdownColor: AppTheme.cardColor,
                    style: TextStyle(
                      color: AppTheme.textPrimaryColor,
                      fontSize: 16,
                    ),
                    items: _trackOptions.map((String track) {
                      return DropdownMenuItem<String>(
                        value: track,
                        child: Text(track),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedTrack = newValue;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Repository URL
          CustomTextField(
            label: 'Repository URL (GitHub, GitLab, etc.)',
            hint: 'Enter your repository URL (e.g., https://github.com/username/repo)',
            controller: _repoUrlController,
            keyboardType: TextInputType.url,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter repository URL';
              } 
              
              final uri = Uri.tryParse(value);
              if (uri == null || !uri.isAbsolute) {
                return 'Please enter a valid URL starting with http:// or https://';
              }
              
              if (!uri.scheme.startsWith('http')) {
                return 'URL must start with http:// or https://';
              }
              
              return null;
            },
          ),
          const SizedBox(height: 20),
          
          // Demo URL (Optional)
          CustomTextField(
            label: 'Demo URL (Optional)',
            hint: 'Enter demo URL if available (e.g., https://yourdemo.com)',
            controller: _demoUrlController,
            keyboardType: TextInputType.url,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return null; // Optional field
              }
              
              final uri = Uri.tryParse(value);
              if (uri == null || !uri.isAbsolute) {
                return 'Please enter a valid URL starting with http:// or https://';
              }
              
              if (!uri.scheme.startsWith('http')) {
                return 'URL must start with http:// or https://';
              }
              
              return null;
            },
          ),
          const SizedBox(height: 30),
          
          // Error message
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
            const SizedBox(height: 20),
          ],
          
          // Submit button
          SizedBox(
            width: double.infinity,
            child: GlassButton(
              text: 'Submit Project',
              onPressed: _submitProject,
              isLoading: _isLoading,
              icon: Icons.send,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Instructions note
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.glassBorderColor,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppTheme.accentColor,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Important Note',
                      style: TextStyle(
                        color: AppTheme.accentColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Once submitted, you cannot modify your project details. Make sure all information is correct before submitting.',
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 30),
        ],
      ),
    );
  }
} 