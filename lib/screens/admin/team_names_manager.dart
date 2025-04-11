import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;
import '../../services/team_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class TeamNamesManagerScreen extends StatefulWidget {
  const TeamNamesManagerScreen({super.key});

  @override
  _TeamNamesManagerScreenState createState() => _TeamNamesManagerScreenState();
}

class _TeamNamesManagerScreenState extends State<TeamNamesManagerScreen> {
  final TeamService _teamService = TeamService();
  final _formKey = GlobalKey<FormState>();
  final _teamNameController = TextEditingController();
  final _searchController = TextEditingController();
  
  bool _isLoading = true;
  bool _isAdding = false;
  bool _isDeleting = false;
  List<String> _allTeamNames = [];
  List<String> _filteredTeamNames = [];
  String? _errorMessage;
  String? _successMessage;
  
  @override
  void initState() {
    super.initState();
    _loadTeamNames();
    _searchController.addListener(_filterTeamNames);
  }
  
  void _filterTeamNames() {
    final searchQuery = _searchController.text.toLowerCase();
    if (searchQuery.isEmpty) {
      setState(() {
        _filteredTeamNames = List.from(_allTeamNames);
      });
    } else {
      setState(() {
        _filteredTeamNames = _allTeamNames
            .where((teamName) => teamName.toLowerCase().contains(searchQuery))
            .toList();
      });
    }
  }
  
  Future<void> _loadTeamNames() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });
    
    try {
      final teamNames = await _teamService.getAllTeamNames();
      
      // Sort team names alphabetically
      teamNames.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      
      setState(() {
        _allTeamNames = teamNames;
        _filteredTeamNames = List.from(teamNames);
        _isLoading = false;
      });
      
      developer.log('Loaded ${teamNames.length} team names');
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading team names: $e';
        _isLoading = false;
      });
      developer.log('Error loading team names: $e');
    }
  }
  
  Future<void> _addTeamName() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    final teamName = _teamNameController.text.trim();
    
    if (teamName.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a team name';
      });
      return;
    }
    
    setState(() {
      _isAdding = true;
      _errorMessage = null;
      _successMessage = null;
    });
    
    try {
      // Check if the team name already exists
      if (_allTeamNames.any((name) => name.toLowerCase() == teamName.toLowerCase())) {
        setState(() {
          _errorMessage = 'Team name already exists';
          _isAdding = false;
        });
        return;
      }
      
      // Add the team name
      final success = await _teamService.addTeamName(teamName);
      
      if (success) {
        setState(() {
          _successMessage = 'Team name added successfully';
          _teamNameController.clear();
        });
        
        // Reload the team names list
        await _loadTeamNames();
      } else {
        setState(() {
          _errorMessage = 'Failed to add team name';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error adding team name: $e';
      });
      developer.log('Error adding team name: $e');
    } finally {
      setState(() {
        _isAdding = false;
      });
    }
  }
  
  Future<void> _deleteTeamName(String teamName) async {
    setState(() {
      _isDeleting = true;
      _errorMessage = null;
      _successMessage = null;
    });
    
    try {
      final success = await _teamService.removeTeamName(teamName);
      
      if (success) {
        setState(() {
          _successMessage = 'Team name removed successfully';
        });
        
        // Reload the team names list
        await _loadTeamNames();
      } else {
        setState(() {
          _errorMessage = 'Failed to remove team name';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error removing team name: $e';
      });
      developer.log('Error removing team name: $e');
    } finally {
      setState(() {
        _isDeleting = false;
      });
    }
  }
  
  Future<void> _confirmDeleteTeamName(String teamName) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: Text(
          'Confirm Deletion',
          style: TextStyle(
            color: AppTheme.textPrimaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to remove "$teamName" from the approved team names list?',
          style: TextStyle(
            color: AppTheme.textSecondaryColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteTeamName(teamName);
            },
            child: Text(
              'Delete',
              style: TextStyle(
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _importTeamNamesDialog() async {
    final textController = TextEditingController();
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: Text(
          'Import Team Names',
          style: TextStyle(
            color: AppTheme.textPrimaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Paste a list of team names, one per line:',
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: textController,
              maxLines: 10,
              decoration: InputDecoration(
                hintText: 'Team A\nTeam B\nTeam C',
                hintStyle: TextStyle(
                  color: AppTheme.textSecondaryColor.withOpacity(0.5),
                ),
                border: OutlineInputBorder(),
                fillColor: AppTheme.backgroundColor.withOpacity(0.3),
                filled: true,
              ),
              style: TextStyle(
                color: AppTheme.textPrimaryColor,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _importTeamNames(textController.text);
            },
            child: Text(
              'Import',
              style: TextStyle(
                color: AppTheme.accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _importTeamNames(String textData) async {
    if (textData.trim().isEmpty) {
      setState(() {
        _errorMessage = 'No team names to import';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });
    
    try {
      // Split the text into lines and remove empty lines
      final teamNames = textData
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      
      if (teamNames.isEmpty) {
        setState(() {
          _errorMessage = 'No valid team names found';
          _isLoading = false;
        });
        return;
      }
      
      int successCount = 0;
      
      // Add each team name
      for (final teamName in teamNames) {
        final success = await _teamService.addTeamName(teamName);
        if (success) {
          successCount++;
        }
      }
      
      setState(() {
        _successMessage = 'Imported $successCount of ${teamNames.length} team names';
      });
      
      // Reload the team names list
      await _loadTeamNames();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error importing team names: $e';
      });
      developer.log('Error importing team names: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  void dispose() {
    _teamNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(
        title: 'Manage Team Names',
      ),
      body: Stack(
        children: [
          Container(
            color: AppTheme.backgroundColor,
          ),
          SafeArea(
            child: Column(
              children: [
                // Add Team Name Form
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add New Team Name',
                              style: TextStyle(
                                color: AppTheme.textPrimaryColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _teamNameController,
                                    decoration: InputDecoration(
                                      labelText: 'Team Name',
                                      labelStyle: TextStyle(
                                        color: AppTheme.textSecondaryColor,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      fillColor: AppTheme.cardColor.withOpacity(0.5),
                                      filled: true,
                                    ),
                                    style: TextStyle(
                                      color: AppTheme.textPrimaryColor,
                                    ),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Please enter a team name';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                ElevatedButton(
                                  onPressed: _isAdding ? null : _addTeamName,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: _isAdding
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('Add'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'or import multiple team names:',
                                  style: TextStyle(
                                    color: AppTheme.textSecondaryColor,
                                    fontSize: 12,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: _importTeamNamesDialog,
                                  icon: Icon(
                                    Icons.upload_file,
                                    color: AppTheme.accentColor,
                                    size: 16,
                                  ),
                                  label: Text(
                                    'Import From Text',
                                    style: TextStyle(
                                      color: AppTheme.accentColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Status Messages
                if (_errorMessage != null || _successMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _errorMessage != null
                            ? Colors.red.withOpacity(0.1)
                            : Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _errorMessage != null
                              ? Colors.red.withOpacity(0.3)
                              : Colors.green.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _errorMessage != null
                                ? Icons.error_outline
                                : Icons.check_circle_outline,
                            color: _errorMessage != null ? Colors.red : Colors.green,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage ?? _successMessage!,
                              style: TextStyle(
                                color: _errorMessage != null ? Colors.red : Colors.green,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Search Bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search Team Names',
                      labelStyle: TextStyle(
                        color: AppTheme.textSecondaryColor,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: AppTheme.textSecondaryColor,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      fillColor: AppTheme.cardColor.withOpacity(0.5),
                      filled: true,
                    ),
                    style: TextStyle(
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                ),
                
                // Team Names List
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredTeamNames.isEmpty
                          ? Center(
                              child: Text(
                                _allTeamNames.isEmpty
                                    ? 'No team names added yet'
                                    : 'No team names match your search',
                                style: TextStyle(
                                  color: AppTheme.textSecondaryColor,
                                  fontSize: 16,
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredTeamNames.length,
                              itemBuilder: (context, index) {
                                final teamName = _filteredTeamNames[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: GlassCard(
                                    child: ListTile(
                                      title: Text(
                                        teamName,
                                        style: TextStyle(
                                          color: AppTheme.textPrimaryColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      trailing: IconButton(
                                        icon: Icon(
                                          Icons.delete,
                                          color: Colors.red.withOpacity(0.7),
                                        ),
                                        onPressed: () => _confirmDeleteTeamName(teamName),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
                
                // Status Bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Total Teams: ${_allTeamNames.length} | Showing: ${_filteredTeamNames.length}',
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
        ],
      ),
    );
  }
} 