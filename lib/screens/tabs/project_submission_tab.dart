import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
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
  bool _isSubmissionClosed = false;
  String? _errorMessage;
  String? _selectedTrack;
  Map<String, dynamic>? _submissionData;
  DateTime? _submissionDeadline;
  Timer? _deadlineTimer;
  List<String> _trackOptions = ['Open Innovation', 'Edtech', 'AgriTech and MedTech', 'IoT', 'Sustainability & Social Well Being', 'Blockchain'];

  @override
  void initState() {
    super.initState();
    // Log the user who is accessing the project submission
    if (widget.userId != null) {
      developer.log('Project submission accessed by user ID: ${widget.userId}');
    }
    
    // Check if the team has already submitted a project and fetch the submission deadline
    _initializeData();
  }

  Future<void> _initializeData() async {
    await Future.wait([
      _checkExistingSubmission(),
      _fetchSubmissionDeadline(),
    ]);
  }

  Future<void> _fetchSubmissionDeadline() async {
    try {
      // Fetch submission deadline from the timer collection
      final timerDoc = await _firestore.collection('timer').doc('projectSubmission').get();
      
      if (timerDoc.exists) {
        final data = timerDoc.data();
        if (data != null && data.containsKey('deadline')) {
          final deadline = (data['deadline'] as Timestamp).toDate();
          setState(() {
            _submissionDeadline = deadline;
            _isSubmissionClosed = DateTime.now().isAfter(deadline);
          });
          
          developer.log('Submission deadline: $_submissionDeadline, closed: $_isSubmissionClosed');
          
          // Set up a timer to check the deadline periodically
          _setupDeadlineTimer();
        } else {
          developer.log('No deadline field found in timer document');
        }
      } else {
        developer.log('No submission deadline configured');
      }
    } catch (e) {
      developer.log('Error fetching submission deadline: $e');
    }
  }

  void _setupDeadlineTimer() {
    // Cancel any existing timer
    _deadlineTimer?.cancel();
    
    // If deadline exists and hasn't passed yet, set up a timer
    if (_submissionDeadline != null && !_isSubmissionClosed) {
      final now = DateTime.now();
      if (now.isBefore(_submissionDeadline!)) {
        // Calculate time until deadline
        final timeUntilDeadline = _submissionDeadline!.difference(now);
        
        // If deadline is more than a day away, check once a day
        // Otherwise check more frequently as it gets closer
        Duration checkInterval;
        if (timeUntilDeadline.inDays > 1) {
          checkInterval = const Duration(hours: 12);
        } else if (timeUntilDeadline.inHours > 1) {
          checkInterval = const Duration(minutes: 30);
        } else {
          checkInterval = const Duration(minutes: 1);
        }
        
        developer.log('Setting deadline timer to check every ${checkInterval.inMinutes} minutes');
        
        // Set up periodic timer
        _deadlineTimer = Timer.periodic(checkInterval, (timer) {
          if (DateTime.now().isAfter(_submissionDeadline!)) {
            setState(() {
              _isSubmissionClosed = true;
            });
            timer.cancel();
            developer.log('Submission deadline reached, portal closed');
          }
        });
      } else {
        // Deadline has already passed
        setState(() {
          _isSubmissionClosed = true;
        });
      }
    }
    
    // Also set up a listener for real-time updates to the deadline
    _setupDeadlineListener();
  }
  
  void _setupDeadlineListener() {
    // Listen for changes to the deadline document in real-time
    _firestore.collection('timer').doc('projectSubmission').snapshots().listen((docSnapshot) {
      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        if (data != null && data.containsKey('deadline')) {
          final newDeadline = (data['deadline'] as Timestamp).toDate();
          
          // Only update if the deadline has changed
          if (_submissionDeadline == null || !_submissionDeadline!.isAtSameMomentAs(newDeadline)) {
            setState(() {
              _submissionDeadline = newDeadline;
              _isSubmissionClosed = DateTime.now().isAfter(newDeadline);
            });
            
            developer.log('Deadline updated: $_submissionDeadline, closed: $_isSubmissionClosed');
            
            // Reset the timer with the new deadline
            _setupDeadlineTimer();
          }
        }
      }
    }, onError: (error) {
      developer.log('Error in deadline listener: $error');
    });
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
    _deadlineTimer?.cancel();
    super.dispose();
  }

  Future<void> _submitProject() async {
    // Check if submission is closed
    if (_isSubmissionClosed) {
      setState(() {
        _errorMessage = 'Submission period has ended. Project submissions are now closed.';
      });
      return;
    }

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
        
        // Check deadline one more time before saving
        await _fetchSubmissionDeadline();
        if (_isSubmissionClosed) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Submission period has ended. Project submissions are now closed.';
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
        
        // Update the team document with the submission URL and description
        await _firestore.collection('teams').doc(widget.team.teamId).update({
          'projectSubmissionUrl': _repoUrlController.text.trim(),
          'projectSubmissionId': submissionId,
          'projectSubmittedAt': timestamp,
          'projectSubmittedBy': widget.userId,
          'projectName': _projectNameController.text.trim(),
          'projectTrack': _selectedTrack,
          'projectDescription': _descriptionController.text.trim(),
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
            // Deadline banner if available
            if (_submissionDeadline != null) _buildDeadlineBanner(),
            
            // Submission closed message
            if (_isSubmissionClosed && !_hasTeamSubmitted) _buildSubmissionClosedMessage(),
            
            // Project Submission Status
            if (_hasTeamSubmitted)
              _buildSubmittedProject()
            else if (!_isSubmissionClosed)
              _buildSubmissionForm(),
          ],
        ),
      ),
    );
  }

  Widget _buildDeadlineBanner() {
    final now = DateTime.now();
    final isNearDeadline = _submissionDeadline != null && 
                         now.isBefore(_submissionDeadline!) && 
                         now.add(const Duration(hours: 12)).isAfter(_submissionDeadline!);
    
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(
              _isSubmissionClosed ? Icons.timer_off : (isNearDeadline ? Icons.alarm : Icons.access_time),
              color: _isSubmissionClosed ? Colors.red : (isNearDeadline ? Colors.orange : AppTheme.accentColor),
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isSubmissionClosed 
                      ? 'Submission Closed' 
                      : (isNearDeadline ? 'Deadline Approaching' : 'Submission Deadline'),
                    style: TextStyle(
                      color: _isSubmissionClosed ? Colors.red : (isNearDeadline ? Colors.orange : AppTheme.textPrimaryColor),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isSubmissionClosed
                      ? 'The submission period ended on ${_formatDateTime(_submissionDeadline!)}'
                      : 'Submissions close on ${_formatDateTime(_submissionDeadline!)}',
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (_isSubmissionClosed && !_hasTeamSubmitted)
              const Icon(Icons.lock, color: Colors.red, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmissionClosedMessage() {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 12.0),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.event_busy,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Submission Period Has Ended',
                style: TextStyle(
                  color: AppTheme.textPrimaryColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Project submissions are now closed. We\'re sorry, but the deadline has passed and new submissions are no longer being accepted.',
                style: TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Submissions closed on: ${_formatDateTime(_submissionDeadline!)}',
                style: TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    // Format: "Apr 12, 2023 at 11:59 PM"
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = months[dateTime.month - 1];
    final day = dateTime.day;
    final year = dateTime.year;
    
    // Format hours for 12-hour clock with AM/PM
    int hour = dateTime.hour;
    final period = hour >= 12 ? 'PM' : 'AM';
    hour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    
    final minute = dateTime.minute.toString().padLeft(2, '0');
    
    return '$month $day, $year at $hour:$minute $period';
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
              // Row(
              //   mainAxisAlignment: MainAxisAlignment.center,
              //   children: [
              //     ElevatedButton.icon(
              //       onPressed: () {
              //         // Open submission URL
              //         // TODO: Implement URL launcher
              //       },
              //       icon: const Icon(Icons.open_in_new),
              //       label: const Text('View Repository'),
              //       style: ElevatedButton.styleFrom(
              //         backgroundColor: AppTheme.accentColor,
              //         foregroundColor: Colors.white,
              //         shape: RoundedRectangleBorder(
              //           borderRadius: BorderRadius.circular(12),
              //         ),
              //         padding: const EdgeInsets.symmetric(
              //           horizontal: 16,
              //           vertical: 12,
              //         ),
              //       ),
              //     ),
              //   ],
              // ),
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