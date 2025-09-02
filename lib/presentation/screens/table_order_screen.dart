import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/customer_model.dart';
import '../../data/models/order_model.dart';
import '../../data/models/table_order_model.dart';
import '../../data/models/sale_record_model.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/services/sale_service.dart';
import '../../data/models/order_model.dart' show getCategoryTitle;
import '../screens/menu_management_screen.dart';
import 'dart:io';
import 'dart:async';
import '../../data/repositories/menu_repository.dart';
import '../../data/repositories/table_order_repository.dart';
import 'package:flutter/services.dart';

class TableOrderScreen extends StatefulWidget {
  final CustomerRepository customerRepository;

  const TableOrderScreen({super.key, required this.customerRepository});

  @override
  State<TableOrderScreen> createState() => _TableOrderScreenState();
}

class _TableOrderScreenState extends State<TableOrderScreen>
    with SingleTickerProviderStateMixin {
  List<TableOrder> _tableOrders = [];
  int _nextTableNumber = 1;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final MenuRepository _menuRepository = MenuRepository();
  final TableOrderRepository _tableOrderRepository = TableOrderRepository();
  final SaleService _saleService = SaleService();
  late TabController _tabController;
  List<ProductItem> products = [];
  bool isLoading = true;
  Timer? _tableRefreshTimer;

  @override
  void initState() {
    super.initState();
    // Menü repository'den verileri yeniden yükle
    _loadProducts();

    _tabController = TabController(
      length: ProductCategory.values.length,
      vsync: this,
    );

    // Menü öğelerini yükle
    _loadMenuItems();

    // Firebase'den masa verileri yükle
    _loadTablesFromFirebase();

    // Masa değişikliklerini dinle
    _tableOrderRepository.tablesStream.listen((tables) {
      if (mounted) {
        setState(() {
          // Firebase'den gelen masaları doğrudan kullan
          _tableOrders = tables;
        });
      }
    });

    // Her 2 saniyede bir masa verilerini yenile (daha güvenli)
    _tableRefreshTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        _loadTablesFromFirebase();
      }
    });

    // Her gün masa numaralarını sıfırla
    _checkAndResetTableNumbers();
  }

  // Firebase'den masaları yükle
  Future<void> _loadTablesFromFirebase() async {
    try {
      final tables = await _tableOrderRepository.getAllTables();
      if (mounted) {
        setState(() {
          // Firebase'den gelen masaları doğrudan kullan
          _tableOrders = tables;
        });
      }
    } catch (e) {
      print("Masa yükleme hatası: $e");
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



  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _tableRefreshTimer?.cancel();
    super.dispose();
  }

  // Menüyü yükle
  Future<void> _loadProducts() async {
    try {
      await _menuRepository.loadMenuItems();

      if (mounted) {
        setState(() {
          // Sessizce menüyü güncelle, bildirim gösterme
        });
      }
    } catch (e) {
      print("Menü yükleme hatası: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Menü yüklenirken hata oluştu: $e"),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Tekrar Dene',
              onPressed: _loadProducts,
              textColor: Colors.white,
            ),
          ),
        );
      }
    }
  }

  // Menü öğelerini yükle
  Future<void> _loadMenuItems() async {
    try {
      await _menuRepository.loadMenuItems();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print("Menü yükleme hatası: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Menü yüklenirken hata oluştu: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Aktif müşterilerden masa oluştur - ARTIK KULLANILMIYOR
  void _initializeTablesFromCustomers() {
    // Otomatik masa oluşturma kaldırıldı
    // Artık sadece manuel olarak masa eklenebilir
  }

  // Müşterilerden masaları güncelle - ARTIK KULLANILMIYOR
  void _updateTablesFromCustomers(List<Customer> customers) {
    // Otomatik masa güncelleme kaldırıldı
    // Artık sadece manuel masalar korunuyor
  }

  // Sonraki masa numarasını al (manuel masalar için)
  Future<int> _getNextTableNumber() async {
    // Her gün masa numaralarını sıfırla
    await _checkAndResetTableNumbers();
    
    // Manuel masalar için 1'den başlayan numaralar kullan
    const int manualBaseNumber = 1;

    if (_tableOrders.isEmpty) {
      return manualBaseNumber;
    }

    // Sadece manuel masaların numaralarını al
    final manualTableNumbers = _tableOrders
        .where((t) => t.isManual)
        .map((t) => t.tableNumber)
        .toList();

    if (manualTableNumbers.isEmpty) {
      return manualBaseNumber;
    }

    final maxTableNumber = manualTableNumbers.reduce(
      (max, number) => number > max ? number : max,
    );
    return maxTableNumber + 1;
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
        ticketNumber: customer.ticketNumber,
        childCount: siblings.length,
        isManual: false, // Müşteri kaydından otomatik oluşturulan masa
      );

      // Firebase'e ekle
      await _tableOrderRepository.addTable(newTable);

      // UI'ı güncelle
      setState(() {
        _tableOrders.add(newTable);
        _tableOrders.sort((a, b) => a.tableNumber.compareTo(b.tableNumber));
      });

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
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  _addManualTable(nameController.text.trim());
                  Navigator.pop(context);
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

  // Manuel masa ekle
  Future<void> _addManualTable(String customerName) async {
    final nextTableNumber = await _getNextTableNumber();
    
    final newTable = TableOrder(
      tableNumber: nextTableNumber,
      customerName: customerName,
      ticketNumber: 0, // Manuel masalar için 0 değeri
      childCount: 1, // Varsayılan olarak 1 çocuk
      isManual: true, // Manuel olarak işaretle
    );

    setState(() {
      _tableOrders.add(newTable);
      _tableOrders.sort((a, b) => a.tableNumber.compareTo(b.tableNumber));
    });

    // Firebase'e de ekle
    await _tableOrderRepository.addTable(newTable);
  }

  // Masa ekleme dialog'u
  Future<void> _showAddTableDialog() async {
    // Firebase'den güncel müşteri listesini al
    List<Customer> customers = [];
    try {
      customers = await widget.customerRepository.getActiveCustomers();
      print('TABLE_ORDER_SCREEN: Masa ekleme dialog\'unda ${customers.length} aktif müşteri bulundu');
    } catch (e) {
      print('TABLE_ORDER_SCREEN: Aktif müşteriler alınamadı: $e');
      // Hata durumunda repository'deki listeyi kullan
      customers = widget.customerRepository.customers;
    }
    
    // Firebase'den mevcut masaları al
    List<TableOrder> existingTables = [];
    try {
      existingTables = await _tableOrderRepository.getAllTables();
    } catch (e) {
      print('Masa bilgileri alınamadı: $e');
    }
    
    // Masası olmayan aktif çocukları bul
    final customersWithoutTable = customers.where((customer) {
      // Aktif olan çocuklar
      if (customer.remainingTime.inSeconds <= 0 || customer.ticketNumber <= 0) {
        return false;
      }
      
      // Bu bilet numarası için zaten masa var mı kontrol et
      final hasTable = existingTables.any((table) => 
        table.ticketNumber == customer.ticketNumber
      );
      
      return !hasTable; // Masası olmayan çocukları döndür
    }).toList();

    // Debug: Bilet numaralarını log'la
    print('TABLE_ORDER_SCREEN: Masa ekleme dialog\'unda bulunan müşteriler:');
    for (final customer in customersWithoutTable) {
      print('TABLE_ORDER_SCREEN: ${customer.childName} - Bilet: ${customer.ticketNumber}');
    }

    if (!mounted) return;

    setState(() {
      // UI'ı güncelle
    });

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
                                  'Kalan: ${customer.explicitRemainingMinutes ?? customer.remainingTime.inMinutes} dk',
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
  }

  // Masa silme
  void _deleteTable(TableOrder table) async {
    try {
      // Masa silinmeden önce ürünleri stoğa geri ekle
      await _restoreProductsToStock(table.orders);
      
      // Firebase'den sil
      await _tableOrderRepository.deleteTable(table.tableNumber);

      // UI'dan kaldır
      setState(() {
        _tableOrders.remove(table);
      });

      // Başarı mesajı
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Masa #${table.tableNumber} silindi ve ürünler stoğa geri eklendi'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('Masa silinirken hata: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Masa silinirken hata: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Ürünleri stoğa geri ekle
  Future<void> _restoreProductsToStock(List<Order> orders) async {
    try {
      for (final order in orders) {
        // Menü öğelerinden bu ürünü bul
        final menuItems = _menuRepository.menuItems;
        final product = menuItems.firstWhere(
          (item) => item.name == order.productName,
          orElse: () => throw Exception('Ürün bulunamadı: ${order.productName}'),
        );

        // Stoğu geri ekle
        final newStock = product.stock + order.quantity;
        await _menuRepository.updateProductStock(product.id, newStock);
        
        print('Stok geri eklendi: ${product.name} - Yeni stok: $newStock');
      }
    } catch (e) {
      print('Ürünler stoğa geri eklenirken hata: $e');
      throw e;
    }
  }

  // Sipariş ekleme
  void _addOrderToTable(TableOrder table, Order order) async {
    print('🔄 Sipariş ekleniyor: ${order.productName} x${order.quantity} (ID: ${order.id})');
    print('   Masa #${table.tableNumber} - Mevcut sipariş sayısı: ${table.orders.length}');
    
    // Önce mevcut masa verisini al (güncel olanı)
    final currentTableIndex = _tableOrders.indexWhere(
      (t) => t.tableNumber == table.tableNumber,
    );
    
    final currentTable = currentTableIndex != -1 ? _tableOrders[currentTableIndex] : table;
    print('   Güncel masa verisi alındı: ${currentTable.orders.length} sipariş');
    
    // Aynı ürün zaten masada var mı kontrol et
    final existingOrderIndex = currentTable.orders.indexWhere(
      (existingOrder) => existingOrder.productName == order.productName,
    );
    
    TableOrder updatedTable;
    if (existingOrderIndex != -1) {
      // Aynı ürün zaten var, miktarını artır
      final existingOrder = currentTable.orders[existingOrderIndex];
      final updatedOrder = existingOrder.copyWith(
        quantity: existingOrder.quantity + order.quantity,
      );
      
      // Siparişi güncelle
      updatedTable = currentTable.updateOrder(updatedOrder);
      print('   Mevcut ürün miktarı artırıldı: ${order.productName} ${existingOrder.quantity} + ${order.quantity} = ${updatedOrder.quantity}');
    } else {
      // Yeni ürün ekle
      updatedTable = currentTable.addOrder(order);
      print('   Yeni ürün eklendi: ${order.productName} x${order.quantity}');
    }
    
    print('   Yeni sipariş sayısı: ${updatedTable.orders.length}');
    for (var o in updatedTable.orders) {
      print('     - ${o.productName} x${o.quantity} (ID: ${o.id})');
    }

    setState(() {
      if (currentTableIndex != -1) {
        _tableOrders[currentTableIndex] = updatedTable;
        print('   Masa listesi güncellendi: index $currentTableIndex');
      } else {
        _tableOrders.add(updatedTable);
        print('   Yeni masa eklendi');
      }
    });

    // Firebase'de güncelle
    await _tableOrderRepository.updateTable(updatedTable);
    
    print('✅ Firebase güncellendi: #${table.tableNumber} - Sipariş: ${order.productName} x${order.quantity}');
    
    // Başarı mesajı göster
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${order.productName} x${order.quantity} masaya eklendi'),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Sipariş tamamlama
  void _completeOrder(TableOrder table, String orderId) {
    final updatedTable = table.completeOrder(orderId);

    setState(() {
      final index = _tableOrders.indexWhere(
        (t) => t.tableNumber == table.tableNumber,
      );
      if (index != -1) {
        _tableOrders[index] = updatedTable;
      }
    });

    // Firebase'de güncelle
    _tableOrderRepository.updateTable(updatedTable);
  }

  // Sipariş silme
  void _removeOrder(TableOrder table, String orderId) {
    final updatedTable = table.removeOrder(orderId);

    setState(() {
      final index = _tableOrders.indexWhere(
        (t) => t.tableNumber == table.tableNumber,
      );
      if (index != -1) {
        _tableOrders[index] = updatedTable;
      }
    });

    // Firebase'de güncelle
    _tableOrderRepository.updateTable(updatedTable);
  }

  // Masa detayı ve sipariş ekleme sayfasını göster
  void _showTableDetail(TableOrder table) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TableDetailScreen(
          table: table,
          onAddOrder: (order) => _addOrderToTable(table, order),
          onCompleteOrder: (orderId) => _completeOrder(table, orderId),
          onRemoveOrder: (orderId) => _removeOrder(table, orderId),
          onDeleteTable: _deleteTable,
          getCurrentTable: () => _tableOrders.firstWhere(
            (t) => t.tableNumber == table.tableNumber,
            orElse: () => table,
          ),
        ),
      ),
    );
  }

  // Filtrelenmiş masaları al
  List<TableOrder> get _filteredTables {
    if (_searchQuery.isEmpty) {
      return _tableOrders;
    }

    return _tableOrders.where((table) {
      return table.customerName.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ||
          table.tableNumber.toString().contains(_searchQuery);
    }).toList();
  }

  // Sadece aktif masaları al
  List<TableOrder> get _activeTables =>
      _filteredTables.where((table) => table.isActive).toList();

  // Menü düzenleme ekranını göster ve geri dönünce ürünleri güncelle
  void _showMenuManagementDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MenuManagementScreen()),
    ).then((_) async {
      // Menü ekranından dönünce menü öğelerini tekrar yükle ve UI'ı güncelle
      await _loadMenuItems(); // Yeniden menüyü yükle
      setState(() {
        // UI'ı güncelle
      });
    });
  }

  // Kategori simgesini döndür
  IconData _getCategoryIcon(ProductCategory category) {
    switch (category) {
      case ProductCategory.food:
        return Icons.fastfood;
      case ProductCategory.drink:
        return Icons.local_drink;
      case ProductCategory.dessert:
        return Icons.cake;
      case ProductCategory.toy:
        return Icons.toys;
      case ProductCategory.game:
        return Icons.gamepad;
      case ProductCategory.coding:
        return Icons.code;
      case ProductCategory.other:
        return Icons.more_horiz;
    }
  }

  // Kategori öğelerini gösteren diyalog
  void _showCategoryItemsDialog(ProductCategory category) {
    final items = menuItems.where((item) => item.category == category).toList();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(_getCategoryIcon(category), color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(getCategoryTitle(category)),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  title: Text(item.name),
                  subtitle: Text('${item.price.toStringAsFixed(2)} ₺'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      // Ürün düzenleme fonksiyonu eklenebilir
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kapat'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Yeni Ürün'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                // Yeni ürün ekleme fonksiyonu eklenebilir
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeTables = _activeTables;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Başlık ve Arama
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Masa Siparişleri',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.table_restaurant_rounded,
                              size: 14,
                              color: AppTheme.accentColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Toplam ${_tableOrders.length} masa',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.secondaryTextColor,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Icon(
                              Icons.room_service_rounded,
                              size: 14,
                              color: AppTheme.accentColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${_tableOrders.fold<int>(0, (sum, table) => sum + table.orders.length)} sipariş',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Menü Düzenleme Butonu
                  IconButton(
                    onPressed: _showMenuManagementDialog,
                    icon: const Icon(Icons.restaurant_menu),
                    tooltip: 'Menüyü Düzenle',
                    color: AppTheme.accentColor,
                  ),
                  const SizedBox(width: 8),
                  // Masa Ekleme Butonu
                  ElevatedButton.icon(
                    onPressed: _showAddTableDialog,
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
                ],
              ),

              // Menü veritabanı durum göstergesi
              if (false) // isOfflineMode kaldırıldığı için koşulu devre dışı bırakıyorum
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.orange.shade300,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange.shade800,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Menü verileri çevrimdışı modda.',
                          style: TextStyle(
                            color: Colors.orange.shade900,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          await _loadProducts();
                          setState(() {});
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 30),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Yeniden Dene',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // Arama çubuğu
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
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
                    hintText: 'Sipariş ara...',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),

              // Sipariş sayısı
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.receipt_long,
                      size: 18,
                      color: Colors.grey.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Siparişler ${_filteredTables.length}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),

              // Sipariş listesi
              Expanded(
                child: _filteredTables.isEmpty
                    ? _buildEmptyState()
                    : _buildTablesGrid(_filteredTables),
              ),
            ],
          ),
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
              Icons.table_restaurant,
              size: 60,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Aktif Masa Bulunmuyor',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryTextColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Şu anda hiç aktif masa siparişi bulunmuyor',
            style: TextStyle(fontSize: 16, color: AppTheme.secondaryTextColor),
          ),
          const SizedBox(height: 8),
          Text(
            'Yeni bir masa eklemek için aşağıdaki butona tıklayabilirsiniz',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.secondaryTextColor.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _showAddTableDialog,
            icon: const Icon(Icons.table_restaurant_rounded, size: 20),
            label: const Text('Masa Ekle'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentColor,
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

  Widget _buildTablesGrid(List<TableOrder> tables) {
    return GridView.builder(
      key: ValueKey('tables_grid_${tables.length}'), // TableOrder için uygun key
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // 2x2 grid
        childAspectRatio: 0.85, // kart boyut oranı
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: tables.length,
      itemBuilder: (context, index) {
        return _buildTableCard(tables[index]);
      },
    );
  }

  Widget _buildTableCard(TableOrder table) {
    final bool isManual = table.isManual;
    final hasOrders = table.orders.isNotEmpty;
    final hasActiveOrders = table.hasActiveOrders;

    // Kart rengi
    Color accentColor = isManual ? Colors.orange : AppTheme.primaryColor;
    if (hasActiveOrders) {
      accentColor = Colors.green.shade600;
    }

    return GestureDetector(
      onTap: () => _showTableDetail(table),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: accentColor.withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst kısım - Masa no ve isim
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
              ),
              child: Row(
                children: [
                  // Masa numarası
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        table.tableNumber.toString(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Müşteri ismi
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          table.customerName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: [
                            Icon(
                              Icons.people,
                              size: 12,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${table.childCount} çocuk',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Manuel işareti
                  if (isManual)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'M',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Orta kısım - Sipariş bilgileri
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: hasOrders
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Sipariş sayısı
                          Row(
                            children: [
                              Icon(
                                Icons.receipt_long,
                                size: 14,
                                color: hasActiveOrders
                                    ? Colors.green.shade600
                                    : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${table.orders.length} sipariş',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: hasActiveOrders
                                      ? Colors.green.shade600
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Son 2 sipariş
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: table.orders.take(3).map((order) {
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: 6,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: order.isCompleted
                                                ? Colors.grey
                                                : Colors.green,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            '${order.quantity}x ${order.productName}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: order.isCompleted
                                                  ? Colors.grey
                                                  : Colors.black87,
                                              decoration: order.isCompleted
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.room_service_outlined,
                              size: 28,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Henüz sipariş yok',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
              ),
            ),

            // Alt kısım - Toplam tutar ve Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(14),
                ),
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200, width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Toplam tutar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Toplam',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      Text(
                        '${table.totalOrderAmount.toStringAsFixed(2)} ₺',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: hasOrders
                              ? Colors.green.shade700
                              : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),

                  // Sipariş butonu
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: hasOrders
                          ? Colors.green.shade50
                          : AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          hasOrders
                              ? Icons.visibility
                              : Icons.add_shopping_cart,
                          size: 14,
                          color: hasOrders
                              ? Colors.green.shade700
                              : AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          hasOrders ? 'Detay' : 'Sipariş',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: hasOrders
                                ? Colors.green.shade700
                                : AppTheme.primaryColor,
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
  }
}

// Masa Detay Ekranı
class TableDetailScreen extends StatefulWidget {
  final TableOrder table;
  final Function(Order) onAddOrder;
  final Function(String) onCompleteOrder;
  final Function(String) onRemoveOrder;
  final Function(TableOrder) onDeleteTable;
  final Function() getCurrentTable;

  const TableDetailScreen({
    Key? key,
    required this.table,
    required this.onAddOrder,
    required this.onCompleteOrder,
    required this.onRemoveOrder,
    required this.onDeleteTable,
    required this.getCurrentTable,
  }) : super(key: key);

  @override
  State<TableDetailScreen> createState() => _TableDetailScreenState();
}

class _TableDetailScreenState extends State<TableDetailScreen>
    with SingleTickerProviderStateMixin {
  List<Order> _filteredOrders = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final SaleService _saleService = SaleService();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _filteredOrders = widget.table.orders;
    
    // Her 2 saniyede bir masa verilerini yenile (daha güvenli)
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        setState(() {
          // Güncel masa verilerini al ve sipariş listesini güncelle
          final currentTable = widget.getCurrentTable();
          _filteredOrders = currentTable.orders; // Sadece güncel siparişleri al, filtreleme build'de yapılacak
          print('🔄 Masa detay ekranı güncellendi: ${currentTable.orders.length} sipariş');
          for (var order in currentTable.orders) {
            print('   - ${order.productName} x${order.quantity} (ID: ${order.id})');
          }
        });
      }
    });
  }

  @override
  void didUpdateWidget(TableDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Widget güncellendiğinde sipariş listesini yenile
    if (oldWidget.table.orders != widget.table.orders) {
      _filterOrders(_searchQuery);
    }
  }

  // Güncel masa bilgisini al
  TableOrder get _currentTable => widget.getCurrentTable();

  @override
  void dispose() {
    _searchController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _filterOrders(String query) {
    setState(() {
      _searchQuery = query;
      // Arama sorgusu değiştiğinde filtreleme yapılacak
    });
  }

  void _showAddOrderDialog() {
    // Mevcut masa siparişlerini al
    final currentTable = _currentTable;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProductSelectionSheet(
        onAddOrder: widget.onAddOrder,
        existingOrders: currentTable.orders, // Mevcut siparişleri geç
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Güncel masa bilgisini al
    final currentTable = _currentTable;
    
    // Sipariş listesini güncelle - build metodunda değil, timer'da yapılıyor
    // Burada sadece güncel listeyi kullan
    final displayOrders = _searchQuery.isEmpty 
        ? _filteredOrders 
        : _filteredOrders.where((order) {
            return order.productName.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                );
          }).toList();
    
    print('📱 Masa detay build: ${_filteredOrders.length} sipariş, ${displayOrders.length} gösteriliyor');

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Masa ${currentTable.tableNumber} - ${currentTable.customerName}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    '${currentTable.childCount} çocuk${currentTable.isManual ? " • Manuel" : ""}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Yeni Sipariş Butonu
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              onPressed: _showAddOrderDialog,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Yeni Sipariş'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Arama çubuğu
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _filterOrders,
              decoration: InputDecoration(
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Colors.grey.shade500,
                ),
                hintText: 'Sipariş ara...',
                hintStyle: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),

          // Sipariş sayısı
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.receipt_long,
                  size: 18,
                  color: Colors.grey.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  'Siparişler ${displayOrders.length}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),

          // Sipariş listesi
          Expanded(
            child: displayOrders.isEmpty
                ? _buildEmptyState()
                : _buildOrdersList(displayOrders),
          ),

          // Toplam tutar ve butonlar - Yukarı taşındı
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16), // Alt margin eklendi
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Toplam tutar kısmı
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade100),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Toplam Tutar:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                      Text(
                        '${currentTable.totalOrderAmount.toStringAsFixed(2)} ₺',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),

                // Butonlar
                Row(
                  children: [
                    // Masayı Sil butonu
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showDeleteTableDialog(),
                        icon: const Icon(Icons.delete_outline, size: 20),
                        label: const Text(
                          'Masayı Sil',
                          style:
                              TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.red.shade600,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Ödeme Al butonu
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showPaymentDialog(),
                        icon: const Icon(Icons.payment, size: 20),
                        label: const Text(
                          'Ödeme Al',
                          style:
                              TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.green.shade600,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
              color: AppTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              size: 60,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Henüz Sipariş Bulunmuyor',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryTextColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Bu masada henüz sipariş verilmemiş',
            style: TextStyle(fontSize: 16, color: AppTheme.secondaryTextColor),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _showAddOrderDialog,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Sipariş Ekle'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              elevation: 2,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList(List<Order> orders) {
    // Siparişleri zamana göre sırala (en yeniler üstte)
    orders.sort((a, b) => b.orderTime.compareTo(a.orderTime));

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final order = orders[index];
        final isCompleted = order.isCompleted;

        return Dismissible(
          key: Key(order.id),
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          direction: DismissDirection.endToStart,
          confirmDismiss: (direction) async {
            return await showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Siparişi Sil'),
                  content: const Text(
                    'Bu siparişi silmek istediğinize emin misiniz?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('İptal'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text(
                        'Sil',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                );
              },
            );
          },
          onDismissed: (direction) {
            widget.onRemoveOrder(order.id);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${order.productName} siparişi silindi'),
                action: SnackBarAction(label: 'Tamam', onPressed: () {}),
              ),
            );
          },
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isCompleted
                    ? Colors.grey.shade200
                    : AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(
                  Icons.restaurant,
                  color: isCompleted
                      ? Colors.grey.shade500
                      : AppTheme.primaryColor,
                  size: 24,
                ),
              ),
            ),
            title: Text(
              order.productName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                decoration: isCompleted ? TextDecoration.lineThrough : null,
                color: isCompleted ? Colors.grey : Colors.black87,
              ),
            ),
            subtitle: Text(
              '${order.quantity} adet - ${(order.totalPrice).toStringAsFixed(2)} ₺',
              style: TextStyle(
                fontSize: 14,
                color:
                    isCompleted ? Colors.grey.shade500 : Colors.grey.shade700,
              ),
            ),
            trailing: isCompleted
                ? const Icon(Icons.check_circle, color: Colors.green)
                : IconButton(
                    icon: const Icon(
                      Icons.check_circle_outline,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      widget.onCompleteOrder(order.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${order.productName} siparişi tamamlandı',
                          ),
                          action: SnackBarAction(
                            label: 'Tamam',
                            onPressed: () {},
                          ),
                        ),
                      );
                    },
                  ),
          ),
        );
      },
    );
  }

  // Ödeme dialog'u
  void _showPaymentDialog() {
    final currentTable = _currentTable;
    final totalAmount = currentTable.totalOrderAmount;
    String paymentMethod = 'nakit'; // Varsayılan ödeme yöntemi

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
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
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.payment,
                          color: Colors.green.shade600,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Ödeme İşlemi',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Masa bilgisi
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              currentTable.tableNumber.toString(),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentTable.customerName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${currentTable.childCount} çocuk',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Sipariş Özeti Başlığı
                  Row(
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 18,
                        color: Colors.grey.shade700,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Sipariş Özeti',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Siparişlerin listesi
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: SingleChildScrollView(
                      child: Column(
                        children: currentTable.orders.isEmpty
                            ? [
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: Text(
                                      'Sipariş bulunmamaktadır',
                                      style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontStyle: FontStyle.italic),
                                    ),
                                  ),
                                )
                              ]
                            : currentTable.orders
                                .map((order) => Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8, horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: order.isCompleted
                                            ? Colors.grey.shade50
                                            : Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: order.isCompleted
                                                ? Colors.grey.shade200
                                                : Colors.green.shade200),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: order.isCompleted
                                                      ? Colors.grey.shade200
                                                      : Colors.green.shade100,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Text(
                                                  order.quantity.toString(),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    color: order.isCompleted
                                                        ? Colors.grey.shade700
                                                        : Colors.green.shade700,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                order.productName,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  decoration: order.isCompleted
                                                      ? TextDecoration
                                                          .lineThrough
                                                      : null,
                                                  color: order.isCompleted
                                                      ? Colors.grey.shade500
                                                      : Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            '${order.totalPrice.toStringAsFixed(2)} ₺',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: order.isCompleted
                                                  ? Colors.grey.shade500
                                                  : Colors.green.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ))
                                .toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Toplam Tutar
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Toplam Tutar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${totalAmount.toStringAsFixed(2)} ₺',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Ödeme Yöntemleri
                  const Text(
                    'Ödeme Yöntemi',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Nakit/Kart Seçimi
                  Row(
                    children: [
                      // Nakit Seçimi
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              paymentMethod = 'nakit';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: paymentMethod == 'nakit'
                                  ? Colors.green.shade50
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: paymentMethod == 'nakit'
                                    ? Colors.green.shade300
                                    : Colors.grey.shade300,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.money,
                                  size: 32,
                                  color: paymentMethod == 'nakit'
                                      ? Colors.green.shade700
                                      : Colors.grey.shade500,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Nakit',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: paymentMethod == 'nakit'
                                        ? Colors.green.shade700
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Kart Seçimi
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              paymentMethod = 'kart';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: paymentMethod == 'kart'
                                  ? Colors.green.shade50
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: paymentMethod == 'kart'
                                    ? Colors.green.shade300
                                    : Colors.grey.shade300,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.credit_card,
                                  size: 32,
                                  color: paymentMethod == 'kart'
                                      ? Colors.green.shade700
                                      : Colors.grey.shade500,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Kart',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: paymentMethod == 'kart'
                                        ? Colors.green.shade700
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Butonlar
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'İptal',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            // Satış kaydı oluştur
                            await _createSaleRecord();
                            
                            // Ödeme alındı ve masa silindi
                            Navigator.pop(context); // Dialog'u kapat
                            Navigator.pop(context); // Detay sayfasını kapat

                            // Masayı sil
                            widget.onDeleteTable(currentTable);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Ödemeyi Tamamla',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  // Masa silme onay dialog'u
  void _showDeleteTableDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Başlık
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.delete_outline,
                    color: Colors.red.shade600,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Masayı Sil',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Uyarı metni
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.amber.shade700,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Masa #${_currentTable.tableNumber} silinecek',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Bu işlem geri alınamaz ve masadaki tüm siparişler silinecektir.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Masa bilgisi
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            _currentTable.tableNumber.toString(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentTable.customerName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              children: [
                                Icon(Icons.people,
                                    size: 12, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Text(
                                  '${_currentTable.childCount} çocuk',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(Icons.receipt_long,
                                    size: 12, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Text(
                                  '${_currentTable.orders.length} sipariş',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
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

                // Butonlar
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Vazgeç',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          // Masayı sil
                          Navigator.pop(context); // Dialog'u kapat
                          Navigator.pop(context); // Detay sayfasını kapat

                          // Masayı sil
                          widget.onDeleteTable(_currentTable);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Masayı Sil',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Satış kaydı oluştur
  Future<void> _createSaleRecord() async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) return;

      // Sipariş detaylarını hazırla
      final currentTable = _currentTable;
      final completedOrders = currentTable.orders.where((order) => order.isCompleted).toList();
      final allOrders = currentTable.orders;
      
      print('Debug - Toplam sipariş sayısı: ${allOrders.length}');
      print('Debug - Tamamlanan sipariş sayısı: ${completedOrders.length}');
      
      // Tüm siparişleri kullan (tamamlanmamış olsa bile)
      final orderDescriptions = allOrders.map((order) => 
        '${order.productName} x${order.quantity}'
      ).join(', ');

      // Açıklama metni oluştur
      String description;
      if (orderDescriptions.isNotEmpty) {
        description = orderDescriptions;
      } else {
        description = 'Masa Siparişi';
      }
      
      print('Debug - Açıklama: $description');

      final saleRecord = SaleRecord(
        id: '', // Firestore otomatik oluşturacak
        userId: firebaseUser.uid,
        userName: firebaseUser.displayName ?? firebaseUser.email?.split('@')[0] ?? 'Kullanıcı',
        customerName: currentTable.customerName,
        amount: currentTable.totalOrderAmount,
        description: description,
        date: DateTime.now(),
        customerPhone: null,
        customerEmail: null,
        items: completedOrders.map((order) => order.productName).toList(),
        paymentMethod: 'Nakit', // Varsayılan olarak nakit
        status: 'Tamamlandı',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await _saleService.createSale(saleRecord);
      if (result != null) {
        print('✅ Masa siparişi satış kaydı oluşturuldu: ${currentTable.customerName}');
        print('   - Tutar: ${currentTable.totalOrderAmount}₺');
        print('   - User ID: ${firebaseUser.uid}');
        print('   - Satış ID: ${result.id}');
        
        // Profil ekranındaki satış geçmişini güncelle
        try {
          // ProfileScreen static metodunu çağır
          // ProfileScreen import edilmeli - şimdilik sadece log
          print('📊 Satış kaydı oluşturuldu - Profil ekranı güncellenmeli');
        } catch (e) {
          print('Profil ekranı güncellenirken hata: $e');
        }
        
        // Başarı mesajı göster
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Satış kaydı oluşturuldu: ${currentTable.totalOrderAmount}₺'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        print('❌ Satış kaydı oluşturulamadı');
      }
    } catch (e) {
      print('Satış kaydı oluşturulurken hata: $e');
    }
  }
}

// Ürün Seçim Sayfası
class ProductSelectionSheet extends StatefulWidget {
  final Function(Order) onAddOrder;
  final List<Order> existingOrders;

  const ProductSelectionSheet({
    Key? key, 
    required this.onAddOrder,
    this.existingOrders = const [],
  }) : super(key: key);

  @override
  State<ProductSelectionSheet> createState() => _ProductSelectionSheetState();
}

class _ProductSelectionSheetState extends State<ProductSelectionSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final MenuRepository _menuRepository = MenuRepository();
  List<ProductItem> products = [];
  bool isLoading = false;
  int _selectedQuantity = 1;
  
  // Seçilen ürünleri tutacak liste
  List<Map<String, dynamic>> _selectedProducts = [];
  
  // Her kategori için benzersiz scrollController
  final Map<ProductCategory, ScrollController> _scrollControllers = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: ProductCategory.values.length,
      vsync: this,
    );
    
    // Her kategori için benzersiz scrollController oluştur
    for (var category in ProductCategory.values) {
      _scrollControllers[category] = ScrollController();
    }
    
    // Menü öğelerini yükle
    _loadProducts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    
    // Tüm scrollController'ları dispose et
    for (var controller in _scrollControllers.values) {
      controller.dispose();
    }
    
    super.dispose();
  }

  // Menü öğelerini yükle
  Future<void> _loadProducts() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Firebase'den menüyü yükle
      await _menuRepository.loadMenuItems();

      if (mounted) {
        setState(() {
          products = _menuRepository.menuItems;
          isLoading = false;

          // Firebase'de ürün yoksa
          if (products.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    "Menüde hiç ürün yok. Test ürünleri oluşturabilirsiniz."),
                duration: Duration(seconds: 3),
              ),
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Menü yüklenirken hata: $e"),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Kategoriye göre ürünleri filtrele
  List<ProductItem> _getFilteredProducts(ProductCategory category) {
    if (_searchQuery.isEmpty) {
      return products.where((item) => item.category == category).toList();
    } else {
      return products
          .where(
            (item) =>
                item.category == category &&
                (item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    (item.description
                            ?.toLowerCase()
                            .contains(_searchQuery.toLowerCase()) ??
                        false)),
          )
          .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      key: const ValueKey('product_selection_sheet'), // Benzersiz key ekle
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (_, scrollController) {
        return Container(
          key: const ValueKey('product_sheet_container'), // Benzersiz key ekle
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Başlık ve Kapat buton
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Sipariş Ekle',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        Row(
                          children: [
                            // Yenile butonu
                            IconButton(
                              key: const ValueKey('refresh_button'), // Benzersiz key
                              icon: const Icon(Icons.refresh),
                              onPressed: _loadProducts,
                              tooltip: 'Menüyü Yenile',
                            ),
                            IconButton(
                              key: const ValueKey('close_button'), // Benzersiz key
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                              tooltip: 'Kapat',
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),
                    // Arama
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
                          hintText: 'Ürün ara...',
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

              // Tab Bar
              TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: AppTheme.primaryColor,
                unselectedLabelColor: Colors.grey,
                indicatorColor: AppTheme.primaryColor,
                tabs: [
                  for (var category in ProductCategory.values)
                    Tab(
                      key: ValueKey('tab_${category.name}'), // Benzersiz key
                      text: getCategoryTitle(category),
                    ),
                ],
              ),



              // Ürün Listesi
              Expanded(
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          // Kategorilere göre ürün listeleri
                          for (var category in ProductCategory.values)
                            KeyedSubtree(
                              key: ValueKey('tabview_${category.name}'), // Benzersiz key ekle
                              child: _buildProductList(
                                _getFilteredProducts(category),
                                _scrollControllers[category]!, // Benzersiz scrollController kullan
                              ),
                            ),
                        ],
                      ),
              ),

              // Sepet Butonu
              if (_selectedProducts.isNotEmpty)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: _buildCartButton(),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductCard(ProductItem product) {
    return InkWell(
      key: ValueKey('product_${product.name}_${product.category}'), // Benzersiz key ekle
      onTap: () {
        // Kart tıklama efekti
        HapticFeedback.lightImpact();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
          ],
          border: Border.all(
            color: product.stock > 0 ? Colors.grey.shade100 : Colors.red.shade200,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ürün Görseli ve Stok Durumu
            Stack(
              children: [
                // Ürün Görseli
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  child: Container(
                    height: 90, // 100'den 90'a düşürüldü
                    width: double.infinity,
                    color: Colors.grey.shade50,
                    child: product.imageUrl != null
                        ? Image.file(
                            File(product.imageUrl!),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildPlaceholderImage(product.category);
                            },
                          )
                        : _buildPlaceholderImage(product.category),
                  ),
                ),
                
                // Stok yoksa overlay
                if (product.stock <= 0)
                  Container(
                    height: 90, // 100'den 90'a düşürüldü
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.red.shade600.withOpacity(0.9),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Stok yok ikonu
                        Center(
                          child: Icon(
                            Icons.block,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        // Stok yok yazısı
                        Positioned(
                          bottom: 6, // 8'den 6'ya düşürüldü
                          left: 6, // 8'den 6'ya düşürüldü
                          right: 6, // 8'den 6'ya düşürüldü
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'STOK YOK',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // Stok etiketi
                Positioned(
                  top: 6, // 8'den 6'ya düşürüldü
                  right: 6, // 8'den 6'ya düşürüldü
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: product.stock > 0 ? Colors.green.shade500 : Colors.red.shade500,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      product.stock > 0 ? '${product.stock}' : '0',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Ürün Bilgileri - Daha kompakt padding
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12), // Alt padding 8'den 12'ye çıkarıldı
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ürün Adı
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.black87,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 8),

                    // Fiyat
                    Row(
                      children: [
                        Text(
                          '${product.price.toStringAsFixed(2)} ₺',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.green.shade700,
                          ),
                        ),
                        const Spacer(),
                        if (product.stock > 0) ...[
                          // Hızlı Ekleme - Daha kompakt
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Azalt
                              GestureDetector(
                                onTap: () => _quickAddToTable(product, -1),
                                child: Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: const Icon(
                                    Icons.remove,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              
                              const SizedBox(width: 6),
                              
                              // Miktar
                              Container(
                                width: 30,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Center(
                                  child: Text(
                                    '${_getQuickAddQuantity(product)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              
                              const SizedBox(width: 6),
                              
                              // Artır
                              GestureDetector(
                                onTap: () => _quickAddToTable(product, 1),
                                child: Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: const Icon(
                                    Icons.add,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),

                    const Spacer(),

                    // Ekle Butonu veya Stok Yok - Daha kompakt ve tam görünür
                    if (product.stock > 0) ...[
                      Container(
                        width: double.infinity,
                        height: 40, // 36'dan 40'a çıkarıldı
                        margin: const EdgeInsets.only(top: 4), // Üst margin eklendi
                        child: ElevatedButton(
                          onPressed: () => _addToTableFromCard(product),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Masaya Ekle',
                            style: TextStyle(
                              fontSize: 13, // 12'den 13'e çıkarıldı
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      Container(
                        width: double.infinity,
                        height: 40, // 36'dan 40'a çıkarıldı
                        margin: const EdgeInsets.only(top: 4), // Üst margin eklendi
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: const Center(
                          child: Text(
                            'Stok Yok',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 13, // 12'den 13'e çıkarıldı
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Kategori simgesi için yardımcı metot
  Widget _buildPlaceholderImage(ProductCategory category) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey.shade100,
            Colors.grey.shade200,
          ],
        ),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            _getCategoryIcon(category),
            size: 32,
            color: Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  // Kategori simgesi getir
  IconData _getCategoryIcon(ProductCategory category) {
    switch (category) {
      case ProductCategory.food:
        return Icons.restaurant_rounded;
      case ProductCategory.drink:
        return Icons.local_cafe_rounded;
      case ProductCategory.dessert:
        return Icons.cake_rounded;
      case ProductCategory.toy:
        return Icons.toys_rounded;
      case ProductCategory.game:
        return Icons.sports_esports_rounded;
      case ProductCategory.coding:
        return Icons.code_rounded;
      case ProductCategory.other:
        return Icons.category_rounded;
    }
  }

  // Hızlı ekleme için ürün miktarlarını takip et
  final Map<String, int> _quickAddQuantities = {};

  // Hızlı ekleme miktarını al
  int _getQuickAddQuantity(ProductItem product) {
    return _quickAddQuantities[product.name] ?? 0;
  }

  // Hızlı ekleme işlemi
  void _quickAddToTable(ProductItem product, int change) {
    final currentQuantity = _getQuickAddQuantity(product);
    final newQuantity = currentQuantity + change;
    
    if (newQuantity >= 0 && newQuantity <= product.stock) {
      setState(() {
        _quickAddQuantities[product.name] = newQuantity;
      });
    }
  }

  // Karttan seçilen listeye ekleme
  void _addToTableFromCard(ProductItem product) {
    final quantity = _getQuickAddQuantity(product);
    if (quantity > 0) {
      // Ürünü seçilen listeye ekle
      _addProductToSelectedList(product, quantity);
      
      // Miktarı sıfırla
      setState(() {
        _quickAddQuantities[product.name] = 0;
      });
    }
  }

  // Ürünü seçilen listeye ekle
  void _addProductToSelectedList(ProductItem product, int quantity) async {
    try {
      // Stok kontrolü
      if (product.stock < quantity) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Yetersiz stok! Mevcut: ${product.stock}, İstenen: $quantity'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Aynı ürün zaten seçilmiş mi kontrol et (hem seçilen listede hem de mevcut siparişlerde)
      final existingIndex = _selectedProducts.indexWhere(
        (item) => item['product'].name == product.name,
      );

      // Mevcut masa siparişlerinde de aynı ürün var mı kontrol et
      final existingOrderIndex = widget.existingOrders.indexWhere(
        (order) => order.productName == product.name,
      );

      if (existingIndex != -1) {
        // Seçilen listede zaten var, miktarını artır
        final currentQuantity = _selectedProducts[existingIndex]['quantity'] as int;
        final newTotalQuantity = currentQuantity + quantity;
        
        // Toplam miktar stoktan fazla mı kontrol et
        if (newTotalQuantity > product.stock) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Yetersiz stok! Mevcut: ${product.stock}, Toplam istenen: $newTotalQuantity'),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
        
        // Stok güncelle - sadece eklenen miktar kadar düşür
        await _updateProductStock(product, quantity);
        
        setState(() {
          _selectedProducts[existingIndex]['quantity'] = newTotalQuantity;
        });
        print('📦 Seçilen listede mevcut ürün miktarı artırıldı: ${product.name} +$quantity = $newTotalQuantity');
      } else if (existingOrderIndex != -1) {
        // Mevcut masa siparişlerinde var, yeni sipariş olarak ekle (miktar artırılacak)
        // Stok güncelle - yeni eklenen miktar kadar düşür
        await _updateProductStock(product, quantity);
        
        setState(() {
          _selectedProducts.add({
            'product': product,
            'quantity': quantity,
          });
        });
        print('📦 Mevcut masa siparişinde olan ürün yeni sipariş olarak eklendi: ${product.name} x$quantity');
      } else {
        // Yeni ürün ekle
        // Stok güncelle - yeni eklenen miktar kadar düşür
        await _updateProductStock(product, quantity);
        
        setState(() {
          _selectedProducts.add({
            'product': product,
            'quantity': quantity,
          });
        });
        print('📦 Yeni ürün eklendi: ${product.name} x$quantity');
      }
      
      // Başarı mesajı
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} x$quantity seçildi'),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );

    } catch (e) {
      print('Ürün seçilirken hata: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Seçilen ürünü listeden kaldır
  Future<void> _removeSelectedProduct(int index) async {
    // Index kontrolü
    if (index < 0 || index >= _selectedProducts.length) {
      print('❌ Geçersiz index: $index, Liste uzunluğu: ${_selectedProducts.length}');
      return;
    }
    
    final product = _selectedProducts[index]['product'] as ProductItem;
    final quantity = _selectedProducts[index]['quantity'] as int;
    
    // Stok güncelle - silinen miktar kadar geri ekle
    await _updateProductStock(product, -quantity);
    
    // Tamamen yeni liste oluştur
    final newList = List<Map<String, dynamic>>.from(_selectedProducts);
    newList.removeAt(index);
    
    setState(() {
      _selectedProducts = newList;
    });
    
    // Ekstra güvenlik için tekrar setState çağır
    Future.delayed(Duration.zero, () {
      if (mounted) {
        setState(() {});
      }
    });
    print('🗑️ Sepetten ürün kaldırıldı: ${product.name} x$quantity (Stok geri eklendi)');
  }

  // Seçilen ürünün miktarını güncelle
  Future<void> _updateSelectedProductQuantity(int index, int newQuantity) async {
    // Index kontrolü
    if (index < 0 || index >= _selectedProducts.length) {
      print('❌ Geçersiz index: $index, Liste uzunluğu: ${_selectedProducts.length}');
      return;
    }
    
    if (newQuantity <= 0) {
      _removeSelectedProduct(index);
      return;
    }
    
    final product = _selectedProducts[index]['product'] as ProductItem;
    final currentQuantity = _selectedProducts[index]['quantity'] as int;
    
    // Stok kontrolü - mevcut stok + sepet içindeki miktar ile karşılaştır
    final availableStock = product.stock + currentQuantity; // Sepetteki miktar geri eklenmiş stok
    if (newQuantity > availableStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Yetersiz stok! Mevcut: $availableStock'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    // Stok farkını hesapla ve güncelle
    final quantityDifference = newQuantity - currentQuantity;
    if (quantityDifference != 0) {
      await _updateProductStock(product, quantityDifference);
    }
    
    // Tamamen yeni liste oluştur
    final newList = List<Map<String, dynamic>>.from(_selectedProducts);
    newList[index] = {
      'product': product,
      'quantity': newQuantity,
    };
    
    setState(() {
      _selectedProducts = newList;
    });
    
    // Ekstra güvenlik için tekrar setState çağır
    Future.delayed(Duration.zero, () {
      if (mounted) {
        setState(() {});
      }
    });
    
    print('📦 Sepetteki ürün miktarı güncellendi: ${product.name} x$newQuantity (Fark: $quantityDifference)');
  }

  // Toplam fiyatı hesapla
  double _getTotalPrice() {
    double total = 0;
    for (var selectedItem in _selectedProducts) {
      final product = selectedItem['product'] as ProductItem;
      final quantity = selectedItem['quantity'] as int;
      total += product.price * quantity;
    }
    return total;
  }

  // Sepet butonu widget'ı
  Widget _buildCartButton() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _showCartDropdown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.shopping_cart,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sepettekiler',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${_selectedProducts.length} ürün',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      '${_getTotalPrice().toStringAsFixed(2)} ₺',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white.withOpacity(0.8),
                      size: 24,
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

  // Sepet dropdown menüsünü göster
  void _showCartDropdown() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => _buildCartModal(setModalState),
      ),
    );
  }

  // Sepet modal widget'ı
  Widget _buildCartModal(StateSetter setModalState) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Modal başlığı
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sepettekiler (${_selectedProducts.length})',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      'Toplam: ${_getTotalPrice().toStringAsFixed(2)} ₺',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade600,
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Alt butonlar - daha yukarı çekildi
          Container(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      // Tüm sepet ürünlerinin stoklarını geri ekle
                      for (var selectedItem in _selectedProducts) {
                        final product = selectedItem['product'] as ProductItem;
                        final quantity = selectedItem['quantity'] as int;
                        await _updateProductStock(product, -quantity);
                      }
                      
                      setState(() {
                        _selectedProducts.clear();
                      });
                      setModalState(() {});
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Temizle',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _addSelectedProductsToTable();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Masaya Ekle',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Ürün listesi
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              itemCount: _selectedProducts.length,
              itemBuilder: (context, index) {
                final selectedItem = _selectedProducts[index];
                final product = selectedItem['product'] as ProductItem;
                final quantity = selectedItem['quantity'] as int;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      // Ürün ikonu
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getCategoryIcon(product.category),
                          color: AppTheme.primaryColor,
                          size: 24,
                        ),
                      ),
                      
                      const SizedBox(width: 16),
                      
                      // Ürün bilgileri
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${product.price.toStringAsFixed(2)} ₺',
                              style: TextStyle(
                                color: Colors.green.shade600,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Miktar kontrolleri
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () async {
                              await _updateSelectedProductQuantity(
                                index, 
                                quantity - 1,
                              );
                              setModalState(() {});
                            },
                            color: Colors.red.shade400,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Text(
                              quantity.toString(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () async {
                              await _updateSelectedProductQuantity(
                                index, 
                                quantity + 1,
                              );
                              setModalState(() {});
                            },
                            color: Colors.green.shade400,
                          ),
                        ],
                      ),
                      
                      const SizedBox(width: 8),
                      
                      // Kaldır butonu
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await _removeSelectedProduct(index);
                          setModalState(() {});
                        },
                        color: Colors.red.shade400,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }



  // Seçilen ürünleri masaya ekle
  void _addSelectedProductsToTable() async {
    if (_selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lütfen en az bir ürün seçin'),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      print('🛒 Sepetteki ürünler masaya ekleniyor: ${_selectedProducts.length} ürün');
      
      // Tüm siparişleri oluştur
      final List<Order> ordersToAdd = [];
      for (var selectedItem in _selectedProducts) {
        final product = selectedItem['product'] as ProductItem;
        final quantity = selectedItem['quantity'] as int;

        // Yeni sipariş oluştur - HER BİRİNE BENZERSİZ ID VER
        final newOrder = Order(
          productName: product.name,
          price: product.price,
          quantity: quantity,
        );
        ordersToAdd.add(newOrder);
        print('   📦 Sipariş oluşturuldu: ${product.name} x$quantity (ID: ${newOrder.id})');
      }

      print('🔄 ${ordersToAdd.length} sipariş masaya ekleniyor...');

      // TÜM SİPARİŞLERİ TEK SEFERDE EKLE - AYRI AYRI DEĞİL
      for (int i = 0; i < ordersToAdd.length; i++) {
        var order = ordersToAdd[i];
        print('   ${i + 1}/${ordersToAdd.length} - ${order.productName} x${order.quantity} ekleniyor...');
        widget.onAddOrder(order);
        print('   ➕ Sipariş eklendi: ${order.productName} x${order.quantity} (ID: ${order.id})');
        // Her sipariş arasında kısa bekleme ekle
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // Stok güncellemeleri zaten sepet işlemlerinde yapıldı
      print('✅ Stok güncellemeleri zaten sepet işlemlerinde tamamlandı!');

      print('✅ Tüm siparişler başarıyla eklendi!');

      // Başarı mesajı
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_selectedProducts.length} ürün masaya eklendi'),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Seçilen ürünleri temizle ve ekranı kapat
      setState(() {
        _selectedProducts.clear();
      });
      Navigator.pop(context);

    } catch (e) {
      print('❌ Ürünler masaya eklenirken hata: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Ürün stokunu güncelle
  Future<void> _updateProductStock(ProductItem product, int quantity) async {
    try {
      print('🔄 Stok güncelleme başlıyor: ${product.name}');
      print('   Mevcut stok: ${product.stock}');
      print('   Değişim miktarı: $quantity');
      
      // MenuRepository üzerinden stok güncelle
      if (product.id.isNotEmpty) {
        final newStock = product.stock - quantity; // Negatif quantity stok artırır
        print('   Yeni stok hesaplandı: $newStock');
        
        // Stok negatif olamaz
        if (newStock < 0) {
          print('❌ Stok negatif olamaz! Mevcut: ${product.stock}, İstenen değişim: $quantity');
          return;
        }
        
        await _menuRepository.updateProductStock(product.id, newStock);
        
        // Products listesindeki ürünü de güncelle
        final productIndex = products.indexWhere((p) => p.id == product.id);
        if (productIndex != -1) {
          // Yeni ProductItem oluştur (immutable olduğu için)
          final updatedProduct = ProductItem(
            id: product.id,
            name: product.name,
            price: product.price,
            category: product.category,
            description: product.description,
            stock: newStock,
            imageUrl: product.imageUrl,
          );
          products[productIndex] = updatedProduct;
          
          // Sepetteki ürünü de güncelle
          for (int i = 0; i < _selectedProducts.length; i++) {
            if (_selectedProducts[i]['product'].id == product.id) {
              _selectedProducts[i]['product'] = updatedProduct;
            }
          }
        }
        
        print('✅ Stok güncellendi: ${product.name} - Yeni stok: $newStock');
      } else {
        print('❌ Ürün ID bulunamadı, stok güncellenemedi');
      }
    } catch (e) {
      print('❌ Stok güncelleme hatası: $e');
    }
  }

  // Ürün listesi görünümünü grid view olarak değiştir
  Widget _buildProductList(
      List<ProductItem> products, ScrollController scrollController) {
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.no_food_rounded,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Bu kategoride ürün bulunamadı',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    // Ekran boyutuna göre responsive grid
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Ekran boyutuna göre grid ayarları - Buton için daha fazla alan
    int crossAxisCount;
    double childAspectRatio;
    double spacing;
    
    if (screenWidth < 400) {
      // Küçük ekranlar (telefon)
      crossAxisCount = 2;
      childAspectRatio = 0.85; // 0.75'ten 0.85'e çıkarıldı
      spacing = 12;
    } else if (screenWidth < 600) {
      // Orta ekranlar (büyük telefon)
      crossAxisCount = 2;
      childAspectRatio = 0.88; // 0.78'den 0.88'e çıkarıldı
      spacing = 16;
    } else if (screenWidth < 900) {
      // Tablet
      crossAxisCount = 3;
      childAspectRatio = 0.9; // 0.8'den 0.9'a çıkarıldı
      spacing = 20;
    } else {
      // Büyük tablet/desktop
      crossAxisCount = 4;
      childAspectRatio = 0.95; // 0.85'ten 0.95'e çıkarıldı
      spacing = 24;
    }

    return GridView.builder(
      key: ValueKey('grid_${products.length}_${products.isNotEmpty ? products.first.category : 'empty'}'), // Benzersiz key ekle
      controller: scrollController,
      padding: EdgeInsets.all(spacing),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return _buildProductCard(product);
      },
    );
  }

  void _showQuantityDialog(ProductItem product) {
    _selectedQuantity = 1;
    
    // Stok kontrolü - stok yoksa sipariş ekranında hata ver
    if (product.stock <= 0) {
      // Masa ekranında stok hatası gösterme, sadece sipariş ekranında göster
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          key: ValueKey('quantity_dialog_${product.name}'), // Benzersiz key ekle
          builder: (context, setModalState) {
            final totalAmount = product.price * _selectedQuantity;

            return AlertDialog(
              key: ValueKey('alert_dialog_${product.name}'), // Benzersiz key ekle
              title: Row(
                children: [
                  Icon(
                    _getCategoryIcon(product.category),
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Sipariş: ${product.name}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ürün detayları
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Text(
                      '${product.price.toStringAsFixed(2)} ₺',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Adet seçici
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Adet:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              key: ValueKey('remove_${product.name}'), // Benzersiz key
                              icon: const Icon(Icons.remove),
                              onPressed: _selectedQuantity > 1
                                  ? () {
                                      setModalState(() {
                                        _selectedQuantity--;
                                      });
                                    }
                                  : null,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                _selectedQuantity.toString(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              key: ValueKey('add_${product.name}'), // Benzersiz key
                              icon: const Icon(Icons.add),
                              onPressed: _selectedQuantity < product.stock
                                  ? () {
                                      setModalState(() {
                                        _selectedQuantity++;
                                      });
                                    }
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Stok bilgisi
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.inventory_2_rounded,
                          color: Colors.blue.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Mevcut Stok: ${product.stock} adet',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Toplam fiyat
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Toplam Tutar:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${totalAmount.toStringAsFixed(2)} ₺',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
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
                  onPressed: _selectedQuantity <= product.stock
                      ? () {
                          final newOrder = Order(
                            productName: product.name,
                            price: product.price,
                            quantity: _selectedQuantity,
                          );

                    widget.onAddOrder(newOrder);
                    Navigator.pop(context); // Order dialog
                    Navigator.pop(context); // Product selection sheet

                    // Reset selected quantity for next time
                    _selectedQuantity = 1;

                    // Bildirimi göster
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${product.name} siparişi eklendi.'),
                        backgroundColor: Colors.green.shade700,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                  : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedQuantity <= product.stock 
                        ? AppTheme.primaryColor 
                        : Colors.grey.shade400,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(_selectedQuantity <= product.stock ? 'Siparişi Ekle' : 'Stok Yetersiz'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
