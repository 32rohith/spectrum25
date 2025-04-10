import 'package:flutter/material.dart';
import '../../models/track.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;

class SubmitTab extends StatefulWidget {
  const SubmitTab({super.key});

  @override
  State<SubmitTab> createState() => _SubmitTabState();
}

class _SubmitTabState extends State<SubmitTab> {
  final _formKey = GlobalKey<FormState>();
  final _projectNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _githubLinkController = TextEditingController();
  Track _selectedTrack = Track.openInnovation;
  bool _isSubmitting = false;
  bool _isLoading = true;
  bool _teamHasSubmission = false;
  String? _teamId;
  String? _errorMessage;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _checkTeamSubmission();
  }

  @override
  void dispose() {
    _projectNameController.dispose();
    _descriptionController.dispose();
    _githubLinkController.dispose();
    super.dispose();
  }

  Future<void> _checkTeamSubmission() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = 'User not authenticated';
          _isLoading = false;
        });
        return;
      }

      // Get member document to find team
      final memberEmail = user.email;
      if (memberEmail == null) throw 'User email not found';

      // Query members collection to find user's team
      final memberQuery = await _firestore
          .collection('members')
          .where('email', isEqualTo: memberEmail)
          .limit(1)
          .get();

      if (memberQuery.docs.isEmpty) {
        setState(() {
          _errorMessage = 'Member not found';
          _isLoading = false;
        });
        return;
      }

      // Get team ID from member document
      final memberData = memberQuery.docs.first.data();
      _teamId = memberData['teamId'];

      if (_teamId == null) {
        setState(() {
          _errorMessage = 'Team not found';
          _isLoading = false;
        });
        return;
      }

      // Check if team has already submitted a project
      final teamDoc = await _firestore.collection('teams').doc(_teamId).get();
      final projectSubmissionUrl = teamDoc.data()?['projectSubmissionUrl'];
      
      setState(() {
        _teamHasSubmission = projectSubmissionUrl != null;
        _isLoading = false;
      });

    } catch (e) {
      developer.log('Error checking team submission: $e', error: e);
      setState(() {
        _errorMessage = 'Error checking submission status: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _submitProject() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      if (_teamId == null) throw 'Team not found';

      // Double-check that team hasn't already submitted
      final teamDoc = await _firestore.collection('teams').doc(_teamId).get();
      final hasSubmission = teamDoc.data()?['projectSubmissionUrl'] != null;
      
      if (hasSubmission) {
        setState(() {
          _teamHasSubmission = true;
          _isSubmitting = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your team has already submitted a project'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Create submission document
      final submissionRef = await _firestore.collection('submissions').add({
        'projectName': _projectNameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'githubLink': _githubLinkController.text.trim(),
        'track': _selectedTrack.displayName,
        'teamId': _teamId,
        'submittedAt': FieldValue.serverTimestamp(),
        'status': 'submitted', 
      });

      // Update team with submission URL and description
      await _firestore.collection('teams').doc(_teamId).update({
        'projectSubmissionUrl': _githubLinkController.text.trim(),
        'projectSubmissionId': submissionRef.id,
        'projectSubmittedAt': FieldValue.serverTimestamp(),
        'projectTrack': _selectedTrack.displayName,
        'projectDescription': _descriptionController.text.trim(),
        'projectName': _projectNameController.text.trim(),
      });

      if (!mounted) return;
      
      setState(() {
        _teamHasSubmission = true;
        _isSubmitting = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Project submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Clear form
      _projectNameController.clear();
      _descriptionController.clear();
      _githubLinkController.clear();
      setState(() {
        _selectedTrack = Track.openInnovation;
      });
    } catch (e) {
      developer.log('Error submitting project: $e', error: e);
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting project: $e'),
          backgroundColor: Colors.red,
        ),
      );
      
        setState(() {
          _isSubmitting = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(
        title: 'Submit Project',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorMessage()
              : _teamHasSubmission
                  ? _buildSubmissionComplete()
                  : _buildSubmissionForm(),
    );
  }

  Widget _buildErrorMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.orange,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error',
                  style: TextStyle(
                    color: AppTheme.textPrimaryColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ?? 'An unknown error occurred',
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _checkTeamSubmission,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentColor,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmissionComplete() {
    // Fetch submission details
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('teams').doc(_teamId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading submission details: ${snapshot.error}',
              style: TextStyle(color: AppTheme.textSecondaryColor),
              textAlign: TextAlign.center,
            ),
          );
        }
        
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final projectName = data?['projectName'] ?? 'Your project';
        final projectTrack = data?['projectTrack'] ?? 'Unknown track';
        final projectUrl = data?['projectSubmissionUrl'] ?? '';
        final submittedAt = data?['projectSubmittedAt'] as Timestamp?;
        final formattedDate = submittedAt != null 
            ? '${submittedAt.toDate().day}/${submittedAt.toDate().month}/${submittedAt.toDate().year} at ${submittedAt.toDate().hour}:${submittedAt.toDate().minute.toString().padLeft(2, '0')}'
            : 'Recently';
            
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
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
                              'Your team has successfully submitted a project. Thank you for your participation!',
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
                  const SizedBox(height: 24),
                  
                  // Project details
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
                        const SizedBox(height: 12),
                        
                        // Project Track row
                        Row(
                          children: [
                            Icon(
                              Icons.category,
                              color: AppTheme.textSecondaryColor,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Track:',
                              style: TextStyle(
                                color: AppTheme.textSecondaryColor,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                projectTrack,
                                style: TextStyle(
                                  color: AppTheme.textPrimaryColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Submission date
                        Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              color: AppTheme.textSecondaryColor,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Submitted on:',
                              style: TextStyle(
                                color: AppTheme.textSecondaryColor,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                formattedDate,
                                style: TextStyle(
                                  color: AppTheme.textPrimaryColor,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        // Repository link (if available)
                        if (projectUrl.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.link,
                                color: AppTheme.textSecondaryColor,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Repository:',
                                style: TextStyle(
                                  color: AppTheme.textSecondaryColor,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  projectUrl,
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  Text(
                    'You cannot submit another project. If you need to make changes, please contact the organizers.',
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildSubmissionForm() {
    return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Project Details',
                style: TextStyle(
                  color: AppTheme.textPrimaryColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Fill out the form below to submit your project. All team members will be listed as contributors.',
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _projectNameController,
                        style: TextStyle(color: AppTheme.textPrimaryColor),
                        decoration: InputDecoration(
                          labelText: 'Project Name',
                          labelStyle: TextStyle(color: AppTheme.textSecondaryColor),
                          border: OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a project name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<Track>(
                        value: _selectedTrack,
                        style: TextStyle(color: AppTheme.textPrimaryColor),
                        dropdownColor: AppTheme.cardColor,
                        decoration: InputDecoration(
                          labelText: 'Track',
                          labelStyle: TextStyle(color: AppTheme.textSecondaryColor),
                          border: const OutlineInputBorder(),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: AppTheme.textSecondaryColor),
                          ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        icon: Icon(Icons.arrow_drop_down, color: AppTheme.textSecondaryColor),
                        items: Track.values.map((Track track) {
                          return DropdownMenuItem<Track>(
                            value: track,
                            child: Text(
                              track.displayName,
                              style: TextStyle(
                                color: AppTheme.textPrimaryColor,
                                fontSize: 16,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (Track? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedTrack = newValue;
                            });
                          }
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Please select a track';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        style: TextStyle(color: AppTheme.textPrimaryColor),
                        decoration: InputDecoration(
                          labelText: 'Project Description',
                          labelStyle: TextStyle(color: AppTheme.textSecondaryColor),
                          border: OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        hintText: 'Describe your project, its purpose, and how it works',
                        hintStyle: TextStyle(color: AppTheme.textSecondaryColor.withOpacity(0.7)),
                        ),
                      maxLines: 5,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a project description';
                          }
                        if (value.length < 50) {
                          return 'Description must be at least 50 characters long';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _githubLinkController,
                        style: TextStyle(color: AppTheme.textPrimaryColor),
                        decoration: InputDecoration(
                          labelText: 'GitHub Repository Link',
                          labelStyle: TextStyle(color: AppTheme.textSecondaryColor),
                          border: OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        hintText: 'https://github.com/username/repository',
                        hintStyle: TextStyle(color: AppTheme.textSecondaryColor.withOpacity(0.7)),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your GitHub repository link';
                          }
                          if (!value.startsWith('https://github.com/')) {
                            return 'Please enter a valid GitHub repository link';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitProject,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: AppTheme.primaryColor,
                          ),
                          child: _isSubmitting
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text('Submitting...'),
                                ],
                              )
                              : const Text('Submit Project'),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      'Note: Only one submission is allowed per team. Make sure all details are correct before submitting.',
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
        ),
      ),
    );
  }
}