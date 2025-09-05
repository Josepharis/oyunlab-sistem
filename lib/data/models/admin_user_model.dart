import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole {
  admin,      // Tam yetki
  manager,    // Yönetici
  staff,      // Personel
  viewer      // Sadece görüntüleme
}

class AdminUser {
  final String id;
  final String email;
  final String name;
  final String? phone;
  final UserRole role;
  final DateTime createdAt;
  final DateTime lastLoginAt;
  final bool isActive;
  final List<String> permissions;
  final Map<String, dynamic>? additionalData;
  final String? firebaseUid; // Firebase Auth UID

  AdminUser({
    required this.id,
    required this.email,
    required this.name,
    this.phone,
    required this.role,
    required this.createdAt,
    required this.lastLoginAt,
    required this.isActive,
    required this.permissions,
    this.additionalData,
    this.firebaseUid,
  });

  // JSON'dan AdminUser oluştur
  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'] as String? ?? '',
      email: json['email'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      role: UserRole.values.firstWhere(
        (e) => e.toString() == 'UserRole.${json['role']}',
        orElse: () => UserRole.staff,
      ),
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      lastLoginAt: (json['lastLoginAt'] as Timestamp).toDate(),
      isActive: json['isActive'] as bool? ?? true,
      permissions: List<String>.from(json['permissions'] ?? []),
      additionalData: json['additionalData'] as Map<String, dynamic>?,
      firebaseUid: json['firebaseUid'] as String?,
    );
  }

  // AdminUser'ı JSON'a çevir
  Map<String, dynamic> toJson() {
    final data = {
      'email': email,
      'name': name,
      'phone': phone,
      'role': role.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt': Timestamp.fromDate(lastLoginAt),
      'isActive': isActive,
      'permissions': permissions,
      'additionalData': additionalData,
      'firebaseUid': firebaseUid,
    };
    
    // ID sadece boş değilse ekle
    if (id.isNotEmpty) {
      data['id'] = id;
    }
    
    return data;
  }

  // Admin mi?
  bool get isAdmin => role == UserRole.admin;

  // Yönetici mi?
  bool get isManager => role == UserRole.manager || role == UserRole.admin;

  // Personel mi?
  bool get isStaff => role == UserRole.staff || role == UserRole.manager || role == UserRole.admin;

  // Belirli izne sahip mi?
  bool hasPermission(String permission) {
    return permissions.contains(permission) || isAdmin;
  }

  // Kopya oluştur
  AdminUser copyWith({
    String? id,
    String? email,
    String? name,
    String? phone,
    UserRole? role,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    bool? isActive,
    List<String>? permissions,
    Map<String, dynamic>? additionalData,
    String? firebaseUid,
  }) {
    return AdminUser(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isActive: isActive ?? this.isActive,
      permissions: permissions ?? this.permissions,
      additionalData: additionalData ?? this.additionalData,
      firebaseUid: firebaseUid ?? this.firebaseUid,
    );
  }

  // Eşitlik kontrolü
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AdminUser && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'AdminUser(id: $id, email: $email, name: $name, role: $role)';
  }
}

// Varsayılan admin kullanıcısı
class DefaultAdminUser {
  static AdminUser get yusufAdmin => AdminUser(
    id: 'admin_yusuf_001',
    email: 'yusuffrkn73@gmail.com',
    name: 'Yusuf Admin',
    phone: '+90 555 123 45 67',
    role: UserRole.admin,
    createdAt: DateTime.now(),
    lastLoginAt: DateTime.now(),
    isActive: true,
    permissions: [
      'user_management',      // Kullanıcı yönetimi
      'system_settings',      // Sistem ayarları
      'data_export',          // Veri dışa aktarma
      'analytics',            // Analitik
      'backup_restore',       // Yedekleme/geri yükleme
      'all_permissions',      // Tüm izinler
    ],
    additionalData: {
      'department': 'IT',
      'position': 'System Administrator',
      'notes': 'Ana sistem yöneticisi',
    },
  );

  // Varsayılan izinler
  static List<String> get defaultAdminPermissions => [
    'user_management',
    'system_settings',
    'data_export',
    'analytics',
    'backup_restore',
    'all_permissions',
  ];

  static List<String> get defaultManagerPermissions => [
    'user_management',
    'analytics',
    'data_export',
  ];

  static List<String> get defaultStaffPermissions => [
    'basic_operations',
    'view_reports',
  ];
}
