import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskDifficulty { easy, medium, hard }
enum TaskStatus { pending, inProgress, completed }

class Task {
  final String id;
  final String title;
  final String description;
  final TaskDifficulty difficulty;
  final TaskStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final List<String> assignedStaffIds;
  final List<String> completedByStaffIds;
  final String? completedImageUrl;
  final List<TaskComplaint> complaints;
  final bool isActive;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.difficulty,
    required this.status,
    required this.createdAt,
    this.completedAt,
    required this.assignedStaffIds,
    required this.completedByStaffIds,
    this.completedImageUrl,
    required this.complaints,
    required this.isActive,
  });

  Task copyWith({
    String? id,
    String? title,
    String? description,
    TaskDifficulty? difficulty,
    TaskStatus? status,
    DateTime? createdAt,
    DateTime? completedAt,
    List<String>? assignedStaffIds,
    List<String>? completedByStaffIds,
    String? completedImageUrl,
    List<TaskComplaint>? complaints,
    bool? isActive,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      difficulty: difficulty ?? this.difficulty,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      assignedStaffIds: assignedStaffIds ?? this.assignedStaffIds,
      completedByStaffIds: completedByStaffIds ?? this.completedByStaffIds,
      completedImageUrl: completedImageUrl ?? this.completedImageUrl,
      complaints: complaints ?? this.complaints,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'difficulty': difficulty.name,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'assignedStaffIds': assignedStaffIds,
      'completedByStaffIds': completedByStaffIds,
      'completedImageUrl': completedImageUrl,
      'complaints': complaints.map((c) => c.toJson()).toList(),
      'isActive': isActive,
    };
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      difficulty: TaskDifficulty.values.firstWhere(
        (e) => e.name == json['difficulty'],
        orElse: () => TaskDifficulty.medium,
      ),
      status: TaskStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TaskStatus.pending,
      ),
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] is Timestamp 
              ? (json['createdAt'] as Timestamp).toDate()
              : DateTime.parse(json['createdAt']))
          : DateTime.now(),
      completedAt: json['completedAt'] != null
          ? (json['completedAt'] is Timestamp 
              ? (json['completedAt'] as Timestamp).toDate()
              : DateTime.parse(json['completedAt']))
          : null,
      assignedStaffIds: List<String>.from(json['assignedStaffIds'] ?? []),
      completedByStaffIds: List<String>.from(json['completedByStaffIds'] ?? []),
      completedImageUrl: json['completedImageUrl'],
      complaints: (json['complaints'] as List<dynamic>?)
              ?.map((c) => TaskComplaint.fromJson(c))
              .toList() ??
          [],
      isActive: json['isActive'] ?? true,
    );
  }

  factory Task.create({
    required String title,
    required String description,
    required TaskDifficulty difficulty,
  }) {
    return Task(
      id: '',
      title: title,
      description: description,
      difficulty: difficulty,
      status: TaskStatus.pending,
      createdAt: DateTime.now(),
      assignedStaffIds: [],
      completedByStaffIds: [],
      complaints: [],
      isActive: true,
    );
  }
}

class TaskComplaint {
  final String id;
  final String complaintText;
  final String? complaintImageUrl;
  final DateTime createdAt;
  final bool isAnonymous;
  final String? reporterName; // Anonim değilse isim

  TaskComplaint({
    required this.id,
    required this.complaintText,
    this.complaintImageUrl,
    required this.createdAt,
    required this.isAnonymous,
    this.reporterName,
  });

  TaskComplaint copyWith({
    String? id,
    String? complaintText,
    String? complaintImageUrl,
    DateTime? createdAt,
    bool? isAnonymous,
    String? reporterName,
  }) {
    return TaskComplaint(
      id: id ?? this.id,
      complaintText: complaintText ?? this.complaintText,
      complaintImageUrl: complaintImageUrl ?? this.complaintImageUrl,
      createdAt: createdAt ?? this.createdAt,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      reporterName: reporterName ?? this.reporterName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'complaintText': complaintText,
      'complaintImageUrl': complaintImageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'isAnonymous': isAnonymous,
      'reporterName': reporterName,
    };
  }

  factory TaskComplaint.fromJson(Map<String, dynamic> json) {
    return TaskComplaint(
      id: json['id'] ?? '',
      complaintText: json['complaintText'] ?? '',
      complaintImageUrl: json['complaintImageUrl'],
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] is Timestamp 
              ? (json['createdAt'] as Timestamp).toDate()
              : DateTime.parse(json['createdAt']))
          : DateTime.now(),
      isAnonymous: json['isAnonymous'] ?? true,
      reporterName: json['reporterName'],
    );
  }

  factory TaskComplaint.create({
    required String complaintText,
    String? complaintImageUrl,
    bool isAnonymous = true,
    String? reporterName,
  }) {
    return TaskComplaint(
      id: '',
      complaintText: complaintText,
      complaintImageUrl: complaintImageUrl,
      createdAt: DateTime.now(),
      isAnonymous: isAnonymous,
      reporterName: reporterName,
    );
  }
}
