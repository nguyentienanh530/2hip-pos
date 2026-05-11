import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/supplier.dart';
import '../services/database_service.dart';

class SupplierProvider extends ChangeNotifier {
  final _db = DatabaseService();
  List<Supplier> _suppliers = [];
  bool _isLoading = false;

  List<Supplier> get suppliers => _suppliers;
  bool get isLoading => _isLoading;

  Future<void> loadSuppliers() async {
    _isLoading = true;
    notifyListeners();
    _suppliers = await _db.getSuppliers();
    _isLoading = false;
    notifyListeners();
  }

  /// Returns null on success, error message on failure.
  Future<String?> createSupplier({
    required String tenNCC,
    String? maNCC,
    String? diaChi,
    String? soDienThoai,
    String? email,
    String? website,
    String? ghiChu,
  }) async {
    if (maNCC != null &&
        maNCC.isNotEmpty &&
        await _db.supplierCodeExists(maNCC)) {
      return 'Mã nhà cung cấp đã tồn tại';
    }
    await _db.insertSupplier(Supplier(
      id: const Uuid().v4(),
      tenNCC: tenNCC.trim(),
      maNCC: maNCC?.trim().isEmpty == true ? null : maNCC?.trim(),
      diaChi: diaChi?.trim().isEmpty == true ? null : diaChi?.trim(),
      soDienThoai:
          soDienThoai?.trim().isEmpty == true ? null : soDienThoai?.trim(),
      email: email?.trim().isEmpty == true ? null : email?.trim(),
      website: website?.trim().isEmpty == true ? null : website?.trim(),
      ghiChu: ghiChu?.trim().isEmpty == true ? null : ghiChu?.trim(),
      createdAt: DateTime.now(),
    ));
    await loadSuppliers();
    return null;
  }

  Future<String?> updateSupplier(Supplier updated) async {
    if (updated.maNCC != null && updated.maNCC!.isNotEmpty) {
      if (await _db.supplierCodeExists(updated.maNCC!, excludeId: updated.id)) {
        return 'Mã nhà cung cấp đã tồn tại';
      }
    }
    await _db.updateSupplier(updated);
    await loadSuppliers();
    return null;
  }

  Future<void> deleteSupplier(String id) async {
    await _db.deleteSupplier(id);
    await loadSuppliers();
  }
}
