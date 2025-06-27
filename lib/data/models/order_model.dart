import 'package:uuid/uuid.dart';

// Sipariş modeli
class Order {
  final String id;
  final String productName;
  final double price;
  final int quantity;
  final DateTime orderTime;
  final bool isCompleted;

  Order({
    String? id,
    required this.productName,
    required this.price,
    required this.quantity,
    DateTime? orderTime,
    this.isCompleted = false,
  })  : this.id = id ?? const Uuid().v4(),
        this.orderTime = orderTime ?? DateTime.now();

  double get totalPrice => price * quantity;

  Order copyWith({
    String? id,
    String? productName,
    double? price,
    int? quantity,
    DateTime? orderTime,
    bool? isCompleted,
  }) {
    return Order(
      id: id ?? this.id,
      productName: productName ?? this.productName,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      orderTime: orderTime ?? this.orderTime,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      productName: json['productName'] as String,
      price: json['price'] as double,
      quantity: json['quantity'] as int,
      orderTime: DateTime.parse(json['orderTime'] as String),
      isCompleted: json['isCompleted'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productName': productName,
      'price': price,
      'quantity': quantity,
      'orderTime': orderTime.toIso8601String(),
      'isCompleted': isCompleted,
    };
  }
}

// Ürün kategorileri
enum ProductCategory {
  food, // Yiyecekler
  drink, // İçecekler
  dessert, // Tatlılar
  toy, // Oyuncaklar
  game, // Oyun Grupları
  coding, // Robotik Kodlama
  other, // Diğer
}

// Örnek ürünler
class ProductItem {
  final String name;
  final double price;
  final ProductCategory category;
  final String? imageUrl;
  final String? description;

  const ProductItem({
    required this.name,
    required this.price,
    required this.category,
    this.imageUrl,
    this.description,
  });

  // Firebase'den veri almak için
  factory ProductItem.fromJson(Map<String, dynamic> json) {
    try {
      // Fiyat dönüşümü
      double price = 0.0;
      if (json['price'] != null) {
        if (json['price'] is int) {
          price = (json['price'] as int).toDouble();
        } else if (json['price'] is double) {
          price = json['price'] as double;
        } else if (json['price'] is String) {
          price = double.tryParse(json['price'] as String) ?? 0.0;
        }
      }
      
      // Kategori dönüşümü
      ProductCategory category = ProductCategory.other;
      if (json['category'] != null) {
        String categoryStr = json['category'].toString().toLowerCase();
        
        if (categoryStr.contains('food')) {
          category = ProductCategory.food;
        } else if (categoryStr.contains('drink')) {
          category = ProductCategory.drink;
        } else if (categoryStr.contains('dessert')) {
          category = ProductCategory.dessert;
        } else if (categoryStr.contains('toy')) {
          category = ProductCategory.toy;
        } else if (categoryStr.contains('game')) {
          category = ProductCategory.game;
        } else if (categoryStr.contains('cod')) {
          category = ProductCategory.coding;
        }
      }
      
      return ProductItem(
        name: json['name'] as String? ?? 'İsimsiz Ürün',
        price: price,
        category: category,
        imageUrl: json['imageUrl'] as String?,
        description: json['description'] as String?,
      );
    } catch (e) {
      print('❌ Ürün dönüşüm hatası: $e');
      return ProductItem(
        name: 'Hatalı Ürün',
        price: 0.0,
        category: ProductCategory.other,
      );
    }
  }

  // Firebase'e veri göndermek için
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'price': price,
      'category': category.toString().split('.').last,
      'imageUrl': imageUrl,
      'description': description,
    };
  }
}

// Kategori başlıklarını döndüren yardımcı fonksiyon
String getCategoryTitle(ProductCategory category) {
  switch (category) {
    case ProductCategory.food:
      return 'Yiyecekler';
    case ProductCategory.drink:
      return 'İçecekler';
    case ProductCategory.dessert:
      return 'Tatlılar';
    case ProductCategory.toy:
      return 'Oyuncaklar';
    case ProductCategory.game:
      return 'Oyun Grupları';
    case ProductCategory.coding:
      return 'Robotik Kodlama';
    case ProductCategory.other:
      return 'Diğer';
  }
}

// Örnek ürün listesi
final List<ProductItem> menuItems = [
  // YIYECEKLER
  ProductItem(
    name: 'Patates Kızartması',
    price: 35.0,
    category: ProductCategory.food,
  ),
  ProductItem(name: 'Çıtır Tavuk', price: 45.0, category: ProductCategory.food),
  ProductItem(name: 'Tost', price: 30.0, category: ProductCategory.food),
  ProductItem(
    name: 'Pizza (Küçük)',
    price: 65.0,
    category: ProductCategory.food,
  ),
  ProductItem(name: 'Hamburger', price: 60.0, category: ProductCategory.food),
  ProductItem(name: 'Sandviç', price: 40.0, category: ProductCategory.food),
  ProductItem(name: 'Nugget', price: 38.0, category: ProductCategory.food),

  // IÇECEKLER
  ProductItem(name: 'Su', price: 10.0, category: ProductCategory.drink),
  ProductItem(name: 'Ayran', price: 15.0, category: ProductCategory.drink),
  ProductItem(name: 'Kola', price: 20.0, category: ProductCategory.drink),
  ProductItem(name: 'Meyve Suyu', price: 18.0, category: ProductCategory.drink),
  ProductItem(name: 'Çay', price: 12.0, category: ProductCategory.drink),
  ProductItem(
    name: 'Türk Kahvesi',
    price: 25.0,
    category: ProductCategory.drink,
  ),
  ProductItem(name: 'Limonata', price: 22.0, category: ProductCategory.drink),

  // TATLILAR
  ProductItem(
    name: 'Dondurma (Top)',
    price: 15.0,
    category: ProductCategory.dessert,
  ),
  ProductItem(
    name: 'Çikolatalı Pasta',
    price: 30.0,
    category: ProductCategory.dessert,
  ),
  ProductItem(name: 'Sütlaç', price: 25.0, category: ProductCategory.dessert),
  ProductItem(
    name: 'Profiterol',
    price: 28.0,
    category: ProductCategory.dessert,
  ),
  ProductItem(name: 'Waffle', price: 45.0, category: ProductCategory.dessert),

  // OYUNCAKLAR
  ProductItem(
    name: 'Küçük Oyuncak',
    price: 30.0,
    category: ProductCategory.toy,
  ),
  ProductItem(
    name: 'Peluş Oyuncak',
    price: 50.0,
    category: ProductCategory.toy,
  ),
  ProductItem(name: 'Araba', price: 40.0, category: ProductCategory.toy),
  ProductItem(name: 'Bebek', price: 45.0, category: ProductCategory.toy),
  ProductItem(
    name: 'Lego (Küçük Set)',
    price: 70.0,
    category: ProductCategory.toy,
  ),
  ProductItem(name: 'Balon', price: 10.0, category: ProductCategory.toy),

  // OYUN GRUPLARI
  ProductItem(
    name: 'Grup Oyunu (30 dk)',
    price: 100.0,
    category: ProductCategory.game,
  ),
  ProductItem(
    name: 'Doğum Günü Paketi',
    price: 500.0,
    category: ProductCategory.game,
  ),
  ProductItem(name: 'Yüz Boyama', price: 40.0, category: ProductCategory.game),
  ProductItem(
    name: 'Masa Oyunu (60 dk)',
    price: 80.0,
    category: ProductCategory.game,
  ),
  ProductItem(
    name: 'Özel Etkinlik (kişi başı)',
    price: 75.0,
    category: ProductCategory.game,
  ),

  // ROBOTIK KODLAMA
  ProductItem(
    name: 'Kodlama Dersi (30 dk)',
    price: 120.0,
    category: ProductCategory.coding,
  ),
  ProductItem(
    name: 'Robot Kit Kullanımı',
    price: 150.0,
    category: ProductCategory.coding,
  ),
  ProductItem(
    name: 'Grup Kodlama (kişi başı)',
    price: 100.0,
    category: ProductCategory.coding,
  ),
  ProductItem(
    name: 'Elektronik Atölye',
    price: 180.0,
    category: ProductCategory.coding,
  ),
  ProductItem(
    name: 'Kodlama Aylık Paket',
    price: 450.0,
    category: ProductCategory.coding,
  ),

  // DIĞER
  ProductItem(
    name: 'Hediye Paketi',
    price: 50.0,
    category: ProductCategory.other,
  ),
  ProductItem(
    name: 'Fotoğraf Çekimi',
    price: 60.0,
    category: ProductCategory.other,
  ),
  ProductItem(name: 'Özel İstek', price: 0.0, category: ProductCategory.other),
];
