import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/admin_user_model.dart';

class AdminUserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'admin_users';

  // Tüm admin kullanıcıları getir
  Future<List<AdminUser>> getAllAdminUsers() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => AdminUser.fromJson({
                'id': doc.id,
                ...doc.data() as Map<String, dynamic>,
              }))
          .toList();
    } catch (e) {
      print('Admin kullanıcıları getirme hatası: $e');
      rethrow;
    }
  }

  // ID'ye göre admin kullanıcı getir
  Future<AdminUser?> getAdminUserById(String id) async {
    try {
      final DocumentSnapshot doc = await _firestore
          .collection(_collection)
          .doc(id)
          .get();

      if (doc.exists) {
        return AdminUser.fromJson({
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        });
      }
      return null;
    } catch (e) {
      print('Admin kullanıcı getirme hatası: $e');
      rethrow;
    }
  }

  // E-posta ile admin kullanıcı getir
  Future<AdminUser?> getAdminUserByEmail(String email) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('email', isEqualTo: email)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        return AdminUser.fromJson({
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        });
      }
      return null;
    } catch (e) {
      print('E-posta ile admin kullanıcı getirme hatası: $e');
      rethrow;
    }
  }

  // Yeni admin kullanıcı ekle
  Future<String> addAdminUser(AdminUser user) async {
    try {
      final docRef = await _firestore.collection(_collection).add(user.toJson());
      
      print('Admin kullanıcı başarıyla eklendi: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('Admin kullanıcı ekleme hatası: $e');
      rethrow;
    }
  }

  // Admin kullanıcı güncelle
  Future<void> updateAdminUser(AdminUser user) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(user.id)
          .update(user.toJson());

      print('Admin kullanıcı başarıyla güncellendi: ${user.id}');
    } catch (e) {
      print('Admin kullanıcı güncelleme hatası: $e');
      rethrow;
    }
  }

  // Admin kullanıcı sil (soft delete)
  Future<void> deleteAdminUser(String id) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(id)
          .update({
            'isActive': false,
            'deletedAt': Timestamp.now(),
          });

      print('Admin kullanıcı başarıyla silindi: $id');
    } catch (e) {
      print('Admin kullanıcı silme hatası: $e');
      rethrow;
    }
  }

  // Son giriş zamanını güncelle
  Future<void> updateLastLogin(String id) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(id)
          .update({
            'lastLoginAt': Timestamp.now(),
          });
    } catch (e) {
      print('Son giriş zamanı güncelleme hatası: $e');
    }
  }

  // Kullanıcı rolünü güncelle
  Future<void> updateUserRole(String id, UserRole newRole) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(id)
          .update({
            'role': newRole.toString().split('.').last,
            'updatedAt': Timestamp.now(),
          });

      print('Kullanıcı rolü başarıyla güncellendi: $id -> $newRole');
    } catch (e) {
      print('Kullanıcı rolü güncelleme hatası: $e');
      rethrow;
    }
  }

  // Kullanıcı izinlerini güncelle
  Future<void> updateUserPermissions(String id, List<String> permissions) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(id)
          .update({
            'permissions': permissions,
            'updatedAt': Timestamp.now(),
          });

      print('Kullanıcı izinleri başarıyla güncellendi: $id');
    } catch (e) {
      print('Kullanıcı izinleri güncelleme hatası: $e');
      rethrow;
    }
  }

  // Varsayılan admin kullanıcısını ekle (ilk kurulum için)
  Future<void> addDefaultAdminUser() async {
    try {
      // Varsayılan admin kullanıcısı zaten var mı kontrol et
      final existingAdmin = await getAdminUserByEmail(DefaultAdminUser.yusufAdmin.email);
      
      if (existingAdmin == null) {
        await addAdminUser(DefaultAdminUser.yusufAdmin);
        print('Varsayılan admin kullanıcısı eklendi: ${DefaultAdminUser.yusufAdmin.email}');
      } else {
        print('Varsayılan admin kullanıcısı zaten mevcut');
      }
    } catch (e) {
      print('Varsayılan admin kullanıcısı ekleme hatası: $e');
      rethrow;
    }
  }

  // Kullanıcı sayısını getir
  Future<int> getAdminUserCount() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      print('Admin kullanıcı sayısı getirme hatası: $e');
      return 0;
    }
  }

  // Rol bazında kullanıcı sayılarını getir
  Future<Map<UserRole, int>> getAdminUserCountByRole() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .get();

      final Map<UserRole, int> roleCounts = {};
      
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final role = UserRole.values.firstWhere(
          (e) => e.toString() == 'UserRole.${data['role']}',
          orElse: () => UserRole.staff,
        );
        
        roleCounts[role] = (roleCounts[role] ?? 0) + 1;
      }

      return roleCounts;
    } catch (e) {
      print('Rol bazında kullanıcı sayısı getirme hatası: $e');
      return {};
    }
  }

  // Stream olarak admin kullanıcıları dinle
  Stream<List<AdminUser>> adminUsersStream() {
    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AdminUser.fromJson({
                  'id': doc.id,
                  ...doc.data() as Map<String, dynamic>,
                }))
            .toList());
  }
}
