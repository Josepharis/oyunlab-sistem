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
  final String id; // Firestore document ID
  final String name;
  final double price;
  final ProductCategory category;
  final String? imageUrl;
  final String? description;
  final int stock; // Stok miktarı

  const ProductItem({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    this.imageUrl,
    this.description,
    this.stock = 0, // Varsayılan stok 0
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
        id: json['id'] as String? ?? '', // Firestore ID'yi al
        name: json['name'] as String? ?? 'İsimsiz Ürün',
        price: price,
        category: category,
        imageUrl: json['imageUrl'] as String?,
        description: json['description'] as String?,
        stock: json['stock'] as int? ?? 0,
      );
    } catch (e) {
      print('❌ Ürün dönüşüm hatası: $e');
      return ProductItem(
        id: '', // ID'yi boş bırak
        name: 'Hatalı Ürün',
        price: 0.0,
        category: ProductCategory.other,
      );
    }
  }

  // Firebase'e veri göndermek için
  Map<String, dynamic> toJson() {
    return {
      'id': id, // Firestore ID'yi dahil et
      'name': name,
      'price': price,
      'category': category.toString().split('.').last,
      'imageUrl': imageUrl,
      'description': description,
      'stock': stock,
    };
  }
}

// ProductItem için copyWith metodu
extension ProductItemExtension on ProductItem {
  ProductItem copyWith({
    String? id,
    String? name,
    double? price,
    ProductCategory? category,
    String? imageUrl,
    String? description,
    int? stock,
  }) {
    return ProductItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
      stock: stock ?? this.stock,
    );
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
    id: '', // Firestore ID'yi boş bırak
    name: 'Patates Kızartması',
    price: 35.0,
    category: ProductCategory.food,
    stock: 50,
  ),
  ProductItem(id: '', name: 'Çıtır Tavuk', price: 45.0, category: ProductCategory.food, stock: 30),
  ProductItem(id: '', name: 'Tost', price: 30.0, category: ProductCategory.food, stock: 25),
  ProductItem(
    id: '',
    name: 'Pizza (Küçük)',
    price: 65.0,
    category: ProductCategory.food,
    stock: 20,
  ),
  ProductItem(id: '', name: 'Hamburger', price: 60.0, category: ProductCategory.food, stock: 35),
  ProductItem(id: '', name: 'Sandviç', price: 40.0, category: ProductCategory.food, stock: 40),
  ProductItem(id: '', name: 'Nugget', price: 38.0, category: ProductCategory.food, stock: 45),

  // IÇECEKLER
  ProductItem(id: '', name: 'Su', price: 10.0, category: ProductCategory.drink, stock: 100),
  ProductItem(id: '', name: 'Ayran', price: 15.0, category: ProductCategory.drink, stock: 80),
  ProductItem(id: '', name: 'Kola', price: 20.0, category: ProductCategory.drink, stock: 75),
  ProductItem(id: '', name: 'Meyve Suyu', price: 18.0, category: ProductCategory.drink, stock: 60),
  ProductItem(id: '', name: 'Çay', price: 12.0, category: ProductCategory.drink, stock: 90),
  ProductItem(
    id: '',
    name: 'Türk Kahvesi',
    price: 25.0,
    category: ProductCategory.drink,
    stock: 40,
  ),
  ProductItem(id: '', name: 'Limonata', price: 22.0, category: ProductCategory.drink, stock: 55),

  // TATLILAR
  ProductItem(
    id: '',
    name: 'Dondurma (Top)',
    price: 15.0,
    category: ProductCategory.dessert,
    stock: 30,
  ),
  ProductItem(
    id: '',
    name: 'Çikolatalı Pasta',
    price: 30.0,
    category: ProductCategory.dessert,
    stock: 15,
  ),
  ProductItem(id: '', name: 'Sütlaç', price: 25.0, category: ProductCategory.dessert, stock: 20),
  ProductItem(
    id: '',
    name: 'Profiterol',
    price: 28.0,
    category: ProductCategory.dessert,
    stock: 18,
  ),
  ProductItem(id: '', name: 'Waffle', price: 45.0, category: ProductCategory.dessert, stock: 12),

  // OYUNCAKLAR
  ProductItem(
    id: '',
    name: 'Küçük Oyuncak',
    price: 30.0,
    category: ProductCategory.toy,
    stock: 25,
  ),
  ProductItem(
    id: '',
    name: 'Peluş Oyuncak',
    price: 50.0,
    category: ProductCategory.toy,
    stock: 20,
  ),
  ProductItem(id: '', name: 'Araba', price: 40.0, category: ProductCategory.toy, stock: 30),
  ProductItem(id: '', name: 'Bebek', price: 45.0, category: ProductCategory.toy, stock: 18),
  ProductItem(
    id: '',
    name: 'Lego (Küçük Set)',
    price: 70.0,
    category: ProductCategory.toy,
    stock: 15,
  ),
  ProductItem(id: '', name: 'Balon', price: 10.0, category: ProductCategory.toy, stock: 100),

  // OYUN GRUPLARI
  ProductItem(
    id: '',
    name: 'Grup Oyunu (30 dk)',
    price: 100.0,
    category: ProductCategory.game,
    stock: 10,
  ),
  ProductItem(
    id: '',
    name: 'Doğum Günü Paketi',
    price: 500.0,
    category: ProductCategory.game,
    stock: 5,
  ),
  ProductItem(id: '', name: 'Yüz Boyama', price: 40.0, category: ProductCategory.game, stock: 20),
  ProductItem(
    id: '',
    name: 'Masa Oyunu (60 dk)',
    price: 80.0,
    category: ProductCategory.game,
    stock: 15,
  ),
  ProductItem(
    id: '',
    name: 'Özel Etkinlik (kişi başı)',
    price: 75.0,
    category: ProductCategory.game,
    stock: 25,
  ),

  // ROBOTIK KODLAMA
  ProductItem(
    id: '',
    name: 'Kodlama Dersi (30 dk)',
    price: 120.0,
    category: ProductCategory.coding,
    stock: 8,
  ),
  ProductItem(
    id: '',
    name: 'Robot Kit Kullanımı',
    price: 150.0,
    category: ProductCategory.coding,
    stock: 6,
  ),
  ProductItem(
    id: '',
    name: 'Grup Kodlama (kişi başı)',
    price: 100.0,
    category: ProductCategory.coding,
    stock: 12,
  ),
  ProductItem(
    id: '',
    name: 'Elektronik Atölye',
    price: 180.0,
    category: ProductCategory.coding,
    stock: 4,
  ),
  ProductItem(
    id: '',
    name: 'Kodlama Aylık Paket',
    price: 450.0,
    category: ProductCategory.coding,
    stock: 10,
  ),

  // DIĞER
  ProductItem(
    id: '',
    name: 'Hediye Paketi',
    price: 50.0,
    category: ProductCategory.other,
    stock: 30,
  ),
  ProductItem(
    id: '',
    name: 'Fotoğraf Çekimi',
    price: 60.0,
    category: ProductCategory.other,
    stock: 15,
  ),
  ProductItem(id: '', name: 'Özel İstek', price: 0.0, category: ProductCategory.other, stock: 999),
];
