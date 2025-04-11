import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class DeadlineManagerScreen extends StatefulWidget {
  const DeadlineManagerScreen({super.key});

  @override
  _DeadlineManagerScreenState createState() => _DeadlineManagerScreenState();
}

class _DeadlineManagerScreenState extends State<DeadlineManagerScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  bool _isSaving = false;
  DateTime? _currentDeadline;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _fetchCurrentDeadline();
  }
  
  Future<void> _fetchCurrentDeadline() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final timerDoc = await _firestore.collection('timer').doc('projectSubmission').get();
      
      if (timerDoc.exists) {
        final data = timerDoc.data();
        if (data != null && data.containsKey('deadline')) {
          final deadline = (data['deadline'] as Timestamp).toDate();
          setState(() {
            _currentDeadline = deadline;
            _selectedDate = deadline;
            _selectedTime = TimeOfDay(hour: deadline.hour, minute: deadline.minute);
          });
          
          developer.log('Current deadline: $_currentDeadline');
        } else {
          developer.log('No deadline field found in timer document');
        }
      } else {
        developer.log('No submission deadline document found');
      }
    } catch (e) {
      developer.log('Error fetching deadline: $e');
      setState(() {
        _errorMessage = 'Error fetching deadline: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)), // Allow setting date in the past
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppTheme.accentColor,
              onPrimary: Colors.white,
              surface: AppTheme.cardColor,
              onSurface: AppTheme.textPrimaryColor,
            ),
            dialogBackgroundColor: AppTheme.backgroundColor,
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }
  
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppTheme.accentColor,
              onPrimary: Colors.white,
              surface: AppTheme.cardColor,
              onSurface: AppTheme.textPrimaryColor,
            ),
            dialogBackgroundColor: AppTheme.backgroundColor,
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }
  
  Future<void> _saveDeadline() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    
    try {
      // Combine date and time
      final deadline = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );
      
      // Save to Firestore
      await _firestore.collection('timer').doc('projectSubmission').set({
        'deadline': Timestamp.fromDate(deadline),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      setState(() {
        _currentDeadline = deadline;
      });
      
      developer.log('Saved new deadline: $deadline');
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Deadline updated successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      developer.log('Error saving deadline: $e');
      setState(() {
        _errorMessage = 'Error saving deadline: $e';
      });
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $_errorMessage'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(
        title: 'Manage Submission Deadline',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current deadline info
                  GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Submission Deadline',
                            style: TextStyle(
                              color: AppTheme.textPrimaryColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(
                                Icons.event,
                                color: AppTheme.accentColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _currentDeadline != null
                                      ? _formatDateTime(_currentDeadline!)
                                      : 'No deadline set',
                                  style: TextStyle(
                                    color: AppTheme.textPrimaryColor,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                _getDeadlineStatusIcon(),
                                color: _getDeadlineStatusColor(),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _getDeadlineStatus(),
                                  style: TextStyle(
                                    color: _getDeadlineStatusColor(),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Update deadline form
                  GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Update Submission Deadline',
                            style: TextStyle(
                              color: AppTheme.textPrimaryColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Date picker
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Date: ${_formatDate(_selectedDate)}',
                                  style: TextStyle(
                                    color: AppTheme.textPrimaryColor,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => _selectDate(context),
                                icon: Icon(
                                  Icons.calendar_today,
                                  color: AppTheme.accentColor,
                                  size: 18,
                                ),
                                label: Text(
                                  'Change',
                                  style: TextStyle(
                                    color: AppTheme.accentColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // Time picker
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Time: ${_formatTime(_selectedTime)}',
                                  style: TextStyle(
                                    color: AppTheme.textPrimaryColor,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => _selectTime(context),
                                icon: Icon(
                                  Icons.access_time,
                                  color: AppTheme.accentColor,
                                  size: 18,
                                ),
                                label: Text(
                                  'Change',
                                  style: TextStyle(
                                    color: AppTheme.accentColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Preview of new deadline
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.cardColor.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppTheme.glassBorderColor,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.preview,
                                  color: Colors.orange,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'New Deadline Preview',
                                        style: TextStyle(
                                          color: AppTheme.textSecondaryColor,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatNewDateTime(),
                                        style: TextStyle(
                                          color: AppTheme.textPrimaryColor,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.red.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          
                          const SizedBox(height: 24),
                          
                          // Save button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _saveDeadline,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Save New Deadline'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Note about automatic updates
                  GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                color: Colors.blue,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Note',
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
                          Text(
                            'The submission deadline is automatically enforced across the entire app. When the deadline passes, all submission forms will be disabled for all users immediately.\n\nChanges to the deadline take effect instantly for all users.',
                            style: TextStyle(
                              color: AppTheme.textSecondaryColor,
                              fontSize: 14,
                            ),
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
  
  String _formatDateTime(DateTime dateTime) {
    final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
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
  
  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
  
  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
  
  String _formatNewDateTime() {
    final dateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    return _formatDateTime(dateTime);
  }
  
  String _getDeadlineStatus() {
    if (_currentDeadline == null) {
      return 'No deadline set';
    }
    
    final now = DateTime.now();
    if (now.isAfter(_currentDeadline!)) {
      return 'Submission period has ended';
    } else {
      final difference = _currentDeadline!.difference(now);
      if (difference.inDays > 0) {
        return 'Submissions close in ${difference.inDays} days';
      } else if (difference.inHours > 0) {
        return 'Submissions close in ${difference.inHours} hours';
      } else if (difference.inMinutes > 0) {
        return 'Submissions close in ${difference.inMinutes} minutes';
      } else {
        return 'Submissions closing in less than a minute';
      }
    }
  }
  
  Color _getDeadlineStatusColor() {
    if (_currentDeadline == null) {
      return Colors.grey;
    }
    
    final now = DateTime.now();
    if (now.isAfter(_currentDeadline!)) {
      return Colors.red;
    } else {
      final difference = _currentDeadline!.difference(now);
      if (difference.inHours < 6) {
        return Colors.red;
      } else if (difference.inHours < 24) {
        return Colors.orange;
      } else {
        return Colors.green;
      }
    }
  }
  
  IconData _getDeadlineStatusIcon() {
    if (_currentDeadline == null) {
      return Icons.help_outline;
    }
    
    final now = DateTime.now();
    if (now.isAfter(_currentDeadline!)) {
      return Icons.lock_clock;
    } else {
      final difference = _currentDeadline!.difference(now);
      if (difference.inHours < 6) {
        return Icons.alarm_on;
      } else if (difference.inHours < 24) {
        return Icons.access_time;
      } else {
        return Icons.check_circle_outline;
      }
    }
  }
} 