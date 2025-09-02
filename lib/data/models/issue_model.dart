import 'package:cloud_firestore/cloud_firestore.dart';

enum IssueCategory { cleaning, cafe, playground, other }
enum IssuePriority { low, medium, high, urgent }

class Issue {
  final String id;
  final String title;
  final String description;
  final IssueCategory category;
  final IssuePriority priority;
  final DateTime createdAt;
  final String createdBy;
  final bool isResolved;
  final DateTime? resolvedAt;
  final String? resolvedBy;

  Issue({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.createdAt,
    required this.createdBy,
    this.isResolved = false,
    this.resolvedAt,
    this.resolvedBy,
  });

  Issue copyWith({
    String? id,
    String? title,
    String? description,
    IssueCategory? category,
    IssuePriority? priority,
    DateTime? createdAt,
    String? createdBy,
    bool? isResolved,
    DateTime? resolvedAt,
    String? resolvedBy,
  }) {
    return Issue(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      isResolved: isResolved ?? this.isResolved,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolvedBy: resolvedBy ?? this.resolvedBy,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category.name,
      'priority': priority.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'isResolved': isResolved,
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'resolvedBy': resolvedBy,
    };
  }

  factory Issue.fromJson(Map<String, dynamic> json) {
    return Issue(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: IssueCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => IssueCategory.other,
      ),
      priority: IssuePriority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => IssuePriority.medium,
      ),
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] is Timestamp 
              ? (json['createdAt'] as Timestamp).toDate()
              : DateTime.parse(json['createdAt']))
          : DateTime.now(),
      createdBy: json['createdBy'] ?? '',
      isResolved: json['isResolved'] ?? false,
      resolvedAt: json['resolvedAt'] != null
          ? (json['resolvedAt'] is Timestamp 
              ? (json['resolvedAt'] as Timestamp).toDate()
              : DateTime.parse(json['resolvedAt']))
          : null,
      resolvedBy: json['resolvedBy'],
    );
  }

  static Issue create({
    required String title,
    required String description,
    required IssueCategory category,
    required IssuePriority priority,
    required String createdBy,
  }) {
    return Issue(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: description,
      category: category,
      priority: priority,
      createdAt: DateTime.now(),
      createdBy: createdBy,
    );
  }
}
