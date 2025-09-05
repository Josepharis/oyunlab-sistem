import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/add_existing_customers.dart';
import '../../data/add_zero_time_customers.dart';
import '../../data/continue_zero_time_customers.dart';

class AddExistingCustomersScreen extends StatefulWidget {
  const AddExistingCustomersScreen({Key? key}) : super(key: key);

  @override
  State<AddExistingCustomersScreen> createState() => _AddExistingCustomersScreenState();
}

class _AddExistingCustomersScreenState extends State<AddExistingCustomersScreen> {
  bool _isLoading = false;
  String _statusMessage = '';
  bool _isSuccess = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Mevcut Kullanıcıları Ekle'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Başlık ve Açıklama
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.people_alt_rounded,
                      size: 64,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Mevcut Kullanıcıları Ekle',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Önceki sistemden kullanıcıları yeni sisteme aktaracaksınız.\nÜç farklı seçenek var:\n• 130 kullanıcı (kalan süreli)\n• Tüm süreleri sıfır olanlar\n• Kaldığımız yerden devam et (2151. biletten sonra)\nBu kullanıcılar giriş yapmayacak, sadece veri kaydedilecek.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Kullanıcı Listesi
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.list_alt_rounded,
                          color: AppTheme.primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Eklenecek Kullanıcılar (130 kişi)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildCustomerList(),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Durum Mesajı
              if (_statusMessage.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isSuccess ? Colors.green.shade50 : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isSuccess ? Colors.green.shade200 : Colors.orange.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isSuccess ? Icons.check_circle : Icons.info,
                        color: _isSuccess ? Colors.green.shade700 : Colors.orange.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _statusMessage,
                          style: TextStyle(
                            color: _isSuccess ? Colors.green.shade700 : Colors.orange.shade700,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // Butonlar
              Column(
                children: [
                  // Ana buton - 130 kullanıcı
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _addAllCustomers,
                      icon: _isLoading ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ) : const Icon(Icons.upload_rounded),
                      label: Text(_isLoading ? 'Ekleniyor...' : '130 Kullanıcıyı Ekle'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // İkinci buton - Süreleri sıfır olanlar
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _addZeroTimeCustomers,
                      icon: _isLoading ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ) : const Icon(Icons.timer_off),
                      label: Text(_isLoading ? 'Ekleniyor...' : 'Süreleri Sıfır Olanları Ekle'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Üçüncü buton - Kaldığımız yerden devam et
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _continueFromWhereWeLeft,
                      icon: _isLoading ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ) : const Icon(Icons.play_arrow),
                      label: Text(_isLoading ? 'Ekleniyor...' : 'Kaldığımız Yerden Devam Et'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerList() {
    final customers = [
      // 1. Sayfa (1-10)
      {'name': 'Abdülhamid', 'phone': '05370645460', 'time': '46 dk'},
      {'name': 'Ada', 'phone': '05541156386', 'time': '10 dk'},
      {'name': 'Adabahar', 'phone': '05535833969', 'time': '46 dk'},
      {'name': 'Agah Kerim', 'phone': '05333721141', 'time': '27 dk'},
      {'name': 'Agâh ve farah', 'phone': '05362553503', 'time': '277 dk'},
      {'name': 'Ahmet-Hafsa', 'phone': '05413967989', 'time': '58 dk'},
      {'name': 'Akif-Asya', 'phone': '05345457478', 'time': '30 dk'},
      {'name': 'Almina', 'phone': '05078365929', 'time': '30 dk'},
      {'name': 'Alparslan', 'phone': '05052542055', 'time': '11 dk'},
      {'name': 'Alperen', 'phone': '05375129140', 'time': '11 dk'},
      
      // 2. Sayfa (11-20)
      {'name': 'Amine duru', 'phone': '05411572323', 'time': '4 dk'},
      {'name': 'Amine mihra', 'phone': '05458053132', 'time': '30 dk'},
      {'name': 'Amine ve feyza', 'phone': '05438627728', 'time': '21 dk'},
      {'name': 'Ardıç(özel)', 'phone': '05346551093', 'time': '17 dk'},
      {'name': 'Arel', 'phone': '05364173817', 'time': '82 dk'},
      {'name': 'Arya', 'phone': '05367139288', 'time': '16 dk'},
      {'name': 'Asel', 'phone': '05396271332', 'time': '3 dk'},
      {'name': 'Asel meva', 'phone': '05359750836', 'time': '134 dk'},
      {'name': 'Asil', 'phone': '05316346404', 'time': '439 dk'},
      {'name': 'aslaan', 'phone': '05079269948', 'time': '1 dk'},
      
      // 3. Sayfa (21-30)
      {'name': 'Asya', 'phone': '05050335351', 'time': '13 dk'},
      {'name': 'Asya-Aybars', 'phone': '05437217071', 'time': '362 dk'},
      {'name': 'Atay', 'phone': '05363957722', 'time': '393 dk'},
      {'name': 'Aybars', 'phone': '05531776262', 'time': '37 dk'},
      {'name': 'Aziz Yiğit', 'phone': '05372693212', 'time': '5 dk'},
      {'name': 'Açelya', 'phone': '05365935726', 'time': '1 dk'},
      {'name': 'Belinay ve kerem', 'phone': '05454269996', 'time': '8 dk'},
      {'name': 'Beril', 'phone': '05070570543', 'time': '21 dk'},
      {'name': 'Beril', 'phone': '05058841710', 'time': '11 dk'},
      {'name': 'Cihangir', 'phone': '05362982454', 'time': '0 dk'},
      
      // 4. Sayfa (31-40)
      {'name': 'Defne', 'phone': '05337954171', 'time': '0 dk'},
      {'name': 'Duha', 'phone': '05397252595', 'time': '17 dk'},
      {'name': 'Ecrin Lina', 'phone': '05073463397', 'time': '45 dk'},
      {'name': 'Elif', 'phone': '05326591024', 'time': '13 dk'},
      {'name': 'Elif', 'phone': '05372431522', 'time': '182 dk'},
      {'name': 'Elif ve amine', 'phone': '05317324004', 'time': '301 dk'},
      {'name': 'Elif-Mihra-Nehir-Irmak', 'phone': '05523262312', 'time': '7 dk'},
      {'name': 'Elif-Zeynep', 'phone': '05347358823', 'time': '25 dk'},
      {'name': 'elif-zümra', 'phone': '05337122553', 'time': '99 dk'},
      {'name': 'Eliz', 'phone': '05061695571', 'time': '50 dk'},
      
      // 5. Sayfa (41-50)
      {'name': 'Elizan', 'phone': '05305179042', 'time': '33 dk'},
      {'name': 'ELİF-AHMET', 'phone': '05079887444', 'time': '471 dk'},
      {'name': 'Elya', 'phone': '05395754145', 'time': '517 dk'},
      {'name': 'Emira', 'phone': '05412592323', 'time': '0 dk'},
      {'name': 'ertuğrul', 'phone': '05073687775', 'time': '431 dk'},
      {'name': 'Erva', 'phone': '05398965995', 'time': '8 dk'},
      {'name': 'Esil Ayaz', 'phone': '05370275511', 'time': '346 dk'},
      {'name': 'Esma', 'phone': '05452165890', 'time': '26 dk'},
      {'name': 'Eymen', 'phone': '05446801523', 'time': '41 dk'},
      {'name': 'Eymen efe', 'phone': '05435405123', 'time': '30 dk'},
      
      // 6. Sayfa (51-60)
      {'name': 'Gökalp', 'phone': '05388298033', 'time': '7 dk'},
      {'name': 'Göktuğ', 'phone': '05384601100', 'time': '6 dk'},
      {'name': 'Göktuğ', 'phone': '05446309900', 'time': '5 dk'},
      {'name': 'Gökçe ve almila', 'phone': '05052661912', 'time': '54 dk'},
      {'name': 'Gülce', 'phone': '05537962505', 'time': '16 dk'},
      {'name': 'Hamza zeynep', 'phone': '05076069106', 'time': '21 dk'},
      {'name': 'Hikmet asaf', 'phone': '05443711023', 'time': '2 dk'},
      {'name': 'hira-aras', 'phone': '05303113423', 'time': '10 dk'},
      {'name': 'Hüma', 'phone': '05076452467', 'time': '542 dk'},
      {'name': 'hürrem -sade', 'phone': '05448972904', 'time': '490 dk'},
      
      // 7. Sayfa (61-70)
      {'name': 'İbrahim', 'phone': '05431155009', 'time': '6 dk'},
      {'name': 'İkra', 'phone': '05353525206', 'time': '0 dk'},
      {'name': 'İnci', 'phone': '05384746542', 'time': '330 dk'},
      {'name': 'İnci', 'phone': '05073564939', 'time': '568 dk'},
      {'name': 'İpek', 'phone': '05459523433', 'time': '170 dk'},
      {'name': 'İpek liya', 'phone': '05388737666', 'time': '90 dk'},
      {'name': 'İsmail', 'phone': '05069983533', 'time': '18 dk'},
      {'name': 'İzgi', 'phone': '05535991620', 'time': '342 dk'},
      {'name': 'Kaan', 'phone': '05423673307', 'time': '14 dk'},
      {'name': 'Kemal', 'phone': '05539513621', 'time': '52 dk'},
      
      // 8. Sayfa (71-80)
      {'name': 'Kerem', 'phone': '05383158984', 'time': '17 dk'},
      {'name': 'Kerem', 'phone': '05318397460', 'time': '407 dk'},
      {'name': 'Kerem ali', 'phone': '05318289105', 'time': '27 dk'},
      {'name': 'Kerem ali', 'phone': '05536500277', 'time': '2 dk'},
      {'name': 'Lina', 'phone': '05300434434', 'time': '51 dk'},
      {'name': 'Liva', 'phone': '05370104261', 'time': '29 dk'},
      {'name': 'Mehmet selim', 'phone': '05304574401', 'time': '32 dk'},
      {'name': 'Melin', 'phone': '05535868026', 'time': '24 dk'},
      {'name': 'Meryem', 'phone': '05342775871', 'time': '8 dk'},
      {'name': 'Meryem', 'phone': '05373330667', 'time': '5 dk'},
      
      // 9. Sayfa (81-90)
      {'name': 'Mete', 'phone': '05301850371', 'time': '2 dk'},
      {'name': 'Mete', 'phone': '05369918229', 'time': '6 dk'},
      {'name': 'Mete', 'phone': '05306300531', 'time': '28 dk'},
      {'name': 'Mete', 'phone': '05369906940', 'time': '25 dk'},
      {'name': 'meva yıldız', 'phone': '05052923998', 'time': '3 dk'},
      {'name': 'Mihrimah', 'phone': '05302306474', 'time': '547 dk'},
      {'name': 'Mila', 'phone': '05349881105', 'time': '9 dk'},
      {'name': 'Mina ve asaf', 'phone': '05413673398', 'time': '425 dk'},
      {'name': 'Mira', 'phone': '05458940161', 'time': '8 dk'},
      {'name': 'Mislina-Metehan', 'phone': '05461092323', 'time': '25 dk'},
      
      // 10. Sayfa (91-100)
      {'name': 'Muhammed ali', 'phone': '05428203695', 'time': '418 dk'},
      {'name': 'Muhhamet Efe', 'phone': '05468998391', 'time': '12 dk'},
      {'name': 'Musab', 'phone': '05013191988', 'time': '570 dk'},
      {'name': 'Mustafa', 'phone': '05368828289', 'time': '3 dk'},
      {'name': 'Mustafa', 'phone': '05358601547', 'time': '55 dk'},
      {'name': 'Mustafa-Umay-Miray', 'phone': '05436338859', 'time': '441 dk'},
      {'name': 'Narin-Miran', 'phone': '05397194772', 'time': '3 dk'},
      {'name': 'nefes ve zeynep', 'phone': '05416172358', 'time': '280 dk'},
      {'name': 'Neva', 'phone': '05369900532', 'time': '26 dk'},
      {'name': 'Nevra ve ravza', 'phone': '05079329277', 'time': '17 dk'},
      
      // 11. Sayfa (101-110)
      {'name': 'Poyraz', 'phone': '05369160181', 'time': '4 dk'},
      {'name': 'Rüzgar', 'phone': '05423609580', 'time': '2 dk'},
      {'name': 'Salih', 'phone': '05379221042', 'time': '0 dk'},
      {'name': 'Sare', 'phone': '05364435340', 'time': '9 dk'},
      {'name': 'selin', 'phone': '05389579412', 'time': '573 dk'},
      {'name': 'Tuğba ve onur', 'phone': '05412183738', 'time': '1 dk'},
      {'name': 'Umay', 'phone': '05312025801', 'time': '60 dk'},
      {'name': 'Umay', 'phone': '05347374597', 'time': '503 dk'},
      {'name': 'Umut', 'phone': '05394307839', 'time': '47 dk'},
      {'name': 'Umut Emre', 'phone': '05367412438', 'time': '24 dk'},
      
      // 12. Sayfa (111-120)
      {'name': 'Yaren ve akin', 'phone': '05545714468', 'time': '248 dk'},
      {'name': 'Yigit alp', 'phone': '05345519930', 'time': '14 dk'},
      {'name': 'Yiğit ali', 'phone': '05520114777', 'time': '2 dk'},
      {'name': 'Yiğit efe', 'phone': '05435921006', 'time': '27 dk'},
      {'name': 'Yusuf eren', 'phone': '05393332076', 'time': '34 dk'},
      {'name': 'Zeynep lina', 'phone': '05365953183', 'time': '5 dk'},
      {'name': 'Zeynep sare', 'phone': '05423587772', 'time': '0 dk'},
      {'name': 'Zeynep ve muhamet', 'phone': '05455761071', 'time': '7 dk'},
      {'name': 'Zümra', 'phone': '05364706567', 'time': '459 dk'},
      {'name': 'Zümra', 'phone': '05534033021', 'time': '543 dk'},
      
      // 13. Sayfa (121-130)
      {'name': 'Ömer amir', 'phone': '05433050023', 'time': '2 dk'},
      {'name': 'Ömer Ecrin', 'phone': '05053210873', 'time': '89 dk'},
      {'name': 'Ömer ve erva', 'phone': '05396615892', 'time': '4 dk'},
      {'name': 'Ömer ve ömür', 'phone': '05335048407', 'time': '14 dk'},
      {'name': 'Ömür', 'phone': '05326128475', 'time': '22 dk'},
      {'name': 'Ömür', 'phone': '05310118582', 'time': '4 dk'},
      {'name': 'Öykü', 'phone': '05378210301', 'time': '3 dk'},
      {'name': 'Şimay sare', 'phone': '05331203523', 'time': '49 dk'},
      {'name': 'Şirin', 'phone': '05362131081', 'time': '1 dk'},
      {'name': 'Şule ve nil', 'phone': '05322855970', 'time': '37 dk'},
    ];

    return Column(
      children: [
        // Toplam sayı göstergesi
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people,
                color: AppTheme.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Toplam ${customers.length} kullanıcı eklenecek',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Kullanıcı listesi
        SizedBox(
          height: 400, // Sabit yükseklik
          child: ListView.builder(
            itemCount: customers.length,
            itemBuilder: (context, index) {
              final customer = customers[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    // Sıra numarası
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Kullanıcı bilgileri
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer['name']!,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            customer['phone']!,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Kalan süre
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        customer['time']!,
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }


  Future<void> _addAllCustomers() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });

    try {
      await AddExistingCustomers.addAll130Customers();
      
      if (!mounted) return;
      setState(() {
        _isSuccess = true;
        _statusMessage = 'Tüm kullanıcılar başarıyla eklendi! Ana sayfaya dönün ve kontrol edin.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSuccess = false;
        _statusMessage = 'Kullanıcılar eklenirken hata oluştu: $e';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addZeroTimeCustomers() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });

    try {
      await AddZeroTimeCustomers.addZeroTimeCustomers();
      
      if (!mounted) return;
      setState(() {
        _isSuccess = true;
        _statusMessage = 'Süreleri sıfır olan kullanıcılar başarıyla eklendi! Ana sayfaya dönün ve kontrol edin.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSuccess = false;
        _statusMessage = 'Süreleri sıfır olan kullanıcılar eklenirken hata oluştu: $e';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _continueFromWhereWeLeft() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });

    try {
      await ContinueZeroTimeCustomers.continueFromWhereWeLeft();
      
      if (!mounted) return;
      setState(() {
        _isSuccess = true;
        _statusMessage = 'Kaldığımız yerden devam edildi! Eksik kalan kullanıcılar eklendi.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSuccess = false;
        _statusMessage = 'Devam ederken hata oluştu: $e';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}
