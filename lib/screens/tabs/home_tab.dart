import 'package:flutter/material.dart';
import 'dart:async';
import '../../models/team.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class TimelineEvent {
  final String time;
  final String title;
  final String description;
  final DateTime dateTime;
  final Duration duration;

  TimelineEvent({
    required this.time,
    required this.title,
    required this.description,
    required this.dateTime,
    this.duration = const Duration(hours: 1),
  });

  bool isActive(DateTime now) {
    return now.isAfter(dateTime) && now.isBefore(dateTime.add(duration));
  }

  bool isPast(DateTime now) {
    return now.isAfter(dateTime.add(duration));
  }

  bool isUpcoming(DateTime now) {
    return now.isBefore(dateTime);
  }

  String getStatus(DateTime now) {
    if (isActive(now)) return 'active';
    if (isPast(now)) return 'past';
    return 'upcoming';
  }
}

class HomeTab extends StatefulWidget {
  final Team team;
  final String? userName;
  final String? userRole;

  const HomeTab({
    super.key,
    required this.team,
    this.userName,
    this.userRole,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  late List<TimelineEvent> _timelineEvents;
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initializeTimelineEvents();
    // Update the UI every minute to reflect time changes
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      setState(() {
        _now = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _initializeTimelineEvents() {
    // Get the current date to use as base
    final now = DateTime.now();
    
    // Hackathon usually runs for 2 days, so we'll set dates for day 1 and day 2
    final day1 = DateTime(now.year, now.month, now.day); // Today
    final day2 = day1.add(const Duration(days: 1)); // Tomorrow
    
    _timelineEvents = [
      TimelineEvent(
        time: '8:30 AM',
        title: 'Reporting Time',
        description: 'For participants',
        dateTime: DateTime(day1.year, day1.month, day1.day, 8, 30),
        duration: const Duration(hours: 1, minutes: 30),
      ),
      TimelineEvent(
        time: '10:00 AM',
        title: 'Inauguration Ceremony',
        description: 'Main Hall',
        dateTime: DateTime(day1.year, day1.month, day1.day, 10, 0),
        duration: const Duration(hours: 2, minutes: 30),
      ),
      TimelineEvent(
        time: '12:30 PM',
        title: 'Lunch',
        description: 'Provided by us',
        dateTime: DateTime(day1.year, day1.month, day1.day, 12, 30),
        duration: const Duration(hours: 1),
      ),
      TimelineEvent(
        time: '1:30 PM',
        title: 'Guest Speaker Session',
        description: 'IBM',
        dateTime: DateTime(day1.year, day1.month, day1.day, 13, 30),
        duration: const Duration(hours: 3, minutes: 30),
      ),
      TimelineEvent(
        time: '5:00 PM',
        title: '2IM Speech',
        description: '',
        dateTime: DateTime(day1.year, day1.month, day1.day, 17, 0),
        duration: const Duration(hours: 2),
      ),
      TimelineEvent(
        time: '7:00 PM',
        title: 'Dinner',
        description: 'Provided by us',
        dateTime: DateTime(day1.year, day1.month, day1.day, 19, 0),
        duration: const Duration(hours: 1),
      ),
      TimelineEvent(
        time: '8:00 PM',
        title: 'Review 1',
        description: '',
        dateTime: DateTime(day1.year, day1.month, day1.day, 20, 0),
        duration: const Duration(hours: 1),
      ),
      TimelineEvent(
        time: '9:00 PM',
        title: 'Vertex Speech',
        description: '',
        dateTime: DateTime(day1.year, day1.month, day1.day, 21, 0),
        duration: const Duration(hours: 2),
      ),
      TimelineEvent(
        time: '11:00 PM',
        title: 'Blackbox AI Interview Selection',
        description: '',
        dateTime: DateTime(day1.year, day1.month, day1.day, 23, 0),
        duration: const Duration(hours: 1),
      ),
      TimelineEvent(
        time: '12:00 AM',
        title: 'Tea/Coffee',
        description: 'Provided by us',
        dateTime: DateTime(day2.year, day2.month, day2.day, 0, 0),
        duration: const Duration(hours: 1),
      ),
      TimelineEvent(
        time: '7:00 AM',
        title: 'Breakfast',
        description: 'Provided by us (Day 2)',
        dateTime: DateTime(day2.year, day2.month, day2.day, 7, 0),
        duration: const Duration(hours: 2),
      ),
      TimelineEvent(
        time: '9:00 AM',
        title: 'Judging Begins',
        description: '',
        dateTime: DateTime(day2.year, day2.month, day2.day, 9, 0),
        duration: const Duration(hours: 2, minutes: 30),
      ),
      TimelineEvent(
        time: '11:30 AM',
        title: 'Judging Ends',
        description: '',
        dateTime: DateTime(day2.year, day2.month, day2.day, 11, 30),
        duration: const Duration(minutes: 30),
      ),
      TimelineEvent(
        time: '12:00 PM',
        title: 'Result Announcement',
        description: '',
        dateTime: DateTime(day2.year, day2.month, day2.day, 12, 0),
        duration: const Duration(minutes: 30),
      ),
      TimelineEvent(
        time: '12:30 PM',
        title: 'Event Ends',
        description: '',
        dateTime: DateTime(day2.year, day2.month, day2.day, 12, 30),
        duration: const Duration(minutes: 30),
      ),
    ];
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
            if (widget.userName != null)
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
                              'Welcome, ${widget.userName}!',
                              style: TextStyle(
                                color: AppTheme.textPrimaryColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (widget.userRole != null)
                              Text(
                                'Logged in as ${widget.userRole == 'leader' ? 'Team Leader' : 'Team Member'}',
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
            
            // Current time indicator
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      color: AppTheme.accentColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Current Time: ${_formatTime(_now)}',
                      style: TextStyle(
                        color: AppTheme.textPrimaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            const SizedBox(height: 16),
            
            // Spectrum Agenda
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
            Text(
                  'Event Timeline',
              style: TextStyle(
                color: AppTheme.textPrimaryColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _now = DateTime.now();
                    });
                  },
                  icon: Icon(Icons.refresh, size: 16, color: AppTheme.accentColor),
                  label: Text('Refresh', style: TextStyle(color: AppTheme.accentColor, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            GlassCard(
              child: Column(
                children: List.generate(_timelineEvents.length, (index) {
                  final event = _timelineEvents[index];
                  final isLast = index == _timelineEvents.length - 1;
                  final status = event.getStatus(_now);
                  
                  return _buildTimelineItem(
                    event: event,
                    status: status,
                    isLast: isLast,
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
  
  Widget _buildTimelineItem({
    required TimelineEvent event,
    required String status,
    bool isLast = false,
  }) {
    final isActive = status == 'active';
    final isPast = status == 'past';
    
    Color getStatusColor() {
      if (isActive) return AppTheme.accentColor;
      if (isPast) return Colors.grey;
      return AppTheme.primaryColor; // upcoming
    }
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            event.time,
            style: TextStyle(
              color: isActive
                  ? AppTheme.accentColor
                  : isPast
                      ? Colors.grey
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
                    : isPast
                        ? Colors.grey.withOpacity(0.3)
                    : AppTheme.cardColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive
                      ? AppTheme.accentColor
                      : isPast
                          ? Colors.grey
                      : AppTheme.glassBorderColor,
                  width: 2,
                ),
              ),
              child: isActive
                  ? const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 12,
                    )
                  : isPast
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
                color: isPast
                    ? Colors.grey.withOpacity(0.5)
                    : isActive 
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      event.title,
                style: TextStyle(
                  color: isActive
                      ? AppTheme.textPrimaryColor
                            : isPast
                                ? Colors.grey
                      : AppTheme.textSecondaryColor,
                  fontSize: 16,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: getStatusColor().withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isActive 
                          ? 'NOW' 
                          : isPast 
                              ? 'PAST'
                              : 'UPCOMING',
                      style: TextStyle(
                        color: getStatusColor(),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (event.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                  event.description,
                style: TextStyle(
                    color: isPast ? Colors.grey : AppTheme.textSecondaryColor,
                  fontSize: 14,
                ),
              ),
              ],
              if (isActive) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _calculateEventProgress(event),
                  backgroundColor: Colors.grey.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentColor),
                ),
              ],
              SizedBox(height: isLast ? 0 : 20),
            ],
          ),
        ),
      ],
    );
  }
  
  double _calculateEventProgress(TimelineEvent event) {
    final start = event.dateTime;
    final end = start.add(event.duration);
    final now = _now;
    
    if (now.isBefore(start)) return 0.0;
    if (now.isAfter(end)) return 1.0;
    
    final totalDuration = end.difference(start).inMilliseconds;
    final elapsedDuration = now.difference(start).inMilliseconds;
    
    return elapsedDuration / totalDuration;
  }
} 