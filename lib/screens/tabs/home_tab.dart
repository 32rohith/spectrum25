import 'package:flutter/material.dart';
import '../../models/team.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class HomeTab extends StatelessWidget {
  final Team team;

  const HomeTab({
    super.key,
    required this.team,
  });

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
            // Spectrum Agenda
            Text(
              'Spectrum Agenda',
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
                    isActive: true,
                  ),
                  _buildTimelineItem(
                    time: '10:00 AM',
                    title: 'Inauguration Ceremony',
                    description: 'Main Hall',
                    isActive: true,
                  ),
                  _buildTimelineItem(
                    time: '12:30 PM',
                    title: 'Lunch',
                    description: 'Provided by us',
                    isActive: false,
                    duration: '1 hour',
                  ),
                  _buildTimelineItem(
                    time: '1:30 PM',
                    title: 'Guest Speaker Session',
                    description: 'IBM',
                    isActive: false,
                    duration: '2 hours',
                  ),
                  _buildTimelineItem(
                    time: '5:00 PM',
                    title: '2IM Speech',
                    description: '',
                    isActive: false,
                    duration: '1 hour',
                  ),
                  _buildTimelineItem(
                    time: '7:00 PM',
                    title: 'Dinner',
                    description: 'Provided by us',
                    isActive: false,
                    duration: '1 hour',
                  ),
                  _buildTimelineItem(
                    time: '8:00 PM',
                    title: 'Review 1',
                    description: '',
                    isActive: false,
                    duration: '1 hour',
                  ),
                  _buildTimelineItem(
                    time: '9:00 PM',
                    title: 'Vertex Speech',
                    description: '',
                    isActive: false,
                    duration: '1 hour',
                  ),
                  _buildTimelineItem(
                    time: '11:00 PM',
                    title: 'Blackbox AI Interview Selection',
                    description: '',
                    isActive: false,
                  ),
                  _buildTimelineItem(
                    time: '12:00 AM',
                    title: 'Tea/Coffee',
                    description: 'Provided by us',
                    isActive: false,
                  ),
                  _buildTimelineItem(
                    time: '7:00 AM',
                    title: 'Breakfast',
                    description: 'Provided by us (12th April)',
                    isActive: false,
                  ),
                  _buildTimelineItem(
                    time: '9:00 AM',
                    title: 'Judging Begins',
                    description: '',
                    isActive: false,
                  ),
                  _buildTimelineItem(
                    time: '11:30 AM',
                    title: 'Judging Ends',
                    description: '',
                    isActive: false,
                  ),
                  _buildTimelineItem(
                    time: '12:00 PM',
                    title: 'Result Announcement',
                    description: '',
                    isActive: false,
                  ),
                  _buildTimelineItem(
                    time: '12:30 PM',
                    title: 'Event Ends',
                    description: '',
                    isActive: false,
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
    String? duration,
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
              if (duration != null) ...[
                const SizedBox(height: 4),
                Text(
                  duration,
                  style: TextStyle(
                    color: AppTheme.accentColor,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
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