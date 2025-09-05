import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import '../core/di/service_locator.dart';
import '../data/models/customer_model.dart';
import '../data/repositories/customer_repository.dart';

class AddZeroTimeCustomers {
  static CustomerRepository get _customerRepository => ServiceLocator.locator<CustomerRepository>();
  static const Uuid _uuid = Uuid();

  static Future<void> addZeroTimeCustomers() async {
    try {
      print('Süreleri sıfır olan kullanıcılar ekleniyor...');
      
      // CSV dosyasını oku
      final csvData = await _readCsvFile();
      
      int addedCount = 0;
      int errorCount = 0;
      
      for (int i = 0; i < csvData.length; i++) {
        try {
          final data = csvData[i];
          final childName = data['childName']?.trim();
          final phoneNumber = data['phoneNumber']?.trim();
          
          if (childName == null || childName.isEmpty || 
              phoneNumber == null || phoneNumber.isEmpty) {
            print('Satır ${i + 1}: Geçersiz veri - İsim veya telefon boş');
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
            print('$addedCount kullanıcı eklendi...');
          }
          
        } catch (e) {
          print('Satır ${i + 1} hatası: $e');
          errorCount++;
        }
      }
      
      print('✅ Süreleri sıfır olan kullanıcılar eklendi!');
      print('📊 Toplam eklenen: $addedCount');
      print('❌ Hata sayısı: $errorCount');
      
    } catch (e) {
      print('❌ Hata: $e');
      rethrow;
    }
  }
  
  static Future<List<Map<String, String>>> _readCsvFile() async {
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
      
      return await _parseCsvFile(csvFile);
      
    } catch (e) {
      print('CSV dosyası okuma hatası: $e');
      rethrow;
    }
  }
  
  static Future<List<Map<String, String>>> _parseCsvFile(File file) async {
    final lines = await file.readAsLines();
    final List<Map<String, String>> customers = [];
    
    // İlk satır başlık, 2. satırdan başla
    for (int i = 2; i < lines.length; i++) {
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
    
    print('CSV dosyasından ${customers.length} kullanıcı okundu');
    return customers;
  }
}
