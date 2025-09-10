class TaskCompletionHistory {
  final String id;
  final String taskId;
  final String taskTitle;
  final String taskDescription;
  final DateTime completedAt;
  final List<String> completedByStaffIds;
  final String? completedImageUrl;
  final DateTime createdAt;

  const TaskCompletionHistory({
    required this.id,
    required this.taskId,
    required this.taskTitle,
    required this.taskDescription,
    required this.completedAt,
    required this.completedByStaffIds,
    this.completedImageUrl,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'taskId': taskId,
      'taskTitle': taskTitle,
      'taskDescription': taskDescription,
      'completedAt': completedAt.toIso8601String(),
      'completedByStaffIds': completedByStaffIds,
      'completedImageUrl': completedImageUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory TaskCompletionHistory.fromJson(Map<String, dynamic> json) {
    return TaskCompletionHistory(
      id: json['id'] as String,
      taskId: json['taskId'] as String,
      taskTitle: json['taskTitle'] as String,
      taskDescription: json['taskDescription'] as String,
      completedAt: DateTime.parse(json['completedAt'] as String),
      completedByStaffIds: List<String>.from(json['completedByStaffIds'] as List),
      completedImageUrl: json['completedImageUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  TaskCompletionHistory copyWith({
    String? id,
    String? taskId,
    String? taskTitle,
    String? taskDescription,
    DateTime? completedAt,
    List<String>? completedByStaffIds,
    String? completedImageUrl,
    DateTime? createdAt,
  }) {
    return TaskCompletionHistory(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      taskTitle: taskTitle ?? this.taskTitle,
      taskDescription: taskDescription ?? this.taskDescription,
      completedAt: completedAt ?? this.completedAt,
      completedByStaffIds: completedByStaffIds ?? this.completedByStaffIds,
      completedImageUrl: completedImageUrl ?? this.completedImageUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
