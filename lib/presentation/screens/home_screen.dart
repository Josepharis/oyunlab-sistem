import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../data/models/customer_model.dart';
import '../../data/models/table_order_model.dart';
import '../../data/models/sale_record_model.dart';
import '../../data/models/business_settings_model.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/table_order_repository.dart';
import '../../data/repositories/business_settings_repository.dart';
import '../../data/services/sale_service.dart';
import '../widgets/countdown_card.dart';
import '../widgets/new_customer_form.dart';
import '../../core/theme/app_theme.dart';
import 'package:intl/intl.dart';


class HomeScreen extends StatefulWidget {
  final CustomerRepository customerRepository;
  final VoidCallback? onDataCleared; // Callback ekle
  final Function(int)? onGoToTable; // Masa ekranına gitme callback'i (masa numarası ile)

  const HomeScreen({
    super.key, 
    required this.customerRepository,
    this.onDataCleared,
    this.onGoToTable,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late Stream<List<Customer>> _customersStream;

  TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final TableOrderRepository _tableOrderRepository = TableOrderRepository();
  final SaleService _saleService = SaleService();
  final BusinessSettingsRepository _businessSettingsRepository = BusinessSettingsRepository();

  @override
  void initState() {
    super.initState();
    _customersStream = widget.customerRepository.customersStream;
    
    // Süre biten müşterileri otomatik tamamla
    _autoCompleteExpiredCustomers();
  }

  /// Süre biten müşterileri otomatik tamamla
  Future<void> _autoCompleteExpiredCustomers() async {
    try {
      await widget.customerRepository.autoCompleteExpiredCustomers();
    } catch (e) {
      print('HOME_SCREEN: Otomatik tamamlama hatası: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showNewCustomerForm() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder:
            (context) => Scaffold(
              appBar: AppBar(
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.sports_kabaddi_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'OyunLab',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                elevation: 0,
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              body: NewCustomerForm(
                onSave: (customer) async {
                  await widget.customerRepository.addCustomer(customer);
                  if (mounted) {
                    Navigator.pop(context);
                  }
                },
              ),
            ),
      ),
    );
  }

  // Masa ekleme dialog'u
  Future<void> _showAddTableDialog() async {
    try {
      // Cache'lenmiş müşteri listesini kullan (hızlı)
      List<Customer> customers = widget.customerRepository.customers;
      print('HOME_SCREEN: Masa ekleme dialog\'unda ${customers.length} müşteri bulundu (cache\'den)');
      
      // Firebase'den mevcut masaları al
      List<TableOrder> existingTables = [];
      try {
        existingTables = await _tableOrderRepository.getAllTables();
      } catch (e) {
        print('Masa bilgileri alınamadı: $e');
      }
      
      // Masası olmayan aktif çocukları bul
      final customersWithoutTable = customers.where((customer) {
        // Sadece aktif müşteriler (tamamlanmamış ve kalan süresi olan)
        if (!customer.isActive || customer.isCompleted || customer.ticketNumber <= 0) {
          return false;
        }
        
        // Bu bilet numarası için zaten masa var mı kontrol et
        final hasTable = existingTables.any((table) => 
          table.ticketNumber == customer.ticketNumber
        );
        
        return !hasTable; // Masası olmayan çocukları döndür
      }).toList();

      // Debug: Bilet numaralarını log'la
      print('HOME_SCREEN: Masa ekleme dialog\'unda bulunan müşteriler:');
      for (final customer in customersWithoutTable) {
        print('HOME_SCREEN: ${customer.childName} - Bilet: ${customer.ticketNumber}');
      }

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.table_restaurant_rounded, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              const Text('Masa Ekle'),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (customersWithoutTable.isNotEmpty) ...[
                  Text(
                    'Masası olmayan aktif çocuklar:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: customersWithoutTable.length,
                      itemBuilder: (context, index) {
                        final customer = customersWithoutTable[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                              child: Text(
                                customer.childName.substring(0, 1).toUpperCase(),
                                style: TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              customer.childName,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Veli: ${customer.parentName}'),
                                Text('Bilet: #${customer.ticketNumber}'),
                                Text(
                                  'Kalan: ${customer.currentRemainingSecondsPerChild ~/ 60} dk',
                                  style: TextStyle(
                                    color: Colors.green.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            trailing: ElevatedButton.icon(
                              onPressed: () async {
                                Navigator.pop(context);
                                await _addTableForCustomer(customer);
                              },
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Masa Aç'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ] else ...[
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Masası olmayan aktif çocuk bulunmuyor',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tüm aktif çocukların zaten masası var',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 16),
                // Manuel masa ekleme butonu
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showManualTableDialog();
                    },
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Manuel Masa Aç'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kapat'),
            ),
          ],
        );
      },
    );
    } catch (e) {
      // Loading dialog'u kapat
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Masa ekleme dialog\'u açılırken hata oluştu: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Müşteri için masa ekleme
  Future<void> _addTableForCustomer(Customer customer) async {
    try {
      // Aynı bilet numarasına sahip kardeşleri bul
      final siblings = widget.customerRepository.customers
          .where((c) => c.ticketNumber == customer.ticketNumber)
          .toList();

      // Yeni masa oluştur
      final newTable = TableOrder(
        tableNumber: customer.ticketNumber, // Bilet numarası masa numarası olarak kullan
        customerName: customer.parentName,
        childName: customer.childName,
        ticketNumber: customer.ticketNumber,
        childCount: siblings.length,
        isManual: false, // Müşteri kaydından otomatik oluşturulan masa
      );

      // Firebase'e ekle
      await _tableOrderRepository.addTable(newTable);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${customer.childName} için masa #${customer.ticketNumber} açıldı'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Masa eklenirken hata oluştu: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Manuel masa ekleme dialog'u
  void _showManualTableDialog() {
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.add_circle_outline, color: AppTheme.accentColor),
              const SizedBox(width: 8),
              const Text('Manuel Masa Ekle'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Müşteri Adı',
                  prefixIcon: Icon(Icons.person),
                  hintText: 'Örn: Ahmet Yılmaz',
                ),
                autofocus: true,
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
                if (nameController.text.trim().isNotEmpty) {
                  await _addManualTable(nameController.text.trim());
                  if (mounted) {
                    Navigator.pop(context);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
              ),
              child: const Text('Ekle'),
            ),
          ],
        );
      },
    );
  }

  // Manuel masa ekleme
  Future<void> _addManualTable(String customerName) async {
    try {
      // Sonraki manuel masa numarasını al
      final nextTableNumber = await _getNextManualTableNumber();

      // Yeni manuel masa oluştur
      final newTable = TableOrder(
        tableNumber: nextTableNumber,
        customerName: customerName,
        childName: '', // Manuel masalar için boş string
        ticketNumber: 0, // Manuel masalar için 0
        childCount: 1, // Varsayılan olarak 1 çocuk
        isManual: true, // Manuel olarak işaretle
      );

      // Firebase'e ekle
      await _tableOrderRepository.addTable(newTable);

    } catch (e) {
      print('Manuel masa eklenirken hata oluştu: $e');
    }
  }

  // Sonraki manuel masa numarasını al
  Future<int> _getNextManualTableNumber() async {
    try {
      // Her gün masa numaralarını sıfırla
      await _checkAndResetTableNumbers();
      
      // Firebase'den mevcut masaları al
      final existingTables = await _tableOrderRepository.getAllTables();
      
      // Manuel masaları filtrele
      final manualTables = existingTables.where((table) => table.isManual).toList();
      
      if (manualTables.isEmpty) {
        return 1; // İlk manuel masa 1'den başlasın
      }
      
      // En yüksek manuel masa numarasını bul
      final maxTableNumber = manualTables
          .map((table) => table.tableNumber)
          .reduce((max, number) => number > max ? number : max);
      
      return maxTableNumber + 1;
    } catch (e) {
      // Hata durumunda varsayılan numara döndür
      return 1;
    }
  }

  // Her gün masa numaralarını sıfırla
  Future<void> _checkAndResetTableNumbers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastResetDate = prefs.getString('last_table_number_reset');
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      // Eğer bugün sıfırlanmamışsa sıfırla
      if (lastResetDate == null || lastResetDate != today.toIso8601String()) {
        // Bugünün tarihini kaydet
        await prefs.setString('last_table_number_reset', today.toIso8601String());
        
        // Tüm manuel masaları sil (sadece bugün için)
        final existingTables = await _tableOrderRepository.getAllTables();
        final manualTables = existingTables.where((table) => table.isManual).toList();
        
        for (final table in manualTables) {
          await _tableOrderRepository.deleteTable(table.tableNumber);
        }
        
        print('Masa numaraları bugün için sıfırlandı');
      }
    } catch (e) {
      print('Masa numarası sıfırlama hatası: $e');
    }
  }

  // Müşterinin masa bilgisini kontrol et
  Future<bool> _hasTable(Customer customer) async {
    try {
      final existingTables = await _tableOrderRepository.getAllTables();
      return existingTables.any((table) => 
        table.ticketNumber == customer.ticketNumber
      );
    } catch (e) {
      print('Masa kontrolü hatası: $e');
      return false;
    }
  }

  // Masa ekranına git
  void _goToTableScreen(Customer customer) {
    // Bottom navigation'da masa ekranı index 1'de
    if (widget.onGoToTable != null) {
      widget.onGoToTable!(customer.ticketNumber);
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Responsive App Bar with search
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                children: [
                  // Title and Add Button - Responsive Layout
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final screenWidth = constraints.maxWidth;
                      final isSmallScreen = screenWidth < 600;
                      final isMediumScreen = screenWidth < 900;
                      
                      if (isSmallScreen) {
                        // Small screens: Stack vertically
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'OyunLab',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                    fontSize: 24,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Oyun Alanı Takip',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.secondaryTextColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Buttons - Full width on small screens
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () async => await _showAddTableDialog(),
                                    icon: const Icon(Icons.table_restaurant_rounded, size: 18),
                                    label: const Text('Masa Ekle'),
                                    style: ElevatedButton.styleFrom(
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      backgroundColor: AppTheme.accentColor,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _showNewCustomerForm,
                                    icon: const Icon(Icons.add_rounded, size: 18),
                                    label: const Text('Yeni Kayıt'),
                                    style: ElevatedButton.styleFrom(
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      } else if (isMediumScreen) {
                        // Medium screens: Horizontal layout with smaller buttons
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Title
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'OyunLab',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                    fontSize: 26,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Oyun Alanı Takip',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.secondaryTextColor,
                                  ),
                                ),
                              ],
                            ),
                            // Buttons - Compact
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () async => await _showAddTableDialog(),
                                  icon: const Icon(Icons.table_restaurant_rounded, size: 18),
                                  label: const Text('Masa Ekle'),
                                  style: ElevatedButton.styleFrom(
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    backgroundColor: AppTheme.accentColor,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: _showNewCustomerForm,
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: const Text('Yeni Kayıt'),
                                  style: ElevatedButton.styleFrom(
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    backgroundColor: AppTheme.primaryColor,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      } else {
                        // Large screens: Full horizontal layout
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Title
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'OyunLab',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                    fontSize: 28,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Oyun Alanı Takip',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.secondaryTextColor,
                                  ),
                                ),
                              ],
                            ),
                            // Buttons - Full size
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () async => await _showAddTableDialog(),
                                  icon: const Icon(Icons.table_restaurant_rounded, size: 20),
                                  label: const Text('Masa Ekle'),
                                  style: ElevatedButton.styleFrom(
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    backgroundColor: AppTheme.accentColor,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  onPressed: _showNewCustomerForm,
                                  icon: const Icon(Icons.add_rounded, size: 20),
                                  label: const Text('Yeni Kayıt'),
                                  style: ElevatedButton.styleFrom(
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    backgroundColor: AppTheme.primaryColor,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      }
                    },
                  ),

                  // Responsive Search Bar
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final screenWidth = constraints.maxWidth;
                      final isSmallScreen = screenWidth < 600;
                      
                      return Container(
                        height: isSmallScreen ? 50 : 45,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          decoration: InputDecoration(
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: Colors.grey.shade500,
                              size: isSmallScreen ? 22 : 20,
                            ),
                            hintText: 'İsim veya telefon numarası ara...',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: isSmallScreen ? 15 : 14,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          style: TextStyle(fontSize: isSmallScreen ? 15 : 14),
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Tek StreamBuilder ile hem header hem de liste
            Expanded(
              child: StreamBuilder<List<Customer>>(
                stream: _customersStream,
                builder: (context, snapshot) {
                  // Veri henüz yüklenmediyse, boş bir liste göster
                  final List<Customer> allCustomers = snapshot.data ?? [];

                  // Aktif müşteriler (isActive: true ve tamamlanmamış) - süresi biten çocuklar da gösterilsin
                  final activeCustomers = allCustomers
                      .where((customer) => 
                          customer.isActive && 
                          !customer.isCompleted)
                      .toList();

                  // Aktif çocuk sayısını childCount'a göre hesapla
                  int activeCount = 0;
                  for (var customer in activeCustomers) {
                    activeCount += customer.childCount;
                  }

                  return Column(
                    children: [
                      // Header with count
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 5, 20, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Aktif Çocuklar',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.people_alt_rounded,
                                    size: 16,
                                    color: AppTheme.primaryColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    activeCount.toString(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryColor,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Content area
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            // Hata durumunda hata mesajı göster
                            if (snapshot.hasError) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.error_outline_rounded,
                                      size: 48,
                                      color: AppTheme.secondaryColor,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Hata: ${snapshot.error}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: AppTheme.secondaryTextColor,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            if (activeCustomers.isEmpty) {
                              return _buildEmptyState();
                            }

                            // Filtrelemeyi uygula
                            final filteredCustomers = _filterCustomers(
                              activeCustomers,
                              _searchQuery,
                            );

                            if (filteredCustomers.isEmpty && _searchQuery.isNotEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.search_off,
                                      size: 50,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Aramanızla eşleşen müşteri bulunamadı',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return _buildCustomersList(filteredCustomers);
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
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
              color: AppTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.people_alt_outlined,
              size: 60,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Aktif Çocuk Bulunmuyor',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryTextColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Şu anda oyun alanında çocuk bulunmuyor',
            style: TextStyle(fontSize: 16, color: AppTheme.secondaryTextColor),
          ),
          const SizedBox(height: 8),
          Text(
            'Yeni bir kayıt eklemek için aşağıdaki butona tıklayabilirsiniz',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.secondaryTextColor.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _showNewCustomerForm,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Yeni Çocuk Ekle'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              elevation: 2,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomersList(List<Customer> customers) {
    // SADECE ANA MÜŞTERİLERİ GÖSTER - kardeşleri gösterme
    // Ana müşteri = bilet numarasına sahip ilk müşteri
    final Map<int, Customer> uniqueTickets = {};

    for (var customer in customers) {
      // Bu bilet numarası için zaten ana müşteri var mı?
      if (!uniqueTickets.containsKey(customer.ticketNumber)) {
        // İlk müşteriyi ana müşteri olarak kaydet
        uniqueTickets[customer.ticketNumber] = customer;
      }
    }

    // Tamamlanan müşterileri filtrele
    final activeUniqueTickets = Map.fromEntries(
        uniqueTickets.entries.where((entry) => !entry.value.isCompleted));

    // Sadece ana müşteriler için kart oluştur
    final List<Widget> cards = [];
    activeUniqueTickets.forEach((ticketNumber, primaryCustomer) {
      cards.add(
        CountdownCard(
          key: ValueKey('ticket-$ticketNumber'),
          customer: primaryCustomer,
          childCount: primaryCustomer.childCount, // Model'den al
          onTap: () => _showCustomerDetails(primaryCustomer),
        ),
      );
    });

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      children: cards,
    );
  }

  void _showCustomerDetails(Customer customer) {

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: const EdgeInsets.only(
                left: 24,
                right: 24,
                top: 16,
                bottom: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Başlık
                  Row(
                    children: [
                      Icon(
                        Icons.person_rounded,
                        color: AppTheme.primaryColor,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Çocuk Bilgileri',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Çocuk Bilgileri
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Avatar
                        Hero(
                          tag: 'avatar-${customer.id}',
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.primaryColor,
                                  AppTheme.primaryColor.withOpacity(0.7),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.person_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // İsim ve diğer bilgiler
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      customer.childName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withOpacity(
                                        0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '#${customer.ticketNumber}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),

                              // İki sütunlu bilgi düzeni
                              Row(
                                children: [
                                  // Sol sütun
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Veli: ${customer.parentName}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.secondaryTextColor,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.schedule_rounded,
                                              size: 12,
                                              color: AppTheme.accentColor,
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              '${customer.durationMinutes} dk',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: AppTheme.accentColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Sağ sütun
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.phone_outlined,
                                              size: 12,
                                              color:
                                                  AppTheme.secondaryTextColor,
                                            ),
                                            const SizedBox(width: 3),
                                            Expanded(
                                              child: Text(
                                                customer.phoneNumber,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      AppTheme
                                                          .secondaryTextColor,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.login_rounded,
                                              size: 12,
                                              color: Colors.green.shade600,
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              DateFormat(
                                                'HH:mm',
                                              ).format(customer.entryTime),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.green.shade600,
                                              ),
                                            ),
                                            const SizedBox(width: 5),
                                            Icon(
                                              Icons.logout_rounded,
                                              size: 12,
                                              color: Colors.red.shade600,
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              DateFormat(
                                                'HH:mm',
                                              ).format(customer.exitTime),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.red.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // İşlem Butonları Başlık
                  Row(
                    children: [
                      Icon(
                        Icons.settings_suggest_rounded,
                        color: AppTheme.primaryColor,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Hızlı İşlemler',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Süre Ekleme ve Teslim Etme
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.add_alarm_rounded,
                          label: 'Süre Ekle',
                          color: AppTheme.primaryColor,
                          onPressed: () => _showAddTimeDialog(customer),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.done_all_rounded,
                          label: 'Teslim Et',
                          color: Colors.green.shade600,
                          onPressed: () => _showDeliverConfirmation(customer),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Kardeş işlemleri ve İptal
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.person_add_rounded,
                          label: 'Kardeş Ekle',
                          color: AppTheme.accentColor,
                          onPressed: () => _showAddSiblingDialog(customer),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.person_remove_rounded,
                          label: 'Kardeş Çıkar',
                          color: Colors.orange.shade600,
                          onPressed: () => _showRemoveSiblingDialog(customer),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Duraklatma ve İptal Etme Butonları
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.pause_circle_outline_rounded,
                          label: 'Oyunu Duraklat',
                          color: Colors.blue.shade600,
                          onPressed: () => _togglePauseCustomer(customer),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.cancel_outlined,
                          label: 'İptal Et',
                          color: Colors.red.shade600,
                          onPressed: () => _showCancelConfirmation(customer),
                        ),
                      ),
                    ],
                  ),

                  // Süresi biten çocuklar için kartı kaldır butonu
                  if (customer.currentRemainingSeconds <= 0) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.delete_outline_rounded,
                            label: 'Kartı Kaldır',
                            color: Colors.red.shade700,
                            onPressed: () => _showRemoveCardConfirmation(customer),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Masa butonu (eğer masa varsa)
                  FutureBuilder<bool>(
                    future: _hasTable(customer),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox.shrink();
                      }
                      
                      final hasTable = snapshot.data ?? false;
                      
                      if (!hasTable) {
                        return const SizedBox.shrink();
                      }
                      
                      return Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              icon: Icons.table_restaurant_rounded,
                              label: 'Masaya Git',
                              color: Colors.purple.shade600,
                              onPressed: () => _goToTableScreen(customer),
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(child: SizedBox()), // Boş alan
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 28),

                  // Kapat butonu
                  SizedBox(
                    width: 200,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, size: 20),
                      label: const Text(
                        'Kapat',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        foregroundColor: Colors.grey.shade800,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: color.withOpacity(0.3), width: 1.5),
        ),
      ),
    );
  }

  // Süre Ekleme Dialog
  void _showAddTimeDialog(Customer customer) async {
    // İşletme ayarlarından süre seçeneklerini al
    final businessSettings = await _businessSettingsRepository.getBusinessSettingByCategory(BusinessCategory.oyunAlani);
    final durationOptions = businessSettings?.durationPrices.where((dp) => dp.isActive).toList() ?? 
        BusinessSettings.getDefaultDurationPrices(BusinessCategory.oyunAlani);
    
    int additionalMinutes = durationOptions.isNotEmpty ? durationOptions.first.duration : 30;
    double selectedPrice = durationOptions.isNotEmpty ? durationOptions.first.price : 1.0;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Süre Ekle'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Eklenecek süreyi seçin',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.secondaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '$additionalMinutes dakika',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () {
                          setState(() {
                            if (additionalMinutes > 5) {
                              additionalMinutes -= 5;
                            }
                          });
                        },
                        icon: const Icon(Icons.remove_circle_outline),
                        color: AppTheme.primaryColor,
                      ),
                      Slider(
                        value: additionalMinutes.toDouble(),
                        min: 5,
                        max: 180,
                        divisions: 35,
                        activeColor: AppTheme.primaryColor,
                        inactiveColor: AppTheme.primaryColor.withOpacity(0.2),
                        onChanged: (value) {
                          setState(() {
                            additionalMinutes = value.round();
                          });
                        },
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            if (additionalMinutes < 180) {
                              additionalMinutes += 5;
                            }
                          });
                        },
                        icon: const Icon(Icons.add_circle_outline),
                        color: AppTheme.primaryColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: durationOptions
                        .map(
                          (durationPrice) => ElevatedButton(
                            onPressed: () {
                              setState(() {
                                additionalMinutes = durationPrice.duration;
                                selectedPrice = durationPrice.price;
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  additionalMinutes == durationPrice.duration
                                      ? AppTheme.primaryColor
                                      : AppTheme.primaryColor.withOpacity(0.1),
                              foregroundColor:
                                  additionalMinutes == durationPrice.duration
                                      ? Colors.white
                                      : AppTheme.primaryColor,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${durationPrice.duration} dk'),
                                if (durationPrice.price > 0)
                                  Text(
                                    '${durationPrice.price.toStringAsFixed(0)}₺',
                                    style: const TextStyle(fontSize: 10),
                                  ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
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
                    // Süre ekleme işlemi
                    // Aynı bilet numarasına sahip tüm kardeşleri bul
                    final siblings =
                        widget.customerRepository.customers
                            .where(
                              (c) => c.ticketNumber == customer.ticketNumber,
                            )
                            .toList();

                    final int siblingCount = siblings.length;

                    // YENİ SİSTEM - Her bir kardeş için süreyi ekleyeceğiz
                    for (var sibling in siblings) {
                      final additionalSeconds = additionalMinutes * 60;
                      final updatedCustomer = sibling.copyWith(
                        totalSeconds: sibling.totalSeconds + additionalSeconds,
                        hasTimePurchase: true, // Süre satın alma işlemi yapıldı
                        purchasedSeconds: additionalSeconds, // Bu girişte satın alınan süre
                      );

                      widget.customerRepository.updateCustomer(updatedCustomer);
                    }

                    // Süre satın alma işlemini satışlara kaydet
                    await _createTimePurchaseSaleRecord(customer, additionalMinutes, siblingCount, selectedPrice);

                    Navigator.pop(context);

                    // Başarılı mesajı göster
                    final message =
                        siblingCount > 1
                            ? '$additionalMinutes dakika ${siblingCount} çocuğa eklendi'
                            : '$additionalMinutes dakika eklendi';

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(message),
                        backgroundColor: Colors.green.shade600,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                  ),
                  child: const Text('Ekle'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Kardeş Ekleme Dialog
  void _showAddSiblingDialog(Customer customer) {
    int siblingCount = 1; // Eklenecek kardeş sayısı

    // Mevcut kardeşleri bul (sadece tamamlanmamış olanlar)
    final currentSiblings =
        widget.customerRepository.customers
            .where((c) => c.ticketNumber == customer.ticketNumber && !c.isCompleted)
            .toList();

    // DEBUG: Hangi süreler alınıyor kontrol et
    print('=== DEBUG: KARDEŞ EKLEME DIALOG ===');
    print('Müşteri: ${customer.childName}');
    print('Bilet No: ${customer.ticketNumber}');
    
    int totalRemainingSeconds = 0;
    Map<String, int> siblingRemainingSeconds = {};
    for (final child in currentSiblings) {
      final childSeconds = child.currentRemainingSeconds;
      totalRemainingSeconds += childSeconds;
      siblingRemainingSeconds[child.id] = childSeconds;
      print('${child.childName}: $childSeconds saniye (${childSeconds ~/ 60}:${(childSeconds % 60).toString().padLeft(2, '0')})');
    }
    print('Toplam süre: $totalRemainingSeconds saniye (${totalRemainingSeconds ~/ 60}:${(totalRemainingSeconds % 60).toString().padLeft(2, '0')})');
    print('=====================================');

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Mevcut çocuk sayısını müşterinin childCount'undan al
            final currentChildCount = currentSiblings.isNotEmpty ? currentSiblings.first.childCount : 1;
            // Yeni kardeş sayısı dahil toplam çocuk sayısı
            final totalChildren = currentChildCount + siblingCount;
            
            // Debug: Hesaplama bilgilerini log'la
            print('DEBUG: Mevcut çocuk sayısı: $currentChildCount');
            print('DEBUG: Eklenecek çocuk sayısı: $siblingCount');
            print('DEBUG: Toplam çocuk sayısı: $totalChildren');

            // Kişi başı düşecek süre (saniye)
            final perChildSeconds = totalRemainingSeconds ~/ totalChildren;
            final perChildMinutes = perChildSeconds ~/ 60;
            final perChildRemainingSeconds = perChildSeconds % 60;



            return AlertDialog(
              title: const Text('Kardeş Ekle'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Kardeş sayısı seçici
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Eklenecek kardeş sayısı:',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.remove,
                                color: AppTheme.primaryColor,
                              ),
                              onPressed: () {
                                if (siblingCount > 1) {
                                  setState(() {
                                    siblingCount--;
                                  });
                                }
                              },
                              iconSize: 20,
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints.tight(Size(32, 32)),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                '$siblingCount',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.add,
                                color: AppTheme.primaryColor,
                              ),
                              onPressed: () {
                                if (siblingCount < 10) {
                                  setState(() {
                                    siblingCount++;
                                  });
                                }
                              },
                              iconSize: 20,
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints.tight(Size(32, 32)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Süre bilgisi
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Süre Bilgisi',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Mevcut aktif çocuk sayısı:',
                              style: TextStyle(fontSize: 13),
                            ),
                            Text(
                              '$currentChildCount',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Eklenecek çocuk sayısı:',
                              style: TextStyle(fontSize: 14),
                            ),
                            Text(
                              '$siblingCount',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Son durum çocuk sayısı:',
                              style: TextStyle(fontSize: 14),
                            ),
                            Text(
                              '$totalChildren',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Toplam kalan süre:',
                              style: TextStyle(fontSize: 13),
                            ),
                            Text(
                              '${totalRemainingSeconds ~/ 60} dk ${totalRemainingSeconds % 60} sn',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Kişi başı düşecek süre:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            Text(
                              '$perChildMinutes dk $perChildRemainingSeconds sn',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ],
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
                  onPressed: () {
                    // Mevcut çocuk sayısını müşterinin childCount'undan al
                    final currentChildCount = currentSiblings.isNotEmpty ? currentSiblings.first.childCount : 1;
                    // Son kez yeni çocuk sayısına göre süreyi hesapla
                    final totalChildren = currentChildCount + siblingCount;
                    final perChildSeconds = totalRemainingSeconds ~/ totalChildren;
                    
                    // Debug: Hesaplama bilgilerini log'la
                    print('DEBUG: Son hesaplama - Mevcut: $currentChildCount, Eklenecek: $siblingCount, Toplam: $totalChildren');
                    print('DEBUG: Toplam süre: $totalRemainingSeconds saniye, Kişi başı: $perChildSeconds saniye');

                    // YENİ SİSTEM - Mevcut kardeşlerin süresini güncelle (ana müşteri dahil)
                    for (var sibling in currentSiblings) {
                      // YENİ SİSTEM - TÜM KARDEŞLERİN childCount'ını güncelle
                      // Toplam süre değişmez, sadece childCount güncellenir
                      final updatedCustomer = sibling.copyWith(
                        childCount: totalChildren, // Doğru toplam çocuk sayısı
                        siblingIds: [...currentSiblings.map((s) => s.id), ...List.generate(siblingCount, (index) => 'temp_${index}')],
                        remainingMinutes: perChildSeconds ~/ 60, // Statik kalan süre güncelle
                        remainingSeconds: perChildSeconds % 60, // Statik kalan süre saniye güncelle
                      );
                      
                      // Debug: Güncellenen müşteri bilgilerini log'la
                      print('DEBUG: ${sibling.childName} güncellendi - Toplam süre: ${sibling.totalSeconds} saniye, Yeni childCount: $totalChildren');

                      widget.customerRepository.updateCustomer(updatedCustomer);
                    }

                    Navigator.pop(context);

                    // Başarılı mesajı göster
                    final childText = siblingCount == 1 ? 'kardeş' : 'kardeş';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$siblingCount $childText eklendi. Toplam çocuk sayısı: $totalChildren'),
                        backgroundColor: Colors.green.shade600,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentColor,
                  ),
                  child: const Text('Ekle'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Kardeş Çıkarma Dialog
  void _showRemoveSiblingDialog(Customer customer) {
    // Gerçek müşteri sayısını kontrol et
    final currentSiblings = widget.customerRepository.customers
        .where((c) => c.ticketNumber == customer.ticketNumber && !c.isCompleted)
        .toList();
    
    // Debug: Gerçek müşteri sayısını kontrol et
    print('DEBUG: Kardeş çıkarma kontrol:');
    print('  - childCount: ${customer.childCount}');
    print('  - Gerçek müşteri sayısı: ${currentSiblings.length}');
    
    // childCount'a göre kontrol et (çocuk sayısına göre)
    if (customer.childCount < 2) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Uyarı'),
            content: const Text('Kardeş yok'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tamam'),
              ),
            ],
          );
        },
      );
      return;
    }

    // Kardeş varsa detaylı dialog aç (kardeş ekleme gibi)
    int removeCount = 1; // Çıkarılacak kardeş sayısı
    
    // Toplam kalan süre hesapla
    int totalRemainingSeconds = 0;
    for (final child in currentSiblings) {
      totalRemainingSeconds += child.currentRemainingSeconds;
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Mevcut çocuk sayısı (childCount'dan al)
            final currentChildCount = customer.childCount;
            // Çıkarılacak çocuk sayısı
            final childrenToRemove = removeCount;
            // Kalan çocuk sayısı
            final remainingChildren = currentChildCount - childrenToRemove;
            
            // Kalan çocuklara düşecek süre (saniye) - ÇIKARMA MANTIĞI
            final perChildSeconds = remainingChildren > 0 ? totalRemainingSeconds ~/ remainingChildren : 0;
            final perChildMinutes = perChildSeconds ~/ 60;
            final perChildRemainingSeconds = perChildSeconds % 60;
            
            // Debug: Hesaplama bilgilerini log'la
            print('DEBUG: Kardeş çıkarma hesaplama:');
            print('  - Mevcut çocuk sayısı: $currentChildCount');
            print('  - Çıkarılacak çocuk sayısı: $childrenToRemove');
            print('  - Kalan çocuk sayısı: $remainingChildren');
            print('  - Toplam kalan süre: $totalRemainingSeconds saniye');
            print('  - Kalan çocuklara düşecek süre: $perChildSeconds saniye ($perChildMinutes dk $perChildRemainingSeconds sn)');

            return AlertDialog(
              title: const Text('Kardeş Çıkar'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Çıkarılacak kardeş sayısı seçici
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Çıkarılacak kardeş sayısı:',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.remove,
                                color: AppTheme.primaryColor,
                              ),
                              onPressed: () {
                                if (removeCount > 1) {
                                  setState(() {
                                    removeCount--;
                                  });
                                }
                              },
                              iconSize: 20,
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints.tight(Size(32, 32)),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                '$removeCount',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.add,
                                color: AppTheme.primaryColor,
                              ),
                              onPressed: () {
                                if (removeCount < currentChildCount - 1) {
                                  setState(() {
                                    removeCount++;
                                  });
                                }
                              },
                              iconSize: 20,
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints.tight(Size(32, 32)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Süre bilgisi
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Çıkarma Bilgisi',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Mevcut çocuk sayısı:',
                              style: TextStyle(fontSize: 13),
                            ),
                            Text(
                              '$currentChildCount',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Çıkarılacak çocuk sayısı:',
                              style: TextStyle(fontSize: 13),
                            ),
                            Text(
                              '$childrenToRemove',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Kalan çocuk sayısı:',
                              style: TextStyle(fontSize: 13),
                            ),
                            Text(
                              '$remainingChildren',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Toplam kalan süre:',
                              style: TextStyle(fontSize: 13),
                            ),
                            Text(
                              '${totalRemainingSeconds ~/ 60} dk ${totalRemainingSeconds % 60} sn',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (remainingChildren > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Kalan çocuklara düşecek süre:',
                                style: TextStyle(fontSize: 13),
                              ),
                              Text(
                                '$perChildMinutes dk $perChildRemainingSeconds sn',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
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
                    // Çıkarma işlemini yap
                    await _performSiblingRemoval(customer, removeCount, currentChildCount, totalRemainingSeconds);
                    Navigator.pop(context);
                  },
                  child: const Text('Çıkar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Kardeş çıkarma işlemi
  Future<void> _performSiblingRemoval(Customer customer, int removeCount, int currentChildCount, int totalRemainingSeconds) async {
    try {
      // Kalan çocuk sayısı
      final remainingChildren = currentChildCount - removeCount;
      
      // Kalan çocuklara düşecek süre
      final perChildSeconds = remainingChildren > 0 ? totalRemainingSeconds ~/ remainingChildren : 0;
      
      // Mevcut kardeşleri bul
      final currentSiblings = widget.customerRepository.customers
          .where((c) => c.ticketNumber == customer.ticketNumber && !c.isCompleted)
          .toList();
      
      if (remainingChildren <= 0) {
        // Tüm çocukları çıkar - hepsini tamamlandı olarak işaretle
        for (var sibling in currentSiblings) {
          await widget.customerRepository.completeCustomer(sibling.id);
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tüm çocuklar çıkarıldı'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      
      // Kalan çocukların süresini güncelle
      for (var sibling in currentSiblings) {
        // Geçen süre (giriş zamanından şu ana kadar)
        final elapsedTime = DateTime.now().difference(sibling.entryTime);
        
        // Yeni toplam süre = geçen süre + kişi başı kalan süre
        final newTotalSeconds = elapsedTime.inSeconds + perChildSeconds;
        
        final updatedCustomer = sibling.copyWith(
          totalSeconds: newTotalSeconds,
          childCount: remainingChildren,
          remainingMinutes: perChildSeconds ~/ 60,
          remainingSeconds: perChildSeconds % 60,
        );
        
        await widget.customerRepository.updateCustomer(updatedCustomer);
      }
      
      // Başarılı mesajı göster
      final perChildMinutes = perChildSeconds ~/ 60;
      final perChildRemainingSeconds = perChildSeconds % 60;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$removeCount çocuk çıkarıldı. Kalan ${remainingChildren} çocuğun süresi: $perChildMinutes dk $perChildRemainingSeconds sn'),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      
    } catch (e) {
      print('Kardeş çıkarma hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Çıkarma işlemi sırasında hata oluştu: $e'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // İptal Etme İşlemi
  void _showCancelConfirmation(Customer customer) {
    // Aynı bilet numarasına sahip tüm kardeşleri bul
    final allSiblings =
        widget.customerRepository.customers
            .where((c) => c.ticketNumber == customer.ticketNumber)
            .toList();

    final bool hasMultipleChildren = allSiblings.length > 1;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            hasMultipleChildren ? 'Kayıtları İptal Et' : 'Kaydı İptal Et',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasMultipleChildren)
                Text(
                  'Bilet #${customer.ticketNumber} numaralı ${allSiblings.length} çocuğun kaydını iptal etmek istiyor musunuz?',
                  style: const TextStyle(fontSize: 16),
                )
              else
                Text(
                  '${customer.childName} kaydını iptal etmek istiyor musunuz?',
                  style: const TextStyle(fontSize: 16),
                ),

              if (hasMultipleChildren) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'İptal Edilecek Kayıtlar',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...allSiblings
                          .map(
                            (sibling) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.person,
                                    size: 14,
                                    color: Colors.red.shade400,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      sibling.childName,
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),
              const Text(
                'Bu işlem geri alınamaz ve tüm kayıtlar iptal olarak işaretlenecek.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.secondaryTextColor,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Tüm kardeşleri iptal edildi olarak işaretle
                for (var sibling in allSiblings) {
                  // Eğer ücret alınmışsa mevcut satış kaydını iptal olarak güncelle
                  if (sibling.price > 0) {
                    await _updateSaleRecordAsCancelled(sibling);
                  }

                  // İptal edilen müşterinin kalan süresinden purchasedSeconds'i düş
                  await _handleCancelledCustomerTime(sibling);

                  // Yeni kullanıcı için kalan süreyi 0 yap
                  final samePhoneCustomers = widget.customerRepository.customers
                      .where((c) => c.phoneNumber == sibling.phoneNumber && c.id != sibling.id)
                      .toList();
                  
                  final isNewUser = samePhoneCustomers.isEmpty;
                  final remainingMinutes = isNewUser ? 0 : sibling.remainingMinutes;
                  final remainingSeconds = isNewUser ? 0 : sibling.remainingSeconds;

                  // İptal durumunu özel bir alan olarak ekleyelim - price alanını kullanarak
                  // price = -1 olan kayıtları iptal edilmiş olarak yorumlayabiliriz
                  final updatedCustomer = sibling.copyWith(
                    isPaused: false, // duraklatma durumunu kaldır
                    price: -1, // iptal işareti olarak negatif değer
                    remainingMinutes: remainingMinutes, // Yeni kullanıcı için 0, diğerleri için mevcut
                    remainingSeconds: remainingSeconds, // Yeni kullanıcı için 0, diğerleri için mevcut
                    isCompleted: true, // İptal edilen müşteri tamamlanmış olarak işaretle
                    completedTime: DateTime.now(), // Tamamlanma zamanı
                  );

                  // Güncellenmiş müşteriyi kaydet
                  await widget.customerRepository.updateCustomer(
                    updatedCustomer,
                  );

                  // Sonra tamamlandı olarak işaretle (isActive = false)
                  // completeCustomer metodu müşterinin aktif durumunu false yapıyor
                  print(
                    '${sibling.childName} iptal ediliyor, ID: ${sibling.id}',
                  );
                  await widget.customerRepository.completeCustomer(sibling.id);
                }

                Navigator.pop(context);
                Navigator.pop(context); // Detay sayfasını da kapat

                // Başarılı mesajı göster
                final message =
                    hasMultipleChildren
                        ? '${allSiblings.length} çocuğun kaydı iptal edildi'
                        : '${customer.childName} kaydı iptal edildi';

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message),
                    backgroundColor: Colors.orange.shade600,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('İptal Et'),
            ),
          ],
        );
      },
    );
  }

  // Teslim Etme İşlemi
  void _showDeliverConfirmation(Customer customer) {
    // Aynı bilet numarasına sahip tüm kardeşleri bul
    final allSiblings =
        widget.customerRepository.customers
            .where((c) => c.ticketNumber == customer.ticketNumber)
            .toList();

    final bool hasMultipleChildren = allSiblings.length > 1;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            hasMultipleChildren ? 'Çocukları Teslim Et' : 'Çocuğu Teslim Et',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasMultipleChildren)
                Text(
                  'Bilet #${customer.ticketNumber} numaralı ${allSiblings.length} çocuğu velisine teslim etmek istiyor musunuz?',
                  style: const TextStyle(fontSize: 16),
                )
              else
                Text(
                  '${customer.childName} isimli çocuğu velisine teslim etmek istiyor musunuz?',
                  style: const TextStyle(fontSize: 16),
                ),
              const SizedBox(height: 16),

              if (hasMultipleChildren)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Teslim Edilecek Çocuklar',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...allSiblings
                          .map(
                            (sibling) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withOpacity(
                                        0.1,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        sibling.childName
                                            .substring(0, 1)
                                            .toUpperCase(),
                                        style: TextStyle(
                                          color: AppTheme.primaryColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      sibling.childName,
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ),
                                  Text(
                                    '${sibling.currentRemainingSecondsPerChild ~/ 60} dk',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ],
                  ),
                ),

              const SizedBox(height: 16),
              const Text(
                'Kalan süre silinecek ve çocuk aktif listeden çıkarılacak.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.secondaryTextColor,
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
                // Tüm kardeşleri tamamlandı olarak işaretle
                for (var sibling in allSiblings) {
                  // Doğrudan silmek yerine aktif durumunu değiştir (tamamlandı işaretle)
                  print(
                    '${sibling.childName} teslim ediliyor, ID: ${sibling.id}',
                  );
                  await widget.customerRepository.completeCustomer(sibling.id);
                }

                Navigator.pop(context);
                Navigator.pop(context); // Detay sayfasını da kapat

                // Başarılı mesajı göster
                final message =
                    hasMultipleChildren
                        ? '${allSiblings.length} çocuk teslim edildi'
                        : '${customer.childName} teslim edildi';

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message),
                    backgroundColor: Colors.green.shade600,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('Teslim Et'),
            ),
          ],
        );
      },
    );
  }

  // Duraklatma İşlemi
  void _togglePauseCustomer(Customer customer) {
    // Aynı bilet numarasına sahip tüm kardeşleri bul
    final siblings =
        widget.customerRepository.customers
            .where((c) => c.ticketNumber == customer.ticketNumber)
            .toList();

    // Müşteri şu anda duraklatılmış mı kontrol et
    final bool isPaused = customer.isPaused;

    final String actionText = isPaused ? 'Devam Ettir' : 'Duraklat';
    final String dialogTitle =
        isPaused ? 'Oyunu Devam Ettir' : 'Oyunu Duraklat';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(dialogTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                siblings.length > 1
                    ? '${siblings.length} çocuğun oyununu ${isPaused ? 'devam ettirmek' : 'duraklatmak'} istiyor musunuz?'
                    : '${customer.childName} isimli çocuğun oyununu ${isPaused ? 'devam ettirmek' : 'duraklatmak'} istiyor musunuz?',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isPaused
                              ? Icons.play_circle_outline
                              : Icons.pause_circle_outline,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isPaused ? 'Devam Ettirilecek' : 'Duraklatılacak',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isPaused
                          ? 'Süre tekrar işlemeye devam edecek.'
                          : 'Duraklatma sırasında süre işlemeyecek ve çocuk oyun alanını terk edebilir.',
                      style: TextStyle(fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
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
              onPressed: () {
                // Duraklatma/devam ettirme işlemini uygula
                for (var sibling in siblings) {
                  Duration? newPausedDuration;
                  DateTime? newPauseTime;

                  if (isPaused) {
                    // Devam ettirme - duraklatma süresini hesapla
                    if (sibling.pauseStartTime != null) {
                      final pauseDuration = DateTime.now().difference(
                        sibling.pauseStartTime!,
                      );
                      // Önceki duraklatmalardan gelen sürelerle topla
                      newPausedDuration = Duration(seconds: sibling.pausedSeconds + pauseDuration.inSeconds);
                    }
                    newPauseTime = null; // Devam ettirince duraklatma zamanı silinir
                  } else {
                    // Duraklatma - şu anki zamanı kaydet
                    newPauseTime = DateTime.now();
                    newPausedDuration = Duration(seconds: sibling.pausedSeconds); // Değişmez
                  }

                  final updatedCustomer = sibling.copyWith(
                    isPaused: !isPaused,
                    pauseStartTime: newPauseTime,
                    pausedSeconds: newPausedDuration?.inSeconds ?? sibling.pausedSeconds,
                  );

                  widget.customerRepository.updateCustomer(updatedCustomer);
                }

                Navigator.pop(context);
                Navigator.pop(context); // Detay sayfasını kapat

                // Başarılı bildirimi göster
                final actionDone = isPaused ? 'devam ettirildi' : 'duraklatıldı';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Oyun $actionDone'),
                    backgroundColor: Colors.green.shade600,
                    behavior: SnackBarBehavior.floating,
                  ),
                );

              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
              ),
              child: Text(actionText),
            ),
          ],
        );
      },
    );
  }



  // Profil ekranındaki satışları güncelle
  void _notifySalesUpdate() {
    try {
      // ProfileScreen'deki static metodu çağır
      // Bu import edilmeli ama şimdilik sadece log
      print('📊 Satış güncellemesi bildirildi - Profil ekranı güncellenmeli');
    } catch (e) {
      print('Satış güncellemesi bildirilirken hata: $e');
    }
  }

  // Mevcut satış kaydını iptal olarak güncelle
  Future<void> _updateSaleRecordAsCancelled(Customer customer) async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        print('❌ Firebase kullanıcısı bulunamadı');
        return;
      }
      
      print('🔄 Satış kaydı aranıyor: ${customer.childName}');
      
      // Müşteri adına göre satış kaydını bul
      final sales = await _saleService.getUserSales(firebaseUser.uid);
      print('📊 Toplam satış kaydı: ${sales.length}');
      
      // Müşteri adı ve telefon numarasına göre satış kaydını bul
      final matchingSales = sales.where(
        (sale) => sale.customerName == customer.childName && 
                  sale.customerPhone == customer.phoneNumber &&
                  sale.amount > 0 && 
                  sale.status != 'İptal Edildi',
      ).toList();
      
      if (matchingSales.isEmpty) {
        print('❌ Eşleşen satış kaydı bulunamadı: ${customer.childName}');
        return;
      }
      
      // En son satış kaydını al (en yeni tarihli)
      final matchingSale = matchingSales.reduce((a, b) => 
        a.date.isAfter(b.date) ? a : b
      );
      
      print('✅ Satış kaydı bulundu: ${matchingSale.id} - ${matchingSale.amount}₺');
      
      // Satış kaydını iptal olarak güncelle - amount'u koruyarak orijinal tutarı göster
      final updatedSale = matchingSale.copyWith(
        status: 'İptal Edildi',
        updatedAt: DateTime.now(),
      );
      
      final result = await _saleService.updateSale(updatedSale);
      if (result != null) {
        print('✅ Satış kaydı iptal olarak güncellendi: ${customer.childName}');
        print('   - Bilet numarası: ${customer.ticketNumber}');
        print('   - Güncellenmiş satış ID: ${result.id}');
        print('   - Güncellenmiş durum: ${result.status}');
        print('   - Güncellenmiş tutar: ${result.amount}₺');
      } else {
        print('❌ Satış kaydı güncellenemedi: ${customer.childName}');
      }
    } catch (e) {
      print('❌ Satış kaydı güncellenirken hata: $e');
    }
  }

  // İptal edilen müşterinin kalan süresinden purchasedSeconds'i düş
  Future<void> _handleCancelledCustomerTime(Customer customer) async {
    try {
      // Eğer bu girişte süre satın alınmışsa (purchasedSeconds > 0)
      if (customer.purchasedSeconds > 0) {
        print('İptal edilen müşteri için kalan süre düzenleniyor: ${customer.childName}');
        print('Satın alınan süre: ${customer.purchasedSeconds} saniye');
        
        // Aynı telefon numarasına sahip diğer müşterileri bul
        final samePhoneCustomers = widget.customerRepository.customers
            .where((c) => c.phoneNumber == customer.phoneNumber && c.id != customer.id)
            .toList();
        
        if (samePhoneCustomers.isNotEmpty) {
          // En son giriş yapan müşteriyi bul (en büyük ticketNumber)
          final latestCustomer = samePhoneCustomers
              .reduce((a, b) => a.ticketNumber > b.ticketNumber ? a : b);
          
          print('En son giriş yapan müşteri bulundu: ${latestCustomer.childName} (Bilet #${latestCustomer.ticketNumber})');
          
          // Kalan süreden purchasedSeconds'i düş
          final currentRemainingSeconds = latestCustomer.currentRemainingSeconds;
          final newRemainingSeconds = currentRemainingSeconds - customer.purchasedSeconds;
          
          // Negatif olmaması için kontrol et
          final finalRemainingSeconds = newRemainingSeconds > 0 ? newRemainingSeconds : 0;
          
          print('Eski kalan süre: ${currentRemainingSeconds} saniye');
          print('Yeni kalan süre: ${finalRemainingSeconds} saniye');
          
          // Müşteriyi güncelle
          final updatedCustomer = latestCustomer.copyWith(
            remainingMinutes: finalRemainingSeconds ~/ 60,
            remainingSeconds: finalRemainingSeconds % 60,
          );
          
          await widget.customerRepository.updateCustomer(updatedCustomer);
          print('✅ Kalan süre güncellendi: ${finalRemainingSeconds} saniye');
        } else {
          // Yeni kullanıcı için aynı telefon numarasına sahip başka müşteri yok
          // Bu durumda iptal edilen müşterinin kendisinin kalan süresini 0 yap
          print('Yeni kullanıcı - iptal edilen müşterinin kalan süresi 0 yapılacak');
          
          // İptal edilen müşterinin kalan süresini 0 yap
          final updatedCustomer = customer.copyWith(
            remainingMinutes: 0,
            remainingSeconds: 0,
          );
          
          await widget.customerRepository.updateCustomer(updatedCustomer);
          print('✅ İptal edilen müşterinin kalan süresi 0 yapıldı');
        }
      } else {
        print('Bu girişte süre satın alınmamış, kalan süre düzenlenmeyecek');
      }
    } catch (e) {
      print('İptal edilen müşteri süre düzenlenirken hata: $e');
    }
  }



  // Süre satın alma satış kaydı oluştur
  Future<void> _createTimePurchaseSaleRecord(Customer customer, int additionalMinutes, int siblingCount, double pricePerMinute) async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) return;

      // Süre satın alma fiyatını hesapla
      final double totalAmount = pricePerMinute * siblingCount;

      final saleRecord = SaleRecord(
        id: '', // Firestore otomatik oluşturacak
        userId: firebaseUser.uid,
        userName: firebaseUser.displayName ?? firebaseUser.email?.split('@')[0] ?? 'Kullanıcı',
        customerName: customer.childName,
        amount: totalAmount,
        description: 'Süre Satın Alma - ${additionalMinutes} dakika ${siblingCount > 1 ? '($siblingCount çocuk)' : ''}',
        date: DateTime.now(),
        customerPhone: customer.phoneNumber,
        customerEmail: null,
        items: ['Süre Satın Alma - ${additionalMinutes} dakika'],
        paymentMethod: 'Nakit',
        status: 'Tamamlandı',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await _saleService.createSale(saleRecord);
      if (result != null) {
        print('✅ Süre satın alma satış kaydı oluşturuldu: ${customer.childName}');
        print('   - Tutar: ${totalAmount}₺');
        print('   - Süre: ${additionalMinutes} dakika');
        print('   - Çocuk sayısı: $siblingCount');
        print('   - Satış ID: ${result.id}');
        
        // Profil ekranındaki satışları güncelle
        _notifySalesUpdate();
      } else {
        print('❌ Süre satın alma satış kaydı oluşturulamadı');
      }
    } catch (e) {
      print('Süre satın alma satış kaydı oluşturulurken hata: $e');
    }
  }

  // Kartı kaldır onay dialog'u
  void _showRemoveCardConfirmation(Customer customer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.red.shade600,
              size: 24,
            ),
            const SizedBox(width: 8),
            const Text('Kartı Kaldır'),
          ],
        ),
        content: Text(
          '${customer.childName} adlı çocuğun kartını kaldırmak istediğinizden emin misiniz?\n\nBu işlem geri alınamaz.',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'İptal',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _removeCustomerCard(customer);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Kartı Kaldır'),
          ),
        ],
      ),
    );
  }

  // Müşteri kartını kaldır
  Future<void> _removeCustomerCard(Customer customer) async {
    try {
      print('🗑️ Kart kaldırma işlemi başlatılıyor: ${customer.childName}');
      
      // Müşteriyi tamamlanmış olarak işaretle
      await widget.customerRepository.completeCustomer(customer.id);
      
      print('✅ Kart başarıyla kaldırıldı: ${customer.childName}');
      
      // Başarı mesajı göster
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${customer.childName} adlı çocuğun kartı kaldırıldı'),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Kart kaldırma hatası: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kart kaldırılırken hata oluştu: $e'),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Müşteri filtreleme fonksiyonu
  List<Customer> _filterCustomers(List<Customer> customers, String query) {
    if (query.isEmpty) {
      return customers;
    }

    query = query.toLowerCase();

    return customers.where((customer) {
      return customer.childName.toLowerCase().contains(query) ||
          customer.parentName.toLowerCase().contains(query) ||
          customer.phoneNumber.contains(query);
    }).toList();
  }
}
