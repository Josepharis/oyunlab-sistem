class Customer {
  final String id;
  final String childName;
  final String parentName;
  final String phoneNumber;
  final DateTime entryTime;
  final int durationMinutes;
  final int ticketNumber;
  final bool isPaused;
  final DateTime? pauseTime;
  final Duration? pausedDuration; // Duraklatma sırasında biriken toplam süre
  final double price; // Müşterinin ödediği ücret
  final int? explicitRemainingMinutes; // Firestore'dan doğrudan gelen kalan süre
  final bool isCompleted; // Müşteri tamamlandı mı?
  final DateTime? completedTime; // Tamamlanma zamanı

  Customer({
    required this.id,
    required this.childName,
    required this.parentName,
    required this.phoneNumber,
    required this.entryTime,
    required this.durationMinutes,
    this.ticketNumber = 0,
    this.isPaused = false,
    this.pauseTime,
    this.pausedDuration,
    this.price = 0.0,
    this.explicitRemainingMinutes,
    this.isCompleted = false,
    this.completedTime,
  });

  // Giriş süresi (dakika cinsinden süreyi Duration nesnesine çevirir)
  Duration get initialTime => Duration(minutes: durationMinutes);

  DateTime get exitTime {
    // Normal süre
    final normalExitTime = entryTime.add(Duration(minutes: durationMinutes));

    print(
      'EXITTIME - Normal exitTime hesaplama: $entryTime + $durationMinutes dk = $normalExitTime',
    );

    // Eğer daha önce duraklatılmış ve biriken süre varsa, çıkış süresini uzat
    if (pausedDuration != null) {
      final adjustedExitTime = normalExitTime.add(pausedDuration!);
      print(
        'EXITTIME - Duraklatma süresi eklenmiş: $pausedDuration -> $adjustedExitTime',
      );
      return adjustedExitTime;
    }

    print('EXITTIME - Nihai çıkış zamanı: $normalExitTime');
    return normalExitTime;
  }

  Duration get remainingTime {
    // Eğer explicitRemainingMinutes değeri varsa, onu doğrudan kullan
    if (explicitRemainingMinutes != null && explicitRemainingMinutes! > 0) {
      print(
        'Firestore\'dan gelen kalan süre kullanılıyor: $explicitRemainingMinutes dk',
      );
      return Duration(minutes: explicitRemainingMinutes!);
    }

    final now = DateTime.now();

    if (!isPaused) {
      // Normal durum - duraklatılmamış
      // Çıkış zamanı şu andan sonra mı kontrolü
      if (exitTime.isAfter(now)) {
        final remaining = exitTime.difference(now);
        print(
          'Hesaplanan kalan süre: ${remaining.inMinutes} dakika, ${remaining.inSeconds} saniye',
        );
        return remaining;
      } else {
        print('Süre dolmuş: exitTime=$exitTime, now=$now');
        return const Duration();
      }
    } else {
      // Duraklatılmış durum - duraklatma anındaki kalan süreyi kullan
      final pausedAt = pauseTime ?? now;

      if (exitTime.isAfter(pausedAt)) {
        final remaining = exitTime.difference(pausedAt);
        print(
          'Duraklatıldığındaki kalan süre: ${remaining.inMinutes} dakika, ${remaining.inSeconds} saniye',
        );
        return remaining;
      } else {
        print('Duraklatıldığında süre dolmuştu');
        return const Duration();
      }
    }
  }

  factory Customer.fromJson(Map<String, dynamic> json) {
    try {
      print('Customer.fromJson: İşlenen veri: $json');

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
        print('Customer.fromJson: entryTime = $entryTime (from $entryTimeStr)');
      } catch (e) {
        print('Customer.fromJson: entryTime parse hatası: $e');
        entryTime = DateTime.now();
      }

      // Çıkış zamanını kontrol et (eksikse entryTime ile hesaplanacak)
      DateTime? explicitExitTime;
      if (json['exitTime'] != null) {
        try {
          final exitTimeStr = json['exitTime'] as String?;
          if (exitTimeStr != null) {
            explicitExitTime = DateTime.parse(exitTimeStr);
            print(
              'Customer.fromJson: explicitExitTime = $explicitExitTime (from $exitTimeStr)',
            );
          }
        } catch (e) {
          print('Customer.fromJson: exitTime parse hatası: $e');
        }
      }

      final durationMinutes = json['durationMinutes'] as int? ?? 60;
      final ticketNumber = json['ticketNumber'] as int? ?? 0;
      final isPaused = json['isPaused'] as bool? ?? false;
      final isActive = json['isActive'] as bool? ?? true;

      // Firestore'dan kalan dakika bilgisini al (varsa)
      final remainingMinutes = json['remainingMinutes'] as int?;
      if (remainingMinutes != null) {
        print(
          'Customer.fromJson: Firestore\'dan kalan dakika: $remainingMinutes',
        );
      }

      // Duraklatma zamanı dönüşümünü güvenli hale getir
      DateTime? pauseTime;
      if (json['pauseTime'] != null) {
        try {
          pauseTime = DateTime.parse(json['pauseTime'] as String);
          print('Customer.fromJson: pauseTime = $pauseTime');
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
          print('Customer.fromJson: pausedDuration = $pausedDuration');
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
          completedTime = DateTime.parse(json['completedTime'] as String);
          print('Customer.fromJson: completedTime = $completedTime');
        } catch (e) {
          print('Customer.fromJson: completedTime parse hatası: $e');
          completedTime = null;
        }
      }

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
          print(
            'Customer.fromJson: Kalan süreye göre ayarlanmış giriş zamanı: $adjustedEntryTime',
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
        ticketNumber: ticketNumber,
        isPaused: isPaused,
        pauseTime: pauseTime,
        pausedDuration: pausedDuration,
        price: price,
        explicitRemainingMinutes:
            remainingMinutes, // Firestore'dan gelen değeri kullan
        isCompleted: isCompleted,
        completedTime: completedTime,
      );

      print('Customer.fromJson: Hesaplanan exitTime = ${customer.exitTime}');
      print(
        'Customer.fromJson: Hesaplanan remainingTime = ${customer.remainingTime.inMinutes} dakika',
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
      'ticketNumber': ticketNumber,
      'isPaused': isPaused,
      'pauseTime': pauseTime?.toIso8601String(),
      'pausedDuration': pausedDuration?.inMilliseconds,
      'price': price,
      'isCompleted': isCompleted,
      'completedTime': completedTime?.toIso8601String(),
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
    int? ticketNumber,
    bool? isPaused,
    DateTime? pauseTime,
    Duration? pausedDuration,
    double? price,
    int? explicitRemainingMinutes,
    bool? isCompleted,
    DateTime? completedTime,
  }) {
    return Customer(
      id: id ?? this.id,
      childName: childName ?? this.childName,
      parentName: parentName ?? this.parentName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      entryTime: entryTime ?? this.entryTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      ticketNumber: ticketNumber ?? this.ticketNumber,
      isPaused: isPaused ?? this.isPaused,
      pauseTime: pauseTime ?? this.pauseTime,
      pausedDuration: pausedDuration ?? this.pausedDuration,
      price: price ?? this.price,
      explicitRemainingMinutes:
          explicitRemainingMinutes ?? this.explicitRemainingMinutes,
      isCompleted: isCompleted ?? this.isCompleted,
      completedTime: completedTime ?? this.completedTime,
    );
  }

  @override
  String toString() {
    return 'Customer{id: $id, childName: $childName, remainingTime: ${remainingTime.inMinutes} dk}';
  }
}
