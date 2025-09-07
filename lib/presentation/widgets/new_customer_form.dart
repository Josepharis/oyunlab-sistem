import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/customer_model.dart';
import '../../data/models/sale_record_model.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/services/sale_service.dart';
import '../../core/di/service_locator.dart';
import '../../data/models/business_settings_model.dart';
import '../../data/repositories/business_settings_repository.dart';

class NewCustomerForm extends StatefulWidget {
  final Function(Customer) onSave;
  final Customer? initialCustomer;
  final CustomerRepository? customerRepository;

  const NewCustomerForm({
    super.key,
    required this.onSave,
    this.initialCustomer,
    this.customerRepository,
  });

  @override
  State<NewCustomerForm> createState() => _NewCustomerFormState();
}

class _NewCustomerFormState extends State<NewCustomerForm>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _childNameController = TextEditingController();
  final _parentNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ticketNumberController = TextEditingController();

  int _selectedDuration = 60;
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _animation;
  late TabController _tabController;

  // Repository referansları
  late CustomerRepository _customerRepository;
  late BusinessSettingsRepository _businessSettingsRepository;
  final SaleService _saleService = SaleService();

  // İşletme ayarları
  // BusinessSettings? _oyunAlaniSettings;
  List<DurationPrice> _availableDurations = [];
  DurationPrice? _selectedDurationPrice;

  // Bilet numarası için değişken
  int _nextTicketNumber = 101; // Bir sonraki bilet numarası
  bool _ticketNumberAssigned = false; // Bilet numarası atandı mı?

  // Telefon ile arama durumları
  bool _isSearchingPhone = false;
  bool _isPhoneFound = false;
  Customer? _foundCustomer;
  bool _isUsingRemainingTime = false;

  // Diğerleri tab için değişkenler
  String? _selectedCategory;
  final _othersChildNameController = TextEditingController();
  final _othersParentNameController = TextEditingController();
  final _othersAmountController = TextEditingController();
  bool _isOthersLoading = false;

  // İndirim sistemi için değişkenler
  String? _selectedDiscountType;
  static const Map<String, double> _discountRates = {
    'Protokol': 0.15, // %15 indirim
    'Özel Çocuk': 1.0, // %100 indirim (ücretsiz)
    'Özel Gün': 0.0, // Şimdilik indirim yok
  };

  // Çocuk sayısı ve kardeş girişi için değişkenler
  int _childCount = 1;
  int _siblingCount = 0;

  // Ödeme yöntemi seçimi
  String _selectedPaymentMethod = 'Nakit';

  @override
  void initState() {
    super.initState();

    // Repository'leri al
    _customerRepository = widget.customerRepository ??
        ServiceLocator.locator<CustomerRepository>();
    _businessSettingsRepository = ServiceLocator.locator<BusinessSettingsRepository>();

    // İşletme ayarlarını yükle
    _loadBusinessSettings();

    // Bilet numarasını yükle - SON numarayı gösterme amaçlı
    _loadTempTicketNumber();

    if (widget.initialCustomer != null) {
      _childNameController.text = widget.initialCustomer!.childName;
      _parentNameController.text = widget.initialCustomer!.parentName;
      _phoneController.text = widget.initialCustomer!.phoneNumber;
      _selectedDuration = widget.initialCustomer!.durationMinutes;
      _ticketNumberController.text =
          widget.initialCustomer!.ticketNumber.toString();
      _ticketNumberAssigned = true; // Düzenleme modunda numara zaten atanmış
    } else {
      // Yeni kayıt için geçici olarak 101 göster (yüklenene kadar)
      _ticketNumberController.text = '101';
      _ticketNumberAssigned = false;
      _nextTicketNumber = 101; // Başlangıç değeri
    }

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _tabController = TabController(length: 2, vsync: this);

    _animationController.forward();
  }

  // İşletme ayarlarını yükle
  Future<void> _loadBusinessSettings() async {
    try {
      // Oyun Alanı kategorisindeki ayarları al
      final settings = await _businessSettingsRepository.getBusinessSettingByCategory(
        BusinessCategory.oyunAlani,
      );
      
      if (settings != null) {
        setState(() {
          // _oyunAlaniSettings = settings;
          _availableDurations = settings.durationPrices.where((dp) => dp.isActive).toList();
          
          // Varsayılan olarak ilk süreyi seç
          if (_availableDurations.isNotEmpty) {
            _selectedDurationPrice = _availableDurations.first;
            _selectedDuration = _selectedDurationPrice!.duration;
          }
        });
        
        print('Oyun alanı ayarları yüklendi: ${_availableDurations.length} seçenek');
      }
    } catch (e) {
      print('İşletme ayarları yüklenirken hata: $e');
    }
  }

  // Son bilet numarasından bir sonraki numarayı göster
  Future<void> _loadTempTicketNumber() async {
    try {
      // Son bilet numarasını al
      final lastNumber = await _customerRepository.getLastTicketNumber();
      print('NEW_CUSTOMER_FORM: Firebase\'den alınan son bilet numarası: $lastNumber');

      if (mounted) {
        setState(() {
          // Bir sonraki bilet numarasını hesapla ve göster
          _nextTicketNumber = lastNumber + 1;

          // Yeni kayıt formunda (düzenleme değilse) bir sonraki numarayı göster
          if (!_ticketNumberAssigned) {
            _ticketNumberController.text = _nextTicketNumber.toString();
            print('NEW_CUSTOMER_FORM: Bir sonraki bilet numarası gösteriliyor: $_nextTicketNumber');
          }
        });
      }
    } catch (e) {
      print('NEW_CUSTOMER_FORM: Bilet numarası yüklenirken hata: $e');
      // Hata durumunda varsayılan değer
      if (mounted) {
        setState(() {
          _nextTicketNumber = 101; // Varsayılan bir sonraki numara

          // Yeni kayıt formunda (düzenleme değilse) 101 göster
          if (!_ticketNumberAssigned) {
            _ticketNumberController.text = "101";
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _childNameController.dispose();
    _parentNameController.dispose();
    _phoneController.dispose();
    _ticketNumberController.dispose();
    _othersChildNameController.dispose();
    _othersParentNameController.dispose();
    _othersAmountController.dispose();
    _animationController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Çocuk ve ebeveyn adı zorunluluğunu kontrol et
      if (_childNameController.text.trim().isEmpty ||
          _parentNameController.text.trim().isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Süre kontrolü - Eğer kalan süresi sıfırsa ve süre eklemediyse kayıt yapmasın
      if (_isPhoneFound &&
          _foundCustomer != null &&
          _foundCustomer!.remainingTime.inSeconds <= 0 &&
          _selectedDuration <= 0) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Doğrudan yeni müşteri oluştur
      _createNewCustomer();
    } catch (e) {
      print('Kayıt sırasında hata: $e');

      setState(() {
        _isLoading = false;
      });
    }
  }

  // Yeni müşteri oluştur ve kaydet
  void _createNewCustomer() async {
    // YENİ SÜRE SİSTEMİ - Toplam süre hesaplama
    int totalSeconds = _selectedDuration * 60; // Dakikayı saniyeye çevir
    
    if (_isUsingRemainingTime && _foundCustomer != null) {
      if (_selectedDuration > 0) {
        // Kalan süreye ek süre ekle
        int remainingSecs = _foundCustomer!.currentRemainingSeconds;
        totalSeconds = (_selectedDuration * 60) + remainingSecs;
      } else {
        // Sadece kalan süreyi kullan
        totalSeconds = _foundCustomer!.currentRemainingSeconds;
      }
    }

    try {
      // Bilet numarasını belirle
      int ticketNumber;

      if (_ticketNumberAssigned && widget.initialCustomer != null) {
        // Düzenleme modunda, mevcut bilet numarasını kullan
        ticketNumber = widget.initialCustomer!.ticketNumber;
      } else {
        // Yeni kayıt yapılıyor, Firebase'de bilet numarasını arttır ve al
        ticketNumber = await _customerRepository.getNextTicketNumber();
        print('NEW_CUSTOMER_FORM: Firebase\'den yeni bilet numarası alındı: $ticketNumber');
        
        // Firebase'de bilet numarası arttırıldı, bir sonraki form açılışında güncel numara gösterilecek
        print('NEW_CUSTOMER_FORM: Firebase\'de bilet numarası arttırıldı');
      }

      // Yeni müşteri oluştur
      final customer = Customer(
        id: const Uuid().v4(), // Her zaman yeni bir ID oluşturuyoruz
        childName: _childNameController.text.trim(),
        parentName: _parentNameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        entryTime: DateTime.now(),
        ticketNumber: ticketNumber,
        totalSeconds: totalSeconds, // YENİ SİSTEM - Toplam süre saniye cinsinden
        usedSeconds: 0, // Yeni müşteri için 0
        pausedSeconds: 0, // Yeni müşteri için 0
        remainingMinutes: totalSeconds ~/ 60, // İlk statik kalan süre = toplam süre
        remainingSeconds: totalSeconds % 60, // İlk statik kalan süre saniye
        price: _calculateFinalPrice(),
        childCount: _childCount, // Kullanıcının seçtiği çocuk sayısı
        siblingIds: [], // Yeni müşteri için boş liste
        hasTimePurchase: !(_isUsingRemainingTime && _selectedDuration == 0), // Sadece kalan süre kullanılmıyorsa satın alma var
        purchasedSeconds: _isUsingRemainingTime && _selectedDuration == 0 ? 0 : (_selectedDuration * 60), // Bu girişte satın alınan süre
        paymentMethod: _selectedPaymentMethod, // Seçilen ödeme yöntemi
      );

      // Kaydet
      widget.onSave(customer);

      // Giriş ücreti satış kaydı oluştur (sadece yeni müşteri için ve ücret varsa)
      if (!_isUsingRemainingTime || _selectedDuration > 0) {
        await _createEntryFeeSaleRecord(customer);
      }

      // İşlem tamam
      setState(() {
        _isLoading = false;
      });


      print('NEW_CUSTOMER_FORM: Kayıt tamamlandı, bilet numarası: $ticketNumber');
    } catch (e) {
      print('Müşteri kaydedilirken hata: $e');
      setState(() {
        _isLoading = false;
      });

      rethrow;
    }
  }



  Future<void> _searchCustomerByPhone() async {
    // Telefon alanının boş olup olmadığını kontrol et
    final phoneText = _phoneController.text.trim();
    if (phoneText.isEmpty) {
      return;
    }

    // Çift tıklama engellemesi
    if (_isSearchingPhone) {
      return;
    }

    // Aramayı başlat
    setState(() {
      _isSearchingPhone = true;
    });

    try {
      print('Telefon araması başlatılıyor: $phoneText');

      // Tüm müşterileri al ve telefon numarasına göre filtrele
      final allCustomers = await _customerRepository.getAllCustomersHistory();
      print('Toplam ${allCustomers.length} müşteri veri tabanından alındı');

      if (!mounted) return;

      // Telefon numarasını yalnızca rakamları kullanarak karşılaştır
      final searchDigits = _normalizePhoneNumber(phoneText);
      final matchingCustomers = allCustomers.where((c) {
        final customerDigits = _normalizePhoneNumber(c.phoneNumber);
        return customerDigits.contains(searchDigits);
      }).toList();

      print(
        'Telefon filtreleme sonucu: ${matchingCustomers.length} eşleşme bulundu',
      );

      if (matchingCustomers.isEmpty) {
        setState(() {
          _isSearchingPhone = false;
          _isPhoneFound = false;
          _foundCustomer = null;
        });

        // Alert kaldırıldı - zaten ekranda form alanları var
        // _showNewCustomerNotification();
        return;
      }

      // Son müşteriyi al
      matchingCustomers.sort((a, b) => b.entryTime.compareTo(a.entryTime));
      final latestCustomer = matchingCustomers.first;
      print(
        'En son müşteri: ${latestCustomer.childName}, ${latestCustomer.entryTime}',
      );

      // Hata ayıklama için çıkış zamanı ve diğer verileri kontrol et
      print('Müşteri id: ${latestCustomer.id}');
      print('Süre dakika: ${latestCustomer.durationMinutes}');
      print('Bilet numarası: ${latestCustomer.ticketNumber}');
      print(
        'Çıkış zamanı hesaplama: ${latestCustomer.entryTime} + ${Duration(minutes: latestCustomer.durationMinutes)}',
      );
      print('Hesaplanan çıkış zamanı: ${latestCustomer.exitTime}');
      print('Duraklatılmış mı: ${latestCustomer.isPaused}');
      print('Duraklatma başlangıç zamanı: ${latestCustomer.pauseStartTime}');
      print('Duraklatılan toplam süre: ${latestCustomer.pausedSeconds} saniye');

      // Formu güncelle
      setState(() {
        _isSearchingPhone = false;
        _isPhoneFound = true;
        _foundCustomer = latestCustomer;

        _childNameController.text = latestCustomer.childName;
        _parentNameController.text = latestCustomer.parentName;

        // Bilet numarası form kaydedilene kadar değiştirme - artık aile bilgisi gösterme
        // _ticketNumberController.text = "Aile: ${latestCustomer.ticketNumber}";

        // Kalan süre kontrolü
        final remainingTime = latestCustomer.remainingTime;
        final remainingSeconds = remainingTime.inSeconds;
        final remainingMinutes = remainingTime.inMinutes;

        // Debug bilgileri yazdır
        print(
          'Bulunan müşteri kalan süre: $remainingMinutes dakika, $remainingSeconds saniye',
        );
        print('Müşteri giriş zamanı: ${latestCustomer.entryTime}');
        print('Müşteri çıkış zamanı: ${latestCustomer.exitTime}');
        print('Şu anki zaman: ${DateTime.now()}');
        print('RemainingTime objesi: $remainingTime');

        // YENİ SİSTEM - Kalan süre hesaplama
        final currentRemainingSeconds = latestCustomer.currentRemainingSeconds;
        
        // Eğer currentRemainingSeconds > 0 ise müşterinin kalan süresi var
        if (currentRemainingSeconds > 0) {
          _isUsingRemainingTime = true;
          _selectedDuration = 0; // Varsayılan olarak sadece kalan süreyi kullan
        } else {
          // Kalan süre yoksa, süre eklemeyi zorunlu yap
          _isUsingRemainingTime = false;
          if (_selectedDuration == 0) {
            _selectedDuration = 60; // Varsayılan süre
          }
        }
      });
    } catch (e) {
      print('Telefon araması sırasında hata: $e');
      print('Hata detayları: ${StackTrace.current}');

      if (!mounted) return;

      setState(() {
        _isSearchingPhone = false;
      });
    }
  }

  // Telefon numarasını standart formatta düzenler (sadece rakam)
  String _normalizePhoneNumber(String phone) {
    return phone.replaceAll(RegExp(r'[^0-9]'), '');
  }

  // İndirim tipine göre süre seçeneklerini filtrele
  List<DurationPrice> _getFilteredDurations() {
    if (_selectedDiscountType == 'Özel Çocuk') {
      // Özel Çocuk için sadece 1 saat (60 dakika) seçeneği
      return _availableDurations.where((dp) => dp.duration == 60).toList();
    }
    // Diğer durumlarda tüm seçenekleri göster
    return _availableDurations;
  }

  // İndirim hesaplaması ile final fiyatı hesapla
  double _calculateFinalPrice() {
    // Kalan süre kullanılıyorsa ve yeni süre eklenmiyorsa ücretsiz
    if (_isUsingRemainingTime && _selectedDuration == 0) {
      return 0.0;
    }
    
    // Seçilen süre fiyatı yoksa 0 döndür
    if (_selectedDurationPrice == null) {
      return 0.0;
    }
    
    // Temel fiyat
    double basePrice = _selectedDurationPrice!.price;
    
    // Kardeş indirimi sadece 60 dakika girişinde uygulanır
    bool isHourlyEntry = _selectedDuration == 60;
    
    double totalPrice;
    
    if (isHourlyEntry && _siblingCount > 0) {
      // 60 dakika girişinde kardeş indirimi: Normal fiyat - (kardeş sayısı × 50₺)
      totalPrice = (basePrice * _childCount) - (_siblingCount * 50.0);
      if (totalPrice < 0) totalPrice = 0; // Negatif fiyat olmasın
    } else {
      // Diğer durumlarda normal çarpım
      totalPrice = basePrice * _childCount;
    }
    
    // İndirim hesaplama
    final discountRate = _discountRates[_selectedDiscountType] ?? 0.0;
    final discountedPrice = totalPrice * (1 - discountRate);
    
    return discountedPrice;
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Column(
        children: [
          // Tab Bar - Minimal
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(8),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey.shade600,
              labelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding: const EdgeInsets.all(2),
              tabAlignment: TabAlignment.fill,
              tabs: const [
                Tab(text: 'Yeni Kayıt'),
                Tab(text: 'Diğerleri'),
              ],
            ),
          ),
          
          // Tab Bar View
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Yeni Kayıt Tab
                _buildNewCustomerTab(),
                
                // Diğerleri Tab
                _buildOthersTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }



  // Yeni Kayıt Tab İçeriği
  Widget _buildNewCustomerTab() {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isVerySmallScreen = screenHeight < 700;
    final isSmallScreen = screenHeight < 800;
    final isNarrowScreen = screenWidth < 400;
    
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isNarrowScreen ? screenWidth * 0.02 : screenWidth * 0.03,
        vertical: isVerySmallScreen ? 2.0 : 4.0,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kişisel Bilgiler Kartı
            _buildPersonalInfoCard(),

            SizedBox(height: isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8)),

            // Süre Seçimi Kartı
            _buildDurationCard(),

            SizedBox(height: isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8)),

            // Ödeme Yöntemi Seçimi
            if (_selectedDurationPrice != null || (_isUsingRemainingTime && _selectedDuration == 0)) _buildPaymentMethodCard(),

            SizedBox(height: isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8)),

            // Ödenecek Tutar Bilgisi
            if (_selectedDurationPrice != null || (_isUsingRemainingTime && _selectedDuration == 0)) _buildPaymentInfoCard(),

            SizedBox(height: isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8)),

            // Kaydet Butonu
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  // Diğerleri Tab İçeriği
  Widget _buildOthersTab() {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isVerySmallScreen = screenHeight < 600;
    final isSmallScreen = screenHeight < 700;
    final isNarrowScreen = screenWidth < 400;
    
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isNarrowScreen ? screenWidth * 0.02 : screenWidth * 0.03,
          vertical: isVerySmallScreen ? 4.0 : 8.0,
        ),
        child: Form(
          key: GlobalKey<FormState>(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Kategori Seçimi Kartı
              _buildCategorySelectionCard(),
              
              SizedBox(height: isVerySmallScreen ? 6 : (isSmallScreen ? 8 : MediaQuery.of(context).size.height * 0.01)),
              
              // Kişisel Bilgiler Kartı
              _buildOthersPersonalInfoCard(),
              
              SizedBox(height: isVerySmallScreen ? 6 : (isSmallScreen ? 8 : MediaQuery.of(context).size.height * 0.01)),
              
              // Tutar Bilgisi Kartı
              _buildOthersAmountCard(),
              
              SizedBox(height: isVerySmallScreen ? 4 : (isSmallScreen ? 6 : MediaQuery.of(context).size.height * 0.008)),
              
              // Kaydet Butonu
              _buildOthersSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  // Kategori Seçimi Kartı
  Widget _buildCategorySelectionCard() {
    final screenHeight = MediaQuery.of(context).size.height;
    final isVerySmallScreen = screenHeight < 600;
    final isSmallScreen = screenHeight < 700;
    
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isVerySmallScreen ? 8 : (isSmallScreen ? 12 : 16))),
      color: Colors.white,
      surfaceTintColor: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(isVerySmallScreen ? 8 : (isSmallScreen ? 10 : 12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8)),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(isVerySmallScreen ? 6 : (isSmallScreen ? 8 : 10)),
                  ),
                  child: Icon(
                    Icons.category_rounded,
                    color: AppTheme.primaryColor,
                    size: isVerySmallScreen ? 14 : (isSmallScreen ? 16 : 20),
                  ),
                ),
                SizedBox(width: isVerySmallScreen ? 6 : (isSmallScreen ? 8 : 10)),
                Text(
                  'Kategori Seçimi',
                  style: TextStyle(
                    fontSize: isVerySmallScreen ? 14 : (isSmallScreen ? 16 : 18), 
                    fontWeight: FontWeight.bold
                  ),
                ),
              ],
            ),
            SizedBox(height: isVerySmallScreen ? 8 : (isSmallScreen ? 12 : 16)),
            
            // Dropdown
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isVerySmallScreen ? 8 : (isSmallScreen ? 12 : 16), 
                vertical: isVerySmallScreen ? 1 : (isSmallScreen ? 2 : 4)
              ),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(isVerySmallScreen ? 8 : (isSmallScreen ? 12 : 16)),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  hint: Text(
                    'Kategori seçiniz',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: isVerySmallScreen ? 12 : (isSmallScreen ? 14 : 16),
                    ),
                  ),
                  isExpanded: true,
                  icon: Icon(
                    Icons.keyboard_arrow_down, 
                    color: AppTheme.primaryColor,
                    size: isVerySmallScreen ? 16 : (isSmallScreen ? 18 : 20),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'Oyun Grubu',
                      child: Text(
                        'Oyun Grubu',
                        style: TextStyle(fontSize: isVerySmallScreen ? 12 : (isSmallScreen ? 14 : 16)),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'Robotik + Kodlama',
                      child: Text(
                        'Robotik + Kodlama',
                        style: TextStyle(fontSize: isVerySmallScreen ? 12 : (isSmallScreen ? 14 : 16)),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'Workshop',
                      child: Text(
                        'Workshop',
                        style: TextStyle(fontSize: isVerySmallScreen ? 12 : (isSmallScreen ? 14 : 16)),
                      ),
                    ),
                  ],
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedCategory = newValue;
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Diğerleri Kişisel Bilgiler Kartı
  Widget _buildOthersPersonalInfoCard() {
    final screenHeight = MediaQuery.of(context).size.height;
    final isVerySmallScreen = screenHeight < 600;
    final isSmallScreen = screenHeight < 700;
    
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isVerySmallScreen ? 8 : (isSmallScreen ? 12 : 16))),
      color: Colors.white,
      surfaceTintColor: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(isVerySmallScreen ? 8 : (isSmallScreen ? 10 : 12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8)),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(isVerySmallScreen ? 6 : (isSmallScreen ? 8 : 10)),
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    color: AppTheme.primaryColor,
                    size: isVerySmallScreen ? 14 : (isSmallScreen ? 16 : 20),
                  ),
                ),
                SizedBox(width: isVerySmallScreen ? 6 : (isSmallScreen ? 8 : 10)),
                Text(
                  'Kişi Bilgileri',
                  style: TextStyle(
                    fontSize: isVerySmallScreen ? 14 : (isSmallScreen ? 16 : 18), 
                    fontWeight: FontWeight.bold
                  ),
                ),
              ],
            ),
            SizedBox(height: isVerySmallScreen ? 8 : (isSmallScreen ? 12 : 16)),

            // Form Alanları
            _buildInputField(
              controller: _othersChildNameController,
              label: 'Çocuk Adı',
              icon: Icons.child_care_rounded,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Çocuk adını giriniz';
                }
                return null;
              },
            ),
            SizedBox(height: isVerySmallScreen ? 6 : (isSmallScreen ? 8 : 12)),

            _buildInputField(
              controller: _othersParentNameController,
              label: 'Ebeveyn Adı',
              icon: Icons.person_outline,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Ebeveyn adını giriniz';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  // Diğerleri Tutar Kartı
  Widget _buildOthersAmountCard() {
    final screenHeight = MediaQuery.of(context).size.height;
    final isVerySmallScreen = screenHeight < 600;
    final isSmallScreen = screenHeight < 700;
    
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isVerySmallScreen ? 8 : (isSmallScreen ? 12 : 16))),
      color: Colors.green.shade50,
      surfaceTintColor: Colors.green.shade50,
      child: Padding(
        padding: EdgeInsets.all(isVerySmallScreen ? 8 : (isSmallScreen ? 10 : 12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8)),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(isVerySmallScreen ? 6 : (isSmallScreen ? 8 : 10)),
                  ),
                  child: Icon(
                    Icons.payment_rounded,
                    color: Colors.green.shade700,
                    size: isVerySmallScreen ? 14 : (isSmallScreen ? 16 : 20),
                  ),
                ),
                SizedBox(width: isVerySmallScreen ? 6 : (isSmallScreen ? 8 : 10)),
                Text(
                  'Tutar Bilgisi',
                  style: TextStyle(
                    fontSize: isVerySmallScreen ? 14 : (isSmallScreen ? 16 : 18),
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
            SizedBox(height: isVerySmallScreen ? 8 : (isSmallScreen ? 12 : 16)),

            // Tutar Girişi
            _buildInputField(
              controller: _othersAmountController,
              label: 'Tutar (₺)',
              icon: Icons.attach_money_rounded,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Tutar giriniz';
                }
                final amount = double.tryParse(value.replaceAll(',', '.'));
                if (amount == null || amount <= 0) {
                  return 'Geçerli bir tutar giriniz';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  // Diğerleri Kaydet Butonu
  Widget _buildOthersSaveButton() {
    final screenHeight = MediaQuery.of(context).size.height;
    final isVerySmallScreen = screenHeight < 600;
    final isSmallScreen = screenHeight < 700;
    
    return SizedBox(
      width: double.infinity,
      height: isVerySmallScreen ? 44 : (isSmallScreen ? 48 : 56),
      child: ElevatedButton.icon(
        onPressed: _isOthersLoading ? null : _saveOthers,
        icon: _isOthersLoading
            ? Container(
                width: isVerySmallScreen ? 16 : (isSmallScreen ? 18 : 20),
                height: isVerySmallScreen ? 16 : (isSmallScreen ? 18 : 20),
                padding: EdgeInsets.all(isVerySmallScreen ? 1 : (isSmallScreen ? 1.5 : 2)),
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Icon(Icons.check_rounded, size: isVerySmallScreen ? 18 : (isSmallScreen ? 20 : 22)),
        label: Text(
          _isOthersLoading ? 'Kaydediliyor...' : 'Kaydı Tamamla',
          style: TextStyle(
            fontSize: isVerySmallScreen ? 14 : (isSmallScreen ? 16 : 18), 
            fontWeight: FontWeight.bold
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: AppTheme.primaryColor.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isVerySmallScreen ? 10 : (isSmallScreen ? 12 : 16)),
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalInfoCard() {
    final screenHeight = MediaQuery.of(context).size.height;
    final isVerySmallScreen = screenHeight < 700;
    final isSmallScreen = screenHeight < 800;
    
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8))),
      color: Colors.white,
      surfaceTintColor: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8)),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(isVerySmallScreen ? 6 : (isSmallScreen ? 8 : 10)),
                      ),
                      child: Icon(
                        Icons.person_rounded,
                        color: AppTheme.primaryColor,
                        size: isVerySmallScreen ? 14 : (isSmallScreen ? 16 : 20),
                      ),
                    ),
                    SizedBox(width: isVerySmallScreen ? 6 : (isSmallScreen ? 8 : 10)),
                    Text(
                      'Kişi Bilgileri',
                      style: TextStyle(
                        fontSize: isVerySmallScreen ? 14 : (isSmallScreen ? 16 : 18), 
                        fontWeight: FontWeight.bold
                      ),
                    ),
                  ],
                ),
                
                // Bilet Numarası
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isVerySmallScreen ? 6 : (isSmallScreen ? 8 : 12), 
                    vertical: isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8)
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(isVerySmallScreen ? 6 : (isSmallScreen ? 8 : 12)),
                    border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.confirmation_number_rounded,
                        color: AppTheme.primaryColor,
                        size: isVerySmallScreen ? 12 : (isSmallScreen ? 14 : 16),
                      ),
                      SizedBox(width: isVerySmallScreen ? 3 : (isSmallScreen ? 4 : 6)),
                      Text(
                        '#${_ticketNumberController.text}',
                        style: TextStyle(
                          fontSize: isVerySmallScreen ? 10 : (isSmallScreen ? 12 : 14),
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: isVerySmallScreen ? 2 : (isSmallScreen ? 3 : 16)),

            // Form Alanları
            _buildInputField(
              controller: _childNameController,
              label: AppConstants.childNameLabel,
              icon: Icons.child_care_rounded,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return AppConstants.enterChildName;
                }
                return null;
              },
            ),
            SizedBox(height: isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8)),

            _buildInputField(
              controller: _parentNameController,
              label: AppConstants.parentNameLabel,
              icon: Icons.person_outline,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return AppConstants.enterParentName;
                }
                return null;
              },
            ),
            SizedBox(height: isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8)),

            // Telefon ve Arama Butonu
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildInputField(
                    controller: _phoneController,
                    label: AppConstants.phoneLabel,
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    hint: '05XX XXX XX XX',
                    inputFormatters: [PhoneTextInputFormatter()],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return AppConstants.enterPhoneNumber;
                      }
                      // En az 10 karakter olmalı (boşluklar hariç)
                      if (value.replaceAll(' ', '').length < 10) {
                        return 'Geçerli bir telefon numarası giriniz';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      // Telefon numarası değiştiğinde, önceki bulunan müşteriyi temizle
                      if (_isPhoneFound) {
                        setState(() {
                          _isPhoneFound = false;
                          _foundCustomer = null;
                          _isUsingRemainingTime = false;
                        });
                      }
                    },
                  ),
                ),
                SizedBox(width: isSmallScreen ? 8 : 10),
                SizedBox(
                  height: isSmallScreen ? 48 : 56, // Yan yana düzgün görünmesi için TextField yüksekliği
                  child: ElevatedButton(
                    onPressed:
                        _isSearchingPhone ? null : _searchCustomerByPhone,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
                      ),
                    ),
                    child: _isSearchingPhone
                        ? SizedBox(
                            width: isSmallScreen ? 18 : 20,
                            height: isSmallScreen ? 18 : 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            Icons.search, 
                            color: Colors.white,
                            size: isSmallScreen ? 18 : 20,
                          ),
                  ),
                ),
              ],
            ),

            SizedBox(height: isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8)),

            // Çocuk Sayısı ve Kardeş Girişi
            Row(
              children: [
                // Çocuk Sayısı
                Expanded(
                  child: _buildChildCountField(),
                ),
                SizedBox(width: isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8)),
                // Kardeş Girişi
                Expanded(
                  child: _buildSiblingCountField(),
                ),
              ],
            ),

            // Müşteri durumu bildirimi
            if (!_isPhoneFound && _phoneController.text.isNotEmpty)
              Container(
                margin: EdgeInsets.only(top: isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8)),
                padding: EdgeInsets.symmetric(
                  horizontal: isVerySmallScreen ? 8 : (isSmallScreen ? 10 : 12), 
                  vertical: isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8)
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8)),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange.shade800,
                      size: isVerySmallScreen ? 14 : (isSmallScreen ? 16 : 18),
                    ),
                    SizedBox(width: isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8)),
                    Expanded(
                      child: Text(
                        'Yeni müşteri: Lütfen çocuk ve ebeveyn bilgilerini giriniz.',
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontSize: isVerySmallScreen ? 10 : (isSmallScreen ? 11 : 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Kalan süre bilgisi gösterimi
            if (_isPhoneFound && _foundCustomer != null)
              Container(
                margin: EdgeInsets.only(top: isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8)),
                padding: EdgeInsets.symmetric(
                  horizontal: isVerySmallScreen ? 6 : (isSmallScreen ? 8 : 10), 
                  vertical: isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8)
                ),
                decoration: BoxDecoration(
                  color: _foundCustomer!.remainingTime.inSeconds > 0
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8)),
                  border: Border.all(
                    color: _foundCustomer!.remainingTime.inSeconds > 0
                        ? Colors.green.shade100
                        : Colors.orange.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _foundCustomer!.remainingTime.inSeconds > 0
                              ? Icons.access_time
                              : Icons.timer_off_outlined,
                          color: _foundCustomer!.remainingTime.inSeconds > 0
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                          size: isVerySmallScreen ? 12 : (isSmallScreen ? 14 : 16),
                        ),
                        SizedBox(width: isVerySmallScreen ? 3 : (isSmallScreen ? 4 : 6)),
                        Expanded(
                          child: Text(
                            _foundCustomer!.remainingTime.inSeconds > 0
                                ? 'Kalan süre: ${_foundCustomer!.remainingTime.inMinutes}:${(_foundCustomer!.remainingTime.inSeconds % 60).toString().padLeft(2, '0')}'
                                : 'Kalan süre: 00:00',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _foundCustomer!.remainingTime.inSeconds > 0
                                  ? Colors.green.shade700
                                  : Colors.orange.shade700,
                              fontSize: isVerySmallScreen ? 10 : (isSmallScreen ? 12 : 13),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Süre kullanımı seçenekleri - Sadece kalan süresi varsa göster
                    if (_foundCustomer!.remainingTime.inSeconds > 0) ...[
                      SizedBox(height: isVerySmallScreen ? 2 : (isSmallScreen ? 4 : 6)),
                      Row(
                        children: [
                          Expanded(
                            child: _buildUsageOptionButton(
                              label: 'Sadece Kalan Süre',
                              icon: Icons.timelapse,
                              isSelected:
                                  _isUsingRemainingTime && _selectedDuration == 0,
                              onTap: () {
                                setState(() {
                                  _isUsingRemainingTime = true;
                                  _selectedDuration = 0;
                                  _selectedDurationPrice = null; // Sadece kalan süre seçildiğinde fiyat null
                                });
                              },
                            ),
                          ),
                          SizedBox(width: isVerySmallScreen ? 2 : (isSmallScreen ? 4 : 6)),
                          Expanded(
                            child: _buildUsageOptionButton(
                              label: 'Kalan Süreye Ekle',
                              icon: Icons.add_circle_outline,
                              isSelected:
                                  _isUsingRemainingTime && _selectedDuration > 0,
                              onTap: () {
                                setState(() {
                                  _isUsingRemainingTime = true;
                                  // Eğer süre seçilmediyse varsayılan bir süre seç
                                  if (_selectedDuration == 0) {
                                    _selectedDuration = 60;
                                  }
                                  // Seçilen süreye göre fiyatı güncelle
                                  _selectedDurationPrice = _availableDurations.firstWhere(
                                    (dp) => dp.duration == _selectedDuration,
                                    orElse: () => _availableDurations.first,
                                  );
                                  // Süre değiştiğinde kardeş sayısını sıfırla (60 dakika değilse)
                                  if (_selectedDuration != 60) {
                                    _siblingCount = 0;
                                  }
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Kalan süre durumunu göster
                    if (_foundCustomer!.remainingTime.inSeconds > 0 &&
                        _isUsingRemainingTime)
                      Padding(
                        padding: EdgeInsets.only(top: isVerySmallScreen ? 2 : (isSmallScreen ? 4 : 6)),
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: isVerySmallScreen ? 6 : (isSmallScreen ? 8 : 10),
                            vertical: isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8),
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedDuration > 0
                                    ? 'Toplam süre: ${((_selectedDuration * 60 + _foundCustomer!.remainingTime.inSeconds) ~/ 60)}:${((_selectedDuration * 60 + _foundCustomer!.remainingTime.inSeconds) % 60).toString().padLeft(2, '0')}'
                                    : 'Sadece kalan süre kullanılacak: ${_foundCustomer!.remainingTime.inMinutes}:${(_foundCustomer!.remainingTime.inSeconds % 60).toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontSize: isVerySmallScreen ? 10 : (isSmallScreen ? 11 : 12),
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade800,
                                ),
                              ),
                              // Çocuk başına düşen süre bilgisi
                              if (_childCount > 1)
                                Text(
                                  'Çocuk başına: ${(_foundCustomer!.remainingTime.inSeconds ~/ _childCount) ~/ 60}:${((_foundCustomer!.remainingTime.inSeconds ~/ _childCount) % 60).toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    fontSize: isVerySmallScreen ? 9 : (isSmallScreen ? 10 : 11),
                                    color: Colors.green.shade700,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                    // Kalan süresi olmayan durumda uyarı mesajını daha belirgin yapalım
                    if (_foundCustomer!.remainingTime.inSeconds <= 0)
                      Padding(
                        padding: EdgeInsets.only(top: isVerySmallScreen ? 2 : (isSmallScreen ? 4 : 6)),
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: isVerySmallScreen ? 6 : (isSmallScreen ? 8 : 10),
                            vertical: isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8),
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: isVerySmallScreen ? 12 : (isSmallScreen ? 14 : 16),
                                color: Colors.orange.shade800,
                              ),
                              SizedBox(width: isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8)),
                              Expanded(
                                child: Text(
                                  'Kalan süre bitmiş. Lütfen yeni süre ekleyin.',
                                  style: TextStyle(
                                    fontSize: isVerySmallScreen ? 10 : (isSmallScreen ? 11 : 12),
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationCard() {
    final screenHeight = MediaQuery.of(context).size.height;
    final isVerySmallScreen = screenHeight < 700;
    final isSmallScreen = screenHeight < 800;
    
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8))),
      color: Colors.white,
      surfaceTintColor: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık ve Süre gösterimi
            Row(
              children: [
                // Başlık kısmı
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 10),
                  ),
                  child: Icon(
                    Icons.timer_rounded,
                    color: AppTheme.primaryColor,
                    size: isSmallScreen ? 16 : 20,
                  ),
                ),
                SizedBox(width: isSmallScreen ? 8 : 10),
                Text(
                  'Oyun Süresi',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 16 : 18, 
                    fontWeight: FontWeight.bold
                  ),
                ),

                const Spacer(),

                // İndirim Dropdown - Modern ve Responsive
                Container(
                  height: isSmallScreen ? 32 : 36,
                  constraints: BoxConstraints(
                    minWidth: isSmallScreen ? 80 : 100, 
                    maxWidth: isSmallScreen ? 100 : 120
                  ),
                  decoration: BoxDecoration(
                    gradient: _selectedDiscountType != null
                        ? LinearGradient(
                            colors: [
                              AppTheme.primaryColor.withOpacity(0.1),
                              AppTheme.primaryColor.withOpacity(0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: _selectedDiscountType == null ? Colors.grey.shade50 : null,
                    borderRadius: BorderRadius.circular(isSmallScreen ? 14 : 18),
                    border: Border.all(
                      color: _selectedDiscountType != null
                          ? AppTheme.primaryColor.withOpacity(0.3)
                          : Colors.grey.shade300,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _selectedDiscountType != null
                            ? AppTheme.primaryColor.withOpacity(0.1)
                            : Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(isSmallScreen ? 14 : 18),
                      onTap: () {
                        // Dropdown açma işlemi için setState
                        setState(() {});
                      },
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 8 : 12, 
                          vertical: isSmallScreen ? 6 : 8
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedDiscountType,
                            hint: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.local_offer_outlined,
                                  size: isSmallScreen ? 12 : 14,
                                  color: Colors.grey.shade600,
                                ),
                                SizedBox(width: isSmallScreen ? 3 : 4),
                                Text(
                                  'İndirim',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 10 : 11,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            selectedItemBuilder: (BuildContext context) {
                              return [
                                // İndirim Yok seçeneği
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade400,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'İndirim Yok',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                // Protokol seçeneği
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade500,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Protokol',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                // Özel Çocuk seçeneği
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade500,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Özel Çocuk',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                // Özel Gün seçeneği
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: Colors.purple.shade500,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Özel Gün',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ];
                            },
                            isExpanded: false,
                            icon: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: _selectedDiscountType != null
                                  ? AppTheme.primaryColor
                                  : Colors.grey.shade500,
                              size: isSmallScreen ? 14 : 16,
                            ),
                            style: TextStyle(
                              fontSize: isSmallScreen ? 10 : 11,
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                            dropdownColor: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            elevation: 8,
                            items: [
                              DropdownMenuItem(
                                value: null, // İndirim yok
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade400,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('İndirim Yok'),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'Protokol',
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade500,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('Protokol'),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'Özel Çocuk',
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade500,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('Özel Çocuk'),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'Özel Gün',
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: Colors.purple.shade500,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('Özel Gün'),
                                  ],
                                ),
                              ),
                            ],
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedDiscountType = newValue;
                                
                                if (newValue == null) {
                                  // İndirim Yok seçildi - indirimi kaldır
                                  _selectedDiscountType = null;
                                } else if (newValue == 'Özel Çocuk') {
                                  // Özel Çocuk seçildiyse sadece 1 saat seçeneğini göster
                                  _selectedDuration = 60; // 1 saat
                                  _selectedDurationPrice = _availableDurations.firstWhere(
                                    (dp) => dp.duration == 60,
                                    orElse: () => _availableDurations.first,
                                  );
                                } else {
                                  // Diğer indirim türleri için normal süre seçeneklerini göster
                                  if (_selectedDurationPrice == null && _availableDurations.isNotEmpty) {
                                    _selectedDurationPrice = _availableDurations.first;
                                    _selectedDuration = _selectedDurationPrice!.duration;
                                  }
                                }
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                SizedBox(width: isSmallScreen ? 6 : 8),

                // Süre gösterimi (sağ tarafta)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 10 : 14,
                    vertical: isSmallScreen ? 6 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 14),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$_selectedDuration',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 16 : 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: isSmallScreen ? 3 : 4),
                      Text(
                        'dk',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 12 : 14,
                          fontWeight: FontWeight.w400,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8)),

            // İşletme Ayarlarından Gelen Süre Seçenekleri
            if (_availableDurations.isNotEmpty) ...[
              Wrap(
                spacing: isVerySmallScreen ? 3 : (isSmallScreen ? 4 : 6),
                runSpacing: isVerySmallScreen ? 3 : (isSmallScreen ? 4 : 6),
                children: _getFilteredDurations().map((durationPrice) {
                  final isSelected = _selectedDurationPrice?.duration == durationPrice.duration;
                  final discountRate = _discountRates[_selectedDiscountType] ?? 0.0;
                  final discountedPrice = durationPrice.price * (1 - discountRate);
                  
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDurationPrice = durationPrice;
                        _selectedDuration = durationPrice.duration;
                        // Süre değiştiğinde kardeş sayısını sıfırla (60 dakika değilse)
                        if (durationPrice.duration != 60) {
                          _siblingCount = 0;
                        }
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8),
                        vertical: isVerySmallScreen ? 3 : (isSmallScreen ? 4 : 6),
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primaryColor : Colors.white,
                        borderRadius: BorderRadius.circular(isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8)),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryColor
                              : Colors.grey.shade300,
                          width: 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withOpacity(
                                    0.15,
                                  ),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${durationPrice.duration} dk',
                            style: TextStyle(
                              fontSize: isVerySmallScreen ? 9 : (isSmallScreen ? 10 : 11),
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : AppTheme.primaryColor,
                            ),
                          ),
                          Text(
                            discountedPrice == 0.0 
                                ? 'Ücretsiz'
                                : '${discountedPrice.toStringAsFixed(2)} ₺',
                            style: TextStyle(
                              fontSize: isVerySmallScreen ? 7 : (isSmallScreen ? 8 : 9),
                              fontWeight: FontWeight.w500,
                              color: isSelected 
                                  ? Colors.white.withOpacity(0.8) 
                                  : (discountedPrice == 0.0 ? Colors.green.shade600 : Colors.green.shade600),
                            ),
                          ),
                          // İndirim bilgisi göster
                          if (discountRate > 0 && discountedPrice > 0)
                            Text(
                              'İndirim: %${(discountRate * 100).toInt()}',
                              style: TextStyle(
                                fontSize: isVerySmallScreen ? 5 : (isSmallScreen ? 6 : 7),
                                fontWeight: FontWeight.w500,
                                color: isSelected 
                                    ? Colors.white.withOpacity(0.7) 
                                    : Colors.orange.shade600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ] else ...[
              // Eğer işletme ayarları yüklenmediyse bilgi mesajı
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 12 : 16, 
                  vertical: isSmallScreen ? 8 : 12
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange.shade700,
                      size: isSmallScreen ? 16 : 20,
                    ),
                    SizedBox(width: isSmallScreen ? 8 : 12),
                    Expanded(
                      child: Text(
                        'Henüz süre seçenekleri belirlenmemiş. Lütfen admin ile iletişime geçin.',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: isSmallScreen ? 11 : 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }



  // Ödeme Yöntemi Seçim Kartı
  Widget _buildPaymentMethodCard() {
    final screenHeight = MediaQuery.of(context).size.height;
    final isVerySmallScreen = screenHeight < 700;
    final isSmallScreen = screenHeight < 800;
    
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8))),
      color: Colors.white,
      surfaceTintColor: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8)),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8)),
                  ),
                  child: Icon(
                    Icons.payment_rounded,
                    color: AppTheme.primaryColor,
                    size: isVerySmallScreen ? 14 : (isSmallScreen ? 16 : 18),
                  ),
                ),
                SizedBox(width: isVerySmallScreen ? 6 : (isSmallScreen ? 8 : 10)),
                Text(
                  'Ödeme Yöntemi',
                  style: TextStyle(
                    fontSize: isVerySmallScreen ? 12 : (isSmallScreen ? 14 : 16), 
                    fontWeight: FontWeight.bold
                  ),
                ),
              ],
            ),
            SizedBox(height: isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8)),
            
            // Ödeme seçenekleri
            Row(
              children: [
                Expanded(
                  child: _buildPaymentMethodButton(
                    label: 'Nakit',
                    icon: Icons.money,
                    isSelected: _selectedPaymentMethod == 'Nakit',
                    onTap: () {
                      setState(() {
                        _selectedPaymentMethod = 'Nakit';
                      });
                    },
                  ),
                ),
                SizedBox(width: isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8)),
                Expanded(
                  child: _buildPaymentMethodButton(
                    label: 'Kart',
                    icon: Icons.credit_card,
                    isSelected: _selectedPaymentMethod == 'Kart',
                    onTap: () {
                      setState(() {
                        _selectedPaymentMethod = 'Kart';
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Ödeme yöntemi butonu
  Widget _buildPaymentMethodButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isVerySmallScreen = screenHeight < 700;
    final isSmallScreen = screenHeight < 800;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: isVerySmallScreen ? 24 : (isSmallScreen ? 28 : 32),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8)),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : AppTheme.primaryColor,
              size: isVerySmallScreen ? 10 : (isSmallScreen ? 12 : 14),
            ),
            SizedBox(width: isVerySmallScreen ? 2 : (isSmallScreen ? 4 : 6)),
            Text(
              label,
              style: TextStyle(
                fontSize: isVerySmallScreen ? 8 : (isSmallScreen ? 9 : 10),
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentInfoCard() {
    final screenHeight = MediaQuery.of(context).size.height;
    final isVerySmallScreen = screenHeight < 700;
    final isSmallScreen = screenHeight < 800;
    
    // Final fiyat hesaplama (çocuk sayısı ve kardeş indirimi dahil)
    final finalPrice = _calculateFinalPrice();
    final isFree = finalPrice == 0.0;
    
    // İndirim hesaplama
    final discountRate = _discountRates[_selectedDiscountType] ?? 0.0;
    
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8))),
      color: isFree ? Colors.blue.shade50 : Colors.green.shade50,
      surfaceTintColor: isFree ? Colors.blue.shade50 : Colors.green.shade50,
      child: Padding(
        padding: EdgeInsets.all(isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8)),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isVerySmallScreen ? 6 : (isSmallScreen ? 8 : 10)),
              decoration: BoxDecoration(
                color: isFree ? Colors.blue.shade100 : Colors.green.shade100,
                borderRadius: BorderRadius.circular(isVerySmallScreen ? 6 : (isSmallScreen ? 8 : 10)),
              ),
              child: Icon(
                isFree ? Icons.card_giftcard_rounded : Icons.payment_rounded,
                color: isFree ? Colors.blue.shade700 : Colors.green.shade700,
                size: isVerySmallScreen ? 16 : (isSmallScreen ? 18 : 20),
              ),
            ),
            SizedBox(width: isVerySmallScreen ? 8 : (isSmallScreen ? 10 : 12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isFree ? 'Ücretsiz' : 'Ödenecek Tutar',
                    style: TextStyle(
                      fontSize: isVerySmallScreen ? 10 : (isSmallScreen ? 11 : 12),
                      color: isFree ? Colors.blue.shade700 : Colors.green.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: isVerySmallScreen ? 2 : (isSmallScreen ? 3 : 4)),
                  Text(
                    _isUsingRemainingTime && _selectedDuration == 0 
                        ? '0.00 ₺' 
                        : isFree 
                            ? 'Ücretsiz'
                            : '${finalPrice.toStringAsFixed(2)} ₺',
                    style: TextStyle(
                      fontSize: isVerySmallScreen ? 14 : (isSmallScreen ? 16 : 18),
                      fontWeight: FontWeight.bold,
                      color: isFree ? Colors.blue.shade800 : Colors.green.shade800,
                    ),
                  ),
                  Text(
                    _isUsingRemainingTime && _selectedDuration == 0 
                        ? 'Kalan süre kullanılacak' 
                        : '${_selectedDurationPrice?.duration ?? 0} dakika için',
                    style: TextStyle(
                      fontSize: isVerySmallScreen ? 8 : (isSmallScreen ? 9 : 10),
                      color: isFree ? Colors.blue.shade600 : Colors.green.shade600,
                    ),
                  ),
                  // Çocuk sayısı ve kardeş bilgisi
                  if (_childCount > 1 || _siblingCount > 0)
                    Text(
                      '${_childCount} çocuk${_siblingCount > 0 ? ' (${_siblingCount} kardeş)' : ''}',
                      style: TextStyle(
                        fontSize: isVerySmallScreen ? 7 : (isSmallScreen ? 8 : 9),
                        color: isFree ? Colors.blue.shade600 : Colors.green.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  // İndirim bilgisi
                  if (discountRate > 0 && !isFree)
                    Text(
                      'İndirim: %${(discountRate * 100).toInt()} (${_selectedDiscountType})',
                      style: TextStyle(
                        fontSize: isVerySmallScreen ? 7 : (isSmallScreen ? 8 : 9),
                        color: Colors.orange.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    final screenHeight = MediaQuery.of(context).size.height;
    final isVerySmallScreen = screenHeight < 700;
    final isSmallScreen = screenHeight < 800;
    
    return SizedBox(
      width: double.infinity,
      height: isVerySmallScreen ? 40 : (isSmallScreen ? 44 : 48),
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _save,
        icon: _isLoading
            ? Container(
                width: isVerySmallScreen ? 16 : (isSmallScreen ? 18 : 20),
                height: isVerySmallScreen ? 16 : (isSmallScreen ? 18 : 20),
                padding: EdgeInsets.all(isVerySmallScreen ? 1 : (isSmallScreen ? 1.5 : 2)),
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Icon(Icons.check_rounded, size: isVerySmallScreen ? 16 : (isSmallScreen ? 18 : 20)),
        label: Text(
          _isLoading ? 'Kaydediliyor...' : 'Kaydı Tamamla',
          style: TextStyle(
            fontSize: isVerySmallScreen ? 12 : (isSmallScreen ? 14 : 16), 
            fontWeight: FontWeight.bold
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: AppTheme.primaryColor.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isVerySmallScreen ? 8 : (isSmallScreen ? 10 : 12)),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? hint,
    Function(String)? onChanged,
  }) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isVerySmallScreen = screenHeight < 700;
    final isSmallScreen = screenHeight < 800;
    
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(
          icon, 
          color: AppTheme.primaryColor,
          size: isVerySmallScreen ? 16 : (isSmallScreen ? 18 : 20),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isVerySmallScreen ? 8 : (isSmallScreen ? 10 : 12)),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isVerySmallScreen ? 8 : (isSmallScreen ? 10 : 12)),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isVerySmallScreen ? 8 : (isSmallScreen ? 10 : 12)),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isVerySmallScreen ? 8 : (isSmallScreen ? 10 : 12)),
          borderSide: BorderSide(color: Colors.red.shade400),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: isVerySmallScreen ? 12 : (isSmallScreen ? 14 : 16),
          vertical: isVerySmallScreen ? 8 : (isSmallScreen ? 10 : 12),
        ),
      ),
      style: TextStyle(fontSize: isVerySmallScreen ? 12 : (isSmallScreen ? 14 : 16)),
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textInputAction: TextInputAction.next,
      onChanged: onChanged,
    );
  }

  Widget _buildUsageOptionButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isVerySmallScreen = screenHeight < 600;
    final isSmallScreen = screenHeight < 700;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isVerySmallScreen ? 2 : (isSmallScreen ? 3 : 12), 
          vertical: isVerySmallScreen ? 2 : (isSmallScreen ? 3 : 8)
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8)),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : AppTheme.primaryColor,
              size: isVerySmallScreen ? 14 : (isSmallScreen ? 16 : 18),
            ),
            SizedBox(width: isVerySmallScreen ? 2 : (isSmallScreen ? 3 : 4)),
            Text(
              label,
              style: TextStyle(
                fontSize: isVerySmallScreen ? 9 : (isSmallScreen ? 11 : 13),
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }



  // Diğerleri tab kayıt fonksiyonu
  void _saveOthers() {
    if (_selectedCategory == null) {
      return;
    }

    if (_othersChildNameController.text.trim().isEmpty ||
        _othersParentNameController.text.trim().isEmpty) {
      return;
    }

    final amountText = _othersAmountController.text.trim();
    if (amountText.isEmpty) {
      return;
    }

    final amount = double.tryParse(amountText.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      return;
    }

    if (_isOthersLoading) return;

    setState(() {
      _isOthersLoading = true;
    });

    _createOthersSaleRecord();
  }

  // Diğerleri satış kaydı oluştur (sadece profil satışlarına ekle)
  Future<void> _createOthersSaleRecord() async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) return;

      final amount = double.parse(_othersAmountController.text.replaceAll(',', '.'));
      
      final saleRecord = SaleRecord(
        id: '', // Firestore otomatik oluşturacak
        userId: firebaseUser.uid,
        userName: firebaseUser.displayName ?? firebaseUser.email?.split('@')[0] ?? 'Kullanıcı',
        customerName: _othersChildNameController.text.trim(),
        amount: amount,
        description: '$_selectedCategory - ${_othersParentNameController.text.trim()}',
        date: DateTime.now(),
        customerPhone: '', // Diğerleri için telefon zorunlu değil
        customerEmail: null,
        items: ['$_selectedCategory - ${_othersParentNameController.text.trim()}'],
        paymentMethod: 'Nakit',
        status: 'Tamamlandı',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await _saleService.createSale(saleRecord);
      if (result != null) {
        // Kategori adını kaydet (form temizlenmeden önce)
        final categoryName = _selectedCategory!;
        final childName = _othersChildNameController.text.trim();
        
        print('✅ Diğerleri satış kaydı oluşturuldu: $childName');
        print('   - Kategori: $categoryName');
        print('   - Tutar: ${amount}₺');
        print('   - Ebeveyn: ${_othersParentNameController.text.trim()}');
        print('   - Satış ID: ${result.id}');
        
        // Formu temizle
        setState(() {
          _selectedCategory = null;
          _othersChildNameController.clear();
          _othersParentNameController.clear();
          _othersAmountController.clear();
          _isOthersLoading = false;
        });

      } else {
        print('❌ Diğerleri satış kaydı oluşturulamadı');
        setState(() {
          _isOthersLoading = false;
        });
      }
    } catch (e) {
      print('Diğerleri satış kaydı oluşturulurken hata: $e');
      setState(() {
        _isOthersLoading = false;
      });
    }
  }

  // Giriş ücreti satış kaydı oluştur
  Future<void> _createEntryFeeSaleRecord(Customer customer) async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) return;

      // Giriş ücreti tutarını al
      final double entryFee = customer.price;
      if (entryFee <= 0) return; // Ücret yoksa satış kaydı oluşturma

      final saleRecord = SaleRecord(
        id: '', // Firestore otomatik oluşturacak
        userId: firebaseUser.uid,
        userName: firebaseUser.displayName ?? firebaseUser.email?.split('@')[0] ?? 'Kullanıcı',
        customerName: customer.childName,
        amount: entryFee,
        description: _selectedDiscountType != null 
            ? 'Giriş Ücreti - ${customer.totalSeconds ~/ 60} dakika (${_selectedDiscountType})'
            : 'Giriş Ücreti - ${customer.totalSeconds ~/ 60} dakika',
        date: DateTime.now(),
        customerPhone: customer.phoneNumber,
        customerEmail: null,
        items: [_selectedDiscountType != null 
            ? 'Giriş Ücreti - ${customer.totalSeconds ~/ 60} dakika (${_selectedDiscountType})'
            : 'Giriş Ücreti - ${customer.totalSeconds ~/ 60} dakika'],
        paymentMethod: customer.paymentMethod, // Müşteriden gelen ödeme yöntemi
        status: 'Tamamlandı',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await _saleService.createSale(saleRecord);
      if (result != null) {
        print('✅ Giriş ücreti satış kaydı oluşturuldu: ${customer.childName}');
        print('   - Tutar: ${entryFee}₺');
        print('   - Süre: ${customer.totalSeconds ~/ 60} dakika');
        print('   - Satış ID: ${result.id}');
        print('   - User ID: ${firebaseUser.uid}');
        print('   - User Name: ${firebaseUser.displayName ?? firebaseUser.email?.split('@')[0] ?? 'Kullanıcı'}');
        
        // Real-time stream otomatik güncelleniyor
      } else {
        print('❌ Giriş ücreti satış kaydı oluşturulamadı');
      }
    } catch (e) {
      print('Giriş ücreti satış kaydı oluşturulurken hata: $e');
    }
  }

  // Çocuk sayısı alanı
  Widget _buildChildCountField() {
    final screenHeight = MediaQuery.of(context).size.height;
    final isVerySmallScreen = screenHeight < 700;
    final isSmallScreen = screenHeight < 800;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Çocuk Sayısı',
          style: TextStyle(
            fontSize: isVerySmallScreen ? 8 : (isSmallScreen ? 9 : 10),
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        SizedBox(height: 2),
        Container(
          height: isVerySmallScreen ? 24 : (isSmallScreen ? 28 : 32),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8)),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: _childCount > 1 ? () {
                  setState(() {
                    _childCount--;
                    if (_siblingCount >= _childCount) {
                      _siblingCount = _childCount - 1;
                    }
                  });
                } : null,
                child: Container(
                  width: isVerySmallScreen ? 20 : (isSmallScreen ? 24 : 28),
                  height: isVerySmallScreen ? 20 : (isSmallScreen ? 24 : 28),
                  decoration: BoxDecoration(
                    color: _childCount > 1 ? AppTheme.primaryColor.withOpacity(0.1) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(isVerySmallScreen ? 3 : (isSmallScreen ? 4 : 6)),
                  ),
                  child: Icon(
                    Icons.remove,
                    color: _childCount > 1 ? AppTheme.primaryColor : Colors.grey.shade400,
                    size: isVerySmallScreen ? 10 : (isSmallScreen ? 12 : 14),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  _childCount.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isVerySmallScreen ? 12 : (isSmallScreen ? 14 : 16),
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _childCount < 10 ? () {
                  setState(() {
                    _childCount++;
                  });
                } : null,
                child: Container(
                  width: isVerySmallScreen ? 20 : (isSmallScreen ? 24 : 28),
                  height: isVerySmallScreen ? 20 : (isSmallScreen ? 24 : 28),
                  decoration: BoxDecoration(
                    color: _childCount < 10 ? AppTheme.primaryColor.withOpacity(0.1) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(isVerySmallScreen ? 3 : (isSmallScreen ? 4 : 6)),
                  ),
                  child: Icon(
                    Icons.add,
                    color: _childCount < 10 ? AppTheme.primaryColor : Colors.grey.shade400,
                    size: isVerySmallScreen ? 10 : (isSmallScreen ? 12 : 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Kardeş girişi alanı
  Widget _buildSiblingCountField() {
    final screenHeight = MediaQuery.of(context).size.height;
    final isVerySmallScreen = screenHeight < 700;
    final isSmallScreen = screenHeight < 800;
    
    // Kardeş indirimi sadece 60 dakika girişinde geçerli
    bool isHourlyEntry = _selectedDuration == 60;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          isHourlyEntry ? 'Kardeş Girişi' : 'Kardeş Girişi (60dk)',
          style: TextStyle(
            fontSize: isVerySmallScreen ? 8 : (isSmallScreen ? 9 : 10),
            fontWeight: FontWeight.w600,
            color: isHourlyEntry ? Colors.grey.shade700 : Colors.grey.shade400,
          ),
        ),
        SizedBox(height: 2),
        Container(
          height: isVerySmallScreen ? 24 : (isSmallScreen ? 28 : 32),
          decoration: BoxDecoration(
            color: isHourlyEntry ? Colors.grey.shade50 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(isVerySmallScreen ? 4 : (isSmallScreen ? 6 : 8)),
            border: Border.all(
              color: isHourlyEntry ? Colors.grey.shade200 : Colors.grey.shade300,
            ),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: isHourlyEntry && _siblingCount > 0 ? () {
                  setState(() {
                    _siblingCount--;
                  });
                } : null,
                child: Container(
                  width: isVerySmallScreen ? 20 : (isSmallScreen ? 24 : 28),
                  height: isVerySmallScreen ? 20 : (isSmallScreen ? 24 : 28),
                  decoration: BoxDecoration(
                    color: isHourlyEntry && _siblingCount > 0 ? AppTheme.primaryColor.withOpacity(0.1) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(isVerySmallScreen ? 3 : (isSmallScreen ? 4 : 6)),
                  ),
                  child: Icon(
                    Icons.remove,
                    color: isHourlyEntry && _siblingCount > 0 ? AppTheme.primaryColor : Colors.grey.shade400,
                    size: isVerySmallScreen ? 10 : (isSmallScreen ? 12 : 14),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  _siblingCount.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isVerySmallScreen ? 12 : (isSmallScreen ? 14 : 16),
                    fontWeight: FontWeight.bold,
                    color: isHourlyEntry ? AppTheme.primaryColor : Colors.grey.shade400,
                  ),
                ),
              ),
              GestureDetector(
                onTap: isHourlyEntry && _siblingCount < _childCount - 1 ? () {
                  setState(() {
                    _siblingCount++;
                  });
                } : null,
                child: Container(
                  width: isVerySmallScreen ? 20 : (isSmallScreen ? 24 : 28),
                  height: isVerySmallScreen ? 20 : (isSmallScreen ? 24 : 28),
                  decoration: BoxDecoration(
                    color: isHourlyEntry && _siblingCount < _childCount - 1 ? AppTheme.primaryColor.withOpacity(0.1) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(isVerySmallScreen ? 3 : (isSmallScreen ? 4 : 6)),
                  ),
                  child: Icon(
                    Icons.add,
                    color: isHourlyEntry && _siblingCount < _childCount - 1 ? AppTheme.primaryColor : Colors.grey.shade400,
                    size: isVerySmallScreen ? 10 : (isSmallScreen ? 12 : 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Türkiye telefon numarası formatı için özel input formatter
/// 05XX XXX XX XX formatında gösterir
class PhoneTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Değer boşsa direkt döndür
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Sadece rakamları al
    String numbersOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    // 11 karakterden fazlasını kes (başında 0 ile birlikte)
    if (numbersOnly.length > 11) {
      numbersOnly = numbersOnly.substring(0, 11);
    }

    // Başında 0 yoksa ekle
    if (numbersOnly.isNotEmpty && !numbersOnly.startsWith('0')) {
      numbersOnly = '0$numbersOnly';
    }

    // Format: 05XX XXX XX XX
    StringBuffer formatted = StringBuffer();
    for (int i = 0; i < numbersOnly.length; i++) {
      // Boşluk eklenecek konumlar: 4, 7, 9
      if (i == 4 || i == 7 || i == 9) {
        formatted.write(' ');
      }
      formatted.write(numbersOnly[i]);
    }

    return TextEditingValue(
      text: formatted.toString(),
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
