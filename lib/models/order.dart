class OrderItem {
  final String productId;
  final String tenHang;
  final int soLuong;
  final int donGia;
  final int thanhTien;
  final int giaVon;

  OrderItem({
    required this.productId,
    required this.tenHang,
    required this.soLuong,
    required this.donGia,
    required this.thanhTien,
    this.giaVon = 0,
  });

  Map<String, dynamic> toMap() => {
        'product_id': productId,
        'ten_hang': tenHang,
        'so_luong': soLuong,
        'don_gia': donGia,
        'thanh_tien': thanhTien,
        'gia_von': giaVon,
      };

  factory OrderItem.fromMap(Map<String, dynamic> map) => OrderItem(
        productId: map['product_id'] ?? '',
        tenHang: map['ten_hang'] ?? '',
        soLuong: map['so_luong'] ?? 0,
        donGia: map['don_gia'] ?? 0,
        thanhTien: map['thanh_tien'] ?? 0,
        giaVon: map['gia_von'] as int? ?? 0,
      );
}

class Order {
  final String id;
  final DateTime ngayTao;
  final List<OrderItem> items;
  final int tongTien;
  final int tongVon;
  final int khachDua;
  final int tienThua;
  final int giamGia;
  final String ghiChu;
  final String trangThai;
  final String? khachHangId;
  final String tenKhach;
  final String nguoiTao;

  Order({
    required this.id,
    required this.ngayTao,
    required this.items,
    required this.tongTien,
    this.tongVon = 0,
    required this.khachDua,
    required this.tienThua,
    this.giamGia = 0,
    this.ghiChu = '',
    this.trangThai = 'hoan_thanh',
    this.khachHangId,
    this.tenKhach = 'Khách lẻ',
    this.nguoiTao = '',
  });

  int get soMatHang => items.length;
  int get tongSoLuong => items.fold(0, (sum, item) => sum + item.soLuong);
  int get tongTienHang => tongTien + giamGia;
  int get loiNhuan => tongTien - tongVon;
}
