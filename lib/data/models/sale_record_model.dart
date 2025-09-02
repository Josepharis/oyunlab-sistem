import 'package:cloud_firestore/cloud_firestore.dart';

class SaleRecord {
  final String id;
  final String userId;
  final String userName;
  final String customerName;
  final double amount;
  final String description;
  final DateTime date;
  final String? customerPhone;
  final String? customerEmail;
  final List<String>? items;
  final String? paymentMethod;
  final String? status;
  final DateTime createdAt;
  final DateTime updatedAt;

  SaleRecord({
    required this.id,
    required this.userId,
    required this.userName,
    required this.customerName,
    required this.amount,
    required this.description,
    required this.date,
    this.customerPhone,
    this.customerEmail,
    this.items,
    this.paymentMethod,
    this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  // JSON'dan SaleRecord oluştur
  factory SaleRecord.fromJson(Map<String, dynamic> json) {
    return SaleRecord(
      id: json['id'] as String,
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      customerName: json['customerName'] as String,
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String,
      date: _parseDateTime(json['date']),
      customerPhone: json['customerPhone'] as String?,
      customerEmail: json['customerEmail'] as String?,
      items: json['items'] != null 
          ? List<String>.from(json['items'] as List)
          : null,
      paymentMethod: json['paymentMethod'] as String?,
      status: json['status'] as String?,
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    
    if (value is DateTime) {
      return value;
    } else if (value is String) {
      return DateTime.parse(value);
    } else {
      // Firestore Timestamp
      return value.toDate();
    }
  }

  // SaleRecord'ı JSON'a çevir
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'customerName': customerName,
      'amount': amount,
      'description': description,
      'date': Timestamp.fromDate(date),
      'customerPhone': customerPhone,
      'customerEmail': customerEmail,
      'items': items,
      'paymentMethod': paymentMethod,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // Kopya oluştur
  SaleRecord copyWith({
    String? id,
    String? userId,
    String? userName,
    String? customerName,
    double? amount,
    String? description,
    DateTime? date,
    String? customerPhone,
    String? customerEmail,
    List<String>? items,
    String? paymentMethod,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SaleRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      customerName: customerName ?? this.customerName,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      date: date ?? this.date,
      customerPhone: customerPhone ?? this.customerPhone,
      customerEmail: customerEmail ?? this.customerEmail,
      items: items ?? this.items,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Eşitlik kontrolü
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SaleRecord && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'SaleRecord(id: $id, customerName: $customerName, amount: $amount, date: $date)';
  }
}
