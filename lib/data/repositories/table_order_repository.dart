import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import '../models/order_model.dart';
import '../models/table_order_model.dart';

/// Masa siparişlerini yönetmek için repository sınıfı
class TableOrderRepository {
  // Firestore koleksiyonu
  static const String _collectionName = 'tables';
  final CollectionReference _tablesCollection =
      FirebaseFirestore.instance.collection(_collectionName);

  // Stream controller ve cache için değişkenler
  final _tableStreamController = StreamController<List<TableOrder>>.broadcast();
  List<TableOrder> _cachedTables = [];

  // Dışa açılan stream ve getterlar
  Stream<List<TableOrder>> get tablesStream => _tableStreamController.stream;
  List<TableOrder> get tables => List.unmodifiable(_cachedTables);

  // Singleton yapısı
  static final TableOrderRepository _instance = TableOrderRepository._internal();
  factory TableOrderRepository() => _instance;

  TableOrderRepository._internal() {
    _startListeningToTables();
    print('TableOrderRepository başarıyla başlatıldı');
  }

  /// Masaları dinlemeye başlar ve değişikliklerini stream'e iletir
  void _startListeningToTables() {
    try {
      _tablesCollection.snapshots().listen(
        (snapshot) {
          _cachedTables = snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return _tableFromJson({...data, 'id': doc.id});
          }).toList();
          
          _tableStreamController.add(_cachedTables);
        },
        onError: (error) {
          print('Masa verileri dinlenirken hata: $error');
          // Hata durumunda boş liste gönder
          _tableStreamController.add([]);
        },
      );
    } catch (e) {
      print('Masa dinleme başlatma hatası: $e');
    }
  }

  /// Firebase'den masa bilgisini dönüştürür
  TableOrder _tableFromJson(Map<String, dynamic> json) {
    try {
      // Order listesini dönüştür
      List<Order> orders = [];
      if (json['orders'] != null) {
        final orderList = json['orders'] as List<dynamic>;
        orders = orderList.map((orderData) {
          return Order(
            id: orderData['id'],
            productName: orderData['productName'],
            price: (orderData['price'] as num).toDouble(),
            quantity: orderData['quantity'],
            orderTime: DateTime.parse(orderData['orderTime']),
            isCompleted: orderData['isCompleted'] ?? false,
          );
        }).toList();
      }

      return TableOrder(
        tableNumber: json['tableNumber'],
        customerName: json['customerName'],
        childName: json['childName'] ?? '',
        ticketNumber: json['ticketNumber'] ?? 0,
        childCount: json['childCount'] ?? 1,
        isManual: json['isManual'] ?? false,
        orders: orders,
        createdAt: json['createdAt'] != null 
            ? (json['createdAt'] is Timestamp 
                ? (json['createdAt'] as Timestamp).toDate()
                : DateTime.parse(json['createdAt']))
            : DateTime.now(),
        isActive: json['isActive'] ?? true,
      );
    } catch (e) {
      print('Masa JSON dönüşüm hatası: $e');
      // Dönüşüm hatası olursa varsayılan bir masa döndür
      return TableOrder(
        tableNumber: 0,
        customerName: 'Hatalı Masa',
        childName: 'Hatalı Çocuk',
        ticketNumber: 0,
        childCount: 0,
        isManual: false,
      );
    }
  }

  /// Masa bilgisini JSON'a dönüştürür
  Map<String, dynamic> _tableToJson(TableOrder table) {
    // Sipariş listesini dönüştür
    final List<Map<String, dynamic>> ordersJson = table.orders.map((order) {
      return {
        'id': order.id,
        'productName': order.productName,
        'price': order.price,
        'quantity': order.quantity,
        'orderTime': order.orderTime.toIso8601String(),
        'isCompleted': order.isCompleted,
      };
    }).toList();

    return {
      'tableNumber': table.tableNumber,
      'customerName': table.customerName,
      'childName': table.childName,
      'ticketNumber': table.ticketNumber,
      'childCount': table.childCount,
      'isManual': table.isManual,
      'orders': ordersJson,
      'createdAt': table.createdAt.toIso8601String(),
      'isActive': table.isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Yeni masa ekler
  Future<void> addTable(TableOrder table) async {
    try {
      final json = _tableToJson(table);
      await _tablesCollection.add(json);
      print('Masa eklendi: #${table.tableNumber}');
    } catch (e) {
      print('Masa eklenirken hata: $e');
      rethrow;
    }
  }

  /// Mevcut masayı günceller
  Future<void> updateTable(TableOrder table) async {
    try {
      // Masa ID'si yoksa, tableNumber ile bul
      final snapshot = await _tablesCollection
          .where('tableNumber', isEqualTo: table.tableNumber)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        // Masa bulunamadıysa yeni ekle
        await addTable(table);
        return;
      }

      // Masa bulunduysa güncelle
      final docId = snapshot.docs.first.id;
      await _tablesCollection.doc(docId).update(_tableToJson(table));
      print('Masa güncellendi: #${table.tableNumber}');
    } catch (e) {
      print('Masa güncellenirken hata: $e');
      rethrow;
    }
  }

  /// Masa siler
  Future<void> deleteTable(int tableNumber) async {
    try {
      // TableNumber ile masa bul
      final snapshot = await _tablesCollection
          .where('tableNumber', isEqualTo: tableNumber)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        print('Silinecek masa bulunamadı: #$tableNumber');
        return;
      }

      // Masa bulunduysa sil
      final docId = snapshot.docs.first.id;
      await _tablesCollection.doc(docId).delete();
      print('Masa silindi: #$tableNumber');
    } catch (e) {
      print('Masa silinirken hata: $e');
      rethrow;
    }
  }

  /// Müşteri biletine göre masayı arar
  Future<TableOrder?> findTableByTicketNumber(int ticketNumber) async {
    try {
      final snapshot = await _tablesCollection
          .where('ticketNumber', isEqualTo: ticketNumber)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      final doc = snapshot.docs.first;
      return _tableFromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id});
    } catch (e) {
      print('Bilet numarasına göre masa aranırken hata: $e');
      return null;
    }
  }

  /// Tüm masaları getirir
  Future<List<TableOrder>> getAllTables() async {
    try {
      final snapshot = await _tablesCollection.get();
      return snapshot.docs.map((doc) {
        return _tableFromJson({...doc.data() as Map<String, dynamic>, 'id': doc.id});
      }).toList();
    } catch (e) {
      print('Masalar alınırken hata: $e');
      return [];
    }
  }

  /// Sipariş ekler veya günceller
  Future<void> updateTableOrders(int tableNumber, List<Order> orders) async {
    try {
      // Masa bul
      final snapshot = await _tablesCollection
          .where('tableNumber', isEqualTo: tableNumber)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        print('Sipariş eklenecek masa bulunamadı: #$tableNumber');
        return;
      }

      // Masa bulunduysa siparişleri güncelle
      final docId = snapshot.docs.first.id;
      
      // Siparişleri JSON'a dönüştür
      final List<Map<String, dynamic>> ordersJson = orders.map((order) {
        return {
          'id': order.id,
          'productName': order.productName,
          'price': order.price,
          'quantity': order.quantity,
          'orderTime': order.orderTime.toIso8601String(),
          'isCompleted': order.isCompleted,
        };
      }).toList();

      await _tablesCollection.doc(docId).update({
        'orders': ordersJson,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      print('Masa siparişleri güncellendi: #$tableNumber');
    } catch (e) {
      print('Masa siparişleri güncellenirken hata: $e');
      rethrow;
    }
  }

  /// Repository kapatılırken stream controller'ı temizler
  void dispose() {
    _tableStreamController.close();
  }
}
