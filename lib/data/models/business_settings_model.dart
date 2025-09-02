import 'package:cloud_firestore/cloud_firestore.dart';

enum BusinessCategory {
  oyunAlani,      // Oyun Alanı
  oyunGrubu,      // Oyun Grubu
  workshop,        // Workshop
  robotikKodlama, // Robotik + Kodlama
}

class BusinessSettings {
  final String id;
  final BusinessCategory category;
  final String name;
  final String description;
  final List<DurationPrice> durationPrices;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  BusinessSettings({
    required this.id,
    required this.category,
    required this.name,
    required this.description,
    required this.durationPrices,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  // JSON'dan BusinessSettings oluştur
  factory BusinessSettings.fromJson(Map<String, dynamic> json) {
    return BusinessSettings(
      id: json['id'] as String,
      category: BusinessCategory.values.firstWhere(
        (e) => e.toString() == 'BusinessCategory.${json['category']}',
        orElse: () => BusinessCategory.oyunAlani,
      ),
      name: json['name'] as String,
      description: json['description'] as String,
      durationPrices: (json['durationPrices'] as List<dynamic>)
          .map((e) => DurationPrice.fromJson(e as Map<String, dynamic>))
          .toList(),
      isActive: json['isActive'] as bool? ?? true,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
    );
  }

  // BusinessSettings'ı JSON'a çevir
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category.toString().split('.').last,
      'name': name,
      'description': description,
      'durationPrices': durationPrices.map((e) => e.toJson()).toList(),
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // Kopya oluştur
  BusinessSettings copyWith({
    String? id,
    BusinessCategory? category,
    String? name,
    String? description,
    List<DurationPrice>? durationPrices,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BusinessSettings(
      id: id ?? this.id,
      category: category ?? this.category,
      name: name ?? this.name,
      description: description ?? this.description,
      durationPrices: durationPrices ?? this.durationPrices,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Kategori başlığını getir
  String get categoryTitle {
    switch (category) {
      case BusinessCategory.oyunAlani:
        return 'Oyun Alanı';
      case BusinessCategory.oyunGrubu:
        return 'Oyun Grubu';
      case BusinessCategory.workshop:
        return 'Workshop';
      case BusinessCategory.robotikKodlama:
        return 'Robotik + Kodlama';
    }
  }

  // Kategori simgesini getir
  String get categoryIcon {
    switch (category) {
      case BusinessCategory.oyunAlani:
        return '🎮';
      case BusinessCategory.oyunGrubu:
        return '👥';
      case BusinessCategory.workshop:
        return '🔧';
      case BusinessCategory.robotikKodlama:
        return '🤖💻';
    }
  }

  // Varsayılan süre seçeneklerini getir
  static List<DurationPrice> getDefaultDurationPrices(BusinessCategory category) {
    switch (category) {
      case BusinessCategory.oyunAlani:
        return [
          DurationPrice(duration: 30, price: 0.0, isActive: true),
          DurationPrice(duration: 60, price: 0.0, isActive: true),
          DurationPrice(duration: 600, price: 0.0, isActive: true),
        ];
      case BusinessCategory.oyunGrubu:
        return [
          DurationPrice(duration: 1, price: 0.0, isActive: true), // 1 seans
          DurationPrice(duration: 8, price: 0.0, isActive: true), // 8 seans
        ];
      case BusinessCategory.workshop:
      case BusinessCategory.robotikKodlama:
        return [
          DurationPrice(duration: 1, price: 0.0, isActive: true), // 1 seans
          DurationPrice(duration: 4, price: 0.0, isActive: true), // 4 seans
          DurationPrice(duration: 8, price: 0.0, isActive: true), // 8 seans
        ];
    }
  }
}

// Süre ve fiyat bilgisi
class DurationPrice {
  final int duration; // dakika cinsinden (seans için 1, 4, 8 gibi)
  final double price;
  final bool isActive;

  DurationPrice({
    required this.duration,
    required this.price,
    required this.isActive,
  });

  // JSON'dan DurationPrice oluştur
  factory DurationPrice.fromJson(Map<String, dynamic> json) {
    return DurationPrice(
      duration: json['duration'] as int,
      price: (json['price'] as num).toDouble(),
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  // DurationPrice'ı JSON'a çevir
  Map<String, dynamic> toJson() {
    return {
      'duration': duration,
      'price': price,
      'isActive': isActive,
    };
  }

  // Kopya oluştur
  DurationPrice copyWith({
    int? duration,
    double? price,
    bool? isActive,
  }) {
    return DurationPrice(
      duration: duration ?? this.duration,
      price: price ?? this.price,
      isActive: isActive ?? this.isActive,
    );
  }

  // Süreyi formatla
  String get formattedDuration {
    if (duration < 60) {
      return '$duration seans';
    } else if (duration == 60) {
      return '1 saat';
    } else if (duration < 1440) { // 24 saatten az
      final hours = duration ~/ 60;
      final minutes = duration % 60;
      if (minutes == 0) {
        return '$hours saat';
      } else {
        return '$hours saat $minutes dakika';
      }
    } else {
      final days = duration ~/ 1440;
      return '$days gün';
    }
  }

  // Fiyatı formatla
  String get formattedPrice {
    return '${price.toStringAsFixed(2)} ₺';
  }
}

// Varsayılan işletme ayarları
class DefaultBusinessSettings {
  static List<BusinessSettings> get defaultSettings => [
    BusinessSettings(
      id: 'oyun_alani_001',
      category: BusinessCategory.oyunAlani,
      name: 'Oyun Alanı',
      description: 'Çocukların eğlenebileceği güvenli oyun alanı',
      durationPrices: BusinessSettings.getDefaultDurationPrices(BusinessCategory.oyunAlani),
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    BusinessSettings(
      id: 'oyun_grubu_001',
      category: BusinessCategory.oyunGrubu,
      name: 'Oyun Grubu',
      description: 'Sosyal etkileşimli grup oyunları',
      durationPrices: BusinessSettings.getDefaultDurationPrices(BusinessCategory.oyunGrubu),
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    BusinessSettings(
      id: 'workshop_001',
      category: BusinessCategory.workshop,
      name: 'Workshop',
      description: 'El becerilerini geliştiren atölye çalışmaları',
      durationPrices: BusinessSettings.getDefaultDurationPrices(BusinessCategory.workshop),
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    BusinessSettings(
      id: 'robotik_kodlama_001',
      category: BusinessCategory.robotikKodlama,
      name: 'Robotik + Kodlama',
      description: 'Robot yapımı ve programlama eğitimi',
      durationPrices: BusinessSettings.getDefaultDurationPrices(BusinessCategory.robotikKodlama),
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];
}
