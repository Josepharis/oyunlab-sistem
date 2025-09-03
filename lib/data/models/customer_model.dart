class Customer {
  final String id;
  final String childName;
  final String parentName;
  final String phoneNumber;
  final DateTime entryTime;
  final int ticketNumber;
  
  // YENİ SÜRE YÖNETİMİ SİSTEMİ - TEK KAYNAK
  final int totalSeconds;             // Toplam süre (saniye cinsinden)
  final int usedSeconds;              // Kullanılan süre (saniye cinsinden)
  final int pausedSeconds;            // Duraklatılan toplam süre (saniye cinsinden)
  final int remainingMinutes;         // Kaydedilen kalan süre (dakika)
  final int remainingSeconds;         // Kaydedilen kalan süre (saniye)
  
  // Durum bilgileri
  final bool isPaused;
  final DateTime? pauseStartTime;
  final bool isCompleted;
  final DateTime? completedTime;
  final double price;
  
  // Kardeş yönetimi
  final int childCount;               // Toplam çocuk sayısı
  final List<String> siblingIds;      // Kardeş ID'leri
  
  // Satın alma bilgisi
  final bool hasTimePurchase;         // Bu müşteri için süre satın alımı yapıldı mı?
  final int purchasedSeconds;         // Bu girişte satın alınan süre (saniye)

  Customer({
    required this.id,
    required this.childName,
    required this.parentName,
    required this.phoneNumber,
    required this.entryTime,
    required this.ticketNumber,
    required this.totalSeconds,
    this.usedSeconds = 0,
    this.pausedSeconds = 0,
    this.remainingMinutes = 0,
    this.remainingSeconds = 0,
    this.isPaused = false,
    this.pauseStartTime,
    this.isCompleted = false,
    this.completedTime,
    this.price = 0.0,
    this.childCount = 1,
    this.siblingIds = const [],
    this.hasTimePurchase = false,
    this.purchasedSeconds = 0,
  });

  // KALAN SÜRE HESAPLAMA - YENİ SİSTEM
  int get calculatedRemainingSeconds {
    // YENİ SİSTEM: currentRemainingSeconds ile aynı mantık
    return currentRemainingSeconds;
  }

  // SABİT KALAN SÜRE (SALES SCREEN İÇİN - DİNAMİK DEĞİL)
  int get staticRemainingSeconds {
    // Teslim edildiğinde kaydedilen gerçek kalan süreyi kullan
    if (isCompleted) {
      // Tamamlanan müşteriler için kaydedilen kalan süre
      return (remainingMinutes * 60) + remainingSeconds;
    } else {
      // Aktif müşteriler için de kaydedilen kalan süreyi kullan (statik)
      // Eğer kaydedilen kalan süre yoksa, toplam süreyi kullan
      if (remainingMinutes > 0 || remainingSeconds > 0) {
        return (remainingMinutes * 60) + remainingSeconds;
      } else {
        // İlk kez hesaplanıyorsa, toplam süreyi kullan
        return totalSeconds;
      }
    }
  }

  // ÇOCUK BAŞINA DÜŞEN KALAN SÜRE
  int get remainingSecondsPerChild {
    if (childCount == 0) return 0;
    return calculatedRemainingSeconds ~/ childCount;
  }

  // GERÇEK ZAMANLI KULLANILAN SÜRE (ANA SAYFA İÇİN) - YENİ SİSTEM
  int get currentUsedSeconds {
    if (isCompleted) return usedSeconds;
    
    // YENİ SİSTEM: Sadece kalan süre üzerinden hesapla
    // Kullanılan süre = Toplam süre - Kalan süre
    final actualRemainingSeconds = currentRemainingSeconds;
    final calculatedUsedSeconds = totalSeconds - actualRemainingSeconds;
    return calculatedUsedSeconds > 0 ? calculatedUsedSeconds : 0;
  }

  // SABİT KULLANILAN SÜRE (SALES SCREEN İÇİN - DİNAMİK DEĞİL)
  int get staticUsedSeconds {
    if (isCompleted) {
      // Tamamlanan müşteriler için kaydedilen kullanılan süre
      return usedSeconds;
    } else {
      // YENİ SİSTEM: Aktif müşteriler için kullanılan süre hesaplama
      // Kullanılan süre = Toplam süre - Kalan süre
      final actualRemainingSeconds = currentRemainingSeconds;
      return totalSeconds - actualRemainingSeconds;
    }
  }

  // GERÇEK ZAMANLI KALAN SÜRE (ANA SAYFA İÇİN) - YENİ SİSTEM
  int get currentRemainingSeconds {
    if (isCompleted) {
      // Tamamlanan müşteriler için kaydedilen kalan süre
      return (remainingMinutes * 60) + remainingSeconds;
    }
    
    // YENİ SİSTEM: Kalan süre hesaplama
    // Kalan süre = Toplam süre - (Geçen süre - Duraklatılan süre) * Çocuk sayısı
    final now = DateTime.now();
    final totalElapsed = now.difference(entryTime).inSeconds;
    final actualElapsed = totalElapsed - pausedSeconds;
    final remaining = totalSeconds - (actualElapsed * childCount);
    return remaining > 0 ? remaining : 0;
  }

  // ÇOCUK BAŞINA DÜŞEN GERÇEK ZAMANLI KALAN SÜRE
  int get currentRemainingSecondsPerChild {
    if (childCount == 0) return 0;
    return currentRemainingSeconds ~/ childCount;
  }

  // ÇIKIŞ ZAMANI
  DateTime get exitTime {
    return entryTime.add(Duration(seconds: totalSeconds));
  }

  // DURATION GETTER'LARI (ESKİ SİSTEM UYUMLULUĞU İÇİN)
  Duration get remainingTime => Duration(seconds: calculatedRemainingSeconds);
  Duration get staticRemainingTime => Duration(seconds: staticRemainingSeconds);
  Duration get remainingTimePerChild => Duration(seconds: remainingSecondsPerChild);
  Duration get currentRemainingTime => Duration(seconds: currentRemainingSeconds);
  Duration get currentRemainingTimePerChild => Duration(seconds: currentRemainingSecondsPerChild);
  Duration get usedTime => Duration(seconds: usedSeconds);
  Duration get currentUsedTime => Duration(seconds: currentUsedSeconds);
  Duration get staticUsedTime => Duration(seconds: staticUsedSeconds);

  // ESKİ SİSTEM UYUMLULUĞU İÇİN
  int get durationMinutes => totalSeconds ~/ 60;
  int get originalDurationMinutes => totalSeconds ~/ 60;
  bool get isActive => !isCompleted && currentRemainingSeconds > 0;

  // TESLİM/SURE BİTİMİNDE KALAN SÜRE KAYDETME
  Customer completeWithRemainingTime() {
    final actualRemainingSeconds = currentRemainingSeconds;
    final actualUsedSeconds = totalSeconds - actualRemainingSeconds;
    
    return copyWith(
      isCompleted: true,
      completedTime: DateTime.now(),
      remainingMinutes: actualRemainingSeconds ~/ 60,
      remainingSeconds: actualRemainingSeconds % 60,
      usedSeconds: actualUsedSeconds,
    );
  }

  factory Customer.fromJson(Map<String, dynamic> json) {
    try {
      final id = json['id'] as String? ?? '';
      final childName = json['childName'] as String? ?? '';
      final parentName = json['parentName'] as String? ?? '';
      final phoneNumber = json['phoneNumber'] as String? ?? '';
      final ticketNumber = json['ticketNumber'] as int? ?? 0;

      // Tarih dönüşümleri
      DateTime entryTime;
      try {
        final entryTimeStr = json['entryTime'] as String?;
        entryTime = entryTimeStr != null ? DateTime.parse(entryTimeStr) : DateTime.now();
      } catch (e) {
        print('Customer.fromJson: entryTime parse hatası: $e');
        entryTime = DateTime.now();
      }

      // YENİ SÜRE SİSTEMİ
      final totalSeconds = json['totalSeconds'] as int? ?? (json['durationMinutes'] as int? ?? 60) * 60;
      final usedSeconds = json['usedSeconds'] as int? ?? 0;
      final pausedSeconds = json['pausedSeconds'] as int? ?? 0;
      final remainingMinutes = json['remainingMinutes'] as int? ?? 0;
      final remainingSeconds = json['remainingSeconds'] as int? ?? 0;

      // Duraklatma zamanı
      DateTime? pauseStartTime;
      if (json['pauseStartTime'] != null) {
        try {
          if (json['pauseStartTime'] is String) {
            pauseStartTime = DateTime.parse(json['pauseStartTime'] as String);
          }
        } catch (e) {
          print('Customer.fromJson: pauseStartTime parse hatası: $e');
        }
      }

      // Tamamlanma zamanı
      DateTime? completedTime;
      if (json['completedTime'] != null) {
        try {
          if (json['completedTime'] is String) {
            completedTime = DateTime.parse(json['completedTime'] as String);
          }
        } catch (e) {
          print('Customer.fromJson: completedTime parse hatası: $e');
        }
      }

      final isPaused = json['isPaused'] as bool? ?? false;
      final isCompleted = json['isCompleted'] as bool? ?? false;
      final price = (json['price'] as num?)?.toDouble() ?? 0.0;
      final childCount = json['childCount'] as int? ?? 1;
      final siblingIds = (json['siblingIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
      final hasTimePurchase = json['hasTimePurchase'] as bool? ?? false;
      final purchasedSeconds = json['purchasedSeconds'] as int? ?? 0;

      return Customer(
        id: id,
        childName: childName,
        parentName: parentName,
        phoneNumber: phoneNumber,
        entryTime: entryTime,
        ticketNumber: ticketNumber,
        totalSeconds: totalSeconds,
        usedSeconds: usedSeconds,
        pausedSeconds: pausedSeconds,
        remainingMinutes: remainingMinutes,
        remainingSeconds: remainingSeconds,
        isPaused: isPaused,
        pauseStartTime: pauseStartTime,
        isCompleted: isCompleted,
        completedTime: completedTime,
        price: price,
        childCount: childCount,
        siblingIds: siblingIds,
        hasTimePurchase: hasTimePurchase,
        purchasedSeconds: purchasedSeconds,
      );
    } catch (e, stackTrace) {
      print('Customer.fromJson: Kritik hata: $e');
      print('Customer.fromJson: Stack: $stackTrace');
      return Customer(
        id: 'error',
        childName: 'Hata',
        parentName: 'Hata',
        phoneNumber: '',
        entryTime: DateTime.now(),
        ticketNumber: 0,
        totalSeconds: 3600, // 1 saat
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'childName': childName,
      'parentName': parentName,
      'phoneNumber': phoneNumber,
      'entryTime': entryTime.toIso8601String(),
      'ticketNumber': ticketNumber,
      'totalSeconds': totalSeconds,
      'usedSeconds': usedSeconds,
      'pausedSeconds': pausedSeconds,
      'remainingMinutes': remainingMinutes,
      'remainingSeconds': remainingSeconds,
      'isPaused': isPaused,
      'pauseStartTime': pauseStartTime?.toIso8601String(),
      'isCompleted': isCompleted,
      'completedTime': completedTime?.toIso8601String(),
      'price': price,
      'childCount': childCount,
      'siblingIds': siblingIds,
      'hasTimePurchase': hasTimePurchase,
      'purchasedSeconds': purchasedSeconds,
      // ESKİ SİSTEM UYUMLULUĞU İÇİN
      'durationMinutes': durationMinutes,
      'originalDurationMinutes': originalDurationMinutes,
      'isActive': isActive,
    };
  }

  Customer copyWith({
    String? id,
    String? childName,
    String? parentName,
    String? phoneNumber,
    DateTime? entryTime,
    int? ticketNumber,
    int? totalSeconds,
    int? usedSeconds,
    int? pausedSeconds,
    int? remainingMinutes,
    int? remainingSeconds,
    bool? isPaused,
    DateTime? pauseStartTime,
    bool? isCompleted,
    DateTime? completedTime,
    double? price,
    int? childCount,
    List<String>? siblingIds,
    bool? hasTimePurchase,
    int? purchasedSeconds,
  }) {
    return Customer(
      id: id ?? this.id,
      childName: childName ?? this.childName,
      parentName: parentName ?? this.parentName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      entryTime: entryTime ?? this.entryTime,
      ticketNumber: ticketNumber ?? this.ticketNumber,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      usedSeconds: usedSeconds ?? this.usedSeconds,
      pausedSeconds: pausedSeconds ?? this.pausedSeconds,
      remainingMinutes: remainingMinutes ?? this.remainingMinutes,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isPaused: isPaused ?? this.isPaused,
      pauseStartTime: pauseStartTime ?? this.pauseStartTime,
      isCompleted: isCompleted ?? this.isCompleted,
      completedTime: completedTime ?? this.completedTime,
      price: price ?? this.price,
      childCount: childCount ?? this.childCount,
      siblingIds: siblingIds ?? this.siblingIds,
      hasTimePurchase: hasTimePurchase ?? this.hasTimePurchase,
      purchasedSeconds: purchasedSeconds ?? this.purchasedSeconds,
    );
  }

  @override
  String toString() {
    return 'Customer{id: $id, childName: $childName, remainingTime: ${currentRemainingTimePerChild.inMinutes} dk, childCount: $childCount}';
  }
}