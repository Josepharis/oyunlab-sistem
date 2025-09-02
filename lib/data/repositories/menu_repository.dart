import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
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
        _menuItems = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          // Firestore document ID'sini ekle
          data['id'] = doc.id;
          return ProductItem.fromJson(data);
        }).toList();

        print("✅ ${_menuItems.length} ürün Firebase'den başarıyla yüklendi");
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

      // Önce tüm mevcut öğeleri temizle
      final snapshot = await _menuCollection.get();
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }

      // Yeni ürünleri ekle
      for (var item in items) {
        await _menuCollection.add(item.toJson());
      }

      // Kaydedilen öğeleri güncelle
      _menuItems = List.from(items);
      print("✅ Ürünler başarıyla kaydedildi");
    } catch (e) {
      print("❌ Ürün kaydetme hatası: $e");
      rethrow;
    }
  }

  // Tek bir ürün ekle
  Future<void> addProduct(ProductItem item) async {
    try {
      print("🔄 Yeni ürün ekleniyor: ${item.name}");
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
      final snapshot = await _menuCollection.get();
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
      _menuItems.clear();
      print("✅ Tüm menü öğeleri silindi");
    } catch (e) {
      print("❌ Menü temizleme hatası: $e");
      rethrow;
    }
  }

  // Test ürünleri oluştur
  Future<void> createTestProducts() async {
    final testItems = _createTestProducts();
    await saveMenuItems(testItems);
  }

  // Test ürünleri oluştur
  List<ProductItem> _createTestProducts() {
    return [
      ProductItem(
        id: 'test_food_1',
        name: 'Patates Kızartması',
        price: 35.0,
        category: ProductCategory.food,
        stock: 50,
      ),
      ProductItem(
        id: 'test_food_2',
        name: 'Çıtır Tavuk',
        price: 45.0,
        category: ProductCategory.food,
        stock: 30,
      ),
      ProductItem(
        id: 'test_food_3',
        name: 'Tost',
        price: 30.0,
        category: ProductCategory.food,
        stock: 25,
      ),
      ProductItem(
        id: 'test_drink_1',
        name: 'Su',
        price: 10.0,
        category: ProductCategory.drink,
        stock: 100,
      ),
      ProductItem(
        id: 'test_drink_2',
        name: 'Kola',
        price: 20.0,
        category: ProductCategory.drink,
        stock: 75,
      ),
    ];
  }
}
