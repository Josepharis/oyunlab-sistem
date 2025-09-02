import 'package:cloud_firestore/cloud_firestore.dart';

class Staff {
  final String id;
  final String name;
  final String email;
  final String? phoneNumber;
  final String? position;
  final DateTime? hireDate;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Staff({
    required this.id,
    required this.name,
    required this.email,
    this.phoneNumber,
    this.position,
    this.hireDate,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  Staff copyWith({
    String? id,
    String? name,
    String? email,
    String? phoneNumber,
    String? position,
    DateTime? hireDate,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Staff(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      position: position ?? this.position,
      hireDate: hireDate ?? this.hireDate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'position': position,
      'hireDate': hireDate?.toIso8601String(),
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Staff.fromJson(Map<String, dynamic> json) {
    return Staff(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phoneNumber: json['phoneNumber'],
      position: json['position'],
      hireDate: json['hireDate'] != null
          ? DateTime.parse(json['hireDate'])
          : null,
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }

  factory Staff.create({
    required String name,
    required String email,
    String? phoneNumber,
    String? position,
  }) {
    return Staff(
      id: '',
      name: name,
      email: email,
      phoneNumber: phoneNumber,
      position: position,
      createdAt: DateTime.now(),
    );
  }
}
