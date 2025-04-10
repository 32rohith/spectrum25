import 'package:flutter/material.dart';
import '../../models/track.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    _projectNameController.dispose();
    _descriptionController.dispose();
    _githubLinkController.dispose();
    super.dispose();
  }

  Future<void> _submitProject() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw 'User not authenticated';

      // Get team ID
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final teamId = userDoc.data()?['teamId'];
      if (teamId == null) throw 'Team not found';

      // Create submission
      await _firestore.collection('submissions').add({
        'projectName': _projectNameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'githubLink': _githubLinkController.text.trim(),
        'track': _selectedTrack.displayName,
        'teamId': teamId,
        'submittedAt': FieldValue.serverTimestamp(),
        'status': 'pending', // Add status field
      });

      if (!mounted) return;
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting project: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(
        title: 'Submit Project',
      ),
      body: SingleChildScrollView(
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
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        ),
                        maxLines: 4,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a project description';
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
                              ? const CircularProgressIndicator()
                              : const Text('Submit Project'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 