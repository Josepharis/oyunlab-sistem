import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/customer_model.dart';
import '../../data/models/order_model.dart';
import '../../data/models/table_order_model.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/models/order_model.dart' show getCategoryTitle;
import '../screens/menu_management_screen.dart';
import 'dart:io';
import '../../data/repositories/menu_repository.dart';
import '../../data/repositories/table_order_repository.dart';

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
  late TabController _tabController;
  List<ProductItem> products = [];
  bool isLoading = true;

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

    // Aktif müşterilerden masa siparişleri oluştur/güncelle
    _initializeTablesFromCustomers();

    // Masa değişikliklerini dinle
    _tableOrderRepository.tablesStream.listen((tables) {
      if (mounted) {
        setState(() {
          // Firebase'den gelen masaları önce geçici bir listede topla
          final List<TableOrder> firebaseTables = tables;

          // Mevcut masalardaki siparişleri koruyarak birleştir
          _mergeTables(firebaseTables);
        });
      }
    });

    // Müşteri değişikliklerini dinle
    widget.customerRepository.customersStream.listen((customers) {
      if (mounted) {
        _updateTablesFromCustomers(customers);
      }
    });
  }

  // Firebase'den masaları yükle
  Future<void> _loadTablesFromFirebase() async {
    try {
      final tables = await _tableOrderRepository.getAllTables();
      if (mounted) {
        setState(() {
          // Mevcut masalardaki siparişleri koruyarak birleştir
          _mergeTables(tables);
        });
      }
    } catch (e) {
      print("Masa yükleme hatası: $e");
    }
  }

  // Gelen masaları mevcut masalarla birleştir
  void _mergeTables(List<TableOrder> newTables) {
    // Mevcut masaların siparişlerini bir map'e kaydet
    final Map<int, List<Order>> existingOrders = {};
    for (var table in _tableOrders) {
      if (table.orders.isNotEmpty) {
        existingOrders[table.tableNumber] = table.orders;
      }
    }

    // Yeni masalara mevcut siparişleri ekle
    final updatedTables = newTables.map((table) {
      if (existingOrders.containsKey(table.tableNumber)) {
        // Siparişleri birleştir - Firebase'de olan siparişleri koru
        if (table.orders.isEmpty) {
          // Firebase'de sipariş yoksa mevcut siparişleri kullan
          return table.copyWith(orders: existingOrders[table.tableNumber]);
        }
      }
      return table;
    }).toList();

    // Sırala
    updatedTables.sort((a, b) => a.tableNumber.compareTo(b.tableNumber));

    _tableOrders = updatedTables;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
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

  // Aktif müşterilerden masa oluştur
  void _initializeTablesFromCustomers() {
    final customers = widget.customerRepository.customers;
    _updateTablesFromCustomers(customers);
  }

  // Müşterilerden masaları güncelle
  void _updateTablesFromCustomers(List<Customer> customers) {
    // Bilet numaralarına göre grupla
    final Map<int, List<Customer>> ticketGroups = {};

    for (var customer in customers) {
      if (customer.remainingTime.inSeconds > 0) {
        // Sadece aktif müşterileri al
        if (!ticketGroups.containsKey(customer.ticketNumber)) {
          ticketGroups[customer.ticketNumber] = [];
        }
        ticketGroups[customer.ticketNumber]!.add(customer);
      }
    }

    // Mevcut masalardaki siparişleri koru
    final Map<int, List<Order>> existingOrders = {};
    for (var table in _tableOrders) {
      if (table.orders.isNotEmpty) {
        existingOrders[table.tableNumber] = table.orders;
      }
    }

    // Manuel masaları koru - MANUEL MASALARI KORUMAK ÖNEMLİ
    final List<TableOrder> manualTables =
        _tableOrders.where((table) => table.isManual).toList();

    // Otomatik masaları da koru - BU DEĞİŞİKLİK İLE ARTIK TÜM MASALAR KORUNACAK
    final List<TableOrder> autoTables =
        _tableOrders.where((table) => !table.isManual).toList();

    // Bir bilet numarasına ait tüm müşteriler kaldırılmışsa, onun masasını otomatik olarak silmek için
    // hangi masaların güncellenmesi gerektiğini belirle
    final List<int> ticketsToUpdate = ticketGroups.keys.toList();
    final List<int> existingTickets = autoTables
        .where((table) => !table.isManual)
        .map((table) => table.ticketNumber)
        .toList();

    // Yeni masa listesi oluştur
    final List<TableOrder> newTables = [];

    // Manuel masaları ekle
    for (var manualTable in manualTables) {
      // Siparişleri koruyarak ekle
      newTables.add(
        manualTable.copyWith(
          orders: existingOrders[manualTable.tableNumber] ?? manualTable.orders,
        ),
      );
    }

    // Aktif müşterileri takip etmek için bir Map (bilet numarası -> masa)
    final Map<int, TableOrder> activeTablesByTicket = {};

    // Mevcut otomatik masaları güncelle
    for (var autoTable in autoTables) {
      // Otomatik masaların durumunu kontrol et
      if (ticketGroups.containsKey(autoTable.ticketNumber)) {
        // Bilet hala aktif, güncelle
        final ticketCustomers = ticketGroups[autoTable.ticketNumber]!;

        // Çocuk sayısını güncelle ve siparişleri koru
        final updatedTable = autoTable.copyWith(
          childCount: ticketCustomers.length,
          orders: existingOrders[autoTable.tableNumber] ?? autoTable.orders,
        );

        newTables.add(updatedTable);

        // Aktif masalar map'ine ekle
        activeTablesByTicket[autoTable.ticketNumber] = updatedTable;

        // Firebase'de güncelle
        _tableOrderRepository.updateTable(updatedTable);
      } else {
        // Bilet artık aktif değil, ama masayı silmiyoruz
        // Sadece Firebase'de güncelleme yapıyoruz
        // Bu müşteriler kaldırılmış olsa bile masa varlığını koruyor

        newTables.add(autoTable); // Masayı ekle

        // Diğer işlemlere devam et (burada masa otomatik silinmeyecek)
      }
    }

    // Yeni müşterilerden elde edilen yeni masaları ekle
    for (var ticketNumber in ticketGroups.keys) {
      // Bu bilet numarası için zaten bir masa var mı kontrol et
      // ÖNEMLİ: Aktif masalar map'inde bu bilet numarası var mı kontrol ediyoruz
      if (!activeTablesByTicket.containsKey(ticketNumber)) {
        final ticketCustomers = ticketGroups[ticketNumber]!;

        final newTable = TableOrder(
          tableNumber:
              ticketNumber, // Bilet numarası masa numarası olarak kullan
          customerName: ticketCustomers.first.parentName,
          ticketNumber: ticketNumber,
          childCount: ticketCustomers.length,
          isManual: false,
        );

        newTables.add(newTable);

        // Aktif masalar map'ine ekle
        activeTablesByTicket[ticketNumber] = newTable;

        // Firebase'e ekle
        _tableOrderRepository.addTable(newTable);
      }
    }

    // Masa numaralarını sırala
    newTables.sort((a, b) => a.tableNumber.compareTo(b.tableNumber));

    setState(() {
      _tableOrders = newTables;
    });
  }

  // Sonraki masa numarasını al (manuel masalar için)
  int _getNextTableNumber() {
    // Manuel masalar için 1000'den başlayan numaralar kullan
    const int manualBaseNumber = 1000;

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

  // Manuel masa ekle
  void _addManualTable(String customerName) {
    final newTable = TableOrder(
      tableNumber: _getNextTableNumber(),
      customerName: customerName,
      ticketNumber: 0, // Manuel masalar için 0 değeri
      childCount: 1, // Varsayılan 1 çocuk
      isManual: true, // Manuel olarak işaretle
    );

    setState(() {
      _tableOrders.add(newTable);
      _tableOrders.sort((a, b) => a.tableNumber.compareTo(b.tableNumber));
    });

    // Firebase'e de ekle
    _tableOrderRepository.addTable(newTable);
  }

  // Masa ekle dialog
  void _showAddTableDialog() {
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Masa Ekle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Müşteri Adı',
                  prefixIcon: Icon(Icons.person),
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
                backgroundColor: AppTheme.primaryColor,
              ),
              child: const Text('Ekle'),
            ),
          ],
        );
      },
    );
  }

  // Masa silme
  void _deleteTable(TableOrder table) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Masa Sil'),
          content: Text(
              '${table.tableNumber} numaralı masayı silmek istediğinize emin misiniz?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () {
                // Firebase'den de sil
                _tableOrderRepository.deleteTable(table.tableNumber);

                // UI'dan kaldır
                setState(() {
                  _tableOrders.remove(table);
                });

                Navigator.pop(context);

                // Bildirim göster
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${table.tableNumber} numaralı masa silindi'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text('Sil', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // Sipariş ekleme
  void _addOrderToTable(TableOrder table, Order order) {
    final updatedTable = table.addOrder(order);

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
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Yeni Masa'),
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
                    hintText: 'Masa ara...',
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

              // Masa Listesi / Grid
              Expanded(
                child: activeTables.isEmpty
                    ? _buildEmptyState()
                    : _buildTablesGrid(activeTables),
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
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Yeni Masa Ekle'),
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

  Widget _buildTablesGrid(List<TableOrder> tables) {
    return GridView.builder(
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

  const TableDetailScreen({
    Key? key,
    required this.table,
    required this.onAddOrder,
    required this.onCompleteOrder,
    required this.onRemoveOrder,
    required this.onDeleteTable,
  }) : super(key: key);

  @override
  State<TableDetailScreen> createState() => _TableDetailScreenState();
}

class _TableDetailScreenState extends State<TableDetailScreen> {
  List<Order> _filteredOrders = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredOrders = widget.table.orders;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterOrders(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredOrders = widget.table.orders;
      } else {
        _filteredOrders = widget.table.orders.where((order) {
          return order.productName.toLowerCase().contains(
                query.toLowerCase(),
              );
        }).toList();
      }
    });
  }

  void _showAddOrderDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          ProductSelectionSheet(onAddOrder: widget.onAddOrder),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Masa ${widget.table.tableNumber} - ${widget.table.customerName}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              '${widget.table.childCount} çocuk${widget.table.isManual ? " • Manuel" : ""}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Text(
                'Toplam: ${widget.table.totalOrderAmount.toStringAsFixed(2)} ₺',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
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
          // Arama ve Filtre
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 45,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
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
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _showAddOrderDialog,
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Sipariş Ekle'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Siparişler başlığı
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Icon(
                  Icons.receipt_long_rounded,
                  size: 20,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Siparişler',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_filteredOrders.length}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Sipariş Listesi
          Expanded(
            child: _filteredOrders.isEmpty
                ? _buildEmptyState()
                : _buildOrdersList(_filteredOrders),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
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
                    '${widget.table.totalOrderAmount.toStringAsFixed(2)} ₺',
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
    final totalAmount = widget.table.totalOrderAmount;
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
                              widget.table.tableNumber.toString(),
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
                              widget.table.customerName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${widget.table.childCount} çocuk',
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
                        children: widget.table.orders.isEmpty
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
                            : widget.table.orders
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
                          onPressed: () {
                            // Ödeme alındı ve masa silindi
                            Navigator.pop(context); // Dialog'u kapat
                            Navigator.pop(context); // Detay sayfasını kapat

                            // Masayı sil
                            widget.onDeleteTable(widget.table);

                            // Bildirim göster
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Ödeme alındı (${paymentMethod == 'nakit' ? 'Nakit' : 'Kart'}) ve masa silindi'),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
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
                              'Masa #${widget.table.tableNumber} silinecek',
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
                            widget.table.tableNumber.toString(),
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
                              widget.table.customerName,
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
                                  '${widget.table.childCount} çocuk',
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
                                  '${widget.table.orders.length} sipariş',
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
                          widget.onDeleteTable(widget.table);

                          // Bildirim göster
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Masa silindi'),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
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
}

// Ürün Seçim Sayfası
class ProductSelectionSheet extends StatefulWidget {
  final Function(Order) onAddOrder;

  const ProductSelectionSheet({Key? key, required this.onAddOrder})
      : super(key: key);

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: ProductCategory.values.length,
      vsync: this,
    );
    // Menü öğelerini yükle
    _loadProducts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
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
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (_, scrollController) {
        return Container(
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
                              icon: const Icon(Icons.refresh),
                              onPressed: _loadProducts,
                              tooltip: 'Menüyü Yenile',
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
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
                    Tab(text: getCategoryTitle(category)),
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
                            _buildProductList(
                              _getFilteredProducts(category),
                              scrollController,
                            ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductCard(ProductItem product) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showQuantityDialog(product),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ürün Görseli
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              child: Container(
                height: 100,
                width: double.infinity,
                color: Colors.grey.shade100,
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

            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ürün adı
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  if (product.description != null &&
                      product.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      product.description!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 10),

                  // Fiyat
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${product.price.toStringAsFixed(2)} ₺',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.green.shade700,
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

  // Kategori simgesi için yardımcı metot
  Widget _buildPlaceholderImage(ProductCategory category) {
    return Center(
      child: Icon(
        _getCategoryIcon(category),
        size: 40,
        color: Colors.grey.shade300,
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

    return GridView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
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
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final totalAmount = product.price * _selectedQuantity;

            return AlertDialog(
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
                              icon: const Icon(Icons.add),
                              onPressed: () {
                                setModalState(() {
                                  _selectedQuantity++;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
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
                  onPressed: () {
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
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Siparişi Ekle'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
