import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/staff_model.dart';

class StaffRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'staff';

  // Tüm personeli getir
  Future<List<Staff>> getAllStaff() async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .get();

      return querySnapshot.docs
          .map((doc) => Staff.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Personel listesi alınırken hata: $e');
      rethrow;
    }
  }

  // ID'ye göre personel getir
  Future<Staff?> getStaffById(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists) {
        return Staff.fromJson({...doc.data()!, 'id': doc.id});
      }
      return null;
    } catch (e) {
      print('Personel getirilirken hata: $e');
      rethrow;
    }
  }

  // Email'e göre personel getir
  Future<Staff?> getStaffByEmail(String email) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('email', isEqualTo: email)
          .where('isActive', isEqualTo: true)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        return Staff.fromJson({...doc.data(), 'id': doc.id});
      }
      return null;
    } catch (e) {
      print('Email ile personel getirilirken hata: $e');
      rethrow;
    }
  }

  // Yeni personel ekle
  Future<String> addStaff(Staff staff) async {
    try {
      final docRef = await _firestore.collection(_collection).add(staff.toJson());
      return docRef.id;
    } catch (e) {
      print('Personel eklenirken hata: $e');
      rethrow;
    }
  }

  // Personel güncelle
  Future<void> updateStaff(Staff staff) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(staff.id)
          .update(staff.toJson());
    } catch (e) {
      print('Personel güncellenirken hata: $e');
      rethrow;
    }
  }

  // Personel sil (soft delete)
  Future<void> deleteStaff(String id) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(id)
          .update({'isActive': false, 'updatedAt': DateTime.now().toIso8601String()});
    } catch (e) {
      print('Personel silinirken hata: $e');
      rethrow;
    }
  }

  // Aktif personel sayısını getir
  Future<int> getActiveStaffCount() async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .get();
      return querySnapshot.docs.length;
    } catch (e) {
      print('Aktif personel sayısı alınırken hata: $e');
      return 0;
    }
  }
}
