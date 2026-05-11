import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../models/cart_item.dart';

class CartProvider extends ChangeNotifier {
  final Map<String, CartItem> _items = {};

  Map<String, CartItem> get items => _items;
  List<CartItem> get itemList => _items.values.toList();
  bool get isEmpty => _items.isEmpty;
  int get itemCount => _items.length;

  int get tongTien => _items.values.fold(0, (sum, i) => sum + i.thanhTien);
  int get tongVon => _items.values.fold(0, (sum, i) => sum + i.tongVon);
  int get tongSoLuong => _items.values.fold(0, (sum, i) => sum + i.soLuong);

  int get quantity {
    return _items.values.fold(
      0,
      (sum, item) => sum + item.soLuong,
    );
  }

  // void addProduct(Product product, {int quantity = 1}) {
  //   print({'quantity': _quantity, 'tonKho': product.tonKho});

  //   if (_items.containsKey(product.id)) {
  //     _items[product.id]!.soLuong += quantity;
  //   } else {
  //     _items[product.id] = CartItem(product: product, soLuong: quantity);
  //   }
  //   _quantity = _items[product.id]!.soLuong;
  //   notifyListeners();
  // }

  void addProduct(Product product, {int quantity = 1}) {
    final existingQuantity = _items[product.id]?.soLuong ?? 0;

    if (existingQuantity + quantity > product.tonKho) {
      print('Vượt quá tồn kho');
      return;
    }

    if (_items.containsKey(product.id)) {
      _items[product.id]!.soLuong += quantity;
    } else {
      _items[product.id] = CartItem(
        product: product,
        soLuong: quantity,
      );
    }

    notifyListeners();
  }

  void removeProduct(String productId) {
    _items.remove(productId);
    // _quantity = 1;
    notifyListeners();
  }

  void increaseQuantity(CartItem item) {
    if (_items.containsKey(item.product.id)) {
      if (_items[item.product.id]!.soLuong >= item.product.tonKho) return;
      _items[item.product.id]!.soLuong++;
      // _quantity = _items[item.product.id]!.soLuong;
      notifyListeners();
    }
  }

  void decreaseQuantity(String productId) {
    if (_items.containsKey(productId)) {
      if (_items[productId]!.soLuong <= 1) {
        _items.remove(productId);
      } else {
        _items[productId]!.soLuong--;
        // _quantity = _items[productId]!.soLuong;
      }
      notifyListeners();
    }
  }

  void updateQuantity(String productId, int quantity) {
    if (_items.containsKey(productId)) {
      if (quantity <= 0) {
        _items.remove(productId);
      } else {
        _items[productId]!.soLuong = quantity;
      }
      notifyListeners();
    }
  }

  void updatePrice(String productId, int price) {
    if (_items.containsKey(productId)) {
      _items[productId]!.donGia = price;
      notifyListeners();
    }
  }

  void clear() {
    _items.clear();
    // _quantity = 1;
    notifyListeners();
  }
}
