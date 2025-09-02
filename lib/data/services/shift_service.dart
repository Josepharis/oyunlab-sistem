import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/shift_record_model.dart';

class ShiftService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'shifts';

  // Aktif mesaiyi getir
  Future<ShiftRecord?> getActiveShift(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .where('endTime', isEqualTo: null)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        return ShiftRecord.fromJson({
          'id': doc.id,
          ...doc.data()! as Map<String, dynamic>,
        });
      }
      return null;
    } catch (e) {
      print('Aktif mesai getirilirken hata: $e');
      return null;
    }
  }

  // Mesaiye başla
  Future<ShiftRecord?> startShift(String userId, String userName) async {
    try {
      // Önce aktif mesai var mı kontrol et
      final activeShift = await getActiveShift(userId);
      if (activeShift != null) {
        throw Exception('Zaten aktif bir mesainiz bulunuyor!');
      }

      final now = DateTime.now();
      final shiftData = {
        'userId': userId,
        'userName': userName,
        'startTime': Timestamp.fromDate(now),
        'endTime': null,
        'duration': null,
        'notes': null,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'isActive': true,
      };

      final docRef = await _firestore.collection(_collection).add(shiftData);
      
      return ShiftRecord.fromJson({
        'id': docRef.id,
        ...shiftData as Map<String, dynamic>,
      });
    } catch (e) {
      print('Mesai başlatılırken hata: $e');
      rethrow;
    }
  }

  // Mesaiden çık
  Future<ShiftRecord?> endShift(String shiftId, String? notes) async {
    try {
      final now = DateTime.now();
      
      // Mesai kaydını getir
      final docRef = _firestore.collection(_collection).doc(shiftId);
      final doc = await docRef.get();
      
      if (!doc.exists) {
        throw Exception('Mesai kaydı bulunamadı!');
      }

      final shiftData = doc.data()!;
      final startTime = (shiftData['startTime'] as Timestamp).toDate();
      final duration = now.difference(startTime);

      // Mesai kaydını güncelle
      await docRef.update({
        'endTime': Timestamp.fromDate(now),
        'duration': duration.inSeconds,
        'notes': notes,
        'updatedAt': Timestamp.fromDate(now),
        'isActive': false,
      });

      return ShiftRecord.fromJson({
        'id': doc.id,
        ...shiftData as Map<String, dynamic>,
        'endTime': Timestamp.fromDate(now),
        'duration': duration.inSeconds,
        'notes': notes,
        'updatedAt': Timestamp.fromDate(now),
        'isActive': false,
      });
    } catch (e) {
      print('Mesai bitirilirken hata: $e');
      rethrow;
    }
  }

  // Kullanıcının mesai geçmişini getir
  Future<List<ShiftRecord>> getUserShiftHistory(
    String userId, {
    int limit = 50,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .orderBy('startTime', descending: true)
          .limit(limit);

      if (startDate != null) {
        query = query.where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final querySnapshot = await query.get();
      
      return querySnapshot.docs.map((doc) {
        return ShiftRecord.fromJson({
          'id': doc.id,
          ...doc.data()! as Map<String, dynamic>,
        });
      }).toList();
    } catch (e) {
      print('Mesai geçmişi getirilirken hata: $e');
      return [];
    }
  }

  // Mesai kaydını güncelle
  Future<ShiftRecord?> updateShift(
    String shiftId, {
    DateTime? startTime,
    DateTime? endTime,
    String? notes,
  }) async {
    try {
      final now = DateTime.now();
      final updateData = <String, dynamic>{
        'updatedAt': Timestamp.fromDate(now),
      };

      if (startTime != null) {
        updateData['startTime'] = Timestamp.fromDate(startTime);
      }

      if (endTime != null) {
        updateData['endTime'] = Timestamp.fromDate(endTime);
        if (startTime != null) {
          updateData['duration'] = endTime.difference(startTime).inSeconds;
        }
      }

      if (notes != null) {
        updateData['notes'] = notes;
      }

      await _firestore.collection(_collection).doc(shiftId).update(updateData);

      // Güncellenmiş kaydı getir
      final doc = await _firestore.collection(_collection).doc(shiftId).get();
      if (doc.exists) {
        return ShiftRecord.fromJson({
          'id': doc.id,
          ...doc.data()! as Map<String, dynamic>,
        });
      }
      return null;
    } catch (e) {
      print('Mesai güncellenirken hata: $e');
      rethrow;
    }
  }

  // Mesai kaydını sil
  Future<bool> deleteShift(String shiftId) async {
    try {
      await _firestore.collection(_collection).doc(shiftId).delete();
      return true;
    } catch (e) {
      print('Mesai silinirken hata: $e');
      return false;
    }
  }

  // Tüm mesai kayıtlarını getir (admin için)
  Future<List<ShiftRecord>> getAllShifts({
    int limit = 100,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore
          .collection(_collection)
          .orderBy('startTime', descending: true)
          .limit(limit);

      if (startDate != null) {
        query = query.where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final querySnapshot = await query.get();
      
      return querySnapshot.docs.map((doc) {
        return ShiftRecord.fromJson({
          'id': doc.id,
          ...doc.data()! as Map<String, dynamic>,
        });
      }).toList();
    } catch (e) {
      print('Tüm mesai kayıtları getirilirken hata: $e');
      return [];
    }
  }

  // Kullanıcının toplam mesai süresini hesapla
  Future<Duration> getUserTotalShiftDuration(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: false);

      if (startDate != null) {
        query = query.where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final querySnapshot = await query.get();
      
      int totalSeconds = 0;
      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null && data['duration'] != null) {
          totalSeconds += data['duration'] as int;
        }
      }

      return Duration(seconds: totalSeconds);
    } catch (e) {
      print('Toplam mesai süresi hesaplanırken hata: $e');
      return Duration.zero;
    }
  }
}
