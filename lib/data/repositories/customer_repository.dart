import 'dart:async';
import 'package:uuid/uuid.dart';
import '../models/customer_model.dart';
import '../services/firebase_service.dart';

/// Müşteri veri yönetiminden sorumlu repository sınıfı.
/// Bu sınıf, uygulama ile veritabanı arasında bir arayüz görevi görür.
/// UI katmanı doğrudan bu sınıf ile etkileşime girer.
class CustomerRepository {
  // Servis sınıfı referansı
  final FirebaseService _firebaseService;

  // Stream controller ve cache için değişkenler
  final _customerStreamController =
      StreamController<List<Customer>>.broadcast();
  List<Customer> _cachedCustomers = [];
  bool _isOfflineMode = false;

  // Dışa açılan stream ve getterlar
  Stream<List<Customer>> get customersStream =>
      _customerStreamController.stream;
  List<Customer> get customers => List.unmodifiable(_cachedCustomers);
  bool get isOfflineMode => _isOfflineMode;

  // Eski kod ile uyumluluk için allCustomersHistory getter'ı
  List<Customer> get allCustomersHistory => _cachedCustomers;

  CustomerRepository({required FirebaseService firebaseService})
    : _firebaseService = firebaseService {
    try {
      // FirebaseService'in offline durumunu kontrol et
      _isOfflineMode = _firebaseService.isOfflineMode;

      if (_isOfflineMode) {
        print('CustomerRepository çevrimdışı modda başlatıldı');
        // Boş liste ile başlat
        _cachedCustomers = [];
        _customerStreamController.add(_cachedCustomers);
      } else {
        // Aktif müşterileri dinlemeye başla
        _startListeningToActiveCustomers();
      }

      // Performans için gereksiz timer kaldırıldı
      // UI sadece veri değiştiğinde güncellenir

      print('CustomerRepository başarıyla başlatıldı');
    } catch (e) {
      print('CustomerRepository başlatma hatası: $e');
      // Boş liste ile başlat
      _cachedCustomers = [];
      _customerStreamController.add(_cachedCustomers);
    }
  }

  /// Aktif müşterileri dinlemeye başlar ve değişikliklerini stream'e iletir
  void _startListeningToActiveCustomers() {
    try {
      // Çevrimdışı modda ise dinlemeye başlama
      if (_isOfflineMode) {
        return;
      }

      // Stream'i optimize et - tüm müşterileri dinle (aktif, tamamlanan, iptal edilen)
      _firebaseService.getAllCustomersStream().listen(
        (customers) {
          // Sadece veri değiştiyse güncelle
          if (_cachedCustomers.length != customers.length || 
              !_areCustomersEqual(_cachedCustomers, customers)) {
            _cachedCustomers = customers;
            _customerStreamController.add(_cachedCustomers);
          }
        },
        onError: (error) {
          print('Müşteri verileri dinlenirken hata: $error');
          // Hata durumunda boş liste gönder
          _customerStreamController.add([]);
        },
      );
    } catch (e) {
      print('Müşteri dinleme başlatma hatası: $e');
    }
  }


  
  /// Müşteri listelerinin eşit olup olmadığını kontrol eder
  bool _areCustomersEqual(List<Customer> list1, List<Customer> list2) {
    if (list1.length != list2.length) return false;
    
    for (int i = 0; i < list1.length; i++) {
      if (list1[i].id != list2[i].id || 
          list1[i].remainingTime != list2[i].remainingTime ||
          list1[i].isCompleted != list2[i].isCompleted ||
          list1[i].isActive != list2[i].isActive) {
        return false;
      }
    }
    return true;
  }

  /// Tüm müşteri geçmişini getirir (aktif ve tamamlanmış)
  Future<List<Customer>> getAllCustomersHistory() async {
    try {
      // Çevrimdışı modda boş liste dön
      if (_isOfflineMode) {
        return [];
      }

      return await _firebaseService.getAllCustomers();
    } catch (e) {
      print('Müşteri geçmişi alınırken hata: $e');
      return [];
    }
  }

  /// Son bilet numarasını getir
  Future<int> getLastTicketNumber() async {
    try {
      if (_isOfflineMode) {
        print('CUSTOMER_REPO: Çevrimdışı modda son bilet numarası alınamadı');
        // Her gün 100'den başla
        return 100;
      }

      return await _firebaseService.getLastTicketNumber();
    } catch (e) {
      print('CUSTOMER_REPO: Son bilet numarası alınırken hata: $e');
      return 100; // Hata durumunda varsayılan değer
    }
  }

  /// Yeni bir bilet numarası al (atomik arttırma)
  Future<int> getNextTicketNumber() async {
    try {
      if (_isOfflineMode) {
        print('CUSTOMER_REPO: Çevrimdışı modda yeni bilet numarası alınamadı');
        // Her gün 100'den başla
        return 100;
      }

      return await _firebaseService.incrementTicketNumber();
    } catch (e) {
      print('CUSTOMER_REPO: Yeni bilet numarası alınırken hata: $e');
      return await getLastTicketNumber() + 1; // Son bilet numarası + 1
    }
  }

  /// Yeni müşteri ekler
  Future<void> addCustomer(Customer customer) async {
    try {
      // Çevrimdışı modda işlemi atla
      if (_isOfflineMode) {
        print('CUSTOMER_REPO: Çevrimdışı modda müşteri eklenemez');
        return;
      }

      print(
        'CUSTOMER_REPO: Müşteri ekleme işlemi başlatıldı: ${customer.childName}',
      );

      // Bilet numarası atanmamışsa veya 0 ise yeni bilet numarası al
      int ticketNumber = customer.ticketNumber;
      if (ticketNumber <= 0) {
        ticketNumber = await getNextTicketNumber();
        print('CUSTOMER_REPO: Yeni bilet numarası alındı: $ticketNumber');
      }

      final uuid = Uuid();
      final customerWithId = customer.copyWith(
        id: uuid.v4(),
        ticketNumber: ticketNumber,
      );

      // JSON verisi oluştur
      final json = customerWithId.toJson();
      print(
        'CUSTOMER_REPO: Müşteri JSON verileri hazırlandı. Bilet: $ticketNumber',
      );

      // Firestore'a ekle
      await _firebaseService.addCustomer(json);

      print(
        'CUSTOMER_REPO: Müşteri başarıyla eklendi: ${customer.childName}, Bilet: $ticketNumber',
      );

      // Firestore listener otomatik olarak güncelleyecek, manuel güncelleme gereksiz
    } catch (e) {
      print('CUSTOMER_REPO: Müşteri eklenirken hata: $e');
      print('CUSTOMER_REPO: Hata stack: ${StackTrace.current}');
      rethrow;
    }
  }

  /// Müşteri bilgilerini günceller
  Future<void> updateCustomer(Customer updatedCustomer) async {
    try {
      // Çevrimdışı modda işlemi atla
      if (_isOfflineMode) {
        print('Çevrimdışı modda müşteri güncellenemez');
        return;
      }

      await _firebaseService.updateCustomer(
        updatedCustomer.id,
        updatedCustomer.toJson(),
      );
    } catch (e) {
      print('Müşteri güncellenirken hata: $e');
      rethrow;
    }
  }

  /// Müşteriyi veritabanından siler
  Future<void> deleteCustomer(String id) async {
    try {
      // Çevrimdışı modda işlemi atla
      if (_isOfflineMode) {
        print('Çevrimdışı modda müşteri silinemez');
        return;
      }

      await _firebaseService.deleteCustomer(id);
    } catch (e) {
      print('Müşteri silinirken hata: $e');
      rethrow;
    }
  }

  /// Süre biten müşterileri otomatik tamamla
  Future<void> autoCompleteExpiredCustomers() async {
    try {
      if (_isOfflineMode) {
        print('CUSTOMER_REPO: Çevrimdışı modda otomatik tamamlama yapılamaz');
        return;
      }

      await _firebaseService.autoCompleteExpiredCustomers();
      print('CUSTOMER_REPO: Süre biten müşteriler otomatik tamamlandı');
    } catch (e) {
      print('CUSTOMER_REPO: Otomatik tamamlama hatası: $e');
    }
  }

  /// Müşteri işleminin tamamlandığını işaretler
  Future<void> completeCustomer(String id) async {
    try {
      // Çevrimdışı modda işlemi atla
      if (_isOfflineMode) {
        print('CUSTOMER_REPO: Çevrimdışı modda müşteri tamamlanamaz');
        return;
      }

      print('CUSTOMER_REPO: Müşteri tamamlama işlemi başlatıldı, ID: $id');

      // Önce müşterinin önbellekte olup olmadığını kontrol et
      final customerIndex = _cachedCustomers.indexWhere((c) => c.id == id);
      if (customerIndex >= 0) {
        print('CUSTOMER_REPO: Müşteri önbellekte bulundu, cache güncelleniyor');

        // Önbellekteki müşteriyi inactive olarak işaretle
        final customer = _cachedCustomers[customerIndex];
        final updatedCustomer = customer.copyWith(
          isPaused: false,
          pauseTime: null,
        );

        // Önbelleği güncelle - aktif müşteriler arasından çıkar
        _cachedCustomers.removeAt(customerIndex);
        _customerStreamController.add(_cachedCustomers);

        print(
          'CUSTOMER_REPO: Müşteri önbellekten kaldırıldı, veritabanı güncelleniyor',
        );
      } else {
        print(
          'CUSTOMER_REPO: Müşteri önbellekte bulunamadı, sadece veritabanı güncelleniyor',
        );
      }

      // Veritabanında güncelle
      await _firebaseService.completeCustomer(id);
      print('CUSTOMER_REPO: Müşteri başarıyla tamamlandı, ID: $id');
    } catch (e) {
      print('CUSTOMER_REPO: Müşteri tamamlanırken hata: $e');

      // Belge bulunamadı hatasını ele al
      if (e.toString().contains('not-found') ||
          e.toString().contains('not found') ||
          e.toString().contains('bulunamadı')) {
        print(
          'CUSTOMER_REPO: Belge bulunamadı hatası alındı, önbellek güncelleme ile devam ediliyor',
        );

        // Veritabanında yoksa bile önbellekten kaldır
        final customerIndex = _cachedCustomers.indexWhere((c) => c.id == id);
        if (customerIndex >= 0) {
          _cachedCustomers.removeAt(customerIndex);
          _customerStreamController.add(_cachedCustomers);
          print('CUSTOMER_REPO: Müşteri önbellekten kaldırıldı');
          return; // Hata fırlatma
        }

        // Önbellekte de yoksa sessizce devam et
        print('CUSTOMER_REPO: Müşteri zaten önbellekte yok, işlem tamamlandı');
        return;
      }

      rethrow; // Diğer hataları yeniden fırlat
    }
  }

  /// Müşteri süresini duraklatır veya devam ettirir
  Future<void> toggleCustomerPause(String id) async {
    try {
      // Çevrimdışı modda işlemi atla
      if (_isOfflineMode) {
        print('Çevrimdışı modda müşteri durumu değiştirilemez');
        return;
      }

      await _firebaseService.toggleCustomerPause(id);
    } catch (e) {
      print('Müşteri duraklatma işleminde hata: $e');
      rethrow;
    }
  }

  /// Aktif müşterileri getirir
  Future<List<Customer>> getActiveCustomers() async {
    try {
      // Çevrimdışı modda cache'den dön
      if (_isOfflineMode) {
        return _cachedCustomers.where((c) => !c.isPaused).toList();
      }

      return await _firebaseService.getActiveCustomers();
    } catch (e) {
      print('Aktif müşteriler alınırken hata: $e');
      return [];
    }
  }

  /// Tamamlanmış müşterileri getirir
  Future<List<Customer>> getCompletedCustomers({int limit = 50}) async {
    try {
      // Çevrimdışı modda boş liste dön
      if (_isOfflineMode) {
        return [];
      }

      return await _firebaseService.getCompletedCustomers(limit: limit);
    } catch (e) {
      print('CUSTOMER_REPO: Tamamlanmış müşteriler alınırken hata: $e');
      return [];
    }
  }

  /// İptal edilmiş müşterileri getirir (price = -1 olanlar)
  Future<List<Customer>> getCancelledCustomers({int limit = 50}) async {
    try {
      // Çevrimdışı modda boş liste dön
      if (_isOfflineMode) {
        print('CUSTOMER_REPO: Çevrimdışı modda iptal müşterileri alınamadı');
        return [];
      }

      final allCompleted = await _firebaseService.getCompletedCustomers(
        limit: limit * 2,
      );

      // price = -1 olanları filtrele (iptal edilmiş olanlar)
      final cancelledCustomers =
          allCompleted.where((c) => c.price == -1).toList();

      // Limit uygula
      if (cancelledCustomers.length > limit) {
        return cancelledCustomers.sublist(0, limit);
      }

      return cancelledCustomers;
    } catch (e) {
      print('CUSTOMER_REPO: İptal müşterileri alınırken hata: $e');
      return [];
    }
  }

  /// Normal tamamlanmış müşterileri getirir (iptal edilenler hariç)
  Future<List<Customer>> getNormalCompletedCustomers({int limit = 50}) async {
    try {
      // Çevrimdışı modda boş liste dön
      if (_isOfflineMode) {
        print('CUSTOMER_REPO: Çevrimdışı modda normal müşteriler alınamadı');
        return [];
      }

      final allCompleted = await _firebaseService.getCompletedCustomers(
        limit: limit * 2,
      );

      // price >= 0 olanları filtrele (normal tamamlananlar, iptal edilenler değil)
      final normalCustomers = allCompleted.where((c) => c.price >= 0).toList();

      // Limit uygula
      if (normalCustomers.length > limit) {
        return normalCustomers.sublist(0, limit);
      }

      return normalCustomers;
    } catch (e) {
      print('CUSTOMER_REPO: Normal müşteriler alınırken hata: $e');
      return [];
    }
  }

  /// Repository kapatılırken stream controller'ı temizler
  void dispose() {
    try {
      _customerStreamController.close();
    } catch (e) {
      print('CUSTOMER_REPO: Stream controller kapatılırken hata: $e');
    }
  }

  /// Bilet numaralarını sıfırla (debug için)
  Future<void> resetTicketNumbers() async {
    try {
      // Çevrimdışı modda işlemi atla
      if (_isOfflineMode) {
        print('CUSTOMER_REPO: Çevrimdışı modda bilet numaraları sıfırlanamaz');
        return;
      }

      await _firebaseService.resetTicketNumbers();
      print('CUSTOMER_REPO: Bilet numaraları sıfırlandı');
    } catch (e) {
      print('CUSTOMER_REPO: Bilet numaraları sıfırlanırken hata: $e');
    }
  }

  /// Tüm müşteri verilerini sil
  Future<void> clearAllCustomers() async {
    try {
      // Çevrimdışı modda işlemi atla
      if (_isOfflineMode) {
        print('CUSTOMER_REPO: Çevrimdışı modda müşteri verileri silinemez');
        return;
      }

      print('CUSTOMER_REPO: Tüm müşteri verileri siliniyor...');

      // Firebase'den tüm müşterileri sil
      await _firebaseService.clearAllCustomers();
      
      // Cache'i temizle
      _cachedCustomers.clear();
      
      // Stream'i güncelle - boş liste gönder
      _customerStreamController.add(_cachedCustomers);
      
      print('CUSTOMER_REPO: Tüm müşteri verileri silindi ve cache temizlendi');
    } catch (e) {
      print('CUSTOMER_REPO: Müşteri verileri silinirken hata: $e');
    }
  }
}
