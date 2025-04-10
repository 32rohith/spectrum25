import 'track.dart';

class ProjectSubmission {
  final String projectName;
  final String description;
  final String githubLink;
  final Track track;
  final String teamId;
  final DateTime submittedAt;

  ProjectSubmission({
    required this.projectName,
    required this.description,
    required this.githubLink,
    required this.track,
    required this.teamId,
    required this.submittedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'projectName': projectName,
      'description': description,
      'githubLink': githubLink,
      'track': track.displayName,
      'teamId': teamId,
      'submittedAt': submittedAt.toIso8601String(),
    };
  }

  factory ProjectSubmission.fromJson(Map<String, dynamic> json) {
    return ProjectSubmission(
      projectName: json['projectName'] as String,
      description: json['description'] as String,
      githubLink: json['githubLink'] as String,
      track: Track.fromString(json['track'] as String),
      teamId: json['teamId'] as String,
      submittedAt: DateTime.parse(json['submittedAt'] as String),
    );
  }
} 