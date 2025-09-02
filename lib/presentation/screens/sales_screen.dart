import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/customer_model.dart';
import '../../data/repositories/customer_repository.dart';

class SalesScreen extends StatefulWidget {
  final CustomerRepository customerRepository;

  const SalesScreen({Key? key, required this.customerRepository})
    : super(key: key);

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  // Filtre için tarih aralığı
  DateTime _startDate = DateTime.now().subtract(const Duration(hours: 24));
  DateTime _endDate = DateTime.now();

  // Arama filtresi
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Girişleri sıralama
  String _sortBy = 'giriş_tarihi';
  bool _sortAscending = false;
  
  // Performans optimizasyonu için
  List<Customer> _cachedCustomers = [];
  bool _isLoading = true;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }
  
  // Müşteri verilerini yükle
  Future<void> _loadCustomers() async {
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

      return isInDateRange && matchesSearch;
    }).toList();
  }

  // Cache'i temizle ve yeniden yükle
  Future<void> _clearCacheAndReload() async {
    setState(() {
      _cachedCustomers.clear();
      _isLoading = true;
    });
    
    await _loadCustomers();
  }

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
            final aRemaining = a.totalSeconds - a.staticRemainingSeconds;
            final bRemaining = b.totalSeconds - b.staticRemainingSeconds;
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
      final remainingSeconds = customer.totalSeconds - customer.staticRemainingSeconds;
      if (!customer.isCompleted && remainingSeconds > 0) {
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
    final totalCustomers = _calculateTotalCustomers();
    final averageTime = _calculateAverageEntryTime();

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

                  // Özet kartları
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
                          value: _calculateActiveCustomers().toString(),
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
                          value: _calculateCompletedCustomers().toString(),
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
                            child: Text('Kalan Süre'),
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
                  : sortedCustomers.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: sortedCustomers.length,
                        itemBuilder: (context, index) {
                          final customer = sortedCustomers[index];

                          // Her müşteri için, toplam süre
                          final totalTime = Duration(seconds: customer.totalSeconds);
                          
                          // KALAN SÜRE BAZLI SİSTEM: Kalan süreyi al, kullanılanı hesapla
                          final totalRemainingSeconds = customer.staticRemainingSeconds;
                          final totalUsedSeconds = customer.totalSeconds - totalRemainingSeconds;
                          
                          final remainingTime = Duration(seconds: totalRemainingSeconds);
                          final usedDuration = Duration(seconds: totalUsedSeconds);
                          
                          // Çıkış zamanı (tamamlanma zamanı varsa onu kullan, yoksa hesaplanan çıkış zamanı)
                          final actualExitTime = customer.isCompleted && customer.completedTime != null
                              ? customer.completedTime!
                              : customer.exitTime;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Üst kısım - Müşteri bilgileri
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Bilet numarası
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor
                                              .withOpacity(0.1),
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                                        final isMediumScreen = constraints.maxWidth < 600;
                                        
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
                                                      duration: totalTime,
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
                                                      icon: Icons.timer,
                                                      iconColor: Colors.purple.shade600,
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
                                                      iconColor: Colors.orange.shade600,
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
                                                  duration: totalTime,
                                                  isSmall: false,
                                                ),
                                              ),

                                              // Ayırıcı
                                              Container(
                                                height: 40,
                                                width: 1,
                                                color: Colors.grey.shade300,
                                              ),

                                              // Kullanılan süre
                                              Expanded(
                                                child: _buildTimeInfo(
                                                  icon: Icons.timer,
                                                  iconColor: Colors.purple.shade600,
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
                                              
                                              // Kalan süre
                                              Expanded(
                                                child: _buildTimeInfo(
                                                  icon: Icons.schedule,
                                                  iconColor: Colors.orange.shade600,
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
                                  
                                  // Satın alınan süre bilgisi
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
                                          Icons.timer_outlined,
                                          size: 16,
                                          color: Colors.orange.shade700,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Satın Alınan Süre: ${customer.price > 0 ? _formatDuration(totalTime) : 'Yok'}',
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
                              ),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
        ),
      ),
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
      return 'Tamamlandı';
    } else if (remainingTime.inSeconds <= 0) {
      return 'Süre Bitti';
    } else {
      return 'Aktif';
    }
  }

  Color _getCustomerStatusColor(Customer customer, Duration remainingTime) {
    if (customer.isCompleted) {
      return Colors.green.shade700;
    } else if (remainingTime.inSeconds <= 0) {
      return Colors.red.shade700;
    } else {
      return Colors.blue.shade700;
    }
  }

  Color _getCustomerStatusContainerColor(Customer customer, Duration remainingTime) {
    if (customer.isCompleted) {
      return Colors.green.shade50;
    } else if (remainingTime.inSeconds <= 0) {
      return Colors.red.shade50;
    } else {
      return Colors.blue.shade50; // Aktif durum için mavi
    }
  }

  Color _getCustomerStatusBorderColor(Customer customer, Duration remainingTime) {
    if (customer.isCompleted) {
      return Colors.green.shade200;
    } else if (remainingTime.inSeconds <= 0) {
      return Colors.red.shade200;
    } else {
      return Colors.blue.shade200; // Aktif durum için mavi
    }
  }
}
