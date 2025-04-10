class LeaderboardEntry {
  final String teamName;
  final int rank;
  final int score;

  LeaderboardEntry({
    required this.teamName,
    required this.rank,
    required this.score,
  });

  factory LeaderboardEntry.fromMap(Map<String, dynamic> map) {
    return LeaderboardEntry(
      teamName: map['teamName'] ?? '',
      rank: map['rank'] ?? 0,
      score: map['score'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'teamName': teamName,
      'rank': rank,
      'score': score,
    };
  }
} 