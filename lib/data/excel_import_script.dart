import 'dart:io';
import 'package:excel/excel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'models/customer_model.dart';
import 'services/firebase_service.dart';

/// Excel dosyasından veri aktarım scripti
/// Bu script, Excel dosyasındaki çocuk isimlerini ve numaralarını okuyup
/// Firestore'a müşteri olarak kaydeder.
class ExcelImportScript {
  final FirebaseService _firebaseService;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Uuid _uuid;

  ExcelImportScript()
      : _firebaseService = FirebaseService(),
        _firestore = FirebaseFirestore.instance,
        _auth = FirebaseAuth.instance,
        _uuid = const Uuid();

  /// Excel dosyasını okuyup verileri Firestore'a aktar
  Future<void> importFromExcel() async {
    try {
      print('📊 Excel import scripti başlatılıyor...');

      // Firebase'e giriş yap
      await _ensureAuthenticated();

      // Excel dosyasını oku
      final excelData = await _readExcelFile();
      if (excelData.isEmpty) {
        print('❌ Excel dosyasında veri bulunamadı');
        return;
      }

      print('📋 ${excelData.length} satır veri bulundu');

      // Verileri Firestore'a aktar
      await _importToFirestore(excelData);

      print('✅ Excel import işlemi tamamlandı!');
    } catch (e) {
      print('❌ Excel import hatası: $e');
      rethrow;
    }
  }

  /// Firebase kimlik doğrulamasını sağla
  Future<void> _ensureAuthenticated() async {
    if (_auth.currentUser == null) {
      print('🔐 Firebase kimlik doğrulaması yapılıyor...');
      await _auth.signInAnonymously();
      print('✅ Anonim giriş yapıldı: ${_auth.currentUser?.uid}');
    }
  }

  /// Excel dosyasını oku
  Future<List<Map<String, dynamic>>> _readExcelFile() async {
    try {
      // Excel dosyasının yolu
      final filePath = '/Users/yusuf/Desktop/oyunlab sistem/oyunlab-sistem/lib/data/oyunlab-suresi-dolanlar-1757057395.xlsx';
      final file = File(filePath);

      if (!await file.exists()) {
        print('❌ Excel dosyası bulunamadı: $filePath');
        return [];
      }

      print('📁 Excel dosyası okunuyor: $filePath');

      // Excel dosyasını oku
      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);

      // İlk sheet'i al
      final sheet = excel.tables.keys.first;
      final table = excel.tables[sheet]!;

      print('📊 Sheet: $sheet, Satır sayısı: ${table.rows.length}');

      // Verileri parse et
      final List<Map<String, dynamic>> data = [];

      // İlk satır başlık olabilir, 2. satırdan başla
      for (int i = 1; i < table.rows.length; i++) {
        final row = table.rows[i];
        if (row.isEmpty) continue;

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
  Future<void> _importToFirestore(List<Map<String, dynamic>> data) async {
    try {
      print('🔥 Firestore\'a veri aktarılıyor...');

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

  /// Mevcut müşteri verilerini temizle (isteğe bağlı)
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

  /// Import işlemini test et (veri eklemeden sadece oku)
  Future<void> testImport() async {
    try {
      print('🧪 Test modu: Excel dosyası okunuyor...');
      
      final excelData = await _readExcelFile();
      if (excelData.isEmpty) {
        print('❌ Excel dosyasında veri bulunamadı');
        return;
      }

      print('📋 Test sonucu:');
      print('   📊 Toplam satır: ${excelData.length}');
      
      for (int i = 0; i < excelData.length && i < 5; i++) {
        final item = excelData[i];
        print('   👶 ${i + 1}. ${item['childName']} - ${item['phoneNumber']}');
      }
      
      if (excelData.length > 5) {
        print('   ... ve ${excelData.length - 5} satır daha');
      }
      
      print('✅ Test tamamlandı');
    } catch (e) {
      print('❌ Test hatası: $e');
    }
  }
}

/// Script'i çalıştırmak için main fonksiyonu
Future<void> main() async {
  final script = ExcelImportScript();
  
  try {
    // Önce test et
    await script.testImport();
    
    // Kullanıcı onayı al (gerçek import için)
    print('\n⚠️  Gerçek import işlemi yapılacak!');
    print('Bu işlem mevcut müşteri verilerini etkileyebilir.');
    print('Devam etmek için Enter tuşuna basın...');
    
    // Gerçek import işlemini başlat
    await script.importFromExcel();
    
  } catch (e) {
    print('❌ Script hatası: $e');
  }
}
