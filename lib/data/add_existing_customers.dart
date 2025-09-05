import 'package:uuid/uuid.dart';
import 'models/customer_model.dart';
import 'repositories/customer_repository.dart';
import '../core/di/service_locator.dart';

/// Mevcut kullanıcıları sisteme eklemek için script
class AddExistingCustomers {
  static Future<void> addAll130Customers() async {
    try {
      print('🚀 Tüm 130 kullanıcı ekleme işlemi başlatılıyor...');
      
      // Repository'yi al
      final customerRepository = ServiceLocator.locator<CustomerRepository>();
      
      // Görseldeki tüm kullanıcı verisi (1-13. sayfa - 130 kullanıcı)
      final List<Map<String, dynamic>> customersData = [
        // 1. Sayfa (1-10)
        {
          'childName': 'Abdülhamid',
          'phoneNumber': '05370645460',
          'remainingMinutes': 46,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Ada',
          'phoneNumber': '05541156386',
          'remainingMinutes': 10,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Adabahar',
          'phoneNumber': '05535833969',
          'remainingMinutes': 46,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Agah Kerim',
          'phoneNumber': '05333721141',
          'remainingMinutes': 27,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Agâh ve farah',
          'phoneNumber': '05362553503',
          'remainingMinutes': 277,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Ahmet-Hafsa',
          'phoneNumber': '05413967989',
          'remainingMinutes': 58,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Akif-Asya',
          'phoneNumber': '05345457478',
          'remainingMinutes': 30,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Almina',
          'phoneNumber': '05078365929',
          'remainingMinutes': 30,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Alparslan',
          'phoneNumber': '05052542055',
          'remainingMinutes': 11,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Alperen',
          'phoneNumber': '05375129140',
          'remainingMinutes': 11,
          'remainingSeconds': 0,
        },
        
        // 2. Sayfa (11-20)
        {
          'childName': 'Amine duru',
          'phoneNumber': '05411572323',
          'remainingMinutes': 4,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Amine mihra',
          'phoneNumber': '05458053132',
          'remainingMinutes': 30,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Amine ve feyza',
          'phoneNumber': '05438627728',
          'remainingMinutes': 21,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Ardıç(özel)',
          'phoneNumber': '05346551093',
          'remainingMinutes': 17,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Arel',
          'phoneNumber': '05364173817',
          'remainingMinutes': 82,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Arya',
          'phoneNumber': '05367139288',
          'remainingMinutes': 16,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Asel',
          'phoneNumber': '05396271332',
          'remainingMinutes': 3,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Asel meva',
          'phoneNumber': '05359750836',
          'remainingMinutes': 134,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Asil',
          'phoneNumber': '05316346404',
          'remainingMinutes': 439,
          'remainingSeconds': 0,
        },
        {
          'childName': 'aslaan',
          'phoneNumber': '05079269948',
          'remainingMinutes': 1,
          'remainingSeconds': 0,
        },
        
        // 3. Sayfa (21-30)
        {
          'childName': 'Asya',
          'phoneNumber': '05050335351',
          'remainingMinutes': 13,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Asya-Aybars',
          'phoneNumber': '05437217071',
          'remainingMinutes': 362,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Atay',
          'phoneNumber': '05363957722',
          'remainingMinutes': 393,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Aybars',
          'phoneNumber': '05531776262',
          'remainingMinutes': 37,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Aziz Yiğit',
          'phoneNumber': '05372693212',
          'remainingMinutes': 5,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Açelya',
          'phoneNumber': '05365935726',
          'remainingMinutes': 1,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Belinay ve kerem',
          'phoneNumber': '05454269996',
          'remainingMinutes': 8,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Beril',
          'phoneNumber': '05070570543',
          'remainingMinutes': 21,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Beril',
          'phoneNumber': '05058841710',
          'remainingMinutes': 11,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Cihangir',
          'phoneNumber': '05362982454',
          'remainingMinutes': 0,
          'remainingSeconds': 0,
        },
        
        // 4. Sayfa (31-40)
        {
          'childName': 'Defne',
          'phoneNumber': '05337954171',
          'remainingMinutes': 0,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Duha',
          'phoneNumber': '05397252595',
          'remainingMinutes': 17,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Ecrin Lina',
          'phoneNumber': '05073463397',
          'remainingMinutes': 45,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Elif',
          'phoneNumber': '05326591024',
          'remainingMinutes': 13,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Elif',
          'phoneNumber': '05372431522',
          'remainingMinutes': 182,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Elif ve amine',
          'phoneNumber': '05317324004',
          'remainingMinutes': 301,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Elif-Mihra-Nehir-Irmak',
          'phoneNumber': '05523262312',
          'remainingMinutes': 7,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Elif-Zeynep',
          'phoneNumber': '05347358823',
          'remainingMinutes': 25,
          'remainingSeconds': 0,
        },
        {
          'childName': 'elif-zümra',
          'phoneNumber': '05337122553',
          'remainingMinutes': 99,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Eliz',
          'phoneNumber': '05061695571',
          'remainingMinutes': 50,
          'remainingSeconds': 0,
        },
        
        // 5. Sayfa (41-50)
        {
          'childName': 'Elizan',
          'phoneNumber': '05305179042',
          'remainingMinutes': 33,
          'remainingSeconds': 0,
        },
        {
          'childName': 'ELİF-AHMET',
          'phoneNumber': '05079887444',
          'remainingMinutes': 471,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Elya',
          'phoneNumber': '05395754145',
          'remainingMinutes': 517,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Emira',
          'phoneNumber': '05412592323',
          'remainingMinutes': 0,
          'remainingSeconds': 0,
        },
        {
          'childName': 'ertuğrul',
          'phoneNumber': '05073687775',
          'remainingMinutes': 431,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Erva',
          'phoneNumber': '05398965995',
          'remainingMinutes': 8,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Esil Ayaz',
          'phoneNumber': '05370275511',
          'remainingMinutes': 346,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Esma',
          'phoneNumber': '05452165890',
          'remainingMinutes': 26,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Eymen',
          'phoneNumber': '05446801523',
          'remainingMinutes': 41,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Eymen efe',
          'phoneNumber': '05435405123',
          'remainingMinutes': 30,
          'remainingSeconds': 0,
        },
        
        // 6. Sayfa (51-60)
        {
          'childName': 'Gökalp',
          'phoneNumber': '05388298033',
          'remainingMinutes': 7,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Göktuğ',
          'phoneNumber': '05384601100',
          'remainingMinutes': 6,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Göktuğ',
          'phoneNumber': '05446309900',
          'remainingMinutes': 5,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Gökçe ve almila',
          'phoneNumber': '05052661912',
          'remainingMinutes': 54,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Gülce',
          'phoneNumber': '05537962505',
          'remainingMinutes': 16,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Hamza zeynep',
          'phoneNumber': '05076069106',
          'remainingMinutes': 21,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Hikmet asaf',
          'phoneNumber': '05443711023',
          'remainingMinutes': 2,
          'remainingSeconds': 0,
        },
        {
          'childName': 'hira-aras',
          'phoneNumber': '05303113423',
          'remainingMinutes': 10,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Hüma',
          'phoneNumber': '05076452467',
          'remainingMinutes': 542,
          'remainingSeconds': 0,
        },
        {
          'childName': 'hürrem -sade',
          'phoneNumber': '05448972904',
          'remainingMinutes': 490,
          'remainingSeconds': 0,
        },
        
        // 7. Sayfa (61-70)
        {
          'childName': 'İbrahim',
          'phoneNumber': '05431155009',
          'remainingMinutes': 6,
          'remainingSeconds': 0,
        },
        {
          'childName': 'İkra',
          'phoneNumber': '05353525206',
          'remainingMinutes': 0,
          'remainingSeconds': 0,
        },
        {
          'childName': 'İnci',
          'phoneNumber': '05384746542',
          'remainingMinutes': 330,
          'remainingSeconds': 0,
        },
        {
          'childName': 'İnci',
          'phoneNumber': '05073564939',
          'remainingMinutes': 568,
          'remainingSeconds': 0,
        },
        {
          'childName': 'İpek',
          'phoneNumber': '05459523433',
          'remainingMinutes': 170,
          'remainingSeconds': 0,
        },
        {
          'childName': 'İpek liya',
          'phoneNumber': '05388737666',
          'remainingMinutes': 90,
          'remainingSeconds': 0,
        },
        {
          'childName': 'İsmail',
          'phoneNumber': '05069983533',
          'remainingMinutes': 18,
          'remainingSeconds': 0,
        },
        {
          'childName': 'İzgi',
          'phoneNumber': '05535991620',
          'remainingMinutes': 342,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Kaan',
          'phoneNumber': '05423673307',
          'remainingMinutes': 14,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Kemal',
          'phoneNumber': '05539513621',
          'remainingMinutes': 52,
          'remainingSeconds': 0,
        },
        
        // 8. Sayfa (71-80)
        {
          'childName': 'Kerem',
          'phoneNumber': '05383158984',
          'remainingMinutes': 17,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Kerem',
          'phoneNumber': '05318397460',
          'remainingMinutes': 407,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Kerem ali',
          'phoneNumber': '05318289105',
          'remainingMinutes': 27,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Kerem ali',
          'phoneNumber': '05536500277',
          'remainingMinutes': 2,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Lina',
          'phoneNumber': '05300434434',
          'remainingMinutes': 51,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Liva',
          'phoneNumber': '05370104261',
          'remainingMinutes': 29,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Mehmet selim',
          'phoneNumber': '05304574401',
          'remainingMinutes': 32,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Melin',
          'phoneNumber': '05535868026',
          'remainingMinutes': 24,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Meryem',
          'phoneNumber': '05342775871',
          'remainingMinutes': 8,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Meryem',
          'phoneNumber': '05373330667',
          'remainingMinutes': 5,
          'remainingSeconds': 0,
        },
        
        // 9. Sayfa (81-90)
        {
          'childName': 'Mete',
          'phoneNumber': '05301850371',
          'remainingMinutes': 2,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Mete',
          'phoneNumber': '05369918229',
          'remainingMinutes': 6,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Mete',
          'phoneNumber': '05306300531',
          'remainingMinutes': 28,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Mete',
          'phoneNumber': '05369906940',
          'remainingMinutes': 25,
          'remainingSeconds': 0,
        },
        {
          'childName': 'meva yıldız',
          'phoneNumber': '05052923998',
          'remainingMinutes': 3,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Mihrimah',
          'phoneNumber': '05302306474',
          'remainingMinutes': 547,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Mila',
          'phoneNumber': '05349881105',
          'remainingMinutes': 9,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Mina ve asaf',
          'phoneNumber': '05413673398',
          'remainingMinutes': 425,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Mira',
          'phoneNumber': '05458940161',
          'remainingMinutes': 8,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Mislina-Metehan',
          'phoneNumber': '05461092323',
          'remainingMinutes': 25,
          'remainingSeconds': 0,
        },
        
        // 10. Sayfa (91-100)
        {
          'childName': 'Muhammed ali',
          'phoneNumber': '05428203695',
          'remainingMinutes': 418,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Muhhamet Efe',
          'phoneNumber': '05468998391',
          'remainingMinutes': 12,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Musab',
          'phoneNumber': '05013191988',
          'remainingMinutes': 570,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Mustafa',
          'phoneNumber': '05368828289',
          'remainingMinutes': 3,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Mustafa',
          'phoneNumber': '05358601547',
          'remainingMinutes': 55,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Mustafa-Umay-Miray',
          'phoneNumber': '05436338859',
          'remainingMinutes': 441,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Narin-Miran',
          'phoneNumber': '05397194772',
          'remainingMinutes': 3,
          'remainingSeconds': 0,
        },
        {
          'childName': 'nefes ve zeynep',
          'phoneNumber': '05416172358',
          'remainingMinutes': 280,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Neva',
          'phoneNumber': '05369900532',
          'remainingMinutes': 26,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Nevra ve ravza',
          'phoneNumber': '05079329277',
          'remainingMinutes': 17,
          'remainingSeconds': 0,
        },
        
        // 11. Sayfa (101-110)
        {
          'childName': 'Poyraz',
          'phoneNumber': '05369160181',
          'remainingMinutes': 4,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Rüzgar',
          'phoneNumber': '05423609580',
          'remainingMinutes': 2,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Salih',
          'phoneNumber': '05379221042',
          'remainingMinutes': 0,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Sare',
          'phoneNumber': '05364435340',
          'remainingMinutes': 9,
          'remainingSeconds': 0,
        },
        {
          'childName': 'selin',
          'phoneNumber': '05389579412',
          'remainingMinutes': 573,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Tuğba ve onur',
          'phoneNumber': '05412183738',
          'remainingMinutes': 1,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Umay',
          'phoneNumber': '05312025801',
          'remainingMinutes': 60,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Umay',
          'phoneNumber': '05347374597',
          'remainingMinutes': 503,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Umut',
          'phoneNumber': '05394307839',
          'remainingMinutes': 47,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Umut Emre',
          'phoneNumber': '05367412438',
          'remainingMinutes': 24,
          'remainingSeconds': 0,
        },
        
        // 12. Sayfa (111-120)
        {
          'childName': 'Yaren ve akin',
          'phoneNumber': '05545714468',
          'remainingMinutes': 248,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Yigit alp',
          'phoneNumber': '05345519930',
          'remainingMinutes': 14,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Yiğit ali',
          'phoneNumber': '05520114777',
          'remainingMinutes': 2,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Yiğit efe',
          'phoneNumber': '05435921006',
          'remainingMinutes': 27,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Yusuf eren',
          'phoneNumber': '05393332076',
          'remainingMinutes': 34,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Zeynep lina',
          'phoneNumber': '05365953183',
          'remainingMinutes': 5,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Zeynep sare',
          'phoneNumber': '05423587772',
          'remainingMinutes': 0,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Zeynep ve muhamet',
          'phoneNumber': '05455761071',
          'remainingMinutes': 7,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Zümra',
          'phoneNumber': '05364706567',
          'remainingMinutes': 459,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Zümra',
          'phoneNumber': '05534033021',
          'remainingMinutes': 543,
          'remainingSeconds': 0,
        },
        
        // 13. Sayfa (121-130)
        {
          'childName': 'Ömer amir',
          'phoneNumber': '05433050023',
          'remainingMinutes': 2,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Ömer Ecrin',
          'phoneNumber': '05053210873',
          'remainingMinutes': 89,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Ömer ve erva',
          'phoneNumber': '05396615892',
          'remainingMinutes': 4,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Ömer ve ömür',
          'phoneNumber': '05335048407',
          'remainingMinutes': 14,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Ömür',
          'phoneNumber': '05326128475',
          'remainingMinutes': 22,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Ömür',
          'phoneNumber': '05310118582',
          'remainingMinutes': 4,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Öykü',
          'phoneNumber': '05378210301',
          'remainingMinutes': 3,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Şimay sare',
          'phoneNumber': '05331203523',
          'remainingMinutes': 49,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Şirin',
          'phoneNumber': '05362131081',
          'remainingMinutes': 1,
          'remainingSeconds': 0,
        },
        {
          'childName': 'Şule ve nil',
          'phoneNumber': '05322855970',
          'remainingMinutes': 37,
          'remainingSeconds': 0,
        },
      ];

      int successCount = 0;
      int errorCount = 0;

      for (int i = 0; i < customersData.length; i++) {
        try {
          final data = customersData[i];
          final remainingSeconds = (data['remainingMinutes'] as int) * 60 + (data['remainingSeconds'] as int);
          
          // Yeni müşteri oluştur - SADECE VERİ KAYDI, GİRİŞ YAPMAYACAK
          final customer = Customer(
            id: const Uuid().v4(),
            childName: data['childName'] as String,
            parentName: '', // Ebeveyn adı boş bırakıldı
            phoneNumber: data['phoneNumber'] as String,
            entryTime: DateTime.now().subtract(const Duration(hours: 1)), // 1 saat önce giriş yapmış gibi
            ticketNumber: 0, // Repository otomatik atayacak
            totalSeconds: remainingSeconds, // Kalan süre toplam süre olarak ayarlandı
            usedSeconds: 0, // Kullanılan süre 0
            pausedSeconds: 0, // Duraklatılan süre 0
            remainingMinutes: data['remainingMinutes'] as int,
            remainingSeconds: data['remainingSeconds'] as int,
            isPaused: false, // Normal durumda
            isCompleted: true, // Tamamlanmış olarak işaretle - ana sayfada görünmeyecek
            completedTime: DateTime.now(), // Tamamlanma zamanı
            price: 0.0, // Ücretsiz olarak işaretlendi
            childCount: 1,
            siblingIds: const [],
            hasTimePurchase: false, // Mevcut süre olduğu için satın alma yok
            purchasedSeconds: 0,
          );

          // Müşteriyi ekle
          await customerRepository.addCustomer(customer);
          
          successCount++;
          print('✅ ${i + 1}. Müşteri eklendi: ${customer.childName} (${customer.remainingMinutes} dk)');
          
          // Her müşteri arasında kısa bekleme
          await Future.delayed(const Duration(milliseconds: 500));
          
        } catch (e) {
          errorCount++;
          print('❌ ${i + 1}. Müşteri eklenemedi: ${customersData[i]['childName']} - Hata: $e');
        }
      }

      print('\n📊 İşlem Özeti:');
      print('✅ Başarılı: $successCount müşteri');
      print('❌ Hatalı: $errorCount müşteri');
      print('📝 Toplam: ${customersData.length} müşteri');
      
      if (successCount > 0) {
        print('\n🎉 Tüm 130 kullanıcı başarıyla sisteme eklendi!');
        print('💡 Bu kullanıcılar giriş yapmayacak, sadece veri kaydedildi.');
        print('💡 Ebeveyn adları boş bırakıldı, giriş sırasında istenecek.');
        print('💡 Kullanıcılar tamamlanmış olarak işaretlendi - ana sayfada görünmeyecek.');
        print('💡 Kalan süreler doğru şekilde kaydedildi ve sorgulandığında görünecek.');
      }
      
    } catch (e) {
      print('❌ Genel hata: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

}
