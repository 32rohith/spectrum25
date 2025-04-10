import 'package:cloud_firestore/cloud_firestore.dart';

class Meal {
  final String id;
  final String name;
  final DateTime startTime;
  final DateTime endTime;
  final bool isActive;

  Meal({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    this.isActive = false,
  });

  // Check if meal is currently active based on time
  bool get isCurrentlyActive {
    final now = DateTime.now();
    return now.isAfter(startTime) && now.isBefore(endTime);
  }

  factory Meal.fromJson(Map<String, dynamic> json) {
    return Meal(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      startTime: (json['startTime'] as Timestamp).toDate(),
      endTime: (json['endTime'] as Timestamp).toDate(),
      isActive: json['isActive'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'isActive': isActive,
    };
  }
}

class MealConsumption {
  final String id;
  final String memberId;
  final String memberName;
  final String teamId;
  final String teamName;
  final String mealId;
  final String mealName;
  final DateTime timestamp;
  final bool isConsumed;

  MealConsumption({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.teamId,
    required this.teamName,
    required this.mealId,
    required this.mealName,
    required this.timestamp,
    required this.isConsumed,
  });

  factory MealConsumption.fromJson(Map<String, dynamic> json) {
    return MealConsumption(
      id: json['id'] ?? '',
      memberId: json['memberId'] ?? '',
      memberName: json['memberName'] ?? '',
      teamId: json['teamId'] ?? '',
      teamName: json['teamName'] ?? '',
      mealId: json['mealId'] ?? '',
      mealName: json['mealName'] ?? '',
      timestamp: (json['timestamp'] as Timestamp).toDate(),
      isConsumed: json['isConsumed'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'memberId': memberId,
      'memberName': memberName,
      'teamId': teamId,
      'teamName': teamName,
      'mealId': mealId,
      'mealName': mealName,
      'timestamp': Timestamp.fromDate(timestamp),
      'isConsumed': isConsumed,
    };
  }
} 