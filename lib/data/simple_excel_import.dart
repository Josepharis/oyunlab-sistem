import 'dart:io';
import 'package:excel/excel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models/customer_model.dart';
import 'services/firebase_service.dart';

/// Basit Excel import sınıfı
class SimpleExcelImport {
  final FirebaseService _firebaseService;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  SimpleExcelImport()
      : _firebaseService = FirebaseService(),
        _firestore = FirebaseFirestore.instance,
        _auth = FirebaseAuth.instance;

  /// Excel dosyasını okuyup verileri döndür
  Future<List<Map<String, dynamic>>> readExcelData() async {
    try {
      print('📊 Excel dosyası okunuyor...');

      // Excel dosyasının yolu
      final filePath = '/Users/yusuf/Desktop/oyunlab sistem/oyunlab-sistem/lib/data/oyunlab-suresi-dolanlar-1757057395.xlsx';
      final file = File(filePath);

      if (!await file.exists()) {
        print('❌ Excel dosyası bulunamadı: $filePath');
        return [];
      }

      print('📁 Excel dosyası bulundu: $filePath');

      // Excel dosyasını oku
      final bytes = await file.readAsBytes();
      print('📄 Dosya boyutu: ${bytes.length} bytes');
      
      // Excel dosyası formatını kontrol et
      if (bytes.length < 4) {
        print('❌ Dosya çok küçük, geçerli Excel dosyası değil');
        return [];
      }
      
      // Excel dosyası imzasını kontrol et (XLSX: PK, XLS: D0CF11E0)
      final signature = bytes.take(4).toList();
      print('📋 Dosya imzası: ${signature.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
      
      // Excel dosyasını güvenli şekilde oku
      Excel? excel;
      try {
        excel = Excel.decodeBytes(bytes);
        print('📊 Excel tabloları: ${excel.tables.keys.length}');
      } catch (e) {
        print('❌ Excel paketi hatası: $e');
        print('❌ Hata detayı: ${e.toString()}');
        print('❌ Stack trace: ${StackTrace.current}');
        return [];
      }
      
      if (excel == null) {
        print('❌ Excel objesi null');
        return [];
      }
      
      // Excel objesi null değilse devam et
      if (excel.tables.isEmpty) {
        print('❌ Excel dosyasında tablo bulunamadı');
        return [];
      }

      // İlk sheet'i al
      if (excel.tables.isEmpty) {
        print('❌ Excel dosyasında sheet bulunamadı');
        return [];
      }
      
      String sheet;
      try {
        sheet = excel.tables.keys.first;
        print('📋 Sheet adı: $sheet');
      } catch (e) {
        print('❌ Sheet adı alınamadı: $e');
        return [];
      }
      
      dynamic table;
      try {
        table = excel.tables[sheet];
        if (table == null) {
          print('❌ Sheet verisi bulunamadı');
          return [];
        }
        print('📊 Sheet: $sheet, Satır sayısı: ${table.rows.length}');
      } catch (e) {
        print('❌ Table erişim hatası: $e');
        return [];
      }

      // Verileri parse et
      final List<Map<String, dynamic>> data = [];

      // İlk satır başlık olabilir, 2. satırdan başla
      for (int i = 1; i < table.rows.length; i++) {
        final row = table.rows[i];
        if (row == null || row.isEmpty) continue;

        // Satırdaki verileri al
        final childName = _getCellValue(row, 0)?.toString().trim();
        final phoneNumber = _getCellValue(row, 1)?.toString().trim();

        // Boş satırları atla
        if (childName == null || childName.isEmpty) continue;

        // Telefon numarası yoksa varsayılan değer
        final phone = phoneNumber?.isNotEmpty == true ? phoneNumber : '000-000-0000';

        data.add({
          'childName': childName,
          'phoneNumber': phone,
          'rowIndex': i + 1, // Excel satır numarası
        });

        print('👶 Satır ${i + 1}: $childName - $phone');
      }

      print('✅ ${data.length} satır veri okundu');
      return data;
    } catch (e) {
      print('❌ Excel dosyası okuma hatası: $e');
      return [];
    }
  }

  /// Hücre değerini güvenli şekilde al
  dynamic _getCellValue(List<Data?> row, int index) {
    if (index >= row.length) return null;
    final cell = row[index];
    if (cell == null) return null;
    return cell.value;
  }

  /// Verileri Firestore'a aktar
  Future<void> importToFirestore(List<Map<String, dynamic>> data) async {
    try {
      print('🔥 Firestore\'a veri aktarılıyor...');

      // Firebase'e giriş yap
      if (_auth.currentUser == null) {
        print('🔐 Firebase kimlik doğrulaması yapılıyor...');
        await _auth.signInAnonymously();
        print('✅ Anonim giriş yapıldı: ${_auth.currentUser?.uid}');
      }

      int successCount = 0;
      int errorCount = 0;

      for (final item in data) {
        try {
          // Müşteri verisini hazırla
          final customerData = _prepareCustomerData(item);

          // Firestore'a ekle
          await _firebaseService.addCustomer(customerData);
          successCount++;

          print('✅ ${item['childName']} başarıyla eklendi');
        } catch (e) {
          errorCount++;
          print('❌ ${item['childName']} eklenirken hata: $e');
        }

        // Rate limiting için kısa bekleme
        await Future.delayed(const Duration(milliseconds: 100));
      }

      print('📊 Import özeti:');
      print('   ✅ Başarılı: $successCount');
      print('   ❌ Hatalı: $errorCount');
      print('   📋 Toplam: ${data.length}');
    } catch (e) {
      print('❌ Firestore import hatası: $e');
      rethrow;
    }
  }

  /// Müşteri verisini hazırla
  Map<String, dynamic> _prepareCustomerData(Map<String, dynamic> item) {
    final now = DateTime.now();
    final childName = item['childName'] as String;
    final phoneNumber = item['phoneNumber'] as String;

    // Kalan süre 0 olacak (süre dolmuş müşteriler)
    const totalSeconds = 0; // Süre dolmuş
    const remainingMinutes = 0;
    const remainingSeconds = 0;
    const usedSeconds = 0;

    return {
      'childName': childName,
      'parentName': '', // Ebeveyn bilgisi boş
      'phoneNumber': phoneNumber,
      'entryTime': now.toIso8601String(),
      'ticketNumber': 0, // Bilet numarası 0 (süre dolmuş)
      'totalSeconds': totalSeconds,
      'usedSeconds': usedSeconds,
      'pausedSeconds': 0,
      'remainingMinutes': remainingMinutes,
      'remainingSeconds': remainingSeconds,
      'isPaused': false,
      'pauseStartTime': null,
      'isCompleted': true, // Süre dolmuş olduğu için tamamlanmış
      'completedTime': now.toIso8601String(),
      'exitTime': now.toIso8601String(),
      'price': 0.0,
      'childCount': 1,
      'siblingIds': [],
      'hasTimePurchase': false,
      'purchasedSeconds': 0,
      'isActive': false, // Süre dolmuş olduğu için aktif değil
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'importSource': 'excel_import',
      'importDate': now.toIso8601String(),
      'originalRowIndex': item['rowIndex'],
    };
  }

  /// Mevcut müşteri verilerini temizle
  Future<void> clearExistingCustomers() async {
    try {
      print('🗑️ Mevcut müşteri verileri temizleniyor...');
      await _firebaseService.clearAllCustomers();
      print('✅ Müşteri verileri temizlendi');
    } catch (e) {
      print('❌ Müşteri verileri temizlenirken hata: $e');
      rethrow;
    }
  }

}
