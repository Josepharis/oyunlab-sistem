class Customer {
  final String id;
  final String childName;
  final String parentName;
  final String phoneNumber;
  final DateTime entryTime;
  final int durationMinutes; // Çocuk başına düşen süre (kardeş ekleme sonrası)
  final int originalDurationMinutes; // Orijinal alınan toplam süre (değişmez)
  final int ticketNumber;
  final bool isPaused;
  final DateTime? pauseTime;
  final Duration? pausedDuration; // Duraklatma sırasında biriken toplam süre
  final double price; // Müşterinin ödediği ücret
  final int? explicitRemainingMinutes; // Firestore'dan doğrudan gelen kalan süre
  final int? explicitRemainingSeconds; // Firestore'dan doğrudan gelen kalan süre saniye
  final bool isCompleted; // Müşteri tamamlandı mı?
  final DateTime? completedTime; // Tamamlanma zamanı
  final int? usedMinutes; // Kullanılan süre (dakika cinsinden, sabit)
  final int? usedSeconds; // Kullanılan süre (saniye cinsinden, sabit)
  final int childCount; // Bu bilet için toplam çocuk sayısı
  final bool isActive; // Müşteri aktif mi? (süre bitince false olur)

  Customer({
    required this.id,
    required this.childName,
    required this.parentName,
    required this.phoneNumber,
    required this.entryTime,
    required this.durationMinutes,
    this.originalDurationMinutes = 0, // Varsayılan 0, sonra set edilecek
    this.ticketNumber = 0,
    this.isPaused = false,
    this.pauseTime,
    this.pausedDuration,
    this.price = 0.0,
    this.explicitRemainingMinutes,
    this.explicitRemainingSeconds,
    this.isCompleted = false,
    this.completedTime,
    this.usedMinutes,
    this.usedSeconds,
    this.childCount = 1, // Varsayılan olarak 1 çocuk
    this.isActive = true, // Varsayılan olarak aktif
  });

  // Giriş süresi (dakika cinsinden süreyi Duration nesnesine çevirir)
  Duration get initialTime => Duration(minutes: durationMinutes);

  DateTime get exitTime {
    // Normal süre
    final normalExitTime = entryTime.add(Duration(minutes: durationMinutes));



    // Eğer daha önce duraklatılmış ve biriken süre varsa, çıkış süresini uzat
    if (pausedDuration != null) {
      final adjustedExitTime = normalExitTime.add(pausedDuration!);

      return adjustedExitTime;
    }


    return normalExitTime;
  }

  Duration get remainingTime {
    // Eğer explicitRemainingMinutes değeri varsa, onu doğrudan kullan (sabit değer, 0 bile olsa)
    if (explicitRemainingMinutes != null) {
      final seconds = explicitRemainingSeconds ?? 0;
      return Duration(minutes: explicitRemainingMinutes!, seconds: seconds);
    }

    // Sabit değer yok ise 0 döndür (süre akışı olmasın)
    return const Duration();
  }

  /// Kullanılan süreyi döndürür (sabit değer)
  Duration get usedTime {
    // Eğer usedMinutes varsa onu kullan (sabit değer, 0 bile olsa)
    if (usedMinutes != null) {
      final seconds = usedSeconds ?? 0;
      return Duration(minutes: usedMinutes!, seconds: seconds);
    }

    // Sabit değer yok ise 0 döndür (süre akışı olmasın)
    return const Duration();
  }

  /// Aktif müşteriler için gerçek zamanlı kalan süre (anasayfa için)
  Duration get activeRemainingTime {
    // Eğer müşteri tamamlandıysa, sabit 0 döndür
    if (isCompleted) {
      return const Duration();
    }

    // Aktif müşteriler için gerçek zamanlı hesaplama
    final now = DateTime.now();

    if (!isPaused) {
      // Normal durum - duraklatılmamış
      if (exitTime.isAfter(now)) {
        final remaining = exitTime.difference(now);
        return remaining;
      } else {
        return const Duration();
      }
    } else {
      // Duraklatılmış durum - duraklatma anındaki kalan süreyi kullan
      final pausedAt = pauseTime ?? now;

      if (exitTime.isAfter(pausedAt)) {
        final remaining = exitTime.difference(pausedAt);
        return remaining;
      } else {
        return const Duration();
      }
    }
  }

  /// Aktif müşteriler için gerçek zamanlı kullanılan süre (anasayfa için)
  Duration get activeUsedTime {
    // Eğer müşteri tamamlandıysa, sabit 0 döndür
    if (isCompleted) {
      return const Duration();
    }

    // Aktif müşteriler için gerçek zamanlı hesaplama
    final now = DateTime.now();
    return now.difference(entryTime);
  }

  factory Customer.fromJson(Map<String, dynamic> json) {
    try {


      final id = json['id'] as String? ?? '';
      final childName = json['childName'] as String? ?? '';
      final parentName = json['parentName'] as String? ?? '';
      final phoneNumber = json['phoneNumber'] as String? ?? '';

      // Tarih dönüşümlerini güvenli hale getir
      DateTime entryTime;
      try {
        final entryTimeStr = json['entryTime'] as String?;
        entryTime =
            entryTimeStr != null
                ? DateTime.parse(entryTimeStr)
                : DateTime.now();

      } catch (e) {
        print('Customer.fromJson: entryTime parse hatası: $e');
        entryTime = DateTime.now();
      }

      // Çıkış zamanını kontrol et (eksikse entryTime ile hesaplanacak)
      DateTime? explicitExitTime;
      if (json['exitTime'] != null) {
        try {
          // Firebase'den gelen Timestamp tipini kontrol et
          if (json['exitTime'] is String) {
            explicitExitTime = DateTime.parse(json['exitTime'] as String);
          } else if (json['exitTime'] is Map) {
            // Timestamp objesi ise
            final timestamp = json['exitTime'] as Map<String, dynamic>;
            if (timestamp['_seconds'] != null) {
              final seconds = timestamp['_seconds'] as int;
              explicitExitTime = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
            }
          }
        } catch (e) {
          print('Customer.fromJson: exitTime parse hatası: $e');
        }
      }

      final durationMinutes = json['durationMinutes'] as int? ?? 60;
      final ticketNumber = json['ticketNumber'] as int? ?? 0;
      final isPaused = json['isPaused'] as bool? ?? false;
      final isActive = json['isActive'] as bool? ?? true;

      // Firestore'dan kalan dakika ve saniye bilgisini al (varsa)
      final remainingMinutes = json['remainingMinutes'] as int?;
      final remainingSeconds = json['remainingSeconds'] as int?;
      if (remainingMinutes != null) {

      }

      // Duraklatma zamanı dönüşümünü güvenli hale getir
      DateTime? pauseTime;
      if (json['pauseTime'] != null) {
        try {
          // Firebase'den gelen Timestamp tipini kontrol et
          if (json['pauseTime'] is String) {
            pauseTime = DateTime.parse(json['pauseTime'] as String);
          } else if (json['pauseTime'] is Map) {
            // Timestamp objesi ise
            final timestamp = json['pauseTime'] as Map<String, dynamic>;
            if (timestamp['_seconds'] != null) {
              final seconds = timestamp['_seconds'] as int;
              pauseTime = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
            }
          }
        } catch (e) {
          print('Customer.fromJson: pauseTime parse hatası: $e');
          pauseTime = null;
        }
      }

      // Duraklama süresi dönüşümü
      Duration? pausedDuration;
      if (json['pausedDuration'] != null) {
        try {
          final pausedMs = json['pausedDuration'] as int;
          pausedDuration = Duration(milliseconds: pausedMs);

        } catch (e) {
          print('Customer.fromJson: pausedDuration parse hatası: $e');
          pausedDuration = null;
        }
      }

      final price = (json['price'] as num?)?.toDouble() ?? 0.0;
      final isCompleted = json['isCompleted'] as bool? ?? false;
      
      // Tamamlanma zamanı dönüşümü
      DateTime? completedTime;
      if (json['completedTime'] != null) {
        try {
          // Firebase'den gelen Timestamp tipini kontrol et
          if (json['completedTime'] is String) {
            completedTime = DateTime.parse(json['completedTime'] as String);
          } else if (json['completedTime'] is Map) {
            // Timestamp objesi ise
            final timestamp = json['completedTime'] as Map<String, dynamic>;
            if (timestamp['_seconds'] != null) {
              final seconds = timestamp['_seconds'] as int;
              completedTime = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
            }
          }
          print('Customer.fromJson: completedTime = $completedTime');
        } catch (e) {
          print('Customer.fromJson: completedTime parse hatası: $e');
          completedTime = null;
        }
      }

      // Kullanılan süre (dakika cinsinden)
      final usedMinutes = json['usedMinutes'] as int?;

      // Kullanılan saniye bilgisini al (varsa)
      final usedSeconds = json['usedSeconds'] as int?;

      // Çıkış zamanı hesaplaması (durationMinutes kullanılarak)
      final calculatedExitTime = entryTime.add(
        Duration(minutes: durationMinutes),
      );

      // Firestore'daki remainingMinutes değerine göre düzeltilmiş entryTime hesapla
      DateTime adjustedEntryTime = entryTime;
      if (remainingMinutes != null) {
        // Eğer girş zamanı + süre şu andan önceyse ve remainingMinutes > 0 ise
        // entryTime'ı şu andan remainingMinutes kadar önceye ayarla
        final now = DateTime.now();
        if (calculatedExitTime.isBefore(now) && remainingMinutes > 0) {
          // Kalan süreye göre giriş zamanını ayarla
          adjustedEntryTime = now.subtract(
            Duration(minutes: durationMinutes - remainingMinutes),
          );

        }
      }

      final customer = Customer(
        id: id,
        childName: childName,
        parentName: parentName,
        phoneNumber: phoneNumber,
        entryTime: adjustedEntryTime, // Ayarlanmış giriş zamanını kullan
        durationMinutes: durationMinutes,
        originalDurationMinutes: json['originalDurationMinutes'] as int? ?? durationMinutes, // Varsayılan durationMinutes
        ticketNumber: ticketNumber,
        isPaused: isPaused,
        pauseTime: pauseTime,
        pausedDuration: pausedDuration,
        price: price,
        explicitRemainingMinutes:
            remainingMinutes, // Firestore'dan gelen değeri kullan
        explicitRemainingSeconds:
            remainingSeconds, // Kalan süre saniyesi
        isCompleted: isCompleted,
        completedTime: completedTime,
        usedMinutes: usedMinutes,
        usedSeconds: usedSeconds,
        childCount: json['childCount'] as int? ?? 1, // Varsayılan 1
        isActive: isActive, // isActive field'ını ekle
      );



      return customer;
    } catch (e, stackTrace) {
      print('Customer.fromJson: Kritik hata: $e');
      print('Customer.fromJson: Stack: $stackTrace');
      // Hata durumunda varsayılan bir müşteri döndür
      return Customer(
        id: 'error',
        childName: 'Hata',
        parentName: 'Hata',
        phoneNumber: '',
        entryTime: DateTime.now(),
        durationMinutes: 60,
        ticketNumber: 0,
        price: 0.0,
        isCompleted: false,
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
      'durationMinutes': durationMinutes,
      'originalDurationMinutes': originalDurationMinutes,
      'ticketNumber': ticketNumber,
      'isPaused': isPaused,
      'pauseTime': pauseTime?.toIso8601String(),
      'pausedDuration': pausedDuration?.inMilliseconds,
      'price': price,
      'explicitRemainingMinutes': explicitRemainingMinutes,
      'explicitRemainingSeconds': explicitRemainingSeconds,
      'remainingMinutes': explicitRemainingMinutes, // Firebase uyumluluğu için
      'isCompleted': isCompleted,
      'completedTime': completedTime?.toIso8601String(),
      'usedMinutes': usedMinutes,
      'usedSeconds': usedSeconds,
      'childCount': childCount,
      'isActive': isActive,
    };
  }

  /// Customer sınıfının kopyasını oluşturur ve belirtilen alanları günceller
  Customer copyWith({
    String? id,
    String? childName,
    String? parentName,
    String? phoneNumber,
    DateTime? entryTime,
    int? durationMinutes,
    int? originalDurationMinutes,
    int? ticketNumber,
    bool? isPaused,
    DateTime? pauseTime,
    Duration? pausedDuration,
    double? price,
    int? explicitRemainingMinutes,
    int? explicitRemainingSeconds,
    bool? isCompleted,
    DateTime? completedTime,
    int? usedMinutes,
    int? usedSeconds,
    int? childCount,
    bool? isActive,
  }) {
    return Customer(
      id: id ?? this.id,
      childName: childName ?? this.childName,
      parentName: parentName ?? this.parentName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      entryTime: entryTime ?? this.entryTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      originalDurationMinutes: originalDurationMinutes ?? this.originalDurationMinutes,
      ticketNumber: ticketNumber ?? this.ticketNumber,
      isPaused: isPaused ?? this.isPaused,
      pauseTime: pauseTime ?? this.pauseTime,
      pausedDuration: pausedDuration ?? this.pausedDuration,
      price: price ?? this.price,
      explicitRemainingMinutes:
          explicitRemainingMinutes ?? this.explicitRemainingMinutes,
      explicitRemainingSeconds:
          explicitRemainingSeconds ?? this.explicitRemainingSeconds,
      isCompleted: isCompleted ?? this.isCompleted,
      completedTime: completedTime ?? this.completedTime,
      usedMinutes: usedMinutes ?? this.usedMinutes,
      usedSeconds: usedSeconds ?? this.usedSeconds,
      childCount: childCount ?? this.childCount,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() {
    return 'Customer{id: $id, childName: $childName, remainingTime: ${remainingTime.inMinutes} dk, usedTime: ${usedTime.inMinutes} dk}';
  }
}
