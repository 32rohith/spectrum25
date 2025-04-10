class TeamMember {
  final String name;
  final String email;
  final String phone;
  final String device;
  final bool isVerified;

  TeamMember({
    required this.name,
    required this.email,
    required this.phone,
    required this.device,
    this.isVerified = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'device': device,
      'isVerified': isVerified,
    };
  }

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    return TeamMember(
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      device: json['device'] ?? '',
      isVerified: json['isVerified'] ?? true,
    );
  }
}

class Team {
  final String teamName;
  final String teamId;
  final String username;
  final String password;
  final TeamMember leader;
  final List<TeamMember> members;
  final bool isVerified;
  final bool isRegistered;
  final String? projectSubmissionUrl;
  final String? projectDescription;

  Team({
    required this.teamName,
    required this.teamId,
    required this.username,
    required this.password,
    required this.leader,
    required this.members,
    this.isVerified = false,
    this.isRegistered = true,
    this.projectSubmissionUrl,
    this.projectDescription,
  });

  Map<String, dynamic> toJson() {
    return {
      'teamName': teamName,
      'teamId': teamId,
      'username': username,
      'password': password,
      'leader': leader.toJson(),
      'members': members.map((member) => member.toJson()).toList(),
      'isVerified': isVerified,
      'isRegistered': isRegistered,
      'projectSubmissionUrl': projectSubmissionUrl,
      'projectDescription': projectDescription,
    };
  }

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      teamName: json['teamName'] ?? '',
      teamId: json['teamId'] ?? '',
      username: json['username'] ?? '',
      password: json['password'] ?? '',
      leader: TeamMember.fromJson(json['leader'] ?? {}),
      members: (json['members'] as List?)
          ?.map((member) => TeamMember.fromJson(member))
          .toList() ??
          [],
      isVerified: json['isVerified'] ?? false,
      isRegistered: json['isRegistered'] ?? true,
      projectSubmissionUrl: json['projectSubmissionUrl'],
      projectDescription: json['projectDescription'],
    );
  }
}