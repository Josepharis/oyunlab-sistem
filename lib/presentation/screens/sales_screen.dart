import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/customer_model.dart';
import '../../data/models/sale_record_model.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/services/sale_service.dart';

class SalesScreen extends StatefulWidget {
  final CustomerRepository customerRepository;

  const SalesScreen({Key? key, required this.customerRepository})
    : super(key: key);

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  // Filtre için tarih aralığı
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();

  // Arama filtresi
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Kategori filtresi
  String _selectedCategory = 'oyun_alani';

  // Kategori seçenekleri
  final Map<String, String> _categories = {
    'oyun_alani': 'Oyun Alanı',
    'kafe': 'Kafe',
    'oyun_grubu': 'Oyun Grubu',
    'robotik_kodlama': 'Robotik Kodlama',
    'workshop': 'Workshop',
  };

  // Girişleri sıralama
  String _sortBy = 'giriş_tarihi';
  bool _sortAscending = false;
  
  // Performans optimizasyonu için
  List<Customer> _cachedCustomers = [];
  List<SaleRecord> _cachedSales = [];
  bool _isLoading = true;
  Timer? _debounceTimer;
  
  // Services
  final SaleService _saleService = SaleService();
  
  // Stream subscription for real-time updates
  StreamSubscription<List<Customer>>? _customersSubscription;

  @override
  void initState() {
    super.initState();
    _startListeningToCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    _customersSubscription?.cancel();
    super.dispose();
  }
  
  // Müşteri verilerini stream'den dinle
  void _startListeningToCustomers() {
    // İlk veri yüklenene kadar loading göster
    setState(() {
      _isLoading = true;
    });
    
    // İlk veriyi hemen yükle
    _loadInitialData();
    
    _customersSubscription = widget.customerRepository.customersStream.listen(
      (customers) {
        if (mounted) {
          setState(() {
            _cachedCustomers = customers;
            _isLoading = false;
          });
          print('SALES_SCREEN: Stream güncellendi, ${customers.length} müşteri');
        }
      },
      onError: (error) {
        print('Sales screen customer stream error: $error');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      },
    );
  }

  // İlk veriyi yükle
  Future<void> _loadInitialData() async {
    try {
      // Hem müşteri hem de satış verilerini yükle
      final customers = await widget.customerRepository.getAllCustomersHistory();
      final sales = await _saleService.getAllSales(
        startDate: _startDate,
        endDate: _endDate.add(const Duration(days: 1)),
      );
      
      if (mounted) {
        setState(() {
          _cachedCustomers = customers;
          _cachedSales = sales;
          _isLoading = false;
        });
        print('SALES_SCREEN: İlk veri yüklendi, ${customers.length} müşteri, ${sales.length} satış');
      }
    } catch (e) {
      print('SALES_SCREEN: İlk veri yüklenirken hata: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Müşteri verilerini yükle (eski method - artık kullanılmıyor)
  Future<void> _loadCustomers() async {
    // Bu method artık kullanılmıyor, stream otomatik güncelleniyor
    // Sadece RefreshIndicator için bırakıldı
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
      
      try {
        final customers = await widget.customerRepository.getAllCustomersHistory();
        if (mounted) {
          setState(() {
            _cachedCustomers = customers;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  // Tarih aralığına göre girişleri filtrele
  List<Customer> _getFilteredCustomers() {
    // Bugünün sonuna kadar (23:59:59) olan işlemleri dahil et
    final endDateWithTime = DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day,
      23,
      59,
      59,
    );

    // Cache'den müşterileri al
    final allCustomers = _cachedCustomers;

    return allCustomers.where((customer) {
      // Tarih filtreleme
      final customerDate = customer.entryTime;
      final isInDateRange =
          customerDate.isAfter(_startDate) &&
          customerDate.isBefore(endDateWithTime);

      // Arama filtresi
      final matchesSearch =
          _searchQuery.isEmpty ||
          customer.childName.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          customer.parentName.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );

      // Kategori filtresi
      final matchesCategory = _matchesCategory(customer);

      return isInDateRange && matchesSearch && matchesCategory;
    }).toList();
  }

  // Satış verilerini filtrele
  List<SaleRecord> _getFilteredSales() {
    // Bugünün sonuna kadar (23:59:59) olan işlemleri dahil et
    final endDateWithTime = DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day,
      23,
      59,
      59,
    );

    return _cachedSales.where((sale) {
      // Tarih filtreleme
      final saleDate = sale.date;
      final isInDateRange =
          saleDate.isAfter(_startDate) &&
          saleDate.isBefore(endDateWithTime);

      // Arama filtresi
      final matchesSearch =
          _searchQuery.isEmpty ||
          sale.customerName.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          sale.description.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );

      // Kategori filtresi
      final matchesCategory = _matchesSaleCategory(sale);

      return isInDateRange && matchesSearch && matchesCategory;
    }).toList();
  }

  // Kategoriye göre filtreleme (müşteri verileri için)
  bool _matchesCategory(Customer customer) {
    switch (_selectedCategory) {
      case 'oyun_alani':
        // Oyun alanı için mevcut müşteri verilerini göster
        return true;
      case 'kafe':
        // Kafe kategorisinde müşteri verisi yok
        return false;
      case 'oyun_grubu':
        // Oyun grubu kategorisinde müşteri verisi yok
        return false;
      case 'robotik_kodlama':
        // Robotik kodlama kategorisinde müşteri verisi yok
        return false;
      case 'workshop':
        // Workshop kategorisinde müşteri verisi yok
        return false;
      default:
        return true;
    }
  }

  // Kategoriye göre filtreleme (satış verileri için)
  bool _matchesSaleCategory(SaleRecord sale) {
    switch (_selectedCategory) {
      case 'oyun_alani':
        // Oyun alanı satışları - giriş ücreti içeren satışlar
        return sale.description.toLowerCase().contains('giriş ücreti') ||
               sale.description.toLowerCase().contains('dakika');
      case 'kafe':
        // Kafe satışları - masa siparişi içeren satışlar
        return sale.description.toLowerCase().contains('masa') ||
               sale.description.toLowerCase().contains('sipariş') ||
               sale.description.toLowerCase().contains('pasta') ||
               sale.description.toLowerCase().contains('kahve') ||
               sale.description.toLowerCase().contains('çay') ||
               sale.description.toLowerCase().contains('kek') ||
               sale.description.toLowerCase().contains('sandviç') ||
               (sale.items?.any((item) => 
                 item.toLowerCase().contains('kahve') ||
                 item.toLowerCase().contains('çay') ||
                 item.toLowerCase().contains('kek') ||
                 item.toLowerCase().contains('sandviç') ||
                 item.toLowerCase().contains('pasta')
               ) ?? false);
      case 'oyun_grubu':
        // Oyun grubu satışları - grup içeren satışlar
        return sale.description.toLowerCase().contains('grup') ||
               sale.description.toLowerCase().contains('oyun grubu') ||
               sale.description.toLowerCase().contains('aktivite') ||
               sale.description.toLowerCase().contains('etkinlik');
      case 'robotik_kodlama':
        // Robotik kodlama satışları - kurs içeren satışlar
        return sale.description.toLowerCase().contains('kurs') ||
               sale.description.toLowerCase().contains('robotik') ||
               sale.description.toLowerCase().contains('kodlama') ||
               sale.description.toLowerCase().contains('programlama') ||
               sale.description.toLowerCase().contains('arduino');
      case 'workshop':
        // Workshop satışları - workshop içeren satışlar
        return sale.description.toLowerCase().contains('workshop') ||
               sale.description.toLowerCase().contains('stem') ||
               sale.description.toLowerCase().contains('atölye') ||
               sale.description.toLowerCase().contains('eğitim');
      default:
        return false;
    }
  }

  // Kategoriye göre özet kartları
  Widget _buildCategorySummaryCards() {
    switch (_selectedCategory) {
      case 'oyun_alani':
        return _buildOyunAlaniSummaryCards();
      case 'kafe':
        return _buildKafeSummaryCards();
      case 'oyun_grubu':
        return _buildOyunGrubuSummaryCards();
      case 'robotik_kodlama':
        return _buildRobotikKodlamaSummaryCards();
      case 'workshop':
        return _buildWorkshopSummaryCards();
      default:
        return _buildOyunAlaniSummaryCards();
    }
  }

  // Oyun Alanı özet kartları
  Widget _buildOyunAlaniSummaryCards() {
    final totalCustomers = _calculateTotalCustomers();
    final activeCustomers = _calculateActiveCustomers();
    final completedCustomers = _calculateCompletedCustomers();
    final averageTime = _calculateAverageEntryTime();

    return Column(
      children: [
        Row(
          children: [
            // Toplam Müşteri
            Expanded(
              child: _buildSummaryCard(
                icon: Icons.people_outline,
                iconColor: AppTheme.primaryColor,
                title: 'Toplam Müşteri',
                value: totalCustomers.toString(),
              ),
            ),
            SizedBox(width: MediaQuery.of(context).size.width < 400 ? 8 : 12),

            // Aktif Müşteri
            Expanded(
              child: _buildSummaryCard(
                icon: Icons.play_circle,
                iconColor: Colors.green.shade700,
                title: 'Aktif',
                value: activeCustomers.toString(),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        Row(
          children: [
            // Tamamlanan Müşteri
            Expanded(
              child: _buildSummaryCard(
                icon: Icons.check_circle,
                iconColor: Colors.blue.shade700,
                title: 'Tamamlanan',
                value: completedCustomers.toString(),
              ),
            ),
            SizedBox(width: MediaQuery.of(context).size.width < 400 ? 8 : 12),

            // Ortalama Süre
            Expanded(
              child: _buildSummaryCard(
                icon: Icons.timer_outlined,
                iconColor: Colors.orange.shade700,
                title: 'Ortalama Süre',
                value: _formatDuration(averageTime),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Kafe özet kartları
  Widget _buildKafeSummaryCards() {
    // Kafe satış verileri - sales koleksiyonundan
    final kafeSales = _getFilteredSales();
    
    final totalOrders = kafeSales.length;
    final totalRevenue = kafeSales.fold(0.0, (sum, sale) => sum + sale.amount);
    final averageOrderAmount = totalOrders > 0 ? totalRevenue / totalOrders : 0.0;
    final mostOrderedItem = 'Kahve'; // En çok sipariş verilen ürün

    return Column(
      children: [
        Row(
          children: [
            // Toplam Sipariş
            Expanded(
              child: _buildSummaryCard(
                icon: Icons.receipt_long,
                iconColor: Colors.orange.shade600,
                title: 'Toplam Sipariş',
                value: totalOrders.toString(),
              ),
            ),
            SizedBox(width: MediaQuery.of(context).size.width < 400 ? 8 : 12),

            // Ortalama Tutar
            Expanded(
              child: _buildSummaryCard(
                icon: Icons.attach_money,
                iconColor: Colors.green.shade600,
                title: 'Ortalama Tutar',
                value: '₺${averageOrderAmount.toStringAsFixed(2)}',
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        Row(
          children: [
            // Toplam Ciro
            Expanded(
              child: _buildSummaryCard(
                icon: Icons.trending_up,
                iconColor: Colors.blue.shade600,
                title: 'Toplam Ciro',
                value: '₺${totalRevenue.toStringAsFixed(2)}',
              ),
            ),
            SizedBox(width: MediaQuery.of(context).size.width < 400 ? 8 : 12),

            // En Popüler
            Expanded(
              child: _buildSummaryCard(
                icon: Icons.star,
                iconColor: Colors.orange.shade600,
                title: 'En Popüler',
                value: mostOrderedItem,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Oyun Grubu özet kartları
  Widget _buildOyunGrubuSummaryCards() {
    // Oyun Grubu satış verileri - sales koleksiyonundan
    final oyunGrubuSales = _getFilteredSales();
    
    final totalCustomers = oyunGrubuSales.length;
    final totalTransactions = oyunGrubuSales.length; // Her satış bir işlem
    final totalAmount = oyunGrubuSales.fold(0.0, (sum, sale) => sum + sale.amount);

    return Column(
      children: [
        Row(
          children: [
            // Toplam Müşteri
            Expanded(
              child: _buildSummaryCard(
                icon: Icons.people,
                iconColor: Colors.purple.shade600,
                title: 'Toplam Müşteri',
                value: totalCustomers.toString(),
              ),
            ),
            SizedBox(width: MediaQuery.of(context).size.width < 400 ? 8 : 12),

            // Toplam İşlem
            Expanded(
              child: _buildSummaryCard(
                icon: Icons.receipt,
                iconColor: Colors.blue.shade600,
                title: 'Toplam İşlem',
                value: totalTransactions.toString(),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        Row(
          children: [
            // Toplam Tutar
            Expanded(
              child: _buildSummaryCard(
                icon: Icons.attach_money,
                iconColor: Colors.green.shade600,
                title: 'Toplam Tutar',
                value: '₺${totalAmount.toStringAsFixed(2)}',
              ),
            ),
            const SizedBox(width: 8),
            // Boş alan - sadece 3 kart göster
            Expanded(child: Container()),
          ],
        ),
      ],
    );
  }

  // Robotik Kodlama özet kartları
  Widget _buildRobotikKodlamaSummaryCards() {
    // Robotik Kodlama satış verileri - sales koleksiyonundan
    final robotikSales = _getFilteredSales();
    
    final totalCustomers = robotikSales.length;
    final totalTransactions = robotikSales.length; // Her satış bir işlem
    final totalAmount = robotikSales.fold(0.0, (sum, sale) => sum + sale.amount);

    return Column(
      children: [
        Row(
          children: [
            // Toplam Müşteri
            Expanded(
              child: _buildSummaryCard(
                icon: Icons.people,
                iconColor: Colors.blue.shade600,
                title: 'Toplam Müşteri',
                value: totalCustomers.toString(),
              ),
            ),
            SizedBox(width: MediaQuery.of(context).size.width < 400 ? 8 : 12),

            // Toplam İşlem
            Expanded(
              child: _buildSummaryCard(
                icon: Icons.receipt,
                iconColor: Colors.green.shade600,
                title: 'Toplam İşlem',
                value: totalTransactions.toString(),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        Row(
          children: [
            // Toplam Tutar
            Expanded(
              child: _buildSummaryCard(
                icon: Icons.attach_money,
                iconColor: Colors.orange.shade600,
                title: 'Toplam Tutar',
                value: '₺${totalAmount.toStringAsFixed(2)}',
              ),
            ),
            const SizedBox(width: 8),
            // Boş alan - sadece 3 kart göster
            Expanded(child: Container()),
          ],
        ),
      ],
    );
  }

  // Workshop özet kartları
  Widget _buildWorkshopSummaryCards() {
    // Workshop satış verileri - sales koleksiyonundan
    final workshopSales = _getFilteredSales();
    
    final totalCustomers = workshopSales.length;
    final totalTransactions = workshopSales.length; // Her satış bir işlem
    final totalAmount = workshopSales.fold(0.0, (sum, sale) => sum + sale.amount);

    return Column(
      children: [
        Row(
          children: [
            // Toplam Müşteri
            Expanded(
              child: _buildSummaryCard(
                icon: Icons.people,
                iconColor: Colors.green.shade600,
                title: 'Toplam Müşteri',
                value: totalCustomers.toString(),
              ),
            ),
            SizedBox(width: MediaQuery.of(context).size.width < 400 ? 8 : 12),

            // Toplam İşlem
            Expanded(
              child: _buildSummaryCard(
                icon: Icons.receipt,
                iconColor: Colors.blue.shade600,
                title: 'Toplam İşlem',
                value: totalTransactions.toString(),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        Row(
          children: [
            // Toplam Tutar
            Expanded(
              child: _buildSummaryCard(
                icon: Icons.attach_money,
                iconColor: Colors.orange.shade600,
                title: 'Toplam Tutar',
                value: '₺${totalAmount.toStringAsFixed(2)}',
              ),
            ),
            const SizedBox(width: 8),
            // Boş alan - sadece 3 kart göster
            Expanded(child: Container()),
          ],
        ),
      ],
    );
  }

  // Cache'i temizle ve yeniden yükle (artık kullanılmıyor - stream otomatik güncelleniyor)
  // Future<void> _clearCacheAndReload() async {
  //   setState(() {
  //     _cachedCustomers.clear();
  //     _isLoading = true;
  //   });
  //   
  //   await _loadCustomers();
  // }

  // Müşterileri sırala
  List<Customer> _getSortedCustomers() {
    final customers = _getFilteredCustomers();

    switch (_sortBy) {
      case 'giriş_tarihi':
        customers.sort(
          (a, b) =>
              _sortAscending
                  ? a.entryTime.compareTo(b.entryTime)
                  : b.entryTime.compareTo(a.entryTime),
        );
        break;
      case 'çıkış_tarihi':
        customers.sort((a, b) {
          final aExitTime = a.entryTime.add(Duration(seconds: a.totalSeconds));
          final bExitTime = b.entryTime.add(Duration(seconds: b.totalSeconds));
          return _sortAscending
              ? aExitTime.compareTo(bExitTime)
              : bExitTime.compareTo(aExitTime);
        });
        break;
      case 'süre':
        customers.sort(
          (a, b) =>
              _sortAscending
                  ? a.totalSeconds.compareTo(b.totalSeconds)
                  : b.totalSeconds.compareTo(a.totalSeconds),
        );
        break;
      case 'bilet_no':
        customers.sort(
          (a, b) =>
              _sortAscending
                  ? a.ticketNumber.compareTo(b.ticketNumber)
                  : b.ticketNumber.compareTo(a.ticketNumber),
        );
        break;
      case 'kalan_süre':
        customers.sort(
          (a, b) {
            // Sales screen için sadece toplam süreyi kullan
            final aRemaining = a.totalSeconds;
            final bRemaining = b.totalSeconds;
            return _sortAscending
                ? aRemaining.compareTo(bRemaining)
                : bRemaining.compareTo(aRemaining);
          },
        );
        break;
    }

    return customers;
  }

  // Tarihleri seçme dialogu
  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
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
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  // Toplam müşteri sayısını hesapla (childCount'a göre)
  int _calculateTotalCustomers() {
    final customers = _getFilteredCustomers();
      int totalCount = 0;
    
      for (var customer in customers) {
        totalCount += customer.childCount;
      }
    
      return totalCount;
  }

  // Aktif müşteri sayısını hesapla (childCount'a göre)
  int _calculateActiveCustomers() {
    final customers = _getFilteredCustomers();
      int activeCount = 0;
    
      for (var customer in customers) {
      // Sales screen için sadece toplam süreyi kontrol et
        if (!customer.isCompleted && customer.totalSeconds > 0) {
          activeCount += customer.childCount;
        }
      }
    
      return activeCount;
  }

  // Tamamlanan müşteri sayısını hesapla (childCount'a göre)
  int _calculateCompletedCustomers() {
    final customers = _getFilteredCustomers();
      int completedCount = 0;
    
      for (var customer in customers) {
        if (customer.isCompleted) {
          completedCount += customer.childCount;
        }
      }
    
      return completedCount;
  }

  // Ortalama giriş süresini hesapla (saniye hassasiyeti ile)
  Duration _calculateAverageEntryTime() {
    final customers = _getFilteredCustomers();
    if (customers.isEmpty) return Duration.zero;
      
      final totalSeconds = customers.fold<int>(
        0,
        (sum, customer) => sum + customer.totalSeconds,
      );
      
    return Duration(seconds: (totalSeconds / customers.length).round());
  }

  @override
  Widget build(BuildContext context) {
    final sortedCustomers = _getSortedCustomers();
    final formatter = DateFormat('d MMM yyyy', 'tr_TR');

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadCustomers,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Üst bilgi alanı
            Container(
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
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Başlık
                  Text(
                    'Müşteriler',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                  ),
                  const SizedBox(height: 4),

                  // Tarih aralığı
                  InkWell(
                    onTap: _selectDateRange,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.date_range,
                            size: 16,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${formatter.format(_startDate)} - ${formatter.format(_endDate)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down,
                            size: 16,
                            color: AppTheme.primaryColor,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Kategori seçimi
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                    children: [
                        Icon(
                          Icons.category,
                          size: 20,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Kategori:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(width: 12),
                      Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedCategory,
                              isExpanded: true,
                              icon: Icon(
                                Icons.keyboard_arrow_down,
                                color: AppTheme.primaryColor,
                              ),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _selectedCategory = newValue;
                                  });
                                }
                              },
                              items: _categories.entries.map((entry) {
                                return DropdownMenuItem<String>(
                                  value: entry.key,
                                  child: Text(entry.value),
                                );
                              }).toList(),
                            ),
                        ),
                      ),
                    ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Kategoriye göre özet kartları
                  _buildCategorySummaryCards(),



                  const SizedBox(height: 16),

                  // Arama alanı
                  Container(
                    height: 45,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        // Debounce ile performans optimizasyonu
                        _debounceTimer?.cancel();
                        _debounceTimer = Timer(const Duration(milliseconds: 300), () {
                          if (mounted) {
                            setState(() {
                              _searchQuery = value;
                            });
                          }
                        });
                      },
                      decoration: InputDecoration(
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: Colors.grey.shade500,
                        ),
                        hintText: 'Müşteri ara...',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),

            // Liste başlığı
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
              child: Row(
                children: [
                  Text(
                    '${sortedCustomers.length} kayıt bulundu',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.secondaryTextColor,
                    ),
                  ),
                  const Spacer(),
                  // Sıralama dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _sortBy,
                        icon: Icon(
                          _sortAscending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade800,
                        ),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              if (_sortBy == newValue) {
                                _sortAscending = !_sortAscending;
                              } else {
                                _sortBy = newValue;
                                _sortAscending = false;
                              }
                            });
                          }
                        },
                        items: [
                          DropdownMenuItem(
                            value: 'giriş_tarihi',
                            child: Text('Giriş Tarihi'),
                          ),
                          DropdownMenuItem(
                            value: 'çıkış_tarihi',
                            child: Text('Çıkış Tarihi'),
                          ),
                          DropdownMenuItem(value: 'süre', child: Text('Süre')),
                          DropdownMenuItem(
                            value: 'bilet_no',
                            child: Text('Bilet No'),
                          ),
                          DropdownMenuItem(
                            value: 'kalan_süre',
                            child: Text('Satın Alınan Süre'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Listeleme
            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : _buildDataList(),
            ),
          ],
        ),
        ),
      ),
    );
  }

  // Veri listesini oluştur
  Widget _buildDataList() {
    final sortedCustomers = _getSortedCustomers();
    final filteredSales = _getFilteredSales();
    
    // Oyun alanı için müşteri verilerini göster
    if (_selectedCategory == 'oyun_alani') {
      if (sortedCustomers.isEmpty) {
        return _buildEmptyState();
      }
      
      return ListView.builder(
                        padding: const EdgeInsets.all(8),
        itemCount: sortedCustomers.length,
                        itemBuilder: (context, index) {
          final customer = sortedCustomers[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _buildOyunAlaniCard(customer),
            ),
          );
        },
      );
    }
    
    // Diğer kategoriler için satış verilerini göster
    if (filteredSales.isEmpty) {
      return _buildEmptyState();
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: filteredSales.length,
      itemBuilder: (context, index) {
        final sale = filteredSales[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _buildSaleCard(sale),
          ),
        );
      },
    );
  }

  // Satış kartı oluştur
  Widget _buildSaleCard(SaleRecord sale) {
    switch (_selectedCategory) {
      case 'kafe':
        return _buildKafeSaleCard(sale);
      case 'oyun_grubu':
        return _buildOyunGrubuSaleCard(sale);
      case 'robotik_kodlama':
        return _buildRobotikKodlamaSaleCard(sale);
      case 'workshop':
        return _buildWorkshopSaleCard(sale);
      default:
        return _buildGenericSaleCard(sale);
    }
  }


  // Oyun Alanı kartı (mevcut yapı)
  Widget _buildOyunAlaniCard(Customer customer) {
    // Her müşteri için, bu girişte satın alınan süre
    final purchasedTime = Duration(seconds: customer.purchasedSeconds);
    
    // SALES SCREEN SİSTEMİ: Kullanılan süre sadece karta yazarken gösterilir
                          final totalRemainingSeconds = customer.currentRemainingSeconds; // DOĞRU KALAN SÜRE
                          final totalUsedSeconds = customer.staticUsedSeconds; // Kullanılan süre hesapla
                          
                          final remainingTime = Duration(seconds: totalRemainingSeconds);
                          final usedDuration = Duration(seconds: totalUsedSeconds);
                          
                          // Çıkış zamanı (tamamlanma zamanı varsa onu kullan, yoksa hesaplanan çıkış zamanı)
                          final actualExitTime = customer.isCompleted && customer.completedTime != null
                              ? customer.completedTime!
                              : customer.exitTime;

    return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Üst kısım - Müşteri bilgileri
                                  Row(
          crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Bilet numarası
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            customer.ticketNumber.toString(),
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primaryColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // Müşteri detayları
                                      Expanded(
                                        child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              customer.childName,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                decoration: customer.isCompleted ? TextDecoration.lineThrough : null,
                                                color: customer.isCompleted ? Colors.grey.shade600 : Colors.black,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Veli: ${customer.parentName}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Durum bilgisi
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getCustomerStatusContainerColor(customer, remainingTime),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: _getCustomerStatusBorderColor(customer, remainingTime),
                                          ),
                                        ),
                                        child: Text(
                                          _getCustomerStatus(customer, remainingTime),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: _getCustomerStatusColor(customer, remainingTime),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 12),

                                                                    // Alt kısım - Zaman bilgileri
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        // Ekran genişliğine göre responsive ayarlar
                                        final isSmallScreen = constraints.maxWidth < 400;
                                        
                                        if (isSmallScreen) {
                                          // Küçük ekranlar için dikey düzen
                                          return Column(
                                            children: [
                                              // Üst sıra: Giriş, Çıkış, Toplam
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: _buildTimeInfo(
                                                      icon: Icons.login,
                                                      iconColor: Colors.green.shade600,
                                                      title: 'Giriş',
                                                      time: customer.entryTime,
                                                      isSmall: true,
                                                    ),
                                                  ),
                                                  Container(
                                                    height: 30,
                                                    width: 1,
                                                    color: Colors.grey.shade300,
                                                  ),
                                                  Expanded(
                                                    child: _buildTimeInfo(
                                                      icon: customer.isCompleted ? Icons.check_circle : Icons.logout,
                                                      iconColor: customer.isCompleted ? Colors.green.shade600 : Colors.red.shade600,
                                                      title: customer.isCompleted ? 'Tamamlandı' : 'Çıkış',
                                                      time: actualExitTime,
                                                      isSmall: true,
                                                    ),
                                                  ),
                                                  Container(
                                                    height: 30,
                                                    width: 1,
                                                    color: Colors.grey.shade300,
                                                  ),
                                                  Expanded(
                                                    child: _buildTimeInfo(
                                                      icon: Icons.schedule,
                                                      iconColor: AppTheme.primaryColor,
                                                      title: 'Toplam',
                                                      time: null,
                                                      duration: Duration(seconds: customer.totalSeconds),
                                                      isSmall: true,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              // Alt sıra: Kullanılan, Kalan
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: _buildTimeInfo(
                                                      icon: Icons.shopping_cart,
                                                      iconColor: Colors.red.shade600,
                                                      title: 'Kullanılan',
                                                      time: null,
                                                      duration: usedDuration,
                                                      isSmall: true,
                                                    ),
                                                  ),
                                                  Container(
                                                    height: 30,
                                                    width: 1,
                                                    color: Colors.grey.shade300,
                                                  ),
                                                  Expanded(
                                                    child: _buildTimeInfo(
                                                      icon: Icons.schedule,
                                                      iconColor: Colors.green.shade600,
                                                      title: 'Kalan',
                                                      time: null,
                                                      duration: remainingTime,
                                                      isSmall: true,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          );
                                        } else {
                                          // Orta ve büyük ekranlar için yatay düzen
                                          return Row(
                                            children: [
                                              // Giriş zamanı
                                              Expanded(
                                                child: _buildTimeInfo(
                                                  icon: Icons.login,
                                                  iconColor: Colors.green.shade600,
                                                  title: 'Giriş',
                                                  time: customer.entryTime,
                                                  isSmall: false,
                                                ),
                                              ),

                                              // Ayırıcı
                                              Container(
                                                height: 40,
                                                width: 1,
                                                color: Colors.grey.shade300,
                                              ),

                                              // Çıkış zamanı
                                              Expanded(
                                                child: _buildTimeInfo(
                                                  icon: customer.isCompleted ? Icons.check_circle : Icons.logout,
                                                  iconColor: customer.isCompleted ? Colors.green.shade600 : Colors.red.shade600,
                                                  title: customer.isCompleted ? 'Tamamlandı' : 'Çıkış',
                                                  time: actualExitTime,
                                                  isSmall: false,
                                                ),
                                              ),

                                              // Ayırıcı
                                              Container(
                                                height: 40,
                                                width: 1,
                                                color: Colors.grey.shade300,
                                              ),

                                              // Toplam süre
                                              Expanded(
                                                child: _buildTimeInfo(
                                                  icon: Icons.schedule,
                                                  iconColor: AppTheme.primaryColor,
                                                  title: 'Toplam',
                                                  time: null,
                                                  duration: Duration(seconds: customer.totalSeconds),
                                                  isSmall: false,
                                                ),
                                              ),

                                              // Ayırıcı
                                              Container(
                                                height: 40,
                                                width: 1,
                                                color: Colors.grey.shade300,
                                              ),

                                              // Kullanılan süre (sales screen için)
                                              Expanded(
                                                child: _buildTimeInfo(
                                                  icon: Icons.shopping_cart,
                                                  iconColor: Colors.red.shade600,
                                                  title: 'Kullanılan',
                                                  time: null,
                                                  duration: usedDuration,
                                                  isSmall: false,
                                                ),
                                              ),
                                              
                                              // Ayırıcı
                                              Container(
                                                height: 40,
                                                width: 1,
                                                color: Colors.grey.shade300,
                                              ),
                                              
                                              // Kalan süre (sales screen için)
                                              Expanded(
                                                child: _buildTimeInfo(
                                                  icon: Icons.schedule,
                                                  iconColor: Colors.green.shade600,
                                                  title: 'Kalan',
                                                  time: null,
                                                  duration: remainingTime,
                                                  isSmall: false,
                                                ),
                                              ),
                                            ],
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                  
                                  // Satın alınan süre bilgisi - sadece gerçekten para ödenen süre alımları için
                                  if (customer.hasTimePurchase) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.orange.shade200),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.shopping_cart,
                                            size: 16,
                                            color: Colors.orange.shade700,
                                          ),
                                          const SizedBox(width: 8),
                                                                                  Text(
                                          'Satın Alınan Süre: ${_formatDuration(purchasedTime)}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.orange.shade700,
                                          ),
                                        ),
                                        ],
                                      ),
                                    ),
                                  ],
      ],
    );
  }

  // Kafe kartı (masa siparişi ödemeleri için)
  Widget _buildKafeCard(Customer customer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Üst kısım - Müşteri bilgileri
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Masa numarası
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  customer.ticketNumber.toString(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Müşteri detayları
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.childName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      decoration: customer.isCompleted ? TextDecoration.lineThrough : null,
                      color: customer.isCompleted ? Colors.grey.shade600 : Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Veli: ${customer.parentName}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                                ],
                              ),
                            ),

            // Durum bilgisi
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: customer.isCompleted ? Colors.green.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: customer.isCompleted ? Colors.green.shade200 : Colors.orange.shade200,
                ),
              ),
              child: Text(
                customer.isCompleted ? 'Tamamlandı' : 'Hazırlanıyor',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: customer.isCompleted ? Colors.green.shade700 : Colors.orange.shade700,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Alt kısım - Sipariş bilgileri
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sipariş içeriği
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.restaurant_menu,
                      size: 16,
                      color: Colors.orange.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sipariş İçeriği: Kahve, Çay, Kek, Sandviç',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // İşlem tarihi
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: Colors.orange.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'İşlem Tarihi: ${DateFormat('dd/MM/yyyy HH:mm', 'tr_TR').format(customer.entryTime)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
          ],
    );
  }

  // Oyun Grubu kartı
  Widget _buildOyunGrubuCard(Customer customer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Üst kısım - Müşteri bilgileri
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Grup numarası
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.purple.shade100,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  customer.ticketNumber.toString(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Müşteri detayları
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.childName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      decoration: customer.isCompleted ? TextDecoration.lineThrough : null,
                      color: customer.isCompleted ? Colors.grey.shade600 : Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Veli: ${customer.parentName}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        ),

            // Durum bilgisi
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: customer.isCompleted ? Colors.green.shade50 : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: customer.isCompleted ? Colors.green.shade200 : Colors.blue.shade200,
                ),
              ),
              child: Text(
                customer.isCompleted ? 'Tamamlandı' : 'Devam Ediyor',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: customer.isCompleted ? Colors.green.shade700 : Colors.blue.shade700,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Alt kısım - Grup bilgileri
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              // Çocuk adı
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.child_care,
                      size: 16,
                      color: Colors.purple.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Çocuk Adı: ${customer.childName}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.purple.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // İşlem tarihi
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.purple.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: Colors.purple.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'İşlem Tarihi: ${DateFormat('dd/MM/yyyy HH:mm', 'tr_TR').format(customer.entryTime)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.purple.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Robotik Kodlama kartı
  Widget _buildRobotikKodlamaCard(Customer customer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Üst kısım - Müşteri bilgileri
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kurs numarası
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  customer.ticketNumber.toString(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Müşteri detayları
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.childName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      decoration: customer.isCompleted ? TextDecoration.lineThrough : null,
                      color: customer.isCompleted ? Colors.grey.shade600 : Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Veli: ${customer.parentName}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Durum bilgisi
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: customer.isCompleted ? Colors.green.shade50 : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: customer.isCompleted ? Colors.green.shade200 : Colors.blue.shade200,
                ),
              ),
              child: Text(
                customer.isCompleted ? 'Tamamlandı' : 'Devam Ediyor',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: customer.isCompleted ? Colors.green.shade700 : Colors.blue.shade700,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Alt kısım - Kurs bilgileri
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              // Çocuk adı
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.child_care,
                      size: 16,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Çocuk Adı: ${customer.childName}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // İşlem tarihi
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: Colors.blue.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'İşlem Tarihi: ${DateFormat('dd/MM/yyyy HH:mm', 'tr_TR').format(customer.entryTime)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
          ],
    );
  }




  // Workshop kartı
  Widget _buildWorkshopCard(Customer customer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Üst kısım - Müşteri bilgileri
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Workshop numarası
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  customer.ticketNumber.toString(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Müşteri detayları
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.childName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      decoration: customer.isCompleted ? TextDecoration.lineThrough : null,
                      color: customer.isCompleted ? Colors.grey.shade600 : Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Veli: ${customer.parentName}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Durum bilgisi
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: customer.isCompleted ? Colors.green.shade50 : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: customer.isCompleted ? Colors.green.shade200 : Colors.blue.shade200,
                ),
              ),
              child: Text(
                customer.isCompleted ? 'Tamamlandı' : 'Devam Ediyor',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: customer.isCompleted ? Colors.green.shade700 : Colors.blue.shade700,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Alt kısım - Workshop bilgileri
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              // Çocuk adı
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.child_care,
                      size: 16,
                      color: Colors.green.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Çocuk Adı: ${customer.childName}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // İşlem tarihi
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: Colors.green.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'İşlem Tarihi: ${DateFormat('dd/MM/yyyy HH:mm', 'tr_TR').format(customer.entryTime)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
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
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeInfo({
    required IconData icon,
    required Color iconColor,
    required String title,
    DateTime? time,
    Duration? duration,
    String? customValue,
    bool isSmall = false,
  }) {
    final timeFormatter = DateFormat('HH:mm', 'tr_TR');
    final dateFormatter = DateFormat('d MMM', 'tr_TR');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: isSmall ? 12 : 14, color: iconColor),
            SizedBox(width: isSmall ? 2.0 : 4.0),
            Text(
              title,
              style: TextStyle(
                fontSize: isSmall ? 10 : 12, 
                color: Colors.grey.shade600
              ),
            ),
          ],
        ),
        SizedBox(height: isSmall ? 2.0 : 4.0),
        if (time != null) ...[
          Text(
            timeFormatter.format(time),
            style: TextStyle(
              fontSize: isSmall ? 12 : 14, 
              fontWeight: FontWeight.bold
            ),
          ),
          Text(
            dateFormatter.format(time),
            style: TextStyle(
              fontSize: isSmall ? 9 : 11, 
              color: Colors.grey.shade500
            ),
          ),
        ] else if (duration != null) ...[
          Text(
            _formatDuration(duration),
            style: TextStyle(
              fontSize: isSmall ? 12 : 14, 
              fontWeight: FontWeight.bold,
              color: iconColor,
            ),
          ),
        ] else if (customValue != null) ...[
          Text(
            customValue,
            style: TextStyle(
              fontSize: isSmall ? 12 : 14, 
              fontWeight: FontWeight.bold,
              color: iconColor,
            ),
          ),
        ],
      ],
    );
  }

  // Süre formatlaması için yardımcı metod (saniye bilgisi ile)
  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}s ${duration.inMinutes % 60}dk ${duration.inSeconds % 60}sn';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}dk ${duration.inSeconds % 60}sn';
    } else {
      return '${duration.inSeconds}sn';
    }
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Müşteri verileri yükleniyor...',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.people_outline,
              size: 60,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Kayıt Bulunamadı',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryTextColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Seçilen tarih aralığında herhangi bir müşteri kaydı bulunamadı',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: AppTheme.secondaryTextColor),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _selectDateRange,
            icon: const Icon(Icons.date_range, size: 20),
            label: const Text('Tarih Aralığını Değiştir'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getCustomerStatus(Customer customer, Duration remainingTime) {
    if (customer.isCompleted) {
      // İptal edilen müşterileri kontrol et (price = -1)
      if (customer.price < 0) {
        return 'İptal Edildi';
      }
      return 'Tamamlandı';
    } else {
      // Sales screen için sadece tamamlanma durumunu kontrol et
      return 'Aktif';
    }
  }

  Color _getCustomerStatusColor(Customer customer, Duration remainingTime) {
    if (customer.isCompleted) {
      // İptal edilen müşterileri kontrol et (price = -1)
      if (customer.price < 0) {
        return Colors.orange.shade700;
      }
      return Colors.green.shade700;
    } else {
      // Sales screen için sadece tamamlanma durumunu kontrol et
      return Colors.blue.shade700;
    }
  }

  Color _getCustomerStatusContainerColor(Customer customer, Duration remainingTime) {
    if (customer.isCompleted) {
      // İptal edilen müşterileri kontrol et (price = -1)
      if (customer.price < 0) {
        return Colors.orange.shade50;
      }
      return Colors.green.shade50;
    } else if (remainingTime.inSeconds <= 0) {
      return Colors.red.shade50;
    } else {
      return Colors.blue.shade50; // Aktif durum için mavi
    }
  }

  Color _getCustomerStatusBorderColor(Customer customer, Duration remainingTime) {
    if (customer.isCompleted) {
      // İptal edilen müşterileri kontrol et (price = -1)
      if (customer.price < 0) {
        return Colors.orange.shade200;
      }
      return Colors.green.shade200;
    } else if (remainingTime.inSeconds <= 0) {
      return Colors.red.shade200;
    } else {
      return Colors.blue.shade200; // Aktif durum için mavi
    }
  }

  // Kafe satış kartı
  Widget _buildKafeSaleCard(SaleRecord sale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Müşteri adı ve tutar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                sale.customerName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              '₺${sale.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade600,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        // Sipariş içeriği
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Text(
            'Sipariş İçeriği: ${sale.description}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.orange.shade700,
            ),
          ),
        ),
        
        const SizedBox(height: 8),
        
        // İşlem tarihi
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Text(
            'İşlem Tarihi: ${DateFormat('dd/MM/yyyy HH:mm', 'tr_TR').format(sale.date)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.orange.shade700,
            ),
          ),
        ),
      ],
    );
  }

  // Oyun Grubu satış kartı
  Widget _buildOyunGrubuSaleCard(SaleRecord sale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Müşteri adı ve tutar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                sale.customerName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              '₺${sale.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade600,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        // Çocuk adı
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Text(
            'Çocuk Adı: ${sale.customerName}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue.shade700,
            ),
          ),
        ),
        
        const SizedBox(height: 8),
        
        // İşlem tarihi
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Text(
            'İşlem Tarihi: ${DateFormat('dd/MM/yyyy HH:mm', 'tr_TR').format(sale.date)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue.shade700,
            ),
          ),
        ),
      ],
    );
  }

  // Robotik Kodlama satış kartı
  Widget _buildRobotikKodlamaSaleCard(SaleRecord sale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Müşteri adı ve tutar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                sale.customerName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              '₺${sale.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.purple.shade600,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        // Çocuk adı
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.purple.shade200),
          ),
          child: Text(
            'Çocuk Adı: ${sale.customerName}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.purple.shade700,
            ),
          ),
        ),
        
        const SizedBox(height: 8),
        
        // İşlem tarihi
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.purple.shade200),
          ),
          child: Text(
            'İşlem Tarihi: ${DateFormat('dd/MM/yyyy HH:mm', 'tr_TR').format(sale.date)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.purple.shade700,
            ),
          ),
        ),
      ],
    );
  }

  // Workshop satış kartı
  Widget _buildWorkshopSaleCard(SaleRecord sale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Müşteri adı ve tutar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                sale.customerName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              '₺${sale.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade600,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        // Çocuk adı
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Text(
            'Çocuk Adı: ${sale.customerName}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.green.shade700,
            ),
          ),
        ),
        
        const SizedBox(height: 8),
        
        // İşlem tarihi
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Text(
            'İşlem Tarihi: ${DateFormat('dd/MM/yyyy HH:mm', 'tr_TR').format(sale.date)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.green.shade700,
            ),
          ),
        ),
      ],
    );
  }

  // Genel satış kartı
  Widget _buildGenericSaleCard(SaleRecord sale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Müşteri adı ve tutar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                sale.customerName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              '₺${sale.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        // Açıklama
        Text(
          sale.description,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        
        const SizedBox(height: 8),
        
        // İşlem tarihi
        Text(
          'İşlem Tarihi: ${DateFormat('dd/MM/yyyy HH:mm', 'tr_TR').format(sale.date)}',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }
}
