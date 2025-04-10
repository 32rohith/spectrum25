import 'package:flutter/material.dart';
import '../../models/leaderboard_entry.dart';
import '../../services/leaderboard_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class LeaderboardTab extends StatelessWidget {
  final LeaderboardService _leaderboardService = LeaderboardService();

  LeaderboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(
        title: 'Leaderboard',
      ),
      body: StreamBuilder<List<LeaderboardEntry>>(
        stream: _leaderboardService.getTopTeams(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading leaderboard',
                style: TextStyle(color: AppTheme.textPrimaryColor),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final teams = snapshot.data!;
          final topThree = teams.take(3).toList();
          final remainingTeams = teams.skip(3).take(7).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Top 3 Teams
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (topThree.length > 1)
                      _buildTopThreeCard(topThree[1], 2),
                    if (topThree.isNotEmpty)
                      _buildTopThreeCard(topThree[0], 1, isFirst: true),
                    if (topThree.length > 2)
                      _buildTopThreeCard(topThree[2], 3),
                  ],
                ),
                const SizedBox(height: 32),
                // Remaining Teams
                GlassCard(
                  child: Column(
                    children: remainingTeams.map((team) {
                      return _buildTeamRow(team);
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopThreeCard(LeaderboardEntry team, int position, {bool isFirst = false}) {
    final colors = [
      Colors.amber, // Gold
      Colors.grey[400], // Silver
      Colors.brown[300], // Bronze
    ];

    return Container(
      width: isFirst ? 160 : 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors[position - 1]!,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Text(
            '#$position',
            style: TextStyle(
              color: colors[position - 1],
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            team.teamName,
            style: TextStyle(
              color: AppTheme.textPrimaryColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTeamRow(LeaderboardEntry team) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Text(
            '#${team.rank}',
            style: TextStyle(
              color: AppTheme.textSecondaryColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              team.teamName,
              style: TextStyle(
                color: AppTheme.textPrimaryColor,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 