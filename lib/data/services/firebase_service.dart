import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import '../models/customer_model.dart';

/// Firebase veritabanı işlemlerini yöneten servis sınıfı.
/// Bu sınıf, Firestore işlemlerini soyutlayarak repository'lerin
/// doğrudan veritabanı detaylarıyla uğraşmasını engeller.
class FirebaseService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  bool _isInitialized = false;
  bool _isOfflineMode = false;

  FirebaseService()
    : _firestore = FirebaseFirestore.instance,
      _auth = FirebaseAuth.instance {
    _initFirebase();
  }

  bool get isInitialized => _isInitialized;
  bool get isOfflineMode => _isOfflineMode;

  // Firebase bağlantısını başlatma metodu
  Future<void> _initFirebase() async {
    try {
      // Firestore ayarlarını offline kullanım için optimize et
      await _firestore.settings.persistenceEnabled;

      // Eğer kullanıcı oturum açmamışsa, anonim giriş yap
      if (_auth.currentUser == null) {
        try {
          await _auth.signInAnonymously();
          print('Anonim kullanıcı girişi yapıldı: ${_auth.currentUser?.uid}');
        } catch (authError) {
          print('Anonim giriş yapılamadı: $authError');
          _handleOfflineMode('Kimlik doğrulama hatası: $authError');
          return;
        }
      }

      // Firestore bağlantısını test et
      await _firestore
          .collection('customers')
          .limit(1)
          .get()
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              throw PlatformException(
                code: 'timeout',
                message: 'Firestore bağlantı zaman aşımı',
              );
            },
          )
          .then((_) {
            print('Firestore bağlantısı başarılı');
            _isInitialized = true;
            _isOfflineMode = false;
          })
          .catchError((e) {
            print('Firestore bağlantı hatası: $e');
            _handleOfflineMode('Firestore bağlantı hatası: $e');
          });
    } catch (e) {
      print('Firestore servis başlatma hatası: $e');
      _handleOfflineMode('Servis başlatma hatası: $e');
    }
  }

  // Çevrimdışı moda geçme işlemi
  void _handleOfflineMode(String reason) {
    print('Çevrimdışı moda geçiliyor. Neden: $reason');
    _isOfflineMode = true;
    _isInitialized =
        true; // Uygulamanın çalışabilmesi için başlatıldı olarak işaretle
  }

  // Customers koleksiyonu referansı
  CollectionReference<Map<String, dynamic>> get _customersCollection =>
      _firestore.collection('customers');

  // Settings koleksiyonu referansı
  CollectionReference<Map<String, dynamic>> get _settingsCollection =>
      _firestore.collection('settings');

  /// Son bilet numarasını veritabanından getirir
  Future<int> getLastTicketNumber() async {
    try {
      // Çevrimdışı modda varsayılan değer dön
      if (_isOfflineMode) {
        print(
          'FIREBASE_SERVICE: Çevrimdışı modda son bilet numarası alınamadı, varsayılan: 100',
        );
        return 100;
      }

      // Kullanıcının oturum açtığından emin ol
      if (_auth.currentUser == null) {
        print(
          'FIREBASE_SERVICE: Bilet numarası almak için kimlik doğrulaması gerekiyor',
        );
        return 100;
      }



      // Bugünün tarihini al
      final today = DateTime.now();
      final todayKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // settings/daily_tickets dökümanını getir veya oluştur
      final docRef = _settingsCollection.doc('daily_tickets');
      final doc = await docRef.get();

      if (!doc.exists) {
        // Döküman yoksa oluştur
        await docRef.set({
          'currentDate': todayKey,
          'lastTicketNumber': 100,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('FIREBASE_SERVICE: Yeni daily_tickets dökümanı oluşturuldu, 100\'den başlatıldı');
        return 100;
      }

      // Döküman varsa kontrol et
      final data = doc.data()!;
      final currentDate = data['currentDate'] as String? ?? '';
      final lastTicketNumber = data['lastTicketNumber'] as int? ?? 100;
      
      // Eğer farklı günse, sayacı sıfırla
      if (currentDate != todayKey) {
        await docRef.set({
          'currentDate': todayKey,
          'lastTicketNumber': 100,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('FIREBASE_SERVICE: Yeni gün başladı, bilet numarası 100\'e sıfırlandı');
        return 100;
      }

      // Aynı gün içindeyse mevcut son numarayı döndür
      return lastTicketNumber;


    } catch (e) {
      print('FIREBASE_SERVICE: Son bilet numarası alınırken hata: $e');
      return 100; // Hata durumunda varsayılan değer
    }
  }

  /// Bilet numarasını bir arttırır ve yeni değeri döner
  Future<int> incrementTicketNumber() async {
    try {
      // Çevrimdışı modda varsayılan değer dön
      if (_isOfflineMode) {
        print(
          'FIREBASE_SERVICE: Çevrimdışı modda bilet numarası arttırılamadı',
        );
        return 100;
      }

      // Kullanıcının oturum açtığından emin ol
      if (_auth.currentUser == null) {
        print(
          'FIREBASE_SERVICE: Bilet numarası arttırmak için kimlik doğrulaması gerekiyor',
        );
        return 100;
      }



      // Bugünün tarihini al
      final today = DateTime.now();
      final todayKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // Transaction ile atomik arttırma işlemi yap
      final docRef = _settingsCollection.doc('daily_tickets');

      // Transaction başlat
      final newTicketNumber = await _firestore.runTransaction<int>((
        transaction,
      ) async {
        // Dökümanı oku
        final doc = await transaction.get(docRef);

        if (!doc.exists) {
          // Döküman yoksa oluştur
          transaction.set(docRef, {
            'currentDate': todayKey,
            'lastTicketNumber': 101, // İlk bilet numarası 101 olacak
            'updatedAt': FieldValue.serverTimestamp(),
          });
          print('FIREBASE_SERVICE: Transaction\'da yeni daily_tickets dökümanı oluşturuldu, 101 döndürülüyor');
          return 101;
        }

        // Döküman varsa kontrol et
        final data = doc.data()!;
        final currentDate = data['currentDate'] as String? ?? '';
        final currentNumber = data['lastTicketNumber'] as int? ?? 100;
        
        // Eğer farklı günse, sayacı 100'den başlat ve 101'i döndür
        if (currentDate != todayKey) {
          transaction.set(docRef, {
            'currentDate': todayKey,
            'lastTicketNumber': 101,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          print('FIREBASE_SERVICE: Yeni gün başladı, 101 döndürülüyor');
          return 101;
        }

        // Aynı günse mevcut değeri al ve arttır
        final newNumber = currentNumber + 1;

        // Değeri güncelle
        transaction.update(docRef, {
          'lastTicketNumber': newNumber,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return newNumber;
      });


      return newTicketNumber;
    } catch (e) {
      print('FIREBASE_SERVICE: Bilet numarası arttırılırken hata: $e');
      // Hata durumunda 100'den başla
      return 100;
    }
  }

  // Aktif müşterileri dinleme stream'i
  Stream<List<Customer>> getActiveCustomersStream() {
    try {
      // Çevrimdışı mod ise boş stream dön
      if (_isOfflineMode) {
        return Stream.value([]);
      }

      // Kullanıcının oturum açtığından emin ol
      if (_auth.currentUser == null) {
        print('Aktif müşterileri dinlemek için kimlik doğrulaması gerekiyor');
        return Stream.value([]);
      }

      // Stream'i optimize et - sadece gerekli alanları dinle
      return _customersCollection
          .where('isActive', isEqualTo: true)
          .snapshots()
          .map(
            (snapshot) {
              final customers = snapshot.docs
                  .map(
                    (doc) => Customer.fromJson({...doc.data(), 'id': doc.id}),
                  )
                  .toList();
              
              // Sadece bugün giriş yapmış ve aktif olan müşterileri filtrele
              final now = DateTime.now();
              final todayStart = DateTime(now.year, now.month, now.day);
              final todayEnd = todayStart.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
              
              final activeCustomers = customers.where((customer) {
                // entryTime geçerli bir tarih
                
                // Sadece bugün giriş yapmış müşteriler
                if (customer.entryTime.isBefore(todayStart) || customer.entryTime.isAfter(todayEnd)) {
                  return false;
                }
                
                // Kalan süresi var
                if (customer.remainingTime.inSeconds <= 0) return false;
                
                // Tamamlanmamış
                if (customer.isCompleted) return false;
                
                return true;
              }).toList();
              

              
              return activeCustomers;
            },
          )
          .distinct(); // Aynı veriyi tekrar gönderme
    } catch (e) {
      print('Aktif müşterileri dinlerken hata: $e');
      // Boş stream dön
      return Stream.value([]);
    }
  }

  // Tüm müşterileri dinleme stream'i (aktif, tamamlanan, iptal edilen)
  Stream<List<Customer>> getAllCustomersStream() {
    try {
      // Çevrimdışı mod ise boş stream dön
      if (_isOfflineMode) {
        return Stream.value([]);
      }

      // Kullanıcının oturum açtığından emin ol
      if (_auth.currentUser == null) {
        print('Tüm müşterileri dinlemek için kimlik doğrulaması gerekiyor');
        return Stream.value([]);
      }

      print('FIREBASE_SERVICE: getAllCustomersStream başlatıldı');

      // Stream'i optimize et - tüm müşterileri dinle
      return _customersCollection
          .snapshots()
          .map(
            (snapshot) {
              final customers = snapshot.docs
                  .map(
                    (doc) => Customer.fromJson({...doc.data(), 'id': doc.id}),
                  )
                  .toList();
              
              print('FIREBASE_SERVICE: Stream\'den ${customers.length} müşteri alındı');
              
              // Sadece bugün giriş yapmış müşterileri filtrele
              final now = DateTime.now();
              final todayStart = DateTime(now.year, now.month, now.day);
              final todayEnd = todayStart.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
              
              final todayCustomers = customers.where((customer) {
                // entryTime geçerli bir tarih
                
                // Sadece bugün giriş yapmış müşteriler
                if (customer.entryTime.isBefore(todayStart) || customer.entryTime.isAfter(todayEnd)) {
                  return false;
                }
                
                return true;
              }).toList();
              
              print('FIREBASE_SERVICE: Bugünkü müşteriler: ${todayCustomers.length}');
              return todayCustomers;
            },
          );
          // .distinct() kaldırıldı - yeni müşteri eklenmesi durumunda stream güncellenmeyebiliyordu
    } catch (e) {
      print('Tüm müşterileri dinlerken hata: $e');
      // Boş stream dön
      return Stream.value([]);
    }
  }

  // Tüm müşterileri getir
  Future<List<Customer>> getAllCustomers() async {
    try {
      // Kullanıcının oturum açtığından emin ol
      if (_auth.currentUser == null) {
        print('Müşterileri getirmek için kimlik doğrulaması gerekiyor');
        return [];
      }

      final snapshot = await _customersCollection.get();
      return snapshot.docs
          .map((doc) => Customer.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Tüm müşteriler alınırken hata: $e');
      return [];
    }
  }

  // Yeni müşteri ekle
  Future<void> addCustomer(Map<String, dynamic> customerData) async {
    try {
      // Kullanıcının oturum açtığından emin ol
      if (_auth.currentUser == null) {
        print(
          'FIREBASE_SERVICE: Müşteri eklemek için kimlik doğrulaması gerekiyor',
        );
        throw Exception('Müşteri eklemek için kimlik doğrulaması gerekiyor');
      }

      print('FIREBASE_SERVICE: Firestore\'a müşteri ekleniyor...');

      // Eklenecek veriyi hazırla
      final data = {
        ...customerData,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Firestore'a ekle
      final docRef = await _customersCollection.add(data);
      print('FIREBASE_SERVICE: Müşteri eklendi, ID: ${docRef.id}');
    } catch (e) {
      print('FIREBASE_SERVICE: Müşteri eklenirken kritik hata: $e');
      print('FIREBASE_SERVICE: Hata stack: ${StackTrace.current}');
      rethrow;
    }
  }

  // Müşteri güncelle
  Future<void> updateCustomer(String id, Map<String, dynamic> data) async {
    try {
      // Kullanıcının oturum açtığından emin ol
      if (_auth.currentUser == null) {
        throw Exception(
          'Müşteri güncellemek için kimlik doğrulaması gerekiyor',
        );
      }

      await _customersCollection.doc(id).update(data);
    } catch (e) {
      print('Müşteri güncellenirken hata: $e');
      rethrow;
    }
  }

  // Müşteri sil
  Future<void> deleteCustomer(String id) async {
    try {
      // Kullanıcının oturum açtığından emin ol
      if (_auth.currentUser == null) {
        throw Exception('Müşteri silmek için kimlik doğrulaması gerekiyor');
      }

      await _customersCollection.doc(id).delete();
    } catch (e) {
      print('Müşteri silinirken hata: $e');
      rethrow;
    }
  }

  // Süre biten müşterileri otomatik tamamla
  Future<void> autoCompleteExpiredCustomers() async {
    try {
      if (_auth.currentUser == null) return;

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));

      // Bugünkü aktif müşterileri getir
      final snapshot = await _customersCollection
          .where('isActive', isEqualTo: true)
          .where('isCompleted', isEqualTo: false)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final entryTime = DateTime.parse(data['entryTime'] as String);
        
        // Sadece bugünkü müşteriler
        if (entryTime.isBefore(todayStart) || entryTime.isAfter(todayEnd)) {
          continue;
        }

        final durationMinutes = data['durationMinutes'] as int? ?? 60;
        final exitTime = entryTime.add(Duration(minutes: durationMinutes));

        // Süre bittiyse otomatik tamamla
        if (exitTime.isBefore(now)) {
          // KALAN SÜRE BAZLI: Süre bitti, kalan süre 0
          final totalSeconds = durationMinutes * 60;
          final usedTotalSeconds = totalSeconds; // Tüm süre kullanıldı
          final usedMinutes = usedTotalSeconds ~/ 60;
          final usedSeconds = usedTotalSeconds % 60;
          
          await _customersCollection.doc(doc.id).update({
            'isActive': false,
            'isCompleted': true,
            'completedTime': FieldValue.serverTimestamp(),
            'exitTime': FieldValue.serverTimestamp(),
            'remainingMinutes': 0, // Süre bitti
            'remainingSeconds': 0, // Kalan süre saniye
            'explicitRemainingMinutes': 0, // Model için aynı değer
            'explicitRemainingSeconds': 0, // Model için saniye
            'usedMinutes': usedMinutes, // Toplam kullanılan süre
            'usedSeconds': usedSeconds, // Kullanılan süre saniye
          });

          print('FIREBASE_SERVICE: Müşteri otomatik tamamlandı, ID: ${doc.id}');
        }
      }
    } catch (e) {
      print('FIREBASE_SERVICE: Otomatik tamamlama hatası: $e');
    }
  }

  // Müşteriyi tamamlandı olarak işaretle
  Future<void> completeCustomer(String id) async {
    try {
      // Kullanıcının oturum açtığından emin ol
      if (_auth.currentUser == null) {
        throw Exception('Müşteri tamamlamak için kimlik doğrulaması gerekiyor');
      }

      print('FIREBASE_SERVICE: Müşteri tamamlama işlemi başlatıldı, ID: $id');

      // Önce belgenin varlığını kontrol et
      final docSnapshot = await _customersCollection.doc(id).get();

      if (!docSnapshot.exists) {
        print('FIREBASE_SERVICE: Belge bulunamadı, ID: $id');
        throw Exception('Müşteri belgesi bulunamadı');
      }

      // Belge varsa güncelle
      final customerData = docSnapshot.data()!;
      
      // KALAN SÜRE BAZLI SİSTEM: Teslim edildiği andaki kalan süreyi al
      final customer = Customer.fromJson({...customerData, 'id': id});
      final currentRemainingSeconds = customer.currentRemainingSeconds;
      
      // Kalan süreyi kaydet (çocuk sayısı ile çarpılmış toplam kalan süre)
      final totalRemainingSeconds = currentRemainingSeconds;
      final totalRemainingMinutes = totalRemainingSeconds ~/ 60;
      final totalRemainingSecondsOnly = totalRemainingSeconds % 60;
      
      // Kullanılan süreyi hesapla (toplam süre - kalan süre)
      final totalSeconds = customer.totalSeconds;
      final usedTotalSeconds = totalSeconds - totalRemainingSeconds;
      final usedMinutes = usedTotalSeconds ~/ 60;
      final usedSeconds = usedTotalSeconds % 60;
      
      // Giriş ücreti satış kaydı oluştur (eğer ücret varsa)
      final double entryFee = (customerData['price'] as num?)?.toDouble() ?? 0.0;
      if (entryFee > 0) {
        await _createEntryFeeSaleRecord(customer, entryFee);
      }
      
      await _customersCollection.doc(id).update({
        'isActive': false,
        'isCompleted': true,
        'completedTime': FieldValue.serverTimestamp(),
        'exitTime': FieldValue.serverTimestamp(),
        'remainingMinutes': totalRemainingMinutes, // Teslim edildiği andaki TOPLAM kalan süre
        'remainingSeconds': totalRemainingSecondsOnly, // TOPLAM kalan süre saniye
        'explicitRemainingMinutes': totalRemainingMinutes, // Model için aynı değer
        'explicitRemainingSeconds': totalRemainingSecondsOnly, // Model için saniye
        'usedMinutes': usedMinutes, // Teslim edildiği andaki kullanılan süre
        'usedSeconds': usedSeconds, // Kullanılan süre saniye
      });

      print('FIREBASE_SERVICE: Müşteri başarıyla tamamlandı, ID: $id');
    } catch (e) {
      print('FIREBASE_SERVICE: Müşteri tamamlanırken hata: $e');

      // Belge bulunamadı hatası için özel işlem
      if (e.toString().contains('not-found') ||
          e.toString().contains('not found')) {
        print('FIREBASE_SERVICE: Belge bulunamadığı için yeniden deneniyor');

        try {
          // Belge yoksa önce oluşturalım
          await _customersCollection.doc(id).set(
            {
              'isActive': false,
              'isCompleted': true,
              'completedTime': FieldValue.serverTimestamp(),
              'exitTime': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          ); // merge kullanarak var olan alanları koruyoruz

          print('FIREBASE_SERVICE: Belge oluşturuldu ve tamamlandı');
        } catch (retryError) {
          print('FIREBASE_SERVICE: Yeniden deneme sırasında hata: $retryError');
          rethrow;
        }
      } else {
        rethrow;
      }
    }
  }



  // Giriş ücreti satış kaydı oluştur
  Future<void> _createEntryFeeSaleRecord(Customer customer, double entryFee) async {
    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) return;

      // SaleService'i import etmek yerine doğrudan Firestore'a yaz
      final saleRecord = {
        'userId': firebaseUser.uid,
        'userName': firebaseUser.displayName ?? firebaseUser.email?.split('@')[0] ?? 'Kullanıcı',
        'customerName': customer.childName,
        'amount': entryFee,
        'description': 'Giriş Ücreti - ${customer.totalSeconds ~/ 60} dakika',
        'date': FieldValue.serverTimestamp(),
        'customerPhone': customer.phoneNumber,
        'customerEmail': null,
        'items': ['Giriş Ücreti - ${customer.totalSeconds ~/ 60} dakika'],
        'paymentMethod': 'Nakit',
        'status': 'Tamamlandı',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('sales').add(saleRecord);
      print('✅ Giriş ücreti satış kaydı oluşturuldu: ${customer.childName} - ${entryFee}₺');
    } catch (e) {
      print('Giriş ücreti satış kaydı oluşturulurken hata: $e');
    }
  }

  // Müşteri duraklatma/devam ettirme işlemi
  Future<void> toggleCustomerPause(String id) async {
    try {
      // Kullanıcının oturum açtığından emin ol
      if (_auth.currentUser == null) {
        throw Exception(
          'Müşteri duraklatmak için kimlik doğrulaması gerekiyor',
        );
      }

      // Müşteriyi getir
      final doc = await _customersCollection.doc(id).get();
      if (!doc.exists) {
        throw Exception('Müşteri bulunamadı');
      }

      final customerData = doc.data()!;
      final isPaused = customerData['isPaused'] as bool? ?? false;
      final now = DateTime.now();

      if (isPaused) {
        // Duraklatmayı kaldır
        final pauseTime =
            customerData['pauseTime'] != null
                ? DateTime.parse(customerData['pauseTime'] as String)
                : now;

        final pauseDuration = now.difference(pauseTime);

        // Toplam duraklatma süresini hesapla
        final existingPausedDuration = customerData['pausedDuration'] as int?;
        final totalPausedDuration =
            (existingPausedDuration ?? 0) + pauseDuration.inMilliseconds;

        await _customersCollection.doc(id).update({
          'isPaused': false,
          'pauseTime': null,
          'pausedDuration': totalPausedDuration,
        });
      } else {
        // Duraklatmayı başlat
        await _customersCollection.doc(id).update({
          'isPaused': true,
          'pauseTime': now.toIso8601String(),
        });
      }
    } catch (e) {
      print('Müşteri duraklatma işleminde hata: $e');
      rethrow;
    }
  }

  // Aktif müşterileri getir
  Future<List<Customer>> getActiveCustomers() async {
    try {
      // Kullanıcının oturum açtığından emin ol
      if (_auth.currentUser == null) {
        print('Aktif müşterileri getirmek için kimlik doğrulaması gerekiyor');
        return [];
      }

      final snapshot =
          await _customersCollection.where('isActive', isEqualTo: true).get();

      final customers = snapshot.docs
          .map((doc) => Customer.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
      
      // Sadece bugün giriş yapmış ve aktif olan müşterileri filtrele
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
      
      final activeCustomers = customers.where((customer) {
        // entryTime geçerli bir tarih
        
        // Sadece bugün giriş yapmış müşteriler
        if (customer.entryTime.isBefore(todayStart) || customer.entryTime.isAfter(todayEnd)) {
          return false;
        }
        
        // Kalan süresi var
        if (customer.remainingTime.inSeconds <= 0) return false;
        
        // Tamamlanmamış
        if (customer.isCompleted) return false;
        
        return true;
      }).toList();
      

      
      return activeCustomers;
    } catch (e) {
      print('Aktif müşterileri alırken hata: $e');
      return [];
    }
  }

  // Tamamlanmış müşterileri getir
  Future<List<Customer>> getCompletedCustomers({int limit = 50}) async {
    try {
      // Kullanıcının oturum açtığından emin ol
      if (_auth.currentUser == null) {
        print(
          'Tamamlanmış müşterileri getirmek için kimlik doğrulaması gerekiyor',
        );
        return [];
      }

      final snapshot =
          await _customersCollection
              .where('isActive', isEqualTo: false)
              .orderBy('exitTime', descending: true)
              .limit(limit)
              .get();

      return snapshot.docs
          .map((doc) => Customer.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Tamamlanmış müşterileri alırken hata: $e');
      return [];
    }
  }

  // Tasks koleksiyonu referansı
  CollectionReference<Map<String, dynamic>> get _tasksCollection =>
      _firestore.collection('tasks');

  // Issues koleksiyonu referansı
  CollectionReference<Map<String, dynamic>> get _issuesCollection =>
      _firestore.collection('issues');

  /// Tüm görevleri getir
  Future<List<Map<String, dynamic>>> getTasks() async {
    try {
      if (_isOfflineMode) {
        print('FIREBASE_SERVICE: Çevrimdışı modda görevler alınamadı');
        return [];
      }

      if (_auth.currentUser == null) {
        print('Görevleri almak için kimlik doğrulaması gerekiyor');
        return [];
      }

      final snapshot = await _tasksCollection
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();
    } catch (e) {
      print('Görevleri alırken hata: $e');
      return [];
    }
  }

  /// Belirli bir görevi getir
  Future<Map<String, dynamic>?> getTask(String taskId) async {
    try {
      if (_isOfflineMode) {
        print('FIREBASE_SERVICE: Çevrimdışı modda görev alınamadı');
        return null;
      }

      if (_auth.currentUser == null) {
        print('Görevi almak için kimlik doğrulaması gerekiyor');
        return null;
      }

      final doc = await _tasksCollection.doc(taskId).get();
      if (doc.exists) {
        return {...doc.data()!, 'id': doc.id};
      }
      return null;
    } catch (e) {
      print('Görevi alırken hata: $e');
      return null;
    }
  }

  /// Yeni görev ekle
  Future<void> addTask(Map<String, dynamic> taskData) async {
    try {
      if (_isOfflineMode) {
        print('FIREBASE_SERVICE: Çevrimdışı modda görev eklenemez');
        return;
      }

      if (_auth.currentUser == null) {
        print('Görev eklemek için kimlik doğrulaması gerekiyor');
        return;
      }

      await _tasksCollection.add(taskData);
      print('FIREBASE_SERVICE: Görev başarıyla eklendi');
    } catch (e) {
      print('FIREBASE_SERVICE: Görev eklenirken hata: $e');
      rethrow;
    }
  }

  /// Görevi güncelle
  Future<void> updateTask(String taskId, Map<String, dynamic> taskData) async {
    try {
      if (_isOfflineMode) {
        print('FIREBASE_SERVICE: Çevrimdışı modda görev güncellenemez');
        return;
      }

      if (_auth.currentUser == null) {
        print('Görevi güncellemek için kimlik doğrulaması gerekiyor');
        return;
      }

      await _tasksCollection.doc(taskId).update(taskData);
      print('FIREBASE_SERVICE: Görev başarıyla güncellendi');
    } catch (e) {
      print('FIREBASE_SERVICE: Görev güncellenirken hata: $e');
      rethrow;
    }
  }

  /// Görevi sil
  Future<void> deleteTask(String taskId) async {
    try {
      if (_isOfflineMode) {
        print('FIREBASE_SERVICE: Çevrimdışı modda görev silinemez');
        return;
      }

      if (_auth.currentUser == null) {
        print('Görevi silmek için kimlik doğrulaması gerekiyor');
        return;
      }

      await _tasksCollection.doc(taskId).delete();
      print('FIREBASE_SERVICE: Görev başarıyla silindi');
    } catch (e) {
      print('FIREBASE_SERVICE: Görev silinirken hata: $e');
      rethrow;
    }
  }

  // Bilet numaralarını sıfırla (debug için)
  Future<void> resetTicketNumbers() async {
    try {
      // Kullanıcının oturum açtığından emin ol
      if (_auth.currentUser == null) {
        print('Bilet numaralarını sıfırlamak için kimlik doğrulaması gerekiyor');
        return;
      }

      print('FIREBASE_SERVICE: Bilet numaraları sıfırlanıyor...');

      // Bugünün tarihini al
      final today = DateTime.now();
      final todayKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // settings/daily_tickets dökümanını tamamen sil ve yeniden oluştur
      final docRef = _settingsCollection.doc('daily_tickets');
      
      // Önce sil
      try {
        await docRef.delete();
        print('FIREBASE_SERVICE: Eski daily_tickets dökümanı silindi');
      } catch (e) {
        print('FIREBASE_SERVICE: Eski daily_tickets silinirken hata: $e');
      }
      
      // Sonra yeniden oluştur
      await docRef.set({
        'currentDate': todayKey,
        'lastTicketNumber': 100,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('FIREBASE_SERVICE: Bilet numaraları 100\'den başlatıldı');
    } catch (e) {
      print('FIREBASE_SERVICE: Bilet numaraları sıfırlanırken hata: $e');
    }
  }

  // Tüm müşteri verilerini sil
  Future<void> clearAllCustomers() async {
    try {
      // Kullanıcının oturum açtığından emin ol
      if (_auth.currentUser == null) {
        print('Müşteri verilerini silmek için kimlik doğrulaması gerekiyor');
        return;
      }

      print('FIREBASE_SERVICE: Tüm müşteri verileri siliniyor...');

      // Tüm müşteri dökümanlarını getir
      final snapshot = await _customersCollection.get();
      
      // Batch delete işlemi
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      
      // Batch'i uygula
      await batch.commit();

      // daily_tickets dökümanını da tamamen sil
      try {
        final dailyTicketsDoc = _settingsCollection.doc('daily_tickets');
        await dailyTicketsDoc.delete();
        print('FIREBASE_SERVICE: daily_tickets dökümanı silindi');
      } catch (e) {
        print('FIREBASE_SERVICE: daily_tickets silinirken hata: $e');
      }

      print('FIREBASE_SERVICE: ${snapshot.docs.length} müşteri verisi ve daily_tickets silindi');
    } catch (e) {
      print('FIREBASE_SERVICE: Müşteri verileri silinirken hata: $e');
    }
  }

  /// Tüm eksikleri getir
  Future<List<Map<String, dynamic>>> getIssues() async {
    try {
      if (_isOfflineMode) {
        print('FIREBASE_SERVICE: Çevrimdışı modda eksikler alınamadı');
        return [];
      }

      if (_auth.currentUser == null) {
        print('Eksikleri almak için kimlik doğrulaması gerekiyor');
        return [];
      }

      final snapshot = await _issuesCollection
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();
    } catch (e) {
      print('Eksikleri alırken hata: $e');
      return [];
    }
  }

  /// Belirli bir eksik getir
  Future<Map<String, dynamic>?> getIssue(String issueId) async {
    try {
      if (_isOfflineMode) {
        print('FIREBASE_SERVICE: Çevrimdışı modda eksik alınamadı');
        return null;
      }

      if (_auth.currentUser == null) {
        print('Eksik almak için kimlik doğrulaması gerekiyor');
        return null;
      }

      final doc = await _issuesCollection.doc(issueId).get();
      if (doc.exists) {
        return {...doc.data()!, 'id': doc.id};
      }
      return null;
    } catch (e) {
      print('Eksik alırken hata: $e');
      return null;
    }
  }

  /// Yeni eksik ekle
  Future<void> addIssue(Map<String, dynamic> issueData) async {
    try {
      if (_isOfflineMode) {
        print('FIREBASE_SERVICE: Çevrimdışı modda eksik eklenemez');
        return;
      }

      if (_auth.currentUser == null) {
        print('Eksik eklemek için kimlik doğrulaması gerekiyor');
        return;
      }

      await _issuesCollection.add(issueData);
      print('FIREBASE_SERVICE: Eksik başarıyla eklendi');
    } catch (e) {
      print('FIREBASE_SERVICE: Eksik eklenirken hata: $e');
      rethrow;
    }
  }

  /// Eksik güncelle
  Future<void> updateIssue(String issueId, Map<String, dynamic> issueData) async {
    try {
      if (_isOfflineMode) {
        print('FIREBASE_SERVICE: Çevrimdışı modda eksik güncellenemez');
        return;
      }

      if (_auth.currentUser == null) {
        print('Eksik güncellemek için kimlik doğrulaması gerekiyor');
        return;
      }

      await _issuesCollection.doc(issueId).update(issueData);
      print('FIREBASE_SERVICE: Eksik başarıyla güncellendi');
    } catch (e) {
      print('FIREBASE_SERVICE: Eksik güncellenirken hata: $e');
      rethrow;
    }
  }

  /// Eksik sil
  Future<void> deleteIssue(String issueId) async {
    try {
      if (_isOfflineMode) {
        print('FIREBASE_SERVICE: Çevrimdışı modda eksik silinemez');
        return;
      }

      if (_auth.currentUser == null) {
        print('Eksik silmek için kimlik doğrulaması gerekiyor');
        return;
      }

      await _issuesCollection.doc(issueId).delete();
      print('FIREBASE_SERVICE: Eksik başarıyla silindi');
    } catch (e) {
      print('FIREBASE_SERVICE: Eksik silinirken hata: $e');
      rethrow;
    }
  }
}
