import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import '../core/di/service_locator.dart';
import '../data/models/customer_model.dart';
import '../data/repositories/customer_repository.dart';

class ContinueZeroTimeCustomers {
  static CustomerRepository get _customerRepository => ServiceLocator.locator<CustomerRepository>();
  static const Uuid _uuid = Uuid();

  static Future<void> continueFromWhereWeLeft() async {
    try {
      print('Kaldığımız yerden devam ediliyor...');
      print('CSV\'de 1924. satırdan (index 1923) başlanacak...');
      
      // CSV dosyasını oku
      final csvData = await _readCsvFileFromIndex(1923); // 1924. satırdan başla
      
      int addedCount = 0;
      int errorCount = 0;
      
      for (int i = 0; i < csvData.length; i++) {
        try {
          final data = csvData[i];
          final childName = data['childName']?.trim();
          final phoneNumber = data['phoneNumber']?.trim();
          
          if (childName == null || childName.isEmpty || 
              phoneNumber == null || phoneNumber.isEmpty) {
            print('Satır ${2021 + i}: Geçersiz veri - İsim veya telefon boş');
            errorCount++;
            continue;
          }
          
          // Müşteri oluştur - süre sıfır
          final customer = Customer(
            id: _uuid.v4(),
            childName: childName,
            parentName: '', // Boş bırakılacak
            phoneNumber: phoneNumber,
            totalSeconds: 0, // Süre sıfır
            remainingMinutes: 0,
            remainingSeconds: 0,
            isPaused: false,
            isCompleted: true, // Tamamlanmış olarak işaretle
            entryTime: DateTime.now().subtract(const Duration(hours: 1)),
            completedTime: DateTime.now(),
            price: 0.0,
            ticketNumber: 0, // Boş bırakılacak
          );
          
          await _customerRepository.addCustomer(customer);
          addedCount++;
          
          if (addedCount % 50 == 0) {
            print('$addedCount kullanıcı eklendi... (CSV satırı: ${1924 + i})');
          }
          
        } catch (e) {
          print('Satır ${1924 + i} hatası: $e');
          errorCount++;
        }
      }
      
      print('✅ Kaldığımız yerden devam edildi!');
      print('📊 Toplam eklenen: $addedCount');
      print('❌ Hata sayısı: $errorCount');
      print('📍 CSV\'deki son satır: ${1924 + csvData.length}');
      
    } catch (e) {
      print('❌ Hata: $e');
      rethrow;
    }
  }
  
  static Future<List<Map<String, String>>> _readCsvFileFromIndex(int startIndex) async {
    try {
      // Mevcut dizini kontrol et
      final currentDir = Directory.current.path;
      print('Mevcut dizin: $currentDir');
      
      // Farklı yolları dene
      final possiblePaths = [
        path.join(currentDir, 'lib', 'data', 'oyunlab-suresi-dolanlar-1757057395.csv'),
        path.join(currentDir, 'oyunlab-suresi-dolanlar-1757057395.csv'),
        '/Users/yusuf/Desktop/oyunlab sistem/oyunlab-sistem/lib/data/oyunlab-suresi-dolanlar-1757057395.csv',
      ];
      
      File? csvFile;
      
      for (final csvPath in possiblePaths) {
        print('Denenen yol: $csvPath');
        final file = File(csvPath);
        if (await file.exists()) {
          csvFile = file;
          print('✅ CSV dosyası bulundu: $csvPath');
          break;
        }
      }
      
      if (csvFile == null) {
        throw Exception('CSV dosyası hiçbir yolda bulunamadı. Denenen yollar: $possiblePaths');
      }
      
      return await _parseCsvFileFromIndex(csvFile, startIndex);
      
    } catch (e) {
      print('CSV dosyası okuma hatası: $e');
      rethrow;
    }
  }
  
  static Future<List<Map<String, String>>> _parseCsvFileFromIndex(File file, int startIndex) async {
    final lines = await file.readAsLines();
    final List<Map<String, String>> customers = [];
    
    print('CSV toplam satır sayısı: ${lines.length}');
    print('Başlangıç indeksi: $startIndex');
    print('İşlenecek satır sayısı: ${lines.length - startIndex - 2}'); // -2 çünkü başlık ve 2. satır
    
    // Belirtilen indeksten başla (startIndex + 2 çünkü başlık ve 2. satır var)
    for (int i = startIndex + 2; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      
      // Noktalı virgül ile ayır
      final parts = line.split(';');
      if (parts.length >= 2) {
        final childName = parts[0].trim();
        final phoneNumber = parts[1].trim();
        
        // Geçerli telefon numarası kontrolü
        if (phoneNumber.isNotEmpty && phoneNumber.length >= 10) {
          customers.add({
            'childName': childName,
            'phoneNumber': phoneNumber,
          });
        }
      }
    }
    
    print('CSV dosyasından ${customers.length} kullanıcı okundu (${startIndex + 2}. satırdan itibaren)');
    return customers;
  }
}
