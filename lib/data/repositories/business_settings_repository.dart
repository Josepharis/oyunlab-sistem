import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/business_settings_model.dart';

class BusinessSettingsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'business_settings';

  // Tüm işletme ayarlarını getir
  Future<List<BusinessSettings>> getAllBusinessSettings() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => BusinessSettings.fromJson({
                'id': doc.id,
                ...doc.data() as Map<String, dynamic>,
              }))
          .toList();
    } catch (e) {
      print('İşletme ayarları getirme hatası: $e');
      rethrow;
    }
  }

  // ID'ye göre işletme ayarı getir
  Future<BusinessSettings?> getBusinessSettingById(String id) async {
    try {
      final DocumentSnapshot doc = await _firestore
          .collection(_collection)
          .doc(id)
          .get();

      if (doc.exists) {
        return BusinessSettings.fromJson({
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        });
      }
      return null;
    } catch (e) {
      print('İşletme ayarı getirme hatası: $e');
      rethrow;
    }
  }

  // Kategoriye göre işletme ayarı getir
  Future<BusinessSettings?> getBusinessSettingByCategory(BusinessCategory category) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('category', isEqualTo: category.toString().split('.').last)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        return BusinessSettings.fromJson({
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        });
      }
      return null;
    } catch (e) {
      print('Kategori ile işletme ayarı getirme hatası: $e');
      rethrow;
    }
  }

  // Yeni işletme ayarı ekle
  Future<String> addBusinessSetting(BusinessSettings setting) async {
    try {
      final docRef = await _firestore.collection(_collection).add(setting.toJson());
      
      // Oluşturulan ayarı güncelle (ID ekle)
      await _firestore
          .collection(_collection)
          .doc(docRef.id)
          .update({'id': docRef.id});

      print('İşletme ayarı başarıyla eklendi: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('İşletme ayarı ekleme hatası: $e');
      rethrow;
    }
  }

  // İşletme ayarını güncelle
  Future<void> updateBusinessSetting(BusinessSettings setting) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(setting.id)
          .update(setting.copyWith(updatedAt: DateTime.now()).toJson());

      print('İşletme ayarı başarıyla güncellendi: ${setting.id}');
    } catch (e) {
      print('İşletme ayarı güncelleme hatası: $e');
      rethrow;
    }
  }

  // İşletme ayarını sil (soft delete)
  Future<void> deleteBusinessSetting(String id) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(id)
          .update({
            'isActive': false,
            'deletedAt': Timestamp.now(),
          });

      print('İşletme ayarı başarıyla silindi: $id');
    } catch (e) {
      print('İşletme ayarı silme hatası: $e');
      rethrow;
    }
  }

  // Belirli bir kategorinin fiyatını güncelle
  Future<void> updateCategoryPrice(String id, int duration, double newPrice) async {
    try {
      final setting = await getBusinessSettingById(id);
      if (setting != null) {
        final updatedDurationPrices = setting.durationPrices.map((dp) {
          if (dp.duration == duration) {
            return dp.copyWith(price: newPrice);
          }
          return dp;
        }).toList();

        final updatedSetting = setting.copyWith(
          durationPrices: updatedDurationPrices,
          updatedAt: DateTime.now(),
        );

        await updateBusinessSetting(updatedSetting);
        print('Kategori fiyatı güncellendi: $duration -> $newPrice');
      }
    } catch (e) {
      print('Kategori fiyatı güncelleme hatası: $e');
      rethrow;
    }
  }

  // Varsayılan işletme ayarlarını ekle (ilk kurulum için)
  Future<void> addDefaultBusinessSettings() async {
    try {
      for (final setting in DefaultBusinessSettings.defaultSettings) {
        // Kategori zaten var mı kontrol et
        final existingSetting = await getBusinessSettingByCategory(setting.category);
        
        if (existingSetting == null) {
          await addBusinessSetting(setting);
          print('Varsayılan işletme ayarı eklendi: ${setting.categoryTitle}');
        } else {
          print('İşletme ayarı zaten mevcut: ${setting.categoryTitle}');
        }
      }
    } catch (e) {
      print('Varsayılan işletme ayarları ekleme hatası: $e');
      rethrow;
    }
  }

  // İşletme ayarları sayısını getir
  Future<int> getBusinessSettingsCount() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      print('İşletme ayarları sayısı getirme hatası: $e');
      return 0;
    }
  }

  // Stream olarak işletme ayarlarını dinle
  Stream<List<BusinessSettings>> businessSettingsStream() {
    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BusinessSettings.fromJson({
                  'id': doc.id,
                  ...doc.data() as Map<String, dynamic>,
                }))
            .toList());
  }

  // Toplam gelir hesapla (tüm kategoriler için)
  Future<double> calculateTotalRevenue() async {
    try {
      final settings = await getAllBusinessSettings();
      double totalRevenue = 0.0;

      for (final setting in settings) {
        for (final durationPrice in setting.durationPrices) {
          if (durationPrice.isActive) {
            totalRevenue += durationPrice.price;
          }
        }
      }

      return totalRevenue;
    } catch (e) {
      print('Toplam gelir hesaplama hatası: $e');
      return 0.0;
    }
  }

  // Kategori bazında gelir hesapla
  Future<Map<BusinessCategory, double>> calculateRevenueByCategory() async {
    try {
      final settings = await getAllBusinessSettings();
      final Map<BusinessCategory, double> revenueByCategory = {};

      for (final setting in settings) {
        double categoryRevenue = 0.0;
        for (final durationPrice in setting.durationPrices) {
          if (durationPrice.isActive) {
            categoryRevenue += durationPrice.price;
          }
        }
        revenueByCategory[setting.category] = categoryRevenue;
      }

      return revenueByCategory;
    } catch (e) {
      print('Kategori bazında gelir hesaplama hatası: $e');
      return {};
    }
  }
}
