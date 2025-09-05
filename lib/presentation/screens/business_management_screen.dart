import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/business_settings_model.dart';
import '../../data/repositories/business_settings_repository.dart';
import '../../data/services/admin_auth_service.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/services/sale_service.dart';
import '../../core/di/service_locator.dart';
import 'excel_import_screen.dart';
import 'add_existing_customers_screen.dart';

class BusinessManagementScreen extends StatefulWidget {
  const BusinessManagementScreen({Key? key}) : super(key: key);

  @override
  State<BusinessManagementScreen> createState() => _BusinessManagementScreenState();
}

class _BusinessManagementScreenState extends State<BusinessManagementScreen>
    with SingleTickerProviderStateMixin {
  final BusinessSettingsRepository _repository = BusinessSettingsRepository();
  List<BusinessSettings> _businessSettings = [];
  bool _isLoading = true;
  BusinessCategory? _selectedCategory;
  BusinessSettings? _selectedSetting;
  late TabController _tabController;

  // Form controllers
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _durationController = TextEditingController();
  final _priceController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Raporlar için değişkenler
  DateTime _selectedDate = DateTime.now();
  bool _isLoadingReports = false;
  int _dailyChildCount = 0;
  int _totalUsedTime = 0;
  int _totalPurchasedTime = 0;
  double _totalRevenue = 0.0;
  int _packageCount = 0; // 600 dakika paket sayısı
  
  // Ek satış kategorileri
  double _roboticsRevenue = 0.0;
  double _gameGroupRevenue = 0.0;
  double _workshopRevenue = 0.0;
  int _roboticsCount = 0;
  int _gameGroupCount = 0;
  int _workshopCount = 0;
  
  // Oyun alanı ve kafe kategorileri
  double _gameAreaRevenue = 0.0;
  double _cafeRevenue = 0.0;
  int _gameAreaCount = 0;
  int _cafeCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1) {
        // Raporlar tab'ına geçildiğinde raporları yükle
        _loadReports();
      }
    });
    _loadBusinessSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  // İşletme ayarlarını yükle
  Future<void> _loadBusinessSettings() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final settings = await _repository.getAllBusinessSettings();
      
      if (settings.isEmpty) {
        // Varsayılan ayarları ekle
        await _repository.addDefaultBusinessSettings();
        final newSettings = await _repository.getAllBusinessSettings();
        setState(() {
          _businessSettings = newSettings;
        });
      } else {
        setState(() {
          _businessSettings = settings;
        });
      }

      // Debug: Kategorileri logla
      print('Yüklenen kategoriler:');
      for (final setting in _businessSettings) {
        print('- ${setting.name}: ${setting.category}');
      }

      // İlk kategoriyi seç
      if (_businessSettings.isNotEmpty) {
        _selectedCategory = _businessSettings.first.category;
        _updateSelectedSetting();
      }
    } catch (e) {
      print('İşletme ayarları yükleme hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('İşletme ayarları yüklenirken hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Seçilen kategoriye göre ayarları güncelle
  void _updateSelectedSetting() {
    if (_selectedCategory != null) {
      try {
        _selectedSetting = _businessSettings.firstWhere(
          (setting) => setting.category == _selectedCategory,
        );
        print('Seçilen kategori: ${_selectedSetting?.name} (${_selectedSetting?.category})');
      } catch (e) {
        print('Kategori bulunamadı: $_selectedCategory');
        _selectedSetting = null;
      }
    }
  }

  // Kategori değiştiğinde
  void _onCategoryChanged(BusinessCategory? category) {
    setState(() {
      _selectedCategory = category;
      _updateSelectedSetting();
    });
  }

  // Raporları yükle
  Future<void> _loadReports() async {
    setState(() {
      _isLoadingReports = true;
    });

    try {
      final customerRepository = ServiceLocator.locator<CustomerRepository>();
      final saleService = ServiceLocator.locator<SaleService>();

      // Seçilen tarihin başlangıcı ve sonu
      final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Tüm müşteri verilerini al
      final allCustomers = await customerRepository.getAllCustomersHistory();
      
      // Seçilen tarih aralığındaki müşterileri filtrele
      final customers = allCustomers.where((customer) {
        final customerDate = customer.entryTime;
        return customerDate.isAfter(startOfDay) && customerDate.isBefore(endOfDay);
      }).toList();
      
      print('RAPOR: Seçilen tarih: ${DateFormat('dd/MM/yyyy').format(_selectedDate)}');
      print('RAPOR: Tarih aralığı: ${DateFormat('dd/MM/yyyy').format(startOfDay)} - ${DateFormat('dd/MM/yyyy').format(endOfDay)}');
      print('RAPOR: Toplam müşteri: ${allCustomers.length}, Filtrelenmiş müşteri: ${customers.length}');
      
      // Günlük giren çocuk sayısı
      _dailyChildCount = customers.length;

      // Satış verilerini al
      final sales = await saleService.getAllSales(
        startDate: startOfDay,
        endDate: endOfDay,
      );
      
      print('RAPOR: Filtrelenmiş satış sayısı: ${sales.length}');
      
      _totalUsedTime = 0;
      _totalPurchasedTime = 0;
      _totalRevenue = 0.0;
      _packageCount = 0;
      
      // Ek satış kategorilerini sıfırla
      _roboticsRevenue = 0.0;
      _gameGroupRevenue = 0.0;
      _workshopRevenue = 0.0;
      _roboticsCount = 0;
      _gameGroupCount = 0;
      _workshopCount = 0;
      
      // Oyun alanı ve kafe kategorilerini sıfırla
      _gameAreaRevenue = 0.0;
      _cafeRevenue = 0.0;
      _gameAreaCount = 0;
      _cafeCount = 0;

      // Filtrelenmiş müşteri verilerinden süre bilgilerini hesapla
      for (final customer in customers) {
        _totalUsedTime += customer.usedSeconds ~/ 60; // Saniyeyi dakikaya çevir
        _totalPurchasedTime += customer.purchasedSeconds ~/ 60; // Saniyeyi dakikaya çevir
      }

      // Satış verilerinden gelir hesapla ve kategorilere ayır
      print('RAPOR: ${sales.length} satış bulundu');
      for (final sale in sales) {
        _totalRevenue += sale.amount;
        
        // Debug: Satış bilgilerini yazdır
        print('RAPOR: Satış - ${sale.description} (${sale.amount}₺)');
        
        // Satış açıklamasına göre kategorilere ayır
        final description = sale.description.toLowerCase();
        print('RAPOR: Açıklama (küçük harf): $description');
        
        if (description.contains('robotik') || description.contains('kodlama') || description.contains('robot')) {
          _roboticsRevenue += sale.amount;
          _roboticsCount++;
          print('RAPOR: Robotik kategorisine eklendi');
        } else if (description.contains('oyun grubu') || description.contains('oyun grubu') || description.contains('oyun') || description.contains('grup')) {
          _gameGroupRevenue += sale.amount;
          _gameGroupCount++;
          print('RAPOR: Oyun grubu kategorisine eklendi');
        } else if (description.contains('workshop') || description.contains('atölye') || description.contains('atolye')) {
          _workshopRevenue += sale.amount;
          _workshopCount++;
          print('RAPOR: Workshop kategorisine eklendi');
        } else if (description.contains('oyun alanı') || description.contains('oyun alani') || description.contains('oyun alan') || description.contains('süre') || description.contains('sure') || description.contains('dakika') || description.contains('dk')) {
          _gameAreaRevenue += sale.amount;
          _gameAreaCount++;
          print('RAPOR: Oyun alanı kategorisine eklendi');
        } else if (description.contains('kafe') || description.contains('masa') || description.contains('sipariş') || description.contains('siparis') || description.contains('yemek') || description.contains('içecek') || description.contains('icecek') || description.contains('pasta') || description.contains('yiyecek') || description.contains('içecek')) {
          _cafeRevenue += sale.amount;
          _cafeCount++;
          print('RAPOR: Kafe kategorisine eklendi');
        } else {
          print('RAPOR: Hiçbir kategoriye uymadı');
        }
      }
      
      print('RAPOR: Toplam ciro: $_totalRevenue₺');
      print('RAPOR: Robotik: $_roboticsRevenue₺ ($_roboticsCount satış)');
      print('RAPOR: Oyun grubu: $_gameGroupRevenue₺ ($_gameGroupCount satış)');
      print('RAPOR: Workshop: $_workshopRevenue₺ ($_workshopCount satış)');
      print('RAPOR: Oyun alanı: $_gameAreaRevenue₺ ($_gameAreaCount satış)');
      print('RAPOR: Kafe: $_cafeRevenue₺ ($_cafeCount satış)');
      
      // 600 dakika paket sayısını hesapla
      _packageCount = (_totalPurchasedTime / 600).floor();

    } catch (e) {
      print('Rapor yükleme hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Raporlar yüklenirken hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoadingReports = false;
      });
    }
  }

  // Yeni kategori ekleme dialog'u
  void _showAddCategoryDialog() {
    _nameController.clear();
    _descriptionController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.add_business, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            const Text('Yeni Kategori Ekle'),
          ],
        ),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Kategori Adı',
                  prefixIcon: Icon(Icons.category),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Kategori adı gerekli';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Açıklama',
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 2,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Açıklama gerekli';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                try {
                  // Yeni kategori oluştur
                  final newSetting = BusinessSettings(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    category: BusinessCategory.values.first, // Geçici olarak ilk kategori
                    name: _nameController.text.trim(),
                    description: _descriptionController.text.trim(),
                    durationPrices: [],
                    isActive: true,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  );

                  await _repository.addBusinessSetting(newSetting);
                  Navigator.pop(context);
                  _loadBusinessSettings();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Kategori başarıyla eklendi: ${newSetting.name}'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Kategori eklenirken hata oluştu: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  // Yeni süre/fiyat ekleme dialog'u
  void _showAddDurationPriceDialog() {
    _durationController.clear();
    _priceController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.add, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text('${_selectedSetting?.name ?? 'Kategori'} - Yeni Seçenek Ekle'),
          ],
        ),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _durationController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _selectedSetting?.category == BusinessCategory.oyunAlani 
                      ? 'Dakika' 
                      : 'Seans Sayısı',
                  prefixIcon: Icon(
                    _selectedSetting?.category == BusinessCategory.oyunAlani 
                        ? Icons.access_time 
                        : Icons.event_note
                  ),
                  helperText: _selectedSetting?.category == BusinessCategory.oyunAlani 
                      ? 'Örnek: 30, 60, 120 (dakika)'
                      : 'Örnek: 1, 4, 8 (seans)',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Bu alan gerekli';
                  }
                  final number = int.tryParse(value);
                  if (number == null || number <= 0) {
                    return 'Geçerli bir sayı girin';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Fiyat (₺)',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Fiyat gerekli';
                  }
                  final price = double.tryParse(value);
                  if (price == null || price < 0) {
                    return 'Geçerli bir fiyat girin';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                try {
                  final duration = int.parse(_durationController.text);
                  final price = double.parse(_priceController.text);

                  // Yeni süre/fiyat ekle
                  final newDurationPrice = DurationPrice(
                    duration: duration,
                    price: price,
                    isActive: true,
                  );

                  final updatedSetting = _selectedSetting!.copyWith(
                    durationPrices: [..._selectedSetting!.durationPrices, newDurationPrice],
                    updatedAt: DateTime.now(),
                  );

                  await _repository.updateBusinessSetting(updatedSetting);
                  Navigator.pop(context);
                  
                  // Sadece mevcut kategoriyi güncelle, tüm listeyi yeniden yükleme
                  setState(() {
                    _selectedSetting = updatedSetting;
                    // Mevcut kategorideki ayarları güncelle
                    final index = _businessSettings.indexWhere(
                      (setting) => setting.id == updatedSetting.id
                    );
                    if (index != -1) {
                      _businessSettings[index] = updatedSetting;
                    }
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Seçenek başarıyla eklendi'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Seçenek eklenirken hata oluştu: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  // Fiyat düzenleme dialog'u
  void _showEditPriceDialog(DurationPrice durationPrice) {
    final priceController = TextEditingController(
      text: durationPrice.price.toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Text(_selectedSetting?.categoryIcon ?? '📋', style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Text('${_selectedSetting?.name ?? 'Kategori'} - ${durationPrice.formattedDuration}'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Yeni fiyat girin:',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Fiyat (₺)',
                prefixIcon: const Icon(Icons.attach_money),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newPrice = double.tryParse(priceController.text);
              if (newPrice != null && newPrice >= 0) {
                try {
                  await _repository.updateCategoryPrice(
                    _selectedSetting!.id,
                    durationPrice.duration,
                    newPrice,
                  );
                  
                  Navigator.pop(context);
                  
                  // Sadece mevcut kategoriyi güncelle
                  setState(() {
                    // Mevcut kategorideki fiyatı güncelle
                    final updatedDurationPrices = _selectedSetting!.durationPrices.map((dp) {
                      if (dp.duration == durationPrice.duration) {
                        return dp.copyWith(price: newPrice);
                      }
                      return dp;
                    }).toList();
                    
                    _selectedSetting = _selectedSetting!.copyWith(
                      durationPrices: updatedDurationPrices,
                    );
                    
                    // Ana listedeki ayarları da güncelle
                    final index = _businessSettings.indexWhere(
                      (setting) => setting.id == _selectedSetting!.id
                    );
                    if (index != -1) {
                      _businessSettings[index] = _selectedSetting!;
                    }
                  });
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Fiyat başarıyla güncellendi: ${newPrice.toStringAsFixed(2)} ₺'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Fiyat güncellenirken hata oluştu: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Lütfen geçerli bir fiyat girin'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Güncelle'),
          ),
        ],
      ),
    );
  }

  // Kategori silme dialog'u
  void _showDeleteCategoryDialog(BusinessSettings setting) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.delete, color: Colors.red),
            const SizedBox(width: 8),
            const Text('Kategori Sil'),
          ],
        ),
        content: Text(
          '${setting.name} kategorisini silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _repository.deleteBusinessSetting(setting.id);
                Navigator.pop(context);
                _loadBusinessSettings();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${setting.name} kategorisi silindi'),
                    backgroundColor: Colors.orange,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Kategori silinirken hata oluştu: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  // Tüm verileri temizleme dialog'u
  void _showClearAllDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            const SizedBox(width: 8),
            const Text('Tüm Verileri Temizle'),
          ],
        ),
        content: const Text(
          'Bu işlem TÜM müşteri ve satış verilerini kalıcı olarak silecektir. Bu işlem geri alınamaz!\n\nDevam etmek istediğinizden emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _clearAllData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Tüm Verileri Sil'),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  // Tüm verileri temizle
  Future<void> _clearAllData() async {
    try {
      // Loading göster
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Veriler temizleniyor...'),
            ],
          ),
        ),
      );

      final customerRepository = ServiceLocator.locator<CustomerRepository>();
      final saleService = ServiceLocator.locator<SaleService>();

      // Müşteri verilerini temizle
      await customerRepository.clearAllCustomers();
      print('Tüm müşteri verileri temizlendi');

      // Satış verilerini temizle (tüm kullanıcıların satışları)
      // Bu için önce tüm satışları alıp sonra silmemiz gerekiyor
      final allSales = await saleService.getAllSales();
      for (final sale in allSales) {
        await saleService.deleteSale(sale.id);
      }
      print('${allSales.length} satış kaydı temizlendi');

      // Loading dialog'u kapat
      if (mounted) {
        Navigator.pop(context);
      }

      // Başarı mesajı
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tüm veriler başarıyla temizlendi'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }

    } catch (e) {
      print('Veri temizleme hatası: $e');
      
      // Loading dialog'u kapat
      if (mounted) {
        Navigator.pop(context);
      }

      // Hata mesajı
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Veri temizlenirken hata oluştu: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Çıkış yapma dialog'u
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            const SizedBox(width: 8),
            const Text('Çıkış Yap'),
          ],
        ),
        content: const Text('Uygulamadan çıkış yapmak istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Provider.of<AdminAuthService>(context, listen: false).logout();
              Navigator.pop(context); // Dialog'u kapat
              
              // Login sayfasına yönlendir
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login', // Route adı
                (route) => false, // Tüm route'ları temizle
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Çıkış Yap'),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adminAuthService = Provider.of<AdminAuthService>(context);
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final isSmallScreen = screenWidth < 400;
            
            return Row(
              children: [
                Icon(
                  Icons.business, 
                  color: AppTheme.primaryColor,
                  size: isSmallScreen ? 20 : 24,
                ),
                SizedBox(width: isSmallScreen ? 6 : 8),
                Text(
                  'İşletme Yönetimi',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          // Responsive Kullanıcı bilgisi
          LayoutBuilder(
            builder: (context, constraints) {
              final screenWidth = constraints.maxWidth;
              final isSmallScreen = screenWidth < 400;
              
              return Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 8 : 12, 
                  vertical: isSmallScreen ? 4 : 6
                ),
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person,
                      size: isSmallScreen ? 14 : 16,
                      color: AppTheme.primaryColor,
                    ),
                    SizedBox(width: isSmallScreen ? 4 : 6),
                    Text(
                      adminAuthService.userRoleString,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 10 : 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.settings),
              text: 'Ayarlar',
            ),
            Tab(
              icon: Icon(Icons.analytics),
              text: 'Raporlar',
            ),
          ],
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.primaryColor,
        ),
        // Geri butonu kaldırıldı
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Ayarlar Tab
          _buildSettingsTab(),
          // Raporlar Tab
          _buildReportsTab(),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return Column(
      children: [
        // Kategori seçimi ve yönetimi
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.category, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  const Text(
                    'Kategori Seçimi',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  // Yeni kategori ekleme butonu
                  IconButton(
                    onPressed: _showAddCategoryDialog,
                    icon: Icon(Icons.add_circle, color: AppTheme.primaryColor),
                    tooltip: 'Yeni Kategori Ekle',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Kategori dropdown
              DropdownButtonFormField<BusinessCategory>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Kategori Seçin',
                  prefixIcon: Icon(Icons.arrow_drop_down),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: _businessSettings
                    .map((setting) => setting.category)
                    .toSet() // Duplicate kategorileri kaldır
                    .map((category) {
                  final setting = _businessSettings.firstWhere(
                    (s) => s.category == category,
                  );
                  print('Dropdown item: ${setting.name} -> ${category}');
                  return DropdownMenuItem(
                    value: category,
                    child: Row(
                      children: [
                        Text(setting.categoryIcon),
                        const SizedBox(width: 8),
                        Text(setting.name),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: _onCategoryChanged,
              ),
              
              const SizedBox(height: 16),
              
              // Seçilen kategori bilgileri
              if (_selectedSetting != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _selectedSetting!.categoryIcon,
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedSetting!.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              _selectedSetting!.description,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Kategori silme butonu
                      IconButton(
                        onPressed: () => _showDeleteCategoryDialog(_selectedSetting!),
                        icon: Icon(Icons.delete, color: Colors.red.shade600),
                        tooltip: 'Kategoriyi Sil',
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        
        // Mevcut Kullanıcıları Ekleme Bölümü
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.people_alt_rounded, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  const Text(
                    'Mevcut Kullanıcıları Ekle',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Önceki sistemden 130 kullanıcıyı yeni sisteme aktarın. Bu kullanıcılar giriş yapmayacak, sadece veri kaydedilecek. Ebeveyn adları boş bırakılacak ve giriş sırasında istenecek.',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddExistingCustomersScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.upload_rounded),
                  label: const Text('Mevcut Kullanıcıları Ekle'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // İçerik
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : _selectedSetting == null
                  ? _buildEmptyState()
                  : _buildCategoryContent(),
        ),
      ],
    );
  }

  Widget _buildReportsTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Tarih seçimi
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    const Text(
                      'Tarih Seçimi',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() {
                              _selectedDate = date;
                            });
                            _loadReports();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_month, color: Colors.grey.shade600),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('dd/MM/yyyy').format(_selectedDate),
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _loadReports,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Yenile'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Rapor kartları
          _isLoadingReports
              ? const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                )
              : _buildReportCards(),
        ],
      ),
    );
  }

  Widget _buildReportCards() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Ana rapor kartları - Grid layout
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            children: [
              // Toplam ciro - İLK SIRADA
              _buildReportCard(
                title: 'Toplam Ciro',
                value: '${_totalRevenue.toStringAsFixed(0)}₺',
                icon: Icons.attach_money,
                color: Colors.purple,
                subtitle: 'Günlük gelir',
              ),
              
              // Günlük giren çocuk sayısı
              _buildReportCard(
                title: 'Günlük Giren Çocuk',
                value: _dailyChildCount.toString(),
                icon: Icons.child_care,
                color: Colors.blue,
                subtitle: 'Çocuk sayısı',
              ),
              
              // Toplam kullanılan süre
              _buildReportCard(
                title: 'Kullanılan Süre',
                value: '${_totalUsedTime}dk',
                icon: Icons.access_time,
                color: Colors.orange,
                subtitle: 'Oyun süresi',
              ),
              
              // Toplam satın alınan süre
              _buildReportCard(
                title: 'Satın Alınan Süre',
                value: '${_totalPurchasedTime}dk',
                icon: Icons.shopping_cart,
                color: Colors.green,
                subtitle: 'Alınan süre',
              ),
              
              // 600 dakika paket sayısı
              _buildReportCard(
                title: '600dk Paket',
                value: _packageCount.toString(),
                icon: Icons.inventory,
                color: Colors.teal,
                subtitle: 'Paket adedi',
              ),
              
              // Robotik/Kodlama satışları
              _buildReportCard(
                title: 'Robotik/Kodlama',
                value: '${_roboticsRevenue.toStringAsFixed(0)}₺',
                icon: Icons.smart_toy,
                color: Colors.cyan,
                subtitle: '${_roboticsCount} satış',
              ),
              
              // Oyun grubu satışları
              _buildReportCard(
                title: 'Oyun Grubu',
                value: '${_gameGroupRevenue.toStringAsFixed(0)}₺',
                icon: Icons.groups,
                color: Colors.amber,
                subtitle: '${_gameGroupCount} satış',
              ),
              
              // Workshop satışları
              _buildReportCard(
                title: 'Workshop',
                value: '${_workshopRevenue.toStringAsFixed(0)}₺',
                icon: Icons.school,
                color: Colors.deepOrange,
                subtitle: '${_workshopCount} satış',
              ),
              
              // Oyun alanı satışları
              _buildReportCard(
                title: 'Oyun Alanı',
                value: '${_gameAreaRevenue.toStringAsFixed(0)}₺',
                icon: Icons.games,
                color: Colors.blueGrey,
                subtitle: '${_gameAreaCount} satış',
              ),
              
              // Kafe satışları
              _buildReportCard(
                title: 'Kafe',
                value: '${_cafeRevenue.toStringAsFixed(0)}₺',
                icon: Icons.restaurant,
                color: Colors.brown,
                subtitle: '${_cafeCount} satış',
              ),
            ],
          ),
          
          // Paket detayları - sadece paket varsa göster
          if (_packageCount > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.teal, size: 16),
                      const SizedBox(width: 6),
                      const Text(
                        'Paket Detayları',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• ${_packageCount} adet 600 dakika paketi satıldı',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    '• Toplam paket değeri: ${(_packageCount * 600).toString()} dakika',
                    style: const TextStyle(fontSize: 12),
                  ),
                  if (_totalPurchasedTime > 0)
                    Text(
                      '• Paket oranı: %${((_packageCount * 600) / _totalPurchasedTime * 100).toStringAsFixed(1)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReportCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Başlık
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Text(
                _selectedSetting!.categoryIcon,
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_selectedSetting!.name} Seçenekleri',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Mevcut süre ve fiyat seçenekleri',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Seçenekler listesi
        if (_selectedSetting!.durationPrices.isEmpty)
          _buildEmptyOptionsState()
        else
          ..._selectedSetting!.durationPrices.map((durationPrice) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Süre/Seans
                  Expanded(
                    flex: 2,
                    child: Row(
                      children: [
                                                 Icon(
                           _selectedSetting!.category == BusinessCategory.oyunAlani
                               ? Icons.access_time
                               : Icons.event_note,
                           size: 20,
                           color: Colors.grey.shade600,
                         ),
                         const SizedBox(width: 8),
                         Text(
                           _selectedSetting!.category == BusinessCategory.oyunAlani
                               ? '${durationPrice.duration} dakika'
                               : durationPrice.formattedDuration,
                           style: const TextStyle(
                             fontWeight: FontWeight.w600,
                             fontSize: 16,
                           ),
                         ),
                      ],
                    ),
                  ),
                  
                  // Fiyat
                  Expanded(
                    flex: 2,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.attach_money,
                          size: 20,
                          color: Colors.green.shade600,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          durationPrice.formattedPrice,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Düzenle butonu
                  IconButton(
                    onPressed: () => _showEditPriceDialog(durationPrice),
                    icon: Icon(
                      Icons.edit,
                      color: AppTheme.primaryColor,
                    ),
                    tooltip: 'Fiyatı Düzenle',
                  ),
                ],
              ),
            );
          }).toList(),
        
        const SizedBox(height: 16),
        
        // Excel import butonu
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: ElevatedButton.icon(
            onPressed: () => _navigateToExcelImport(),
            icon: const Icon(Icons.upload_file, color: Colors.white),
            label: const Text(
              'Excel Veri Aktarımı',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              elevation: 2,
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        
        // Veri temizleme butonu
        Container(
          margin: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () => _showClearAllDataDialog(),
            icon: const Icon(Icons.delete_forever, color: Colors.white),
            label: const Text(
              'Tüm Verileri Temizle',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
              elevation: 2,
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        
        // Çıkış butonu - Sayfanın altına eklendi
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: ElevatedButton.icon(
            onPressed: () => _showLogoutDialog(),
            icon: const Icon(Icons.logout, color: Colors.white),
            label: const Text(
              'Çıkış Yap',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              elevation: 2,
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.business_center,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Kategori Seçin',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Yukarıdan bir kategori seçin veya yeni kategori ekleyin',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyOptionsState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.add_circle_outline,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Henüz Seçenek Yok',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bu kategori için henüz süre/fiyat seçeneği eklenmemiş',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddDurationPriceDialog,
            icon: const Icon(Icons.add),
            label: Text('${_selectedSetting!.name} Seçeneği Ekle'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Excel import ekranına git
  void _navigateToExcelImport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ExcelImportScreen(),
      ),
    );
  }
}
