import 'package:cloud_firestore/cloud_firestore.dart';

class TaskScore {
  final String id;
  final String taskId;
  final String staffId;
  final double score;
  final DateTime createdAt;

  TaskScore({
    required this.id,
    required this.taskId,
    required this.staffId,
    required this.score,
    required this.createdAt,
  });

  TaskScore copyWith({
    String? id,
    String? taskId,
    String? staffId,
    double? score,
    DateTime? createdAt,
  }) {
    return TaskScore(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      staffId: staffId ?? this.staffId,
      score: score ?? this.score,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'taskId': taskId,
      'staffId': staffId,
      'score': score,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory TaskScore.fromJson(Map<String, dynamic> json) {
    return TaskScore(
      id: json['id'] ?? '',
      taskId: json['taskId'] ?? '',
      staffId: json['staffId'] ?? '',
      score: (json['score'] ?? 0.0).toDouble(),
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] is Timestamp 
              ? (json['createdAt'] as Timestamp).toDate()
              : DateTime.parse(json['createdAt']))
          : DateTime.now(),
    );
  }

  factory TaskScore.create({
    required String taskId,
    required String staffId,
    required double score,
  }) {
    return TaskScore(
      id: '',
      taskId: taskId,
      staffId: staffId,
      score: score,
      createdAt: DateTime.now(),
    );
  }
}
