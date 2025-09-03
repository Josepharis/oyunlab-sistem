import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sale_record_model.dart';

class SaleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'sales';

  // Yeni satış ekle
  Future<SaleRecord?> createSale(SaleRecord sale) async {
    try {
      final saleData = sale.toJson();
      saleData.remove('id'); // ID'yi kaldır, Firestore otomatik oluştursun
      
      final docRef = await _firestore.collection(_collection).add(saleData);
      
      return sale.copyWith(id: docRef.id);
    } catch (e) {
      print('Satış eklenirken hata: $e');
      return null;
    }
  }

  // Kullanıcının satış geçmişini getir
  Future<List<SaleRecord>> getUserSales(
    String userId, {
    int limit = 50,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .orderBy('date', descending: true)
          .limit(limit);

      if (startDate != null) {
        query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final querySnapshot = await query.get();
      
      return querySnapshot.docs.map((doc) {
        return SaleRecord.fromJson({
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        });
      }).toList();
    } catch (e) {
      print('Satış geçmişi getirilirken hata: $e');
      return [];
    }
  }

  // Satış kaydını güncelle
  Future<SaleRecord?> updateSale(SaleRecord sale) async {
    try {
      final now = DateTime.now();
      final updateData = sale.toJson();
      updateData['updatedAt'] = Timestamp.fromDate(now);
      updateData.remove('id'); // ID'yi güncelleme verilerinden çıkar

      await _firestore.collection(_collection).doc(sale.id).update(updateData);

      // Güncellenmiş kaydı getir
      final doc = await _firestore.collection(_collection).doc(sale.id).get();
      if (doc.exists) {
        return SaleRecord.fromJson({
          'id': doc.id,
          ...doc.data()!,
        });
      }
      return null;
    } catch (e) {
      print('Satış güncellenirken hata: $e');
      rethrow;
    }
  }

  // Satış kaydını sil
  Future<bool> deleteSale(String saleId) async {
    try {
      await _firestore.collection(_collection).doc(saleId).delete();
      return true;
    } catch (e) {
      print('Satış silinirken hata: $e');
      return false;
    }
  }

  // Kullanıcının tüm satışlarını sil
  Future<bool> deleteAllUserSales(String userId) async {
    try {
      // Kullanıcının tüm satışlarını getir
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .get();

      if (querySnapshot.docs.isEmpty) {
        print('Silinecek satış kaydı bulunamadı');
        return true;
      }

      // Batch delete işlemi
      final batch = _firestore.batch();
      
      for (var doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print('${querySnapshot.docs.length} satış kaydı başarıyla silindi');
      return true;
    } catch (e) {
      print('Tüm satışlar silinirken hata: $e');
      return false;
    }
  }

  // Tüm satışları getir (admin için)
  Future<List<SaleRecord>> getAllSales({
    int limit = 100,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore
          .collection(_collection)
          .orderBy('date', descending: true)
          .limit(limit);

      if (startDate != null) {
        query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final querySnapshot = await query.get();
      
      return querySnapshot.docs.map((doc) {
        return SaleRecord.fromJson({
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        });
      }).toList();
    } catch (e) {
      print('Tüm satışlar getirilirken hata: $e');
      return [];
    }
  }

  // Kullanıcının toplam satış tutarını hesapla
  Future<double> getUserTotalSales(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId);

      if (startDate != null) {
        query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final querySnapshot = await query.get();
      
      double totalAmount = 0.0;
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        if (data != null && (data as Map<String, dynamic>)['amount'] != null) {
          totalAmount += ((data as Map<String, dynamic>)['amount'] as num).toDouble();
        }
      }

      return totalAmount;
    } catch (e) {
      print('Toplam satış tutarı hesaplanırken hata: $e');
      return 0.0;
    }
  }

  // Günlük satış istatistikleri
  Future<Map<String, dynamic>> getDailySalesStats(
    String userId, {
    DateTime? date,
  }) async {
    try {
      final targetDate = date ?? DateTime.now();
      final startOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final querySnapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      double totalAmount = 0.0;
      int totalSales = querySnapshot.docs.length;

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        if (data != null && (data as Map<String, dynamic>)['amount'] != null) {
          totalAmount += ((data as Map<String, dynamic>)['amount'] as num).toDouble();
        }
      }

      return {
        'totalSales': totalSales,
        'totalAmount': totalAmount,
        'averageAmount': totalSales > 0 ? totalAmount / totalSales : 0.0,
        'date': targetDate,
      };
    } catch (e) {
      print('Günlük satış istatistikleri getirilirken hata: $e');
      return {
        'totalSales': 0,
        'totalAmount': 0.0,
        'averageAmount': 0.0,
        'date': date ?? DateTime.now(),
      };
    }
  }

  // Aylık satış istatistikleri
  Future<Map<String, dynamic>> getMonthlySalesStats(
    String userId, {
    DateTime? date,
  }) async {
    try {
      final targetDate = date ?? DateTime.now();
      final startOfMonth = DateTime(targetDate.year, targetDate.month, 1);
      final endOfMonth = DateTime(targetDate.year, targetDate.month + 1, 1);

      final querySnapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('date', isLessThan: Timestamp.fromDate(endOfMonth))
          .get();

      double totalAmount = 0.0;
      int totalSales = querySnapshot.docs.length;

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        if (data != null && (data as Map<String, dynamic>)['amount'] != null) {
          totalAmount += ((data as Map<String, dynamic>)['amount'] as num).toDouble();
        }
      }

      return {
        'totalSales': totalSales,
        'totalAmount': totalAmount,
        'averageAmount': totalSales > 0 ? totalAmount / totalSales : 0.0,
        'month': targetDate.month,
        'year': targetDate.year,
      };
    } catch (e) {
      print('Aylık satış istatistikleri getirilirken hata: $e');
      return {
        'totalSales': 0,
        'totalAmount': 0.0,
        'averageAmount': 0.0,
        'month': (date ?? DateTime.now()).month,
        'year': (date ?? DateTime.now()).year,
      };
    }
  }

  // Real-time satış stream'i - kullanıcının satışlarını dinle
  Stream<List<SaleRecord>> getUserSalesStream(
    String userId, {
    int limit = 50,
  }) {
    try {
      return _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .orderBy('date', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          return SaleRecord.fromJson({
            'id': doc.id,
            ...doc.data(),
          });
        }).toList();
      });
    } catch (e) {
      print('Satış stream oluşturulurken hata: $e');
      return Stream.value([]);
    }
  }
}
