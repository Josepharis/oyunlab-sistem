import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';

class MenuRepository {
  // Firestore koleksiyonu
  static const String _collectionName = 'menu';
  final CollectionReference _menuCollection =
      FirebaseFirestore.instance.collection(_collectionName);

  // Menü öğeleri
  List<ProductItem> _menuItems = [];

  // Singleton yapısı
  static final MenuRepository _instance = MenuRepository._internal();
  factory MenuRepository() => _instance;

  MenuRepository._internal();

  // Menü öğelerini getir
  List<ProductItem> get menuItems => _menuItems;

  // Firebase'den menü öğelerini yükle
  Future<void> loadMenuItems() async {
    try {
      print("🔄 Firebase'den menü öğeleri yükleniyor...");
      final snapshot = await _menuCollection.get();

      if (snapshot.docs.isNotEmpty) {
        final rawItems = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          // Firestore document ID'sini ekle
          data['id'] = doc.id;
          return ProductItem.fromJson(data);
        }).toList();

        // Duplicate ürünleri temizle (aynı isimde olanları)
        final Map<String, ProductItem> uniqueItems = {};
        for (var item in rawItems) {
          if (!uniqueItems.containsKey(item.name)) {
            uniqueItems[item.name] = item;
            print("📦 Ürün eklendi: ${item.name} (Stok: ${item.stock})");
          } else {
            print("⚠️ Duplicate ürün bulundu ve atlandı: ${item.name}");
          }
        }

        _menuItems = uniqueItems.values.toList();
        print("✅ ${_menuItems.length} benzersiz ürün Firebase'den başarıyla yüklendi");
        print("🗑️ ${rawItems.length - _menuItems.length} duplicate ürün temizlendi");
      } else {
        print("ℹ️ Firebase'de hiç ürün bulunamadı");
        _menuItems = [];
      }
    } catch (e) {
      print("❌ Menü yükleme hatası: $e");
      _menuItems = [];
      rethrow;
    }
  }

  // Menü öğelerini kaydet
  Future<void> saveMenuItems(List<ProductItem> items) async {
    try {
      print("🔄 ${items.length} ürün Firebase'e kaydediliyor...");

      // Duplicate ürünleri temizle (aynı isimde olanları)
      final Map<String, ProductItem> uniqueItems = {};
      for (var item in items) {
        if (!uniqueItems.containsKey(item.name)) {
          uniqueItems[item.name] = item;
        } else {
          print("⚠️ Duplicate ürün atlandı: ${item.name}");
        }
      }

      final cleanedItems = uniqueItems.values.toList();
      print("🧹 ${items.length - cleanedItems.length} duplicate ürün temizlendi");

      // Önce tüm mevcut öğeleri temizle
      final snapshot = await _menuCollection.get();
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }

      // Yeni ürünleri ekle
      for (var item in cleanedItems) {
        await _menuCollection.add(item.toJson());
      }

      // Kaydedilen öğeleri güncelle
      _menuItems = List.from(cleanedItems);
      print("✅ ${cleanedItems.length} benzersiz ürün başarıyla kaydedildi");
    } catch (e) {
      print("❌ Ürün kaydetme hatası: $e");
      rethrow;
    }
  }

  // Tek bir ürün ekle
  Future<void> addProduct(ProductItem item) async {
    try {
      print("🔄 Yeni ürün ekleniyor: ${item.name}");
      
      // Aynı isimde ürün var mı kontrol et
      final existingIndex = _menuItems.indexWhere((existingItem) => existingItem.name == item.name);
      if (existingIndex != -1) {
        print("⚠️ Aynı isimde ürün zaten mevcut: ${item.name}");
        print("🔄 Mevcut ürün güncelleniyor...");
        
        // Mevcut ürünü güncelle
        final existingItem = _menuItems[existingIndex];
        final updatedItem = item.copyWith(id: existingItem.id);
        
        // Firebase'de güncelle
        await _menuCollection.doc(existingItem.id).update(updatedItem.toJson());
        
        // Local listeyi güncelle
        _menuItems[existingIndex] = updatedItem;
        print("✅ Ürün başarıyla güncellendi");
        return;
      }
      
      await _menuCollection.add(item.toJson());

      // Listeye ekle
      _menuItems.add(item);
      print("✅ Ürün başarıyla eklendi");
    } catch (e) {
      print("❌ Ürün ekleme hatası: $e");
      rethrow;
    }
  }

  // Ürün stokunu güncelle
  Future<void> updateProductStock(String productId, int newStock) async {
    try {
      print("🔄 Ürün stoku güncelleniyor: ID=$productId, Yeni stok=$newStock");
      
      // Firestore'da stok güncelle
      final docRef = _menuCollection.doc(productId);
      await docRef.update({'stock': newStock});
      
      // Local listeyi güncelle
      final index = _menuItems.indexWhere((item) => item.id == productId);
      if (index != -1) {
        _menuItems[index] = _menuItems[index].copyWith(stock: newStock);
      }
      
      print("✅ Stok başarıyla güncellendi");
    } catch (e) {
      print("❌ Stok güncelleme hatası: $e");
      rethrow;
    }
  }

  // Menüyü temizle
  Future<void> clearMenu() async {
    try {
      print("🗑️ Tüm menü öğeleri siliniyor...");
      
      // Firebase'den tüm ürünleri sil
      final snapshot = await _menuCollection.get();
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
        print("   🗑️ Firebase'den silindi: ${doc.id}");
      }
      
      // Local listeyi de temizle
      _menuItems.clear();
      
      print("✅ Tüm menü öğeleri hem Firebase'den hem local'den silindi");
      print("📊 Silinen ürün sayısı: ${snapshot.docs.length}");
    } catch (e) {
      print("❌ Menü temizleme hatası: $e");
      rethrow;
    }
  }

}
