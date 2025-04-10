class TeamMemberCredentials {
  final String name;
  final String username;
  final String password;
  final bool isLeader;

  TeamMemberCredentials({
    required this.name,
    required this.username,
    required this.password,
    this.isLeader = false,
  });

  factory TeamMemberCredentials.fromMap(Map<String, dynamic> map) {
    return TeamMemberCredentials(
      name: map['name'] ?? '',
      username: map['username'] ?? '',
      password: map['password'] ?? '',
      isLeader: map['isLeader'] ?? false,
    );
  }
} 