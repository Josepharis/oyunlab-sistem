import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Firebase bağlantı ve izin sorunlarını test eden yardımcı sınıf
class FirebaseTestUtil {
  static Future<void> testFirestoreConnection() async {
    try {
      final firestore = FirebaseFirestore.instance;
      print('FirebaseTestUtil: Firestore bağlantısı başlatıldı');

      // Firestore bağlantı testi
      try {
        final testResult = await firestore.collection('_test').limit(1).get();
        print(
            'FirebaseTestUtil: Firestore erişimi başarılı: ${testResult.docs.length} döküman bulundu');
      } catch (e) {
        print('FirebaseTestUtil: Firestore erişim hatası: $e');

        if (e is FirebaseException) {
          print(
              'FirebaseTestUtil: FirebaseException kodu: ${e.code}, mesajı: ${e.message}');

          if (e.code == 'permission-denied') {
            print('''
----------------------------------------------------------------------
FirebaseTestUtil: İZİN HATASI - GÜVENLİK KURALLARI

Firestore'a erişim için gerekli izinlere sahip değilsiniz.
Firebase Console'dan güvenlik kurallarınızı şuna benzar şekilde güncelleyin:

rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true;  // Test için, canlıya almadan önce düzenleyin!
    }
    
    // Veya daha güvenli bir yaklaşım:
    match /menu_items/{menuItem} {
      allow read, write: if true;
    }
  }
}
----------------------------------------------------------------------
            ''');
          }
        }
      }

      // Menü koleksiyonu testi
      try {
        final menuResult =
            await firestore.collection('menu_items').limit(1).get();
        print(
            'FirebaseTestUtil: menu_items koleksiyonu erişimi başarılı: ${menuResult.docs.length} döküman bulundu');

        // Test verisi ekleme
        try {
          final testDoc = await firestore.collection('menu_items').add({
            'name': 'Test Ürünü',
            'price': 0.0,
            'category': 'other',
            'createdAt': FieldValue.serverTimestamp(),
          });

          print(
              'FirebaseTestUtil: Test verisi başarıyla eklendi. ID: ${testDoc.id}');

          // Test verisini sil
          await testDoc.delete();
          print('FirebaseTestUtil: Test verisi başarıyla silindi');
        } catch (e) {
          print('FirebaseTestUtil: Test verisi yazma/silme hatası: $e');
        }
      } catch (e) {
        print('FirebaseTestUtil: menu_items koleksiyonu erişim hatası: $e');
      }
    } catch (e) {
      print('FirebaseTestUtil: Genel Firestore hatası: $e');
    }
  }
}
