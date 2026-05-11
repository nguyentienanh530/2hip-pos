import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/customer.dart';
import '../services/database_service.dart';

class CustomerProvider extends ChangeNotifier {
  final _db = DatabaseService();
  final _uuid = const Uuid();

  List<Customer> _customers = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String _typeFilter = ''; // '' | 'ca_nhan' | 'cong_ty'

  List<Customer> get customers => _filtered;
  List<Customer> get allCustomers => _customers;
  bool get isLoading => _isLoading;
  int get totalCustomers => _customers.length;

  List<Customer> get _filtered {
    var list = _customers;
    if (_typeFilter.isNotEmpty) {
      list = list.where((c) => c.loaiKhach == _typeFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((c) =>
          c.tenKhachHang.toLowerCase().contains(q) ||
          c.dienThoai.toLowerCase().contains(q) ||
          c.email.toLowerCase().contains(q) ||
          c.maKhachHang.toLowerCase().contains(q) ||
          c.ghiChu.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  Future<void> loadCustomers() async {
    _isLoading = true;
    notifyListeners();
    _customers = await _db.getCustomers();
    _isLoading = false;
    notifyListeners();
  }

  void setSearch(String q) {
    _searchQuery = q;
    notifyListeners();
  }

  void setTypeFilter(String t) {
    _typeFilter = t;
    notifyListeners();
  }

  Future<String?> createCustomer({
    required String tenKhachHang,
    String loaiKhach = 'ca_nhan',
    String dienThoai = '',
    String email = '',
    String diaChi = '',
    String khuVuc = '',
    String phuongXa = '',
    String congTy = '',
    String maSoThue = '',
    String soCMND = '',
    String ngaySinh = '',
    String gioiTinh = '',
    String facebook = '',
    String nhomKhachHang = '',
    String ghiChu = '',
    String nguoiTao = '',
    String? maKhachHang,
  }) async {
    try {
      final code = maKhachHang?.isNotEmpty == true
          ? maKhachHang!
          : await _db.getNextCustomerCode();
      final customer = Customer(
        id: _uuid.v4(),
        maKhachHang: code,
        tenKhachHang: tenKhachHang,
        loaiKhach: loaiKhach,
        dienThoai: dienThoai,
        email: email,
        diaChi: diaChi,
        khuVuc: khuVuc,
        phuongXa: phuongXa,
        congTy: congTy,
        maSoThue: maSoThue,
        soCMND: soCMND,
        ngaySinh: ngaySinh,
        gioiTinh: gioiTinh,
        facebook: facebook,
        nhomKhachHang: nhomKhachHang,
        ghiChu: ghiChu,
        nguoiTao: nguoiTao,
        ngayTao: DateTime.now(),
      );
      await _db.insertCustomer(customer);
      _customers.insert(0, customer);
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> updateCustomer(Customer customer) async {
    await _db.updateCustomer(customer);
    final idx = _customers.indexWhere((c) => c.id == customer.id);
    if (idx >= 0) {
      _customers[idx] = customer;
      notifyListeners();
    }
  }

  Future<void> deleteCustomer(String id) async {
    await _db.deleteCustomer(id);
    _customers.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  Future<void> importCustomers(List<Customer> customers) async {
    for (final c in customers) {
      await _db.insertCustomer(c);
    }
    await loadCustomers();
  }
}
