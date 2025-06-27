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

      print('FIREBASE_SERVICE: Son bilet numarası getiriliyor...');

      // settings/counters dökümanını getir veya oluştur
      final docRef = _settingsCollection.doc('counters');
      final doc = await docRef.get();

      if (!doc.exists) {
        // Döküman yoksa oluştur
        print(
          'FIREBASE_SERVICE: Bilet numarası dökumanı bulunamadı, oluşturuluyor...',
        );
        await docRef.set({
          'lastTicketNumber': 100,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return 100;
      }

      // Döküman varsa son bilet numarasını al
      final data = doc.data()!;
      final lastTicketNumber = data['lastTicketNumber'] as int? ?? 100;
      print('FIREBASE_SERVICE: Son bilet numarası: $lastTicketNumber');
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

      print('FIREBASE_SERVICE: Bilet numarası arttırılıyor...');

      // Transaction ile atomik arttırma işlemi yap
      final docRef = _settingsCollection.doc('counters');

      // Transaction başlat
      final newTicketNumber = await _firestore.runTransaction<int>((
        transaction,
      ) async {
        // Dökümanı oku
        final doc = await transaction.get(docRef);

        if (!doc.exists) {
          // Döküman yoksa oluştur
          transaction.set(docRef, {
            'lastTicketNumber': 101,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          return 101;
        }

        // Mevcut değeri al ve arttır
        final data = doc.data()!;
        final currentNumber = data['lastTicketNumber'] as int? ?? 100;
        final newNumber = currentNumber + 1;

        // Değeri güncelle
        transaction.update(docRef, {
          'lastTicketNumber': newNumber,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return newNumber;
      });

      print('FIREBASE_SERVICE: Yeni bilet numarası: $newTicketNumber');
      return newTicketNumber;
    } catch (e) {
      print('FIREBASE_SERVICE: Bilet numarası arttırılırken hata: $e');
      // Son bilet numarasını tekrar almayı dene
      try {
        final lastNumber = await getLastTicketNumber();
        return lastNumber + 1;
      } catch (_) {
        return 100; // Hata durumunda varsayılan değer
      }
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

      return _customersCollection
          .where('isActive', isEqualTo: true)
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs
                    .map(
                      (doc) => Customer.fromJson({...doc.data(), 'id': doc.id}),
                    )
                    .toList(),
          );
    } catch (e) {
      print('Aktif müşterileri dinlerken hata: $e');
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
      await _customersCollection.doc(id).update({
        'isActive': false,
        'exitTime': FieldValue.serverTimestamp(),
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

      return snapshot.docs
          .map((doc) => Customer.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
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
}
