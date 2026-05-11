class ImportOrderItem {
  final int? id;
  final String importOrderId;
  final String? productId;
  final String tenHang;
  final int soLuong;
  final int donGia;
  final int thanhTien;

  const ImportOrderItem({
    this.id,
    required this.importOrderId,
    this.productId,
    required this.tenHang,
    required this.soLuong,
    required this.donGia,
    required this.thanhTien,
  });

  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{
      'import_order_id': importOrderId,
      'product_id': productId,
      'ten_hang': tenHang,
      'so_luong': soLuong,
      'don_gia': donGia,
      'thanh_tien': thanhTien,
    };
    if (id != null) m['id'] = id;
    return m;
  }

  factory ImportOrderItem.fromMap(Map<String, dynamic> m) => ImportOrderItem(
        id: m['id'] as int?,
        importOrderId: m['import_order_id'] as String,
        productId: m['product_id'] as String?,
        tenHang: m['ten_hang'] as String,
        soLuong: m['so_luong'] as int,
        donGia: m['don_gia'] as int,
        thanhTien: m['thanh_tien'] as int,
      );
}

class ImportOrder {
  final String id;
  final String? supplierId;
  final String? tenNCC;
  final DateTime ngayNhap;
  final int tongTien;
  final int tienShip;
  final String? ghiChu;
  final String trangThai;
  final List<ImportOrderItem> items;

  const ImportOrder({
    required this.id,
    this.supplierId,
    this.tenNCC,
    required this.ngayNhap,
    required this.tongTien,
    this.tienShip = 0,
    this.ghiChu,
    this.trangThai = 'da_nhap',
    this.items = const [],
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'supplier_id': supplierId,
        'ten_ncc': tenNCC,
        'ngay_nhap': ngayNhap.toIso8601String(),
        'tong_tien': tongTien,
        'tien_ship': tienShip,
        'ghi_chu': ghiChu,
        'trang_thai': trangThai,
      };

  factory ImportOrder.fromMap(Map<String, dynamic> m,
          {List<ImportOrderItem> items = const []}) =>
      ImportOrder(
        id: m['id'] as String,
        supplierId: m['supplier_id'] as String?,
        tenNCC: m['ten_ncc'] as String?,
        ngayNhap: DateTime.parse(m['ngay_nhap'] as String),
        tongTien: (m['tong_tien'] as int?) ?? 0,
        tienShip: (m['tien_ship'] as int?) ?? 0,
        ghiChu: m['ghi_chu'] as String?,
        trangThai: (m['trang_thai'] as String?) ?? 'da_nhap',
        items: items,
      );
}
