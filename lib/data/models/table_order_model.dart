import 'package:uuid/uuid.dart';
import 'order_model.dart';

/// Masa Sipariş Modeli
class TableOrder {
  final int tableNumber;
  final String customerName;
  final int ticketNumber;
  final int childCount;
  final bool isManual;
  final List<Order> orders;
  final DateTime createdAt;
  final bool isActive;

  TableOrder({
    required this.tableNumber,
    required this.customerName,
    required this.ticketNumber,
    required this.childCount,
    required this.isManual,
    this.orders = const [],
    DateTime? createdAt,
    this.isActive = true,
  }) : this.createdAt = createdAt ?? DateTime.now();

  // Toplam sipariş tutarı
  double get totalOrderAmount {
    if (orders.isEmpty) return 0;
    return orders.fold(0, (sum, order) => sum + order.totalPrice);
  }

  // Masada tamamlanmamış sipariş var mı
  bool get hasActiveOrders {
    return orders.any((order) => !order.isCompleted);
  }

  // Sipariş ekleme
  TableOrder addOrder(Order order) {
    final newOrders = List<Order>.from(orders)..add(order);
    return copyWith(orders: newOrders);
  }

  // Sipariş güncelleme
  TableOrder updateOrder(Order updatedOrder) {
    final newOrders = orders
        .map((order) => order.id == updatedOrder.id ? updatedOrder : order)
        .toList();

    return copyWith(orders: newOrders);
  }

  // Sipariş tamamlama
  TableOrder completeOrder(String orderId) {
    final newOrders = orders
        .map(
          (order) =>
              order.id == orderId ? order.copyWith(isCompleted: true) : order,
        )
        .toList();

    return copyWith(orders: newOrders);
  }

  // Sipariş silme
  TableOrder removeOrder(String orderId) {
    final newOrders = orders.where((order) => order.id != orderId).toList();
    return copyWith(orders: newOrders);
  }

  // Copy with fonksiyonu
  TableOrder copyWith({
    int? tableNumber,
    String? customerName,
    int? ticketNumber,
    int? childCount,
    bool? isManual,
    List<Order>? orders,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return TableOrder(
      tableNumber: tableNumber ?? this.tableNumber,
      customerName: customerName ?? this.customerName,
      ticketNumber: ticketNumber ?? this.ticketNumber,
      childCount: childCount ?? this.childCount,
      isManual: isManual ?? this.isManual,
      orders: orders ?? this.orders,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }
}
