import 'product.dart';

class CartItem {
  final Product product;
  int soLuong;
  int donGia;

  CartItem({
    required this.product,
    this.soLuong = 1,
    int? donGia,
  }) : donGia = donGia ?? product.giaBan;

  int get thanhTien => soLuong * donGia;
  int get giaVon => product.giaVon;
  int get tongVon => soLuong * giaVon;
}
