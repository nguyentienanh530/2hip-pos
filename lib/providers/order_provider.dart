import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/order.dart';
import '../models/cart_item.dart';
import '../services/database_service.dart';

class OrderProvider extends ChangeNotifier {
  final _db = DatabaseService();
  final _uuid = const Uuid();

  List<Order> _orders = [];
  bool _isLoading = false;
  Map<String, dynamic> _stats = {
    'hom_nay': 0,
    'von_hom_nay': 0,
    'loi_nhuan_hom_nay': 0,
    'thang_nay': 0,
    'von_thang_nay': 0,
    'loi_nhuan_thang_nay': 0,
    'tong_cong': 0,
    'so_don': 0,
  };

  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;
  Map<String, dynamic> get stats => _stats;

  Future<void> loadOrders() async {
    _isLoading = true;
    notifyListeners();

    final orderMaps = await _db.getOrders();
    final orders = <Order>[];

    for (final m in orderMaps) {
      final itemMaps = await _db.getOrderItems(m['id'] as String);
      final items = itemMaps.map((i) => OrderItem.fromMap(i)).toList();
      orders.add(Order(
        id: m['id'] as String,
        ngayTao: DateTime.parse(m['ngay_tao'] as String),
        items: items,
        tongTien: m['tong_tien'] as int,
        tongVon: (m['tong_von'] as int?) ?? 0,
        giamGia: (m['giam_gia'] as int?) ?? 0,
        khachDua: m['khach_dua'] as int,
        tienThua: m['tien_thua'] as int,
        ghiChu: m['ghi_chu']?.toString() ?? '',
        trangThai: m['trang_thai']?.toString() ?? 'hoan_thanh',
        khachHangId: m['khach_hang_id'] as String?,
        tenKhach: m['ten_khach'] as String? ?? 'Khách lẻ',
        nguoiTao: m['nguoi_tao'] as String? ?? '',
      ));
    }

    _orders = orders;
    await refreshStats();
    _isLoading = false;
    notifyListeners();
  }

  Future<Order> createOrder({
    required List<CartItem> cartItems,
    required int tongTien,
    required int tongVon,
    required int khachDua,
    required int tienThua,
    required int giamGia,
    String ghiChu = '',
    String? khachHangId,
    String tenKhach = 'Khách lẻ',
    String nguoiTao = '',
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    final items = cartItems
        .map((c) => OrderItem(
              productId: c.product.id,
              tenHang: c.product.tenHang,
              soLuong: c.soLuong,
              donGia: c.donGia,
              thanhTien: c.thanhTien,
              giaVon: c.giaVon,
            ))
        .toList();

    final itemMaps = cartItems
        .map((c) => {
              'product_id': c.product.id,
              'ten_hang': c.product.tenHang,
              'so_luong': c.soLuong,
              'don_gia': c.donGia,
              'thanh_tien': c.thanhTien,
              'gia_von': c.giaVon,
            })
        .toList();

    await _db.insertOrder(
      id,
      now,
      tongTien,
      khachDua,
      tienThua,
      ghiChu,
      itemMaps,
      tongVon: tongVon,
      giamGia: giamGia,
      khachHangId: khachHangId,
      tenKhach: tenKhach,
      nguoiTao: nguoiTao,
    );

    final order = Order(
        id: id,
        ngayTao: now,
        items: items,
        tongTien: tongTien,
        tongVon: tongVon,
        khachDua: khachDua,
        tienThua: tienThua,
        ghiChu: ghiChu,
        khachHangId: khachHangId,
        tenKhach: tenKhach,
        giamGia: giamGia,
        nguoiTao: nguoiTao);

    _orders.insert(0, order);
    await refreshStats();
    notifyListeners();
    return order;
  }

  Future<void> deleteOrder(String orderId) async {
    await _db.deleteOrder(orderId);
    _orders.removeWhere((o) => o.id == orderId);
    await refreshStats();
    notifyListeners();
  }

  Future<Order> updateOrder(
    Order original, {
    required List<OrderItem> newItems,
    required List<Map<String, dynamic>> newItemMaps,
    required int tongTien,
    required int tongVon,
    required int giamGia,
    required int khachDua,
    required int tienThua,
    String ghiChu = '',
  }) async {
    await _db.updateOrder(
      original.id,
      newItems: newItemMaps,
      tongTien: tongTien,
      tongVon: tongVon,
      giamGia: giamGia,
      khachDua: khachDua,
      tienThua: tienThua,
      ghiChu: ghiChu,
    );
    final updated = Order(
      id: original.id,
      ngayTao: original.ngayTao,
      items: newItems,
      tongTien: tongTien,
      tongVon: tongVon,
      giamGia: giamGia,
      khachDua: khachDua,
      tienThua: tienThua,
      ghiChu: ghiChu,
      trangThai: original.trangThai,
      khachHangId: original.khachHangId,
      tenKhach: original.tenKhach,
    );
    final idx = _orders.indexWhere((o) => o.id == original.id);
    if (idx >= 0) _orders[idx] = updated;
    await refreshStats();
    notifyListeners();
    return updated;
  }

  Future<void> refreshStats() async {
    _stats = await _db.getRevenueStats();
    notifyListeners();
  }
}
