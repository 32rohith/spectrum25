import 'package:flutter/material.dart';
import '../../models/team.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class HomeTab extends StatelessWidget {
  final Team team;
  final String? userName;
  final String? userRole;

  const HomeTab({
    super.key,
    required this.team,
    this.userName,
    this.userRole,
  });

  bool isEventActive(String timeStr, {bool isNextDay = false}) {
    // Parse the time string
    final timeParts = timeStr.split(' ');
    final time = timeParts[0].split(':');
    final hour = int.parse(time[0]);
    final minute = int.parse(time[1]);
    final isPM = timeParts[1] == 'PM';

    // Create DateTime objects
    final now = DateTime.now();
    final eventDate = DateTime(
      now.year,
      now.month,
      isNextDay ? now.day + 1 : now.day,
      isPM && hour != 12 ? hour + 12 : hour,
      minute,
    );

    // Set the reference time to 8:30 AM on April 11th
    final referenceTime = DateTime(
      now.year,
      now.month,
      now.day + 1, // Next day (April 11th)
      8, // 8 AM
      30, // 30 minutes
    );

    // Event is active if it's after the reference time (8:30 AM on April 11th)
    return now.isAfter(referenceTime) && now.isAfter(eventDate);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(
        title: 'Spectrum Hackathon',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome message with user info
            if (userName != null)
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.person,
                        color: AppTheme.primaryColor,
                        size: 36,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome, $userName!',
                              style: TextStyle(
                                color: AppTheme.textPrimaryColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (userRole != null)
                              Text(
                                'Logged in as ${userRole == 'leader' ? 'Team Leader' : 'Team Member'}',
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
            
            const SizedBox(height: 16),
            
            // Spectrum Agenda
            Text(
              '',
              style: TextStyle(
                color: AppTheme.textPrimaryColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            GlassCard(
              child: Column(
                children: [
                  _buildTimelineItem(
                    time: '8:30 AM',
                    title: 'Reporting Time',
                    description: 'For participants',
                    isActive: isEventActive('8:30 AM'),
                  ),
                  _buildTimelineItem(
                    time: '10:00 AM',
                    title: 'Inauguration Ceremony',
                    description: 'Main Hall',
                    isActive: isEventActive('10:00 AM'),
                  ),
                  _buildTimelineItem(
                    time: '12:30 PM',
                    title: 'Lunch',
                    description: 'Provided by us',
                    isActive: isEventActive('12:30 PM'),
                  ),
                  _buildTimelineItem(
                    time: '1:30 PM',
                    title: 'Guest Speaker Session',
                    description: 'IBM',
                    isActive: isEventActive('1:30 PM'),
                  ),
                  _buildTimelineItem(
                    time: '5:00 PM',
                    title: '2IM Speech',
                    description: '',
                    isActive: isEventActive('5:00 PM'),
                  ),
                  _buildTimelineItem(
                    time: '7:00 PM',
                    title: 'Dinner',
                    description: 'Provided by us',
                    isActive: isEventActive('7:00 PM'),
                  ),
                  _buildTimelineItem(
                    time: '8:00 PM',
                    title: 'Review 1',
                    description: '',
                    isActive: isEventActive('8:00 PM'),
                  ),
                  _buildTimelineItem(
                    time: '9:00 PM',
                    title: 'Vertex Speech',
                    description: '',
                    isActive: isEventActive('9:00 PM'),
                  ),
                  _buildTimelineItem(
                    time: '11:00 PM',
                    title: 'Blackbox AI Interview Selection',
                    description: '',
                    isActive: isEventActive('11:00 PM'),
                  ),
                  _buildTimelineItem(
                    time: '12:00 AM',
                    title: 'Tea/Coffee',
                    description: 'Provided by us',
                    isActive: isEventActive('12:00 AM', isNextDay: true),
                  ),
                  _buildTimelineItem(
                    time: '7:00 AM',
                    title: 'Breakfast',
                    description: 'Provided by us (12th April)',
                    isActive: isEventActive('7:00 AM', isNextDay: true),
                  ),
                  _buildTimelineItem(
                    time: '9:00 AM',
                    title: 'Judging Begins',
                    description: '',
                    isActive: isEventActive('9:00 AM', isNextDay: true),
                  ),
                  _buildTimelineItem(
                    time: '11:30 AM',
                    title: 'Judging Ends',
                    description: '',
                    isActive: isEventActive('11:30 AM', isNextDay: true),
                  ),
                  _buildTimelineItem(
                    time: '12:00 PM',
                    title: 'Result Announcement',
                    description: '',
                    isActive: isEventActive('12:00 PM', isNextDay: true),
                  ),
                  _buildTimelineItem(
                    time: '12:30 PM',
                    title: 'Event Ends',
                    description: '',
                    isActive: isEventActive('12:30 PM', isNextDay: true),
                    isLast: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTimelineItem({
    required String time,
    required String title,
    required String description,
    required bool isActive,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            time,
            style: TextStyle(
              color: isActive
                  ? AppTheme.accentColor
                  : AppTheme.textSecondaryColor,
              fontSize: 14,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Column(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isActive
                    ? AppTheme.accentColor
                    : AppTheme.cardColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive
                      ? AppTheme.accentColor
                      : AppTheme.glassBorderColor,
                  width: 2,
                ),
              ),
              child: isActive
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 12,
                    )
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: isActive
                    ? AppTheme.accentColor.withOpacity(0.5)
                    : AppTheme.glassBorderColor,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isActive
                      ? AppTheme.textPrimaryColor
                      : AppTheme.textSecondaryColor,
                  fontSize: 16,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 14,
                ),
              ),
              ],
              SizedBox(height: isLast ? 0 : 20),
            ],
          ),
        ),
      ],
    );
  }
} 