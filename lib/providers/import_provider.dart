import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/import_order.dart';
import '../services/database_service.dart';

class ImportProvider extends ChangeNotifier {
  final _db = DatabaseService();
  List<ImportOrder> _orders = [];
  bool _isLoading = false;

  List<ImportOrder> get orders => _orders;
  bool get isLoading => _isLoading;

  Future<void> loadOrders() async {
    _isLoading = true;
    notifyListeners();
    _orders = await _db.getImportOrders();
    _isLoading = false;
    notifyListeners();
  }

  Future<List<ImportOrderItem>> loadItems(String orderId) {
    return _db.getImportOrderItems(orderId);
  }

  /// [items] chứa donGia/thanhTien gốc (chưa có ship).
  /// [giaVonMap] maps productId → donGia+ship/unit để update gia_von sản phẩm.
  Future<void> createOrder({
    String? supplierId,
    String? tenNCC,
    required DateTime ngayNhap,
    String? ghiChu,
    required List<ImportOrderItem> items,
    int tienShip = 0,
    Map<String, int> giaVonMap = const {},
  }) async {
    final id = const Uuid().v4();
    final tongHang = items.fold<int>(0, (sum, i) => sum + i.thanhTien);
    final order = ImportOrder(
      id: id,
      supplierId: supplierId,
      tenNCC: tenNCC,
      ngayNhap: ngayNhap,
      tongTien: tongHang + tienShip,
      tienShip: tienShip,
      ghiChu: ghiChu?.trim().isEmpty == true ? null : ghiChu?.trim(),
    );
    final itemsWithId = items
        .map((i) => ImportOrderItem(
              importOrderId: id,
              productId: i.productId,
              tenHang: i.tenHang,
              soLuong: i.soLuong,
              donGia: i.donGia,
              thanhTien: i.thanhTien,
            ))
        .toList();
    await _db.insertImportOrder(order, itemsWithId, giaVonMap: giaVonMap);
    await loadOrders();
  }

  Future<void> deleteOrder(String id) async {
    await _db.deleteImportOrder(id);
    _orders.removeWhere((o) => o.id == id);
    notifyListeners();
  }

  /// [newItems] chứa donGia/thanhTien gốc (chưa có ship).
  /// [giaVonMap] maps productId → donGia+ship/unit để update gia_von sản phẩm.
  Future<ImportOrder> updateOrder(
    ImportOrder original, {
    required List<ImportOrderItem> newItems,
    int tienShip = 0,
    String? ghiChu,
    String? supplierId,
    String? tenNCC,
    required DateTime ngayNhap,
    Map<String, int> giaVonMap = const {},
  }) async {
    final tongHang = newItems.fold<int>(0, (s, i) => s + i.thanhTien);
    final tongTien = tongHang + tienShip;
    final cleanGhiChu =
        ghiChu?.trim().isEmpty == true ? null : ghiChu?.trim();
    final newItemMaps = newItems
        .map((i) => {
              'import_order_id': original.id,
              'product_id': i.productId,
              'ten_hang': i.tenHang,
              'so_luong': i.soLuong,
              'don_gia': i.donGia,
              'thanh_tien': i.thanhTien,
            })
        .toList();
    await _db.updateImportOrder(
      original.id,
      newItems: newItemMaps,
      tongTien: tongTien,
      tienShip: tienShip,
      ghiChu: cleanGhiChu,
      supplierId: supplierId,
      tenNCC: tenNCC,
      ngayNhap: ngayNhap,
      giaVonMap: giaVonMap,
    );
    final updated = ImportOrder(
      id: original.id,
      supplierId: supplierId,
      tenNCC: tenNCC,
      ngayNhap: ngayNhap,
      tongTien: tongTien,
      tienShip: tienShip,
      ghiChu: cleanGhiChu,
      trangThai: original.trangThai,
    );
    final idx = _orders.indexWhere((o) => o.id == original.id);
    if (idx >= 0) _orders[idx] = updated;
    notifyListeners();
    return updated;
  }
}
