import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/admin_auth_service.dart';
import '../../data/services/shift_service.dart';
import '../../data/services/sale_service.dart';
import '../../data/models/admin_user_model.dart';
import '../../data/models/shift_record_model.dart';
import '../../data/models/sale_record_model.dart';
import 'dart:async';


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Servisler
  late ShiftService _shiftService;
  late SaleService _saleService;

  // Mesai bilgileri
  bool _isShiftActive = false;
  DateTime? _shiftStartTime;
  Duration _currentShiftDuration = Duration.zero;
  List<ShiftRecord> _shiftHistory = [];
  Timer? _shiftTimer;
  ShiftRecord? _activeShift;
  
  // Satış geçmişi real-time stream
  StreamSubscription<List<SaleRecord>>? _salesStreamSubscription;

  // Satış verileri
  List<SaleRecord> _salesHistory = [];

  // Admin kullanıcı bilgileri
  String _staffName = "Yusuf Admin";
  String _staffPosition = "Sistem Yöneticisi";
  String _staffId = "ADMIN-001";
  AdminUser? _currentUser;

  // Yükleme durumu
  bool _isLoading = true;
  bool _isLoadingShifts = false;
  bool _isLoadingSales = false;

  // Tarih filtreleri
  DateTime _shiftStartDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _shiftEndDate = DateTime.now();
  DateTime _salesStartDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _salesEndDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Servisleri başlat
    _shiftService = ShiftService();
    _saleService = SaleService();

    // AdminAuthService değişikliklerini dinle
    final adminAuthService = Provider.of<AdminAuthService>(context, listen: false);
    adminAuthService.addListener(_onAuthStateChanged);

    // Kullanıcı bilgilerini güncelle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateUserInfo();
    });
    
    // Real-time satış stream'ini başlat
    _startSalesStream();
  }

  // Auth state değişikliklerini dinle
  void _onAuthStateChanged() {
    if (mounted) {
      _updateUserInfo();
    }
  }

  // Kullanıcı bilgilerini güncelle ve verileri yükle
  void _updateUserInfo() async {
    // Firebase Auth'dan kullanıcı bilgilerini al
    final firebaseUser = FirebaseAuth.instance.currentUser;
    print('Firebase Auth current user: $firebaseUser');
    
    if (firebaseUser != null) {
      // Admin kullanıcı kontrolü
      final adminAuthService = Provider.of<AdminAuthService>(context, listen: false);
      final adminUser = adminAuthService.currentUser;
      
      if (adminUser != null) {
        // Admin kullanıcı - Firebase Auth UID'sini kullan (satış kayıtları için)
        setState(() {
          _currentUser = adminUser;
          _staffName = adminUser.name;
          _staffPosition = adminAuthService.userRoleString;
          _staffId = firebaseUser.uid; // DÜZELTME: Firebase Auth UID kullan
        });

        print('Admin kullanıcı bilgileri güncellendi:');
        print('Name: $_staffName');
        print('Position: $_staffPosition');
        print('Admin ID: ${adminUser.id}');
        print('Firebase UID (Staff ID): $_staffId');
      } else {
        // Normal kullanıcı - Firebase Auth'dan bilgileri al
        setState(() {
          _currentUser = null; // Admin değil
          _staffName = firebaseUser.displayName ?? firebaseUser.email?.split('@')[0] ?? 'Kullanıcı';
          _staffPosition = 'Personel';
          _staffId = firebaseUser.uid;
        });

        print('Normal kullanıcı bilgileri güncellendi:');
        print('Name: $_staffName');
        print('Position: $_staffPosition');
        print('ID: $_staffId');
      }

      // Verileri yükle
      await _loadUserData();
    } else {
      print('Hiçbir kullanıcı bulunamadı - loading false yapılıyor');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Kullanıcı verilerini yükle
  Future<void> _loadUserData() async {
    // Kullanıcı ID'si yoksa veri yükleyemeyiz
    if (_staffId.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Aktif mesaiyi kontrol et
      await _checkActiveShift();
      
      // Mesai geçmişini yükle
      await _loadShiftHistory();
      
      // Satış stream'ini yeniden başlat (kullanıcı değiştiyse)
      _startSalesStream();
      
    } catch (e) {
      print('Veriler yüklenirken hata: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Veriler yüklenirken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Aktif mesaiyi kontrol et
  Future<void> _checkActiveShift() async {
    if (_staffId.isEmpty) return;

    try {
      final activeShift = await _shiftService.getActiveShift(_staffId);
      
      if (activeShift != null) {
        setState(() {
          _activeShift = activeShift;
          _isShiftActive = true;
          _shiftStartTime = activeShift.startTime;
          _currentShiftDuration = DateTime.now().difference(activeShift.startTime);
        });

        // Timer başlat
        _startShiftTimer();
      }
    } catch (e) {
      print('Aktif mesai kontrol edilirken hata: $e');
    }
  }

  // Mesai geçmişini yükle
  Future<void> _loadShiftHistory() async {
    if (_staffId.isEmpty) return;

    setState(() {
      _isLoadingShifts = true;
    });

    try {
      final shifts = await _shiftService.getUserShiftHistory(_staffId, limit: 50);
      setState(() {
        _shiftHistory = shifts;
      });
    } catch (e) {
      print('Mesai geçmişi yüklenirken hata: $e');
    } finally {
      setState(() {
        _isLoadingShifts = false;
      });
    }
  }

  // Satış geçmişini yükle (public metod) - artık gerekli değil, stream kullanıyoruz
  Future<void> refreshSalesHistory() async {
    // Stream otomatik güncelleniyor, manuel yenileme gerekmiyor
  }

  // Real-time satış stream'ini başlat
  void _startSalesStream() {
    if (_staffId.isEmpty) return;

    // Önceki stream'i iptal et
    _salesStreamSubscription?.cancel();

    setState(() {
      _isLoadingSales = true;
    });

    // Yeni stream'i başlat
    _salesStreamSubscription = _saleService.getUserSalesStream(_staffId, limit: 50).listen(
      (sales) {
        print('📊 PROFİL SATIŞ STREAM GÜNCELLENDİ:');
        print('   - Arama yapılan User ID: $_staffId');
        print('   - Yeni satış sayısı: ${sales.length}');
        
        // Sadece son 3 satışı göster (çok log olmasın diye)
        final recentSales = sales.take(3).toList();
        for (var sale in recentSales) {
          print('   - Son Satış: ${sale.customerName} - ${sale.amount}₺ - Durum: ${sale.status} - UserID: ${sale.userId}');
        }
        if (sales.length > 3) {
          print('   - ... ve ${sales.length - 3} satış daha');
        }
        
        if (mounted) {
          setState(() {
            // Tüm satışları göster (iptal edilenler dahil)
            _salesHistory = sales;
            _isLoadingSales = false;
          });
        }
      },
      onError: (error) {
        print('Satış stream hatası: $error');
        if (mounted) {
          setState(() {
            _isLoadingSales = false;
          });
        }
      },
    );
  }

  // Mesai timer'ını başlat
  void _startShiftTimer() {
    _shiftTimer?.cancel();
    _shiftTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_shiftStartTime != null) {
        setState(() {
          _currentShiftDuration = DateTime.now().difference(_shiftStartTime!);
        });
      }
    });
  }



  @override
  void dispose() {
    // AdminAuthService listener'ını temizle
    final adminAuthService = Provider.of<AdminAuthService>(context, listen: false);
    adminAuthService.removeListener(_onAuthStateChanged);
    
    _tabController.dispose();
    _shiftTimer?.cancel();
    _salesStreamSubscription?.cancel();
    super.dispose();
  }

  // Mesaiye başla
  Future<void> _startShift() async {
    print('Mesai başlatma butonuna basıldı');
    print('Staff ID: $_staffId');
    print('Staff Name: $_staffName');
    print('Is shift active: $_isShiftActive');
    
    // Önce kullanıcı bilgilerini kontrol et
    if (_staffId.isEmpty) {
      print('Staff ID boş - kullanıcı bilgileri yüklenmemiş');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kullanıcı bilgileri yüklenemedi. Lütfen tekrar giriş yapın.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (_isShiftActive) {
      print('Zaten aktif mesai var');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Zaten aktif bir mesainiz bulunuyor!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      print('Mesai servisi çağrılıyor...');
      final newShift = await _shiftService.startShift(_staffId, _staffName);
      print('Mesai servisi sonucu: $newShift');
      
      if (newShift != null) {
        setState(() {
          _activeShift = newShift;
          _isShiftActive = true;
          _shiftStartTime = newShift.startTime;
          _currentShiftDuration = Duration.zero;
        });

        // Timer başlat
        _startShiftTimer();

        // Mesai geçmişini güncelle
        await _loadShiftHistory();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Mesaiye başladınız!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mesai başlatılırken hata: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Mesaiden çık
  Future<void> _endShift() async {
    if (_staffId.isEmpty || !_isShiftActive || _activeShift == null) return;

    try {
      final endedShift = await _shiftService.endShift(_activeShift!.id, null);
      
      if (endedShift != null) {
        _shiftTimer?.cancel();

        setState(() {
          _isShiftActive = false;
          _shiftStartTime = null;
          _currentShiftDuration = Duration.zero;
          _activeShift = null;
        });

        // Mesai geçmişini güncelle
        await _loadShiftHistory();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Mesainiz başarıyla kaydedildi!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mesai bitirilirken hata: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Mesai kaydını düzenle
  Future<void> _editShiftRecord(
    ShiftRecord shiftRecord,
    DateTime newStartTime,
    DateTime newEndTime,
  ) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final updatedShift = await _shiftService.updateShift(
        shiftRecord.id,
        startTime: newStartTime,
        endTime: newEndTime,
      );

      if (updatedShift != null) {
        // Mesai geçmişini yenile
        await _loadShiftHistory();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Mesai kaydı başarıyla güncellendi!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mesai kaydı güncellenirken hata: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Mesai kaydını sil
  Future<void> _deleteShiftRecord(ShiftRecord shift) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final success = await _shiftService.deleteShift(shift.id);

      if (success) {
        // Mesai geçmişini yenile
        await _loadShiftHistory();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Mesai kaydı başarıyla silindi!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mesai kaydı silinirken hata: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Satış kaydını düzenle
  Future<void> _editSaleRecord(
    SaleRecord saleRecord,
    DateTime newDate,
    String newCustomerName,
    double newAmount,
    String newDescription,
  ) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final updatedSale = saleRecord.copyWith(
        date: newDate,
        customerName: newCustomerName,
        amount: newAmount,
        description: newDescription,
      );

      final result = await _saleService.updateSale(updatedSale);

      if (result != null) {
        // Stream otomatik güncelleniyor, manuel yenileme gerekmiyor

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Satış kaydı başarıyla güncellendi!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Satış kaydı güncellenirken hata: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Satış kaydını sil
  Future<void> _deleteSaleRecord(SaleRecord sale) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final success = await _saleService.deleteSale(sale.id);

      if (success) {
        // Stream otomatik güncelleniyor, manuel yenileme gerekmiyor

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Satış kaydı başarıyla silindi!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Satış kaydı silinirken hata: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Mesai tarih aralığı seçici
  Future<void> _selectShiftDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _shiftStartDate, end: _shiftEndDate),
      firstDate: DateTime(2021),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _shiftStartDate = picked.start;
        _shiftEndDate = picked.end;
      });
    }
  }

  // Satış tarih aralığı seçici
  Future<void> _selectSalesDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _salesStartDate, end: _salesEndDate),
      firstDate: DateTime(2021),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _salesStartDate = picked.start;
        _salesEndDate = picked.end;
      });
    }
  }

  // Toplam mesai süresini hesapla
  Duration _calculateTotalShiftDuration() {
    int totalSeconds = 0;
    
    for (var shift in _shiftHistory) {
      if (shift.endTime != null && shift.duration != null) {
        totalSeconds += shift.duration!.inSeconds;
      }
    }

    return Duration(seconds: totalSeconds);
  }

  // Toplam mesai süresi metni
  String _getTotalShiftDurationText() {
    final duration = _calculateTotalShiftDuration();
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    return '${hours} sa ${minutes} dk ${seconds} sn';
  }

  // Toplam satış tutarını hesapla (iptal edilen satışları çıkar)
  double _getTotalSales() {
    print('🔍 TOPLAM SATIŞ HESAPLAMA:');
    print('   - Kullanıcı ID: $_staffId');
    print('   - Toplam satış kaydı: ${_salesHistory.length}');
    
    double total = 0.0;
    int normalSales = 0;
    int cancelledSales = 0;
    int negativeSales = 0;
    
    // Negatif tutarlı satışları önce bul ve logla
    final negativeSalesList = _salesHistory.where((sale) => sale.amount < 0).toList();
    if (negativeSalesList.isNotEmpty) {
      print('   - NEGATİF TUTARLI SATIŞLAR BULUNDU:');
      for (var sale in negativeSalesList) {
        print('     → ${sale.customerName} - ${sale.amount}₺ - ${sale.description} - ${sale.date}');
      }
    }
    
    // Sadece son 5 satışı detaylı logla
    final recentSales = _salesHistory.take(5).toList();
    for (var sale in recentSales) {
      print('   - Son Satış: ${sale.customerName} - ${sale.amount}₺ - Durum: ${sale.status}');
      
      // Negatif tutarlı satışları (eski refund kayıtları) atla
      if (sale.amount < 0) {
        print('     → Negatif tutar, atlandı: ${sale.amount}₺');
        negativeSales++;
        continue;
      }
      
      if (sale.status == 'İptal Edildi') {
        // İptal edilen satışları toplam satıştan çıkar
        // DÜZELTME: İptal edilen satışlar zaten toplam satışa dahil edilmemeli
        // Burada sadece iptal edilen satışları atla, çıkarma yapma
        print('     → İptal edildi, atlandı: ${sale.amount}₺');
        cancelledSales++;
        continue;
      } else {
        // Normal satışları toplam satışa ekle
        total += sale.amount;
        normalSales++;
        print('     → Normal satış, eklendi: +${sale.amount}₺ (Toplam: ${total}₺)');
      }
    }
    
    // Kalan satışları da hesapla ama loglamadan
    for (int i = 5; i < _salesHistory.length; i++) {
      final sale = _salesHistory[i];
      
      if (sale.amount < 0) {
        negativeSales++;
        continue;
      }
      
      if (sale.status == 'İptal Edildi') {
        cancelledSales++;
        continue;
      } else {
        total += sale.amount;
        normalSales++;
      }
    }
    
    print('   - ÖZET:');
    print('     → Normal satışlar: $normalSales adet');
    print('     → İptal edilen satışlar: $cancelledSales adet');
    print('     → Negatif tutarlı satışlar: $negativeSales adet');
    print('   - TOPLAM SONUÇ: ${total}₺');
    return total;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Profil yükleniyor...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst kısım - Profil bilgileri
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
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
                  // Profil ve mesai durumu
                  Row(
                    children: [
                      // Profil resmi
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                        child: Icon(
                          Icons.person,
                          size: 36,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Profil bilgileri
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _staffName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _staffPosition,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Mesai durumu
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color:
                              _isShiftActive
                                  ? Colors.green.shade50
                                  : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color:
                                _isShiftActive
                                    ? Colors.green.shade300
                                    : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isShiftActive ? Icons.timer : Icons.timer_off,
                              size: 16,
                              color:
                                  _isShiftActive
                                      ? Colors.green.shade700
                                      : Colors.grey.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _isShiftActive ? 'Mesaide' : 'Mesai Dışı',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color:
                                    _isShiftActive
                                        ? Colors.green.shade700
                                        : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Özet bilgiler
                  Row(
                    children: [
                      // Toplam mesai
                      Expanded(
                        child: _buildSummaryCard(
                          icon: Icons.watch_later_outlined,
                          iconColor: AppTheme.primaryColor,
                          title: 'Toplam Mesai',
                          value: _isLoadingShifts 
                              ? 'Yükleniyor...'
                              : _getTotalShiftDurationText(),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Toplam satış
                      Expanded(
                        child: _buildSummaryCard(
                          icon: Icons.child_care,
                          iconColor: Colors.green.shade700,
                          title: 'Toplam Satış',
                          value: _isLoadingSales 
                              ? 'Yükleniyor...'
                              : '${_getTotalSales().toStringAsFixed(2)} ₺',
                        ),
                      ),
                    ],
                  ),

                  // Aktif mesai süresi
                  if (_isShiftActive) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.timer, color: Colors.green),
                              const SizedBox(width: 8),
                              Text(
                                'Aktif Mesai Süresi',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.green.shade800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _formatDuration(_currentShiftDuration),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _shiftStartTime != null
                                ? 'Başlangıç: ${DateFormat('HH:mm, d MMM', 'tr_TR').format(_shiftStartTime!)}'
                                : '',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Mesai başlat/bitir butonu
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        print('Mesai butonuna basıldı - _isShiftActive: $_isShiftActive');
                        print('Current user: $_currentUser');
                        if (_isShiftActive) {
                          _endShift();
                        } else {
                          _startShift();
                        }
                      },
                      icon: Icon(
                        _isShiftActive ? Icons.exit_to_app : Icons.play_arrow,
                      ),
                      label: Text(
                        _isShiftActive ? 'Mesai Çıkışı Yap' : 'Mesaiye Başla',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isShiftActive
                                ? Colors.red.shade600
                                : AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Çıkış Yap Butonu
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showLogoutDialog(),
                      icon: const Icon(Icons.logout, size: 20),
                      label: const Text('Çıkış Yap'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade600,
                        side: BorderSide(color: Colors.red.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Tab bar
                  TabBar(
                    controller: _tabController,
                    labelColor: AppTheme.primaryColor,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: AppTheme.primaryColor,
                    tabs: const [
                      Tab(text: 'Mesai Geçmişi'),
                      Tab(text: 'Satışlarım'),
                    ],
                  ),
                ],
              ),
            ),

            // Tab içerikleri
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Mesai geçmişi
                  _buildShiftHistoryList(),

                  // Satış geçmişi
                  _buildSalesHistoryList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Özet bilgi kartları
  Widget _buildSummaryCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // Mesai geçmişi listesi
  Widget _buildShiftHistoryList() {
    if (_isLoadingShifts) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Mesai geçmişi yükleniyor...'),
          ],
        ),
      );
    }

    if (_shiftHistory.isEmpty) {
      return Column(
        children: [
          // Tarih seçici
          Container(
            margin: const EdgeInsets.all(16),
            child: InkWell(
              onTap: _selectShiftDateRange,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.date_range,
                          size: 20,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Tarih Aralığı: ${DateFormat('d MMM yyyy', 'tr_TR').format(_shiftStartDate)} - ${DateFormat('d MMM yyyy', 'tr_TR').format(_shiftEndDate)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      Icons.keyboard_arrow_down,
                      color: AppTheme.primaryColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Boş durum
          Expanded(
            child: _buildEmptyState(
              'Mesai Kaydı Bulunamadı',
              'Henüz mesai kaydı bulunmuyor.',
            ),
          ),
        ],
      );
    }

    // Sadece bitmiş mesaileri göster ve tarih aralığına göre filtrele
    final completedShifts = _shiftHistory.where((shift) {
      if (shift.endTime == null) return false;
      
      // Tarih aralığına göre filtrele
      final shiftDate = DateTime(
        shift.startTime.year,
        shift.startTime.month,
        shift.startTime.day,
      );
      final startDate = DateTime(
        _shiftStartDate.year,
        _shiftStartDate.month,
        _shiftStartDate.day,
      );
      final endDate = DateTime(
        _shiftEndDate.year,
        _shiftEndDate.month,
        _shiftEndDate.day,
      );
      
      return shiftDate.isAtSameMomentAs(startDate) || 
             shiftDate.isAtSameMomentAs(endDate) ||
             (shiftDate.isAfter(startDate) && shiftDate.isBefore(endDate));
    }).toList();

    return Column(
      children: [
        // Tarih seçici
        Container(
          margin: const EdgeInsets.all(16),
          child: InkWell(
            onTap: _selectShiftDateRange,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.date_range,
                        size: 20,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Tarih Aralığı: ${DateFormat('d MMM yyyy', 'tr_TR').format(_shiftStartDate)} - ${DateFormat('d MMM yyyy', 'tr_TR').format(_shiftEndDate)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    Icons.keyboard_arrow_down,
                    color: AppTheme.primaryColor,
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // Mesai listesi veya boş durum
        Expanded(
          child: completedShifts.isEmpty
              ? _buildEmptyState(
                  'Tarih Aralığında Mesai Bulunamadı',
                  'Seçilen tarih aralığında mesai kaydı bulunmuyor.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: completedShifts.length,
                  itemBuilder: (context, index) {
        final shift = completedShifts[index];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Tarih
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat(
                        'd MMMM yyyy, EEEE',
                        'tr_TR',
                      ).format(shift.startTime),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const Spacer(),
                    // İşlem menüsü
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        color: Colors.grey.shade600,
                        size: 20,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showEditShiftDialog(shift);
                        } else if (value == 'delete') {
                          _showDeleteShiftDialog(shift);
                        }
                      },
                      itemBuilder:
                          (BuildContext context) => [
                            PopupMenuItem<String>(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.edit,
                                    color: Colors.blue.shade600,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Düzenle'),
                                ],
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete,
                                    color: Colors.red.shade600,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Sil'),
                                ],
                              ),
                            ),
                          ],
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Başlangıç - Bitiş - Süre
                Row(
                  children: [
                    Expanded(
                      child: _buildTimeColumn(
                        icon: Icons.login,
                        iconColor: Colors.green.shade600,
                        title: 'Başlangıç',
                        time: shift.startTime,
                      ),
                    ),

                    Container(
                      height: 40,
                      width: 1,
                      color: Colors.grey.shade200,
                    ),

                    Expanded(
                      child: _buildTimeColumn(
                        icon: Icons.logout,
                        iconColor: Colors.red.shade600,
                        title: 'Bitiş',
                        time: shift.endTime!,
                      ),
                    ),

                    Container(
                      height: 40,
                      width: 1,
                      color: Colors.grey.shade200,
                    ),

                    Expanded(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.timelapse,
                                size: 14,
                                color: Colors.blue.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Toplam',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            shift.duration != null 
                                ? '${shift.duration!.inHours} sa ${shift.duration!.inMinutes % 60} dk ${shift.duration!.inSeconds % 60} sn'
                                : 'Devam ediyor',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
                ),
        ),
      ],
    );
  }

  // Satış geçmişi listesi
  Widget _buildSalesHistoryList() {
    if (_isLoadingSales) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Satış geçmişi yükleniyor...'),
          ],
        ),
      );
    }

    if (_salesHistory.isEmpty) {
      return Column(
        children: [
          // Tarih seçici
          Container(
            margin: const EdgeInsets.all(16),
            child: InkWell(
              onTap: _selectSalesDateRange,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.date_range,
                          size: 20,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Tarih Aralığı: ${DateFormat('d MMM yyyy', 'tr_TR').format(_salesStartDate)} - ${DateFormat('d MMM yyyy', 'tr_TR').format(_salesEndDate)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      Icons.keyboard_arrow_down,
                      color: AppTheme.primaryColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Boş durum
          Expanded(
            child: _buildEmptyState(
              'Satış Kaydı Bulunamadı',
              'Henüz satış kaydı bulunmuyor.',
            ),
          ),
        ],
      );
    }

    // Tarih aralığına göre satışları filtrele
    final filteredSales = _salesHistory.where((sale) {
      final saleDate = DateTime(
        sale.date.year,
        sale.date.month,
        sale.date.day,
      );
      final startDate = DateTime(
        _salesStartDate.year,
        _salesStartDate.month,
        _salesStartDate.day,
      );
      final endDate = DateTime(
        _salesEndDate.year,
        _salesEndDate.month,
        _salesEndDate.day,
      );
      
      return saleDate.isAtSameMomentAs(startDate) || 
             saleDate.isAtSameMomentAs(endDate) ||
             (saleDate.isAfter(startDate) && saleDate.isBefore(endDate));
    }).toList();

    return Column(
      children: [
        // Tarih seçici
        Container(
          margin: const EdgeInsets.all(16),
          child: InkWell(
            onTap: _selectSalesDateRange,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.date_range,
                        size: 20,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Tarih Aralığı: ${DateFormat('d MMM yyyy', 'tr_TR').format(_salesStartDate)} - ${DateFormat('d MMM yyyy', 'tr_TR').format(_salesEndDate)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    Icons.keyboard_arrow_down,
                    color: AppTheme.primaryColor,
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // Satış listesi veya boş durum
        Expanded(
          child: filteredSales.isEmpty
              ? _buildEmptyState(
                  'Tarih Aralığında Satış Bulunamadı',
                  'Seçilen tarih aralığında satış kaydı bulunmuyor.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredSales.length,
                  itemBuilder: (context, index) {
              final sale = filteredSales[index];

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Satış tipine göre ikon
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _getSaleTypeColor(sale).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Icon(
                            _getSaleTypeIcon(sale),
                            color: _getSaleTypeColor(sale),
                            size: 20,
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Satış detayları
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  sale.customerName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${sale.amount.toStringAsFixed(2)} ₺',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: sale.status == 'İptal Edildi' ? Colors.orange.shade700 : Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    sale.description,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                                // İptal edilen satışlar için etiket
                                if (sale.status == 'İptal Edildi')
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.orange.shade300, width: 1),
                                    ),
                                    child: Text(
                                      'İPTAL',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange.shade700,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // Ödeme yöntemi
                            if (sale.paymentMethod != null)
                              Row(
                                children: [
                                  Icon(
                                    _getPaymentMethodIcon(sale.paymentMethod!),
                                    size: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _getPaymentMethodText(sale.paymentMethod!),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat(
                                'd MMM yyyy, HH:mm',
                                'tr_TR',
                              ).format(sale.date),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // İşlem menüsü
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert,
                          color: Colors.grey.shade600,
                          size: 20,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showEditSaleDialog(sale);
                          } else if (value == 'delete') {
                            _showDeleteSaleDialog(sale);
                          }
                        },
                        itemBuilder:
                            (BuildContext context) => [
                              PopupMenuItem<String>(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.edit,
                                      color: Colors.blue.shade600,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('Düzenle'),
                                  ],
                                ),
                              ),
                              PopupMenuItem<String>(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete,
                                      color: Colors.red.shade600,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('Sil'),
                                  ],
                                ),
                              ),
                            ],
                      ),
                    ],
                  ),
                ),
              );
            },
                ),
        ),
      ],
    );
  }

  // Zaman bilgisi sütunu
  Widget _buildTimeColumn({
    required IconData icon,
    required Color iconColor,
    required String title,
    required DateTime time,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          DateFormat('HH:mm', 'tr_TR').format(time),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // Boş durum gösterimi
  Widget _buildEmptyState(String title, String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hourglass_empty, size: 50, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // Süre formatı
  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');

    return '$hours:$minutes:$seconds';
  }

  // Mesai düzenleme diyaloğu
  void _showEditShiftDialog(ShiftRecord shift) {
    final startTimeController = TextEditingController(
      text: DateFormat('dd/MM/yyyy HH:mm', 'tr_TR').format(shift.startTime),
    );
    final endTimeController = TextEditingController(
      text: shift.endTime != null 
          ? DateFormat('dd/MM/yyyy HH:mm', 'tr_TR').format(shift.endTime!)
          : '',
    );

    DateTime? newStartTime = shift.startTime;
    DateTime? newEndTime = shift.endTime;

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 8,
            backgroundColor: Colors.white,
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Başlık
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.edit_calendar,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Mesai Kaydını Düzenle',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 20),

                  // Başlangıç zamanı
                  const Text(
                    'Başlangıç Zamanı',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: shift.startTime,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        locale: const Locale('tr', 'TR'),
                        builder: (context, child) {
                          return Theme(
                            data: ThemeData.light().copyWith(
                              colorScheme: ColorScheme.light(
                                primary: AppTheme.primaryColor,
                                onPrimary: Colors.white,
                                surface: Colors.white,
                              ),
                              dialogBackgroundColor: Colors.white,
                            ),
                            child: child!,
                          );
                        },
                      );

                      if (pickedDate != null) {
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(shift.startTime),
                          builder: (context, child) {
                            return Theme(
                              data: ThemeData.light().copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: AppTheme.primaryColor,
                                  onPrimary: Colors.white,
                                  surface: Colors.white,
                                ),
                                dialogBackgroundColor: Colors.white,
                              ),
                              child: child!,
                            );
                          },
                        );

                        if (pickedTime != null) {
                          newStartTime = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          );

                          startTimeController.text = DateFormat(
                            'dd/MM/yyyy HH:mm',
                            'tr_TR',
                          ).format(newStartTime!);
                          setState(() {});
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 18,
                            color: Colors.grey.shade700,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            DateFormat(
                              'dd MMMM yyyy',
                              'tr_TR',
                            ).format(newStartTime!),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.access_time,
                            size: 18,
                            color: Colors.grey.shade700,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            DateFormat('HH:mm', 'tr_TR').format(newStartTime!),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Bitiş zamanı
                  const Text(
                    'Bitiş Zamanı',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: shift.endTime,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        locale: const Locale('tr', 'TR'),
                        builder: (context, child) {
                          return Theme(
                            data: ThemeData.light().copyWith(
                              colorScheme: ColorScheme.light(
                                primary: AppTheme.primaryColor,
                                onPrimary: Colors.white,
                                surface: Colors.white,
                              ),
                              dialogBackgroundColor: Colors.white,
                            ),
                            child: child!,
                          );
                        },
                      );

                      if (pickedDate != null) {
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: shift.endTime != null 
                              ? TimeOfDay.fromDateTime(shift.endTime!)
                              : TimeOfDay.now(),
                          builder: (context, child) {
                            return Theme(
                              data: ThemeData.light().copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: AppTheme.primaryColor,
                                  onPrimary: Colors.white,
                                  surface: Colors.white,
                                ),
                                dialogBackgroundColor: Colors.white,
                              ),
                              child: child!,
                            );
                          },
                        );

                        if (pickedTime != null) {
                          newEndTime = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          );

                          if (newEndTime != null) {
                            endTimeController.text = DateFormat(
                              'dd/MM/yyyy HH:mm',
                              'tr_TR',
                            ).format(newEndTime!);
                          }
                          setState(() {});
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 18,
                            color: Colors.grey.shade700,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            newEndTime != null 
                                ? DateFormat(
                                    'dd MMMM yyyy',
                                    'tr_TR',
                                  ).format(newEndTime!)
                                : 'Tarih seçin',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.access_time,
                            size: 18,
                            color: Colors.grey.shade700,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            newEndTime != null 
                                ? DateFormat('HH:mm', 'tr_TR').format(newEndTime!)
                                : 'Saat seçin',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Toplam süre
                  if (newStartTime != null && newEndTime != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.timer,
                            size: 16,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Toplam Süre: ',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          Text(
                            newStartTime != null && newEndTime != null
                                ? '${newEndTime!.difference(newStartTime!).inHours} saat ${newEndTime!.difference(newStartTime!).inMinutes % 60} dakika'
                                : 'Süre hesaplanamıyor',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Butonlar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        child: Text(
                          'İptal',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {
                          if (newStartTime != null && newEndTime != null) {
                            if (newEndTime!.isAfter(newStartTime!)) {
                              Navigator.of(context).pop();
                              _editShiftRecord(
                                shift,
                                newStartTime!,
                                newEndTime!,
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Bitiş zamanı başlangıç zamanından sonra olmalıdır!',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Lütfen başlangıç ve bitiş zamanlarını seçin!',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Kaydet'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  // Mesai silme diyaloğu
  void _showDeleteShiftDialog(ShiftRecord shift) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 8,
            backgroundColor: Colors.white,
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Başlık
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.delete_forever,
                          color: Colors.red.shade700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Mesai Kaydını Sil',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Uyarı metni
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade100),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red.shade700,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Bu mesai kaydı kalıcı olarak silinecektir. Bu işlem geri alınamaz.',
                            style: TextStyle(
                              color: Colors.red.shade800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Silinecek veri bilgileri
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Silinecek Mesai Kaydı',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Tarih
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat(
                                'd MMMM yyyy',
                                'tr_TR',
                              ).format(shift.startTime),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Saat aralığı
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${DateFormat('HH:mm', 'tr_TR').format(shift.startTime)} - ${shift.endTime != null ? DateFormat('HH:mm', 'tr_TR').format(shift.endTime!) : 'Devam ediyor'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Toplam süre
                        Row(
                          children: [
                            Icon(
                              Icons.timelapse,
                              size: 16,
                              color: Colors.blue.shade600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              shift.duration != null 
                                  ? 'Toplam: ${shift.duration!.inHours} saat ${shift.duration!.inMinutes % 60} dakika ${shift.duration!.inSeconds % 60} saniye'
                                  : 'Süre hesaplanamıyor',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Butonlar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Vazgeç',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _deleteShiftRecord(shift);
                        },
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Sil'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
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

  // Satış düzenleme diyaloğu
  void _showEditSaleDialog(SaleRecord sale) {
    final dateController = TextEditingController(
      text: DateFormat('dd/MM/yyyy HH:mm', 'tr_TR').format(sale.date),
    );
    final customerNameController = TextEditingController(
      text: sale.customerName,
    );
    final amountController = TextEditingController(
      text: sale.amount.toString(),
    );
    final descriptionController = TextEditingController(text: sale.description);

    DateTime? newDate = sale.date;

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 8,
            backgroundColor: Colors.white,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Başlık
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.paid_rounded,
                            color: Colors.green.shade700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Satış Kaydını Düzenle',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 20),

                    // Tarih seçici
                    const Text(
                      'Satış Tarihi',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: sale.date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          locale: const Locale('tr', 'TR'),
                          builder: (context, child) {
                            return Theme(
                              data: ThemeData.light().copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: AppTheme.primaryColor,
                                  onPrimary: Colors.white,
                                  surface: Colors.white,
                                ),
                                dialogBackgroundColor: Colors.white,
                              ),
                              child: child!,
                            );
                          },
                        );

                        if (pickedDate != null) {
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(sale.date),
                            builder: (context, child) {
                              return Theme(
                                data: ThemeData.light().copyWith(
                                  colorScheme: ColorScheme.light(
                                    primary: AppTheme.primaryColor,
                                    onPrimary: Colors.white,
                                    surface: Colors.white,
                                  ),
                                  dialogBackgroundColor: Colors.white,
                                ),
                                child: child!,
                              );
                            },
                          );

                          if (pickedTime != null) {
                            newDate = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );

                            if (newDate != null) {
                              dateController.text = DateFormat(
                                'dd/MM/yyyy HH:mm',
                                'tr_TR',
                              ).format(newDate!);
                            }
                            setState(() {});
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 18,
                              color: Colors.grey.shade700,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              newDate != null 
                                  ? DateFormat(
                                      'dd MMMM yyyy',
                                      'tr_TR',
                                    ).format(newDate!)
                                  : 'Tarih seçin',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.access_time,
                              size: 18,
                              color: Colors.grey.shade700,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              newDate != null 
                                  ? DateFormat('HH:mm', 'tr_TR').format(newDate!)
                                  : 'Saat seçin',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Müşteri Adı
                    const Text(
                      'Müşteri Adı',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: TextField(
                        controller: customerNameController,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          prefixIcon: Icon(
                            Icons.person,
                            color: Colors.grey.shade600,
                          ),
                          hintText: 'Müşteri adını girin',
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Tutar
                    const Text(
                      'Satış Tutarı',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          prefixIcon: Icon(
                            Icons.monetization_on,
                            color: Colors.green.shade600,
                          ),
                          suffixText: '₺',
                          suffixStyle: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                          hintText: 'Tutarı girin',
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Açıklama
                    const Text(
                      'Açıklama',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: TextField(
                        controller: descriptionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(left: 16, top: 12),
                            child: Icon(
                              Icons.description,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                          alignLabelWithHint: true,
                          hintText: 'Satış hakkında açıklama girin',
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Butonlar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          child: Text(
                            'İptal',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {
                            // Form kontrolü
                            if (customerNameController.text.isEmpty ||
                                amountController.text.isEmpty ||
                                descriptionController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Lütfen tüm alanları doldurun!',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            // Tutar doğrulaması
                            double? amount;
                            try {
                              amount = double.parse(
                                amountController.text.replaceAll(',', '.'),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Geçersiz tutar formatı!'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            if (amount <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Tutar 0\'dan büyük olmalıdır!',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            if (newDate != null) {
                              Navigator.of(context).pop();
                              _editSaleRecord(
                                sale,
                                newDate!,
                                customerNameController.text,
                                amount,
                                descriptionController.text,
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Lütfen tarih seçin!'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Kaydet'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  // Çıkış yapma diyaloğu
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 8,
        backgroundColor: Colors.white,
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.logout,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Çıkış Yap',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 16),

              // Uyarı metni
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red.shade700,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Uygulamadan çıkış yapmak istediğinize emin misiniz?',
                        style: TextStyle(
                          color: Colors.red.shade800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Personel bilgileri
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Çıkış Yapılacak Hesap',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Personel adı
                    Row(
                      children: [
                        Icon(
                          Icons.person,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _staffName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Pozisyon
                    Row(
                      children: [
                        Icon(
                          Icons.work,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _staffPosition,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // Butonlar
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Vazgeç',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _logout();
                    },
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Çıkış Yap'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
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

  // Çıkış yapma işlemi
  void _logout() async {
    // Mesai aktifse uyarı göster
    if (_isShiftActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Aktif mesainiz var! Önce mesai çıkışı yapın.'),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      // Firebase Auth ile çıkış yap
      await FirebaseAuth.instance.signOut();

      if (mounted) {
        // Başarılı çıkış mesajı göster
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Başarıyla çıkış yapıldı!'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Login ekranına yönlendir
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/',
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Çıkış yapılırken hata oluştu: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Satış tipine göre ikon
  IconData _getSaleTypeIcon(SaleRecord sale) {
    // Masa siparişi için turuncu tema ile uyumlu ikon
    if (sale.description.toLowerCase().contains('masa') || 
        sale.description.toLowerCase().contains('sipariş') ||
        sale.description.toLowerCase().contains('pasta') ||
        sale.description.toLowerCase().contains('içecek') ||
        sale.description.toLowerCase().contains('yemek') ||
        sale.description.toLowerCase().contains('restoran') ||
        sale.description.toLowerCase().contains('cafe') ||
        sale.description.toLowerCase().contains('kahve') ||
        sale.description.toLowerCase().contains('çay') ||
        sale.description.toLowerCase().contains('kek') ||
        sale.description.toLowerCase().contains('börek') ||
        sale.description.toLowerCase().contains('sandwich') ||
        sale.description.toLowerCase().contains('burger') ||
        sale.description.toLowerCase().contains('pizza') ||
        sale.description.toLowerCase().contains('salata') ||
        sale.description.toLowerCase().contains('soup') ||
        sale.description.toLowerCase().contains('çorba') ||
        sale.description.toLowerCase().contains('su') ||
        sale.description.toLowerCase().contains('cola') ||
        sale.description.toLowerCase().contains('fanta') ||
        sale.description.toLowerCase().contains('ayran') ||
        sale.description.toLowerCase().contains('meyve suyu') ||
        sale.description.toLowerCase().contains('smoothie') ||
        sale.description.toLowerCase().contains('milkshake') ||
        sale.description.toLowerCase().contains('dondurma') ||
        sale.description.toLowerCase().contains('tatlı') ||
        sale.description.toLowerCase().contains('dessert') ||
        sale.description.toLowerCase().contains('snack') ||
        sale.description.toLowerCase().contains('atıştırmalık') ||
        sale.description.toLowerCase().contains('menü') ||
        sale.description.toLowerCase().contains('menu') ||
        sale.description.toLowerCase().contains('combo') ||
        sale.description.toLowerCase().contains('set') ||
        sale.description.toLowerCase().contains('paket') ||
        sale.description.toLowerCase().contains('paket') ||
        sale.description.toLowerCase().contains('tabak') ||
        sale.description.toLowerCase().contains('bardak') ||
        sale.description.toLowerCase().contains('kase') ||
        sale.description.toLowerCase().contains('porsiyon') ||
        sale.description.toLowerCase().contains('adet') ||
        sale.description.toLowerCase().contains('x') ||
        sale.description.toLowerCase().contains('×')) {
      return Icons.restaurant_menu; // Turuncu tema ile uyumlu restoran ikonu
    } else {
      // Tüm oyun alanı satışları için tek ikon
      return Icons.child_care;
    }
  }

  // Satış tipine göre renk
  Color _getSaleTypeColor(SaleRecord sale) {
    if (sale.description.toLowerCase().contains('masa') || 
        sale.description.toLowerCase().contains('sipariş') ||
        sale.description.toLowerCase().contains('pasta') ||
        sale.description.toLowerCase().contains('içecek') ||
        sale.description.toLowerCase().contains('yemek') ||
        sale.description.toLowerCase().contains('restoran') ||
        sale.description.toLowerCase().contains('cafe') ||
        sale.description.toLowerCase().contains('kahve') ||
        sale.description.toLowerCase().contains('çay') ||
        sale.description.toLowerCase().contains('kek') ||
        sale.description.toLowerCase().contains('börek') ||
        sale.description.toLowerCase().contains('sandwich') ||
        sale.description.toLowerCase().contains('burger') ||
        sale.description.toLowerCase().contains('pizza') ||
        sale.description.toLowerCase().contains('salata') ||
        sale.description.toLowerCase().contains('soup') ||
        sale.description.toLowerCase().contains('çorba') ||
        sale.description.toLowerCase().contains('su') ||
        sale.description.toLowerCase().contains('cola') ||
        sale.description.toLowerCase().contains('fanta') ||
        sale.description.toLowerCase().contains('ayran') ||
        sale.description.toLowerCase().contains('meyve suyu') ||
        sale.description.toLowerCase().contains('smoothie') ||
        sale.description.toLowerCase().contains('milkshake') ||
        sale.description.toLowerCase().contains('dondurma') ||
        sale.description.toLowerCase().contains('tatlı') ||
        sale.description.toLowerCase().contains('dessert') ||
        sale.description.toLowerCase().contains('snack') ||
        sale.description.toLowerCase().contains('atıştırmalık') ||
        sale.description.toLowerCase().contains('menü') ||
        sale.description.toLowerCase().contains('menu') ||
        sale.description.toLowerCase().contains('combo') ||
        sale.description.toLowerCase().contains('set') ||
        sale.description.toLowerCase().contains('paket') ||
        sale.description.toLowerCase().contains('tabak') ||
        sale.description.toLowerCase().contains('bardak') ||
        sale.description.toLowerCase().contains('kase') ||
        sale.description.toLowerCase().contains('porsiyon') ||
        sale.description.toLowerCase().contains('adet') ||
        sale.description.toLowerCase().contains('x') ||
        sale.description.toLowerCase().contains('×')) {
      return Colors.orange.shade600;
    } else {
      // Tüm oyun alanı satışları için tek renk (mavi)
      return Colors.blue.shade600;
    }
  }

  // Ödeme yöntemi ikonu
  IconData _getPaymentMethodIcon(String paymentMethod) {
    switch (paymentMethod.toLowerCase()) {
      case 'nakit':
      case 'cash':
        return Icons.money;
      case 'kart':
      case 'card':
        return Icons.credit_card;
      default:
        return Icons.payment;
    }
  }

  // Ödeme yöntemi metni
  String _getPaymentMethodText(String paymentMethod) {
    switch (paymentMethod.toLowerCase()) {
      case 'nakit':
      case 'cash':
        return 'Nakit';
      case 'kart':
      case 'card':
        return 'Kart';
      default:
        return paymentMethod;
    }
  }

  // Satış silme diyaloğu
  void _showDeleteSaleDialog(SaleRecord sale) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 8,
            backgroundColor: Colors.white,
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Başlık
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.delete_forever,
                          color: Colors.red.shade700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Satış Kaydını Sil',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Uyarı metni
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade100),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red.shade700,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Bu satış kaydı kalıcı olarak silinecektir. Bu işlem geri alınamaz.',
                            style: TextStyle(
                              color: Colors.red.shade800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Silinecek veri bilgileri
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Silinecek Satış Kaydı',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Müşteri
                        Row(
                          children: [
                            Icon(
                              Icons.person,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              sale.customerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Tutar
                        Row(
                          children: [
                            Icon(
                              Icons.monetization_on,
                              size: 16,
                              color: sale.status == 'İptal Edildi' ? Colors.orange.shade600 : Colors.green.shade600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${sale.amount.toStringAsFixed(2)} ₺',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: sale.status == 'İptal Edildi' ? Colors.orange.shade700 : Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Açıklama
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.description,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                sale.description,
                                style: const TextStyle(
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Tarih
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat(
                                'd MMMM yyyy, HH:mm',
                                'tr_TR',
                              ).format(sale.date),
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Butonlar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Vazgeç',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _deleteSaleRecord(sale);
                        },
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Sil'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
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
}


