// import 'dart:convert';
import 'package:flutter/foundation.dart';
// import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../models/product.dart';
import '../services/database_service.dart';

class ProductProvider extends ChangeNotifier {
  final _db = DatabaseService();
  final _uuid = const Uuid();

  List<Product> _products = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String _selectedCategory = '';

  List<Product> get products => _filteredProducts;
  List<Product> get allProducts => _products;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;

  List<String> get categories {
    final cats = _products
        .map((p) => p.nhomHang)
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    cats.sort();
    return cats;
  }

  List<Product> get _filteredProducts {
    var list = _products;
    if (_selectedCategory.isNotEmpty) {
      list = list.where((p) => p.nhomHang == _selectedCategory).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((p) =>
              p.tenHang.toLowerCase().contains(q) ||
              p.maHang.toLowerCase().contains(q) ||
              p.maVach.toLowerCase().contains(q) ||
              p.thuongHieu.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  Future<void> loadProducts() async {
    _isLoading = true;
    notifyListeners();

    _products = await _db.getProducts();

    // // If DB is empty, load from assets JSON
    // if (_products.isEmpty) {
    //   await _loadFromAssets();
    // }

    _isLoading = false;
    notifyListeners();
  }

  /// Reload from DB without auto-importing seed data (used after manual clear).
  Future<void> reloadProducts() async {
    _isLoading = true;
    notifyListeners();
    _products = await _db.getProducts();
    _isLoading = false;
    notifyListeners();
  }

  // Future<void> _loadFromAssets() async {
  //   try {
  //     final jsonStr = await rootBundle.loadString('assets/data/products.json');
  //     final List<dynamic> jsonList = json.decode(jsonStr);
  //     final products = jsonList.map((j) {
  //       final p = Product.fromJson(j as Map<String, dynamic>);
  //       return Product(
  //         id: _uuid.v4(),
  //         maHang: p.maHang,
  //         maVach: p.maVach,
  //         tenHang: p.tenHang,
  //         thuongHieu: p.thuongHieu,
  //         giaBan: p.giaBan,
  //         giaVon: p.giaVon,
  //         tonKho: p.tonKho,
  //         nhomHang: p.nhomHang,
  //         loaiHang: p.loaiHang,
  //         hinhAnh: p.hinhAnh,
  //         moTa: p.moTa,
  //       );
  //     }).toList();
  //     await _db.insertProducts(products);
  //     _products = products;
  //   } catch (e) {
  //     debugPrint('Error loading from assets: $e');
  //   }
  // }

  void setSearch(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  Future<void> addProduct(Product product) async {
    final p = Product(
      id: _uuid.v4(),
      maHang: product.maHang,
      maVach: product.maVach,
      tenHang: product.tenHang,
      thuongHieu: product.thuongHieu,
      giaBan: product.giaBan,
      giaVon: product.giaVon,
      tonKho: product.tonKho,
      nhomHang: product.nhomHang,
      loaiHang: product.loaiHang,
      hinhAnh: product.hinhAnh,
      moTa: product.moTa,
    );
    await _db.insertProduct(p);
    _products.insert(0, p);
    notifyListeners();
  }

  Future<void> updateProduct(Product product) async {
    await _db.updateProduct(product);
    final idx = _products.indexWhere((p) => p.id == product.id);
    if (idx >= 0) {
      _products[idx] = product;
      notifyListeners();
    }
  }

  Future<void> deleteProduct(String id) async {
    await _db.deleteProduct(id);
    _products.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  Future<void> importFromExcel(List<Map<String, dynamic>> data) async {
    final products = data.map((row) {
      int parseNum(dynamic v) {
        if (v == null) return 0;
        if (v is int) return v;
        if (v is double) return v.round();
        final s = v.toString().trim();
        if (s.isEmpty) return 0;
        // Vietnamese/common thousand-separator: "42.000", "1.500.000", "42,000"
        if (RegExp(r'^\d{1,3}([.,]\d{3})+$').hasMatch(s)) {
          return int.tryParse(s.replaceAll('.', '').replaceAll(',', '')) ?? 0;
        }
        // Raw numeric string: "42000", "42000.0", "42000.0000", "4.2E+4"
        final d = double.tryParse(s);
        if (d != null) return d.round();
        // Last resort: strip all non-digits
        return int.tryParse(s.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
      }

      return Product(
        id: _uuid.v4(),
        maHang: row['Mã hàng']?.toString() ?? '',
        maVach: row['Mã vạch']?.toString() ?? '',
        tenHang: row['Tên hàng']?.toString() ?? 'Sản phẩm không tên',
        thuongHieu: row['Thương hiệu']?.toString() ?? '',
        giaBan: parseNum(row['Giá bán']),
        giaVon: parseNum(row['Giá vốn']),
        tonKho: parseNum(row['Tồn kho']),
        nhomHang: row['Nhóm hàng(3 Cấp)']?.toString() ?? '',
        loaiHang: row['Loại hàng']?.toString() ?? 'Hàng hóa',
        hinhAnh: row['Hình ảnh (url1,url2...)']?.toString() ?? '',
        moTa: row['Mô tả']?.toString() ?? '',
      );
    }).toList();

    await _db.insertProducts(products);
    _products.insertAll(0, products);
    notifyListeners();
  }

  Future<void> updateStock(String id, int newStock) async {
    await _db.updateStock(id, newStock);
    final idx = _products.indexWhere((p) => p.id == id);
    if (idx >= 0) {
      _products[idx] = _products[idx].copyWith(tonKho: newStock);
      notifyListeners();
    }
  }

  int get totalProducts => _products.length;
  int get lowStockCount => _products.where((p) => p.tonKho < 5).length;
}
