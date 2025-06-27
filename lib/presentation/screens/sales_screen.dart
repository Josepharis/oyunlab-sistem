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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

    // Tüm müşterileri al (hem aktif hem tamamlanmış)
    final allCustomers = widget.customerRepository.allCustomersHistory;

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
          ) ||
          customer.ticketNumber.toString().contains(_searchQuery);

      return isInDateRange && matchesSearch;
    }).toList();
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
          final aExitTime = a.entryTime.add(a.initialTime);
          final bExitTime = b.entryTime.add(b.initialTime);
          return _sortAscending
              ? aExitTime.compareTo(bExitTime)
              : bExitTime.compareTo(aExitTime);
        });
        break;
      case 'süre':
        customers.sort(
          (a, b) =>
              _sortAscending
                  ? a.initialTime.compareTo(b.initialTime)
                  : b.initialTime.compareTo(a.initialTime),
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
          (a, b) =>
              _sortAscending
                  ? a.remainingTime.compareTo(b.remainingTime)
                  : b.remainingTime.compareTo(a.remainingTime),
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

  // Toplam müşteri sayısını hesapla
  int _calculateTotalCustomers() {
    return _getFilteredCustomers().length;
  }

  // Ortalama giriş süresini hesapla
  Duration _calculateAverageEntryTime() {
    final customers = _getFilteredCustomers();
    if (customers.isEmpty) return Duration.zero;

    final totalMinutes = customers.fold<int>(
      0,
      (sum, customer) => sum + customer.initialTime.inMinutes,
    );

    return Duration(minutes: (totalMinutes / customers.length).round());
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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Başlık
                  Text(
                    'Müşteri Kayıtları',
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
                      const SizedBox(width: 12),

                      // Ortalama Süre
                      Expanded(
                        child: _buildSummaryCard(
                          icon: Icons.timer_outlined,
                          iconColor: Colors.orange.shade700,
                          title: 'Ortalama Süre',
                          value: '${averageTime.inMinutes} dk',
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
                        setState(() {
                          _searchQuery = value;
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
              child:
                  sortedCustomers.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: sortedCustomers.length,
                        itemBuilder: (context, index) {
                          final customer = sortedCustomers[index];
                          final exitTime = customer.entryTime.add(
                            customer.initialTime,
                          );

                          // Her müşteri için, toplam ve kalan süre
                          final totalTime = customer.initialTime;
                          final remainingTime = customer.remainingTime;

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
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
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

                                      // Kalan süre bilgisi
                                      if (remainingTime.inSeconds > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Colors.green.shade200,
                                            ),
                                          ),
                                          child: Text(
                                            'Kalan: ${remainingTime.inHours > 0 ? '${remainingTime.inHours} sa ' : ''}${remainingTime.inMinutes % 60} dk',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.green.shade700,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),

                                  const SizedBox(height: 12),

                                  // Alt kısım - Zaman bilgileri
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        // Giriş zamanı
                                        Expanded(
                                          child: _buildTimeInfo(
                                            icon: Icons.login,
                                            iconColor: Colors.green.shade600,
                                            title: 'Giriş',
                                            time: customer.entryTime,
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
                                            icon: Icons.logout,
                                            iconColor: Colors.red.shade600,
                                            title: 'Çıkış',
                                            time: exitTime,
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
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.timer,
                                                    size: 14,
                                                    color:
                                                        Colors.orange.shade600,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Toplam Süre',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          Colors.grey.shade600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${totalTime.inHours > 0 ? '${totalTime.inHours} sa ' : ''}${totalTime.inMinutes % 60} dk',
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
    required DateTime time,
  }) {
    final timeFormatter = DateFormat('HH:mm', 'tr_TR');
    final dateFormatter = DateFormat('d MMM', 'tr_TR');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
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
          timeFormatter.format(time),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        Text(
          dateFormatter.format(time),
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
      ],
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
}
