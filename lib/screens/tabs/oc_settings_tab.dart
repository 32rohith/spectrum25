import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../admin/deadline_manager.dart';
import '../admin/team_names_manager.dart';

class OCSettingsTab extends StatelessWidget {
  const OCSettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            
            Text(
              'Configuration',
              style: TextStyle(
                color: AppTheme.textPrimaryColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Deadline Manager Card
            GlassCard(
              child: ListTile(
                leading: const Icon(
                  Icons.timer,
                  color: Colors.orange,
                  size: 28,
                ),
                title: Text(
                  'Submission Deadline',
                  style: TextStyle(
                    color: AppTheme.textPrimaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  'Configure project submission portal deadlines',
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 12,
                  ),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  color: AppTheme.accentColor,
                  size: 16,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DeadlineManagerScreen(),
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Team Names Manager Card
            GlassCard(
              child: ListTile(
                leading: const Icon(
                  Icons.group,
                  color: Colors.green,
                  size: 28,
                ),
                title: Text(
                  'Team Names',
                  style: TextStyle(
                    color: AppTheme.textPrimaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  'Manage approved team names for registration',
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 12,
                  ),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  color: AppTheme.accentColor,
                  size: 16,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TeamNamesManagerScreen(),
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 24),
            
            Text(
              'System Information',
              style: TextStyle(
                color: AppTheme.textPrimaryColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // App Info Card
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppTheme.accentColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'App Information',
                          style: TextStyle(
                            color: AppTheme.textPrimaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow('App Name', 'Spectrum 25'),
                    _buildInfoRow('Version', '1.0.0'),
                    _buildInfoRow('Build', '23'),
                    _buildInfoRow('Environment', 'Production'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            Center(
              child: Text(
                '© 2023-2024 Spectrum 25 Organizing Committee',
                style: TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                color: AppTheme.textPrimaryColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 