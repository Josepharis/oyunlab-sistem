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
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _childNameController = TextEditingController();
  final _parentNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ticketNumberController = TextEditingController();

  int _selectedDuration = 60;
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

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
    _animationController.dispose();
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

        // Bildirim göster
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lütfen çocuk ve ebeveyn adını giriniz.'),
            backgroundColor: Colors.orange,
          ),
        );
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

        // Bildirim göster
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lütfen bir süre belirleyin.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Doğrudan yeni müşteri oluştur
      _createNewCustomer();
    } catch (e) {
      print('Kayıt sırasında hata: $e');

      setState(() {
        _isLoading = false;
      });

      // Hata mesajı göster
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kayıt sırasında bir hata oluştu'),
          backgroundColor: Colors.red,
        ),
      );
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
        price: _isUsingRemainingTime && _selectedDuration == 0 ? 0.0 : (_selectedDurationPrice?.price ?? 0.0),
        childCount: 1, // Yeni müşteri için 1 çocuk
        siblingIds: [], // Yeni müşteri için boş liste
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

      // Başarı mesajı göster
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Kayıt başarıyla eklendi. Bilet No: $ticketNumber',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      print('NEW_CUSTOMER_FORM: Kayıt tamamlandı, bilet numarası: $ticketNumber');
    } catch (e) {
      print('Müşteri kaydedilirken hata: $e');
      setState(() {
        _isLoading = false;
      });

      // Hata mesajı göster
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kayıt sırasında hata: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );

      rethrow;
    }
  }



  Future<void> _searchCustomerByPhone() async {
    // Telefon alanının boş olup olmadığını kontrol et
    final phoneText = _phoneController.text.trim();
    if (phoneText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen bir telefon numarası girin'),
          backgroundColor: Colors.orange,
        ),
      );
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
        final currentRemainingMinutes = currentRemainingSeconds ~/ 60;
        
        // Eğer currentRemainingSeconds > 0 ise müşterinin kalan süresi var
        if (currentRemainingSeconds > 0) {
          _isUsingRemainingTime = true;
          _selectedDuration = 0; // Varsayılan olarak sadece kalan süreyi kullan

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${latestCustomer.childName} için kalan süre: $currentRemainingMinutes dk',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          // Kalan süre yoksa, süre eklemeyi zorunlu yap
          _isUsingRemainingTime = false;
          if (_selectedDuration == 0) {
            _selectedDuration = 60; // Varsayılan süre
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${latestCustomer.childName} bilgileri dolduruldu. Süre eklemeniz gerekiyor.',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      });
    } catch (e) {
      print('Telefon araması sırasında hata: $e');
      print('Hata detayları: ${StackTrace.current}');

      if (!mounted) return;

      setState(() {
        _isSearchingPhone = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Arama sırasında hata oluştu: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Telefon numarasını standart formatta düzenler (sadece rakam)
  String _normalizePhoneNumber(String phone) {
    return phone.replaceAll(RegExp(r'[^0-9]'), '');
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [


                // Kişisel Bilgiler Kartı
                _buildPersonalInfoCard(),

                const SizedBox(height: 14),

                // Süre Seçimi Kartı
                _buildDurationCard(),

                const SizedBox(height: 12),

                // Ödenecek Tutar Bilgisi
                if (_selectedDurationPrice != null || (_isUsingRemainingTime && _selectedDuration == 0)) _buildPaymentInfoCard(),

                const SizedBox(height: 12),

                // Kaydet Butonu
                _buildSaveButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }



  Widget _buildPersonalInfoCard() {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white,
      surfaceTintColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
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
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Kişi Bilgileri',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                
                // Bilet Numarası
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
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
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '#${_ticketNumberController.text}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

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
            const SizedBox(height: 12),

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
            const SizedBox(height: 12),

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
                const SizedBox(width: 10),
                SizedBox(
                  height:
                      56, // Yan yana düzgün görünmesi için TextField yüksekliği
                  child: ElevatedButton(
                    onPressed:
                        _isSearchingPhone ? null : _searchCustomerByPhone,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isSearchingPhone
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(Icons.search, color: Colors.white),
                  ),
                ),
              ],
            ),

            // Müşteri durumu bildirimi
            if (!_isPhoneFound && _phoneController.text.isNotEmpty)
              Container(
                margin: EdgeInsets.only(top: 10),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange.shade800,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Yeni müşteri: Lütfen çocuk ve ebeveyn bilgilerini giriniz.',
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Kalan süre bilgisi gösterimi
            if (_isPhoneFound && _foundCustomer != null)
              Container(
                margin: EdgeInsets.only(top: 8),
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _foundCustomer!.remainingTime.inSeconds > 0
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
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
                          size: 16,
                        ),
                        SizedBox(width: 6),
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
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Süre kullanımı seçenekleri - Sadece kalan süresi varsa göster
                    if (_foundCustomer!.remainingTime.inSeconds > 0) ...[
                      SizedBox(height: 6),
                      Row(
                        children: [
                          _buildUsageOptionButton(
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
                          SizedBox(width: 4),
                          _buildUsageOptionButton(
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
                              });
                            },
                          ),
                        ],
                      ),
                    ],

                    // Kalan süre durumunu göster
                    if (_foundCustomer!.remainingTime.inSeconds > 0 &&
                        _isUsingRemainingTime)
                      Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _selectedDuration > 0
                                ? 'Toplam süre: ${((_selectedDuration * 60 + _foundCustomer!.remainingTime.inSeconds) ~/ 60)}:${((_selectedDuration * 60 + _foundCustomer!.remainingTime.inSeconds) % 60).toString().padLeft(2, '0')}'
                                : 'Sadece kalan süre kullanılacak: ${_foundCustomer!.remainingTime.inMinutes}:${(_foundCustomer!.remainingTime.inSeconds % 60).toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ),
                      ),

                    // Kalan süresi olmayan durumda uyarı mesajını daha belirgin yapalım
                    if (_foundCustomer!.remainingTime.inSeconds <= 0)
                      Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 14,
                                color: Colors.orange.shade800,
                              ),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Kalan süre bitmiş. Lütfen yeni süre ekleyin.',
                                  style: TextStyle(
                                    fontSize: 12,
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
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white,
      surfaceTintColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık ve Süre gösterimi
            Row(
              children: [
                // Başlık kısmı
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.timer_rounded,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Oyun Süresi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

                const Spacer(),

                // Süre gösterimi (sağ tarafta)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(14),
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
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'dk',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // İşletme Ayarlarından Gelen Süre Seçenekleri
            if (_availableDurations.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Mevcut Süre Seçenekleri',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _availableDurations.map((durationPrice) {
                  final isSelected = _selectedDurationPrice?.duration == durationPrice.duration;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDurationPrice = durationPrice;
                        _selectedDuration = durationPrice.duration;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primaryColor : Colors.white,
                        borderRadius: BorderRadius.circular(10),
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
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${durationPrice.duration} dk',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : AppTheme.primaryColor,
                            ),
                          ),
                          Text(
                            '${durationPrice.price.toStringAsFixed(2)} ₺',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isSelected ? Colors.white.withOpacity(0.8) : Colors.green.shade600,
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Henüz süre seçenekleri belirlenmemiş. Lütfen admin ile iletişime geçin.',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 13,
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



  Widget _buildPaymentInfoCard() {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.green.shade50,
      surfaceTintColor: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.payment_rounded,
                color: Colors.green.shade700,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ödenecek Tutar',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isUsingRemainingTime && _selectedDuration == 0 
                        ? '0.00 ₺' 
                        : '${_selectedDurationPrice?.price.toStringAsFixed(2) ?? '0.00'} ₺',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                  Text(
                    _isUsingRemainingTime && _selectedDuration == 0 
                        ? 'Kalan süre kullanılacak' 
                        : '${_selectedDurationPrice?.duration ?? 0} dakika için',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Text(
                'Ödeme',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _save,
        icon: _isLoading
            ? Container(
                width: 20,
                height: 20,
                padding: const EdgeInsets.all(2),
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.check_rounded, size: 22),
        label: Text(
          _isLoading ? 'Kaydediliyor...' : 'Kaydı Tamamla',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: AppTheme.primaryColor.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
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
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppTheme.primaryColor),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.shade400),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
      ),
      style: const TextStyle(fontSize: 16),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(8),
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
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
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
        description: 'Giriş Ücreti - ${customer.totalSeconds ~/ 60} dakika',
        date: DateTime.now(),
        customerPhone: customer.phoneNumber,
        customerEmail: null,
        items: ['Giriş Ücreti - ${customer.totalSeconds ~/ 60} dakika'],
        paymentMethod: 'Nakit',
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
        
        // Real-time stream otomatik güncelleniyor
      } else {
        print('❌ Giriş ücreti satış kaydı oluşturulamadı');
      }
    } catch (e) {
      print('Giriş ücreti satış kaydı oluşturulurken hata: $e');
    }
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
