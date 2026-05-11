import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:uuid/uuid.dart';

import '../providers/product_provider.dart';
import '../models/product.dart';
import '../services/excel_service.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _searchController = TextEditingController();
  bool _isImporting = false;
  bool _isExporting = false;
  int _currentPage = 0;
  int _pageSize = 20;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Import / Export ───────────────────────────────────────────────────────

  Future<void> _importExcel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (result == null) return;
    setState(() => _isImporting = true);
    try {
      final picked = result.files.single;
      final List<int> bytes;
      if (picked.bytes != null) {
        bytes = picked.bytes!;
      } else if (picked.path != null) {
        bytes = await File(picked.path!).readAsBytes();
      } else {
        if (mounted) showAppError(context, 'Không thể đọc file');
        return;
      }
      List<List<String?>> rows;
      try {
        rows = ExcelService.readXlsxRows(bytes);
      } catch (e) {
        if (mounted) showAppError(context, 'Không đọc được file Excel: $e');
        return;
      }
      if (rows.length < 2) {
        if (mounted) showAppError(context, 'File Excel không có dữ liệu!');
        return;
      }
      final headers = rows.first.map((c) => c?.trim() ?? '').toList();
      final data = <Map<String, dynamic>>[];
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        final map = <String, dynamic>{};
        for (int j = 0; j < headers.length; j++) {
          map[headers[j]] = j < row.length ? row[j] : null;
        }
        final tenHang = map['Tên hàng']?.toString().trim() ?? '';
        if (tenHang.isNotEmpty) data.add(map);
      }
      if (!mounted) return;
      final provider = context.read<ProductProvider>();
      await provider.importFromExcel(data);
      if (mounted) showAppSuccess(context, 'Đã nhập ${data.length} sản phẩm thành công!');
    } catch (e) {
      if (mounted) showAppError(context, 'Lỗi khi đọc file: $e');
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _exportExcel() async {
    final products = context.read<ProductProvider>().allProducts;
    if (products.isEmpty) {
      showAppError(context, 'Không có sản phẩm để xuất!');
      return;
    }
    setState(() => _isExporting = true);
    try {
      final path = await ExcelService.exportProducts(products);
      if (mounted && path != null) {
        showAppSuccess(context, 'Đã xuất ${products.length} sản phẩm ra $path');
      }
    } catch (e) {
      showAppError(context, 'Lỗi khi xuất file: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  Future<void> _confirmDelete(Product p) async {
    final ok = await showAppConfirmDialog(
      context,
      title: 'Xóa sản phẩm?',
      message: 'Bạn có chắc muốn xóa "${p.tenHang}"?',
      confirmLabel: 'Xóa',
    );
    if (ok && mounted) context.read<ProductProvider>().deleteProduct(p.id);
  }

  // ── Add / Edit dialog ─────────────────────────────────────────────────────

  void _showProductDialog([Product? existing]) {
    const uuid = Uuid();
    final isEdit = existing != null;

    final tenCtrl      = TextEditingController(text: existing?.tenHang ?? '');
    final maHangCtrl   = TextEditingController(text: existing?.maHang ?? '');
    final maVachCtrl   = TextEditingController(text: existing?.maVach ?? '');
    final thuongHieuCtrl = TextEditingController(text: existing?.thuongHieu ?? '');
    final giaBanCtrl   = TextEditingController(text: existing != null ? existing.giaBan.toString() : '');
    final giaVonCtrl   = TextEditingController(text: existing != null ? existing.giaVon.toString() : '');
    final tonKhoCtrl   = TextEditingController(text: existing != null ? existing.tonKho.toString() : '0');
    final nhomCtrl     = TextEditingController(text: existing?.nhomHang ?? '');
    final moTaCtrl     = TextEditingController(text: existing?.moTa ?? '');
    final hinhAnhCtrl  = TextEditingController(text: existing?.hinhAnh ?? '');
    final formKey      = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: SizedBox(
          width: 580,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppDialogHeader(
                title: isEdit ? 'Sửa sản phẩm' : 'Thêm sản phẩm mới',
                icon: isEdit ? Icons.edit_outlined : Icons.add_circle_outline,
                onClose: () => Navigator.pop(ctx),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: formKey,
                    child: Column(
                      children: [
                        Row(children: [
                          Expanded(child: _Field(controller: tenCtrl,        label: 'Tên hàng *', required: true)),
                          const SizedBox(width: 12),
                          Expanded(child: _Field(controller: maHangCtrl,     label: 'Mã hàng')),
                        ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(child: _Field(controller: maVachCtrl,     label: 'Mã vạch')),
                          const SizedBox(width: 12),
                          Expanded(child: _Field(controller: thuongHieuCtrl, label: 'Thương hiệu')),
                        ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(child: _Field(controller: giaBanCtrl, label: 'Giá bán (đ) *', required: true, numeric: true)),
                          const SizedBox(width: 12),
                          Expanded(child: _Field(controller: giaVonCtrl,  label: 'Giá vốn (đ)',  numeric: true)),
                          const SizedBox(width: 12),
                          Expanded(child: _Field(controller: tonKhoCtrl,  label: 'Tồn kho',      numeric: true)),
                        ]),
                        const SizedBox(height: 12),
                        _Field(controller: nhomCtrl,    label: 'Nhóm hàng'),
                        const SizedBox(height: 12),
                        _Field(controller: hinhAnhCtrl, label: 'URL hình ảnh'),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: moTaCtrl,
                          maxLines: 3,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: const InputDecoration(labelText: 'Mô tả'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Hủy'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        final product = Product(
                          id:          existing?.id ?? uuid.v4(),
                          maHang:      maHangCtrl.text,
                          maVach:      maVachCtrl.text,
                          tenHang:     tenCtrl.text,
                          thuongHieu:  thuongHieuCtrl.text,
                          giaBan:      int.tryParse(giaBanCtrl.text) ?? 0,
                          giaVon:      int.tryParse(giaVonCtrl.text) ?? 0,
                          tonKho:      int.tryParse(tonKhoCtrl.text) ?? 0,
                          nhomHang:    nhomCtrl.text,
                          hinhAnh:     hinhAnhCtrl.text,
                          moTa:        moTaCtrl.text,
                        );
                        final provider = context.read<ProductProvider>();
                        if (isEdit) {
                          await provider.updateProduct(product);
                        } else {
                          await provider.addProduct(product);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: Text(isEdit ? 'Lưu thay đổi' : 'Thêm sản phẩm'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản Lý Sản Phẩm'),
        automaticallyImplyLeading: false,
        actions: [
          if (_isImporting)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            )
          else
            TextButton.icon(
              onPressed: _importExcel,
              icon: const Icon(Icons.upload_file, color: Colors.white),
              label: const Text('Nhập Excel', style: TextStyle(color: Colors.white)),
            ),
          const SizedBox(width: 4),
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            )
          else
            TextButton.icon(
              onPressed: _exportExcel,
              icon: const Icon(Icons.download, color: Colors.white),
              label: const Text('Xuất Excel', style: TextStyle(color: Colors.white)),
            ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _showProductDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Thêm mới'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // ── Search & filter bar ─────────────────────────────────────────
          Container(
            color: AppColors.card,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Expanded(
                child: AppSearchField(
                  controller: _searchController,
                  hint: 'Tìm theo tên, mã hàng, mã vạch...',
                  onChanged: (v) {
                    context.read<ProductProvider>().setSearch(v);
                    setState(() => _currentPage = 0);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Consumer<ProductProvider>(
                builder: (ctx, p, _) => DropdownButton<String>(
                  value:         p.selectedCategory.isEmpty ? null : p.selectedCategory,
                  hint:          const Text('Tất cả nhóm'),
                  underline:     const SizedBox(),
                  dropdownColor: AppColors.card,
                  style:         const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Tất cả nhóm hàng')),
                    ...p.categories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                  ],
                  onChanged: (v) {
                    p.setCategory(v ?? '');
                    setState(() => _currentPage = 0);
                  },
                ),
              ),
            ]),
          ),
          const Divider(),

          // ── Table ───────────────────────────────────────────────────────
          Expanded(
            child: Consumer<ProductProvider>(
              builder: (ctx, provider, _) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final products   = provider.products;
                final totalPages = (products.length / _pageSize).ceil().clamp(1, 99999);
                final safePage   = _currentPage.clamp(0, totalPages - 1);
                final start      = safePage * _pageSize;
                final end        = (start + _pageSize).clamp(0, products.length);
                final paged      = products.sublist(start, end);

                if (products.isEmpty) {
                  return const AppEmptyState(
                    icon: Icons.inventory_2_outlined,
                    message: 'Chưa có sản phẩm nào',
                    subtitle: 'Thêm mới hoặc nhập từ Excel',
                  );
                }

                return Column(children: [
                  // Header
                  AppTableHeader(cells: [
                    appTh('Tên sản phẩm', flex: 3),
                    appTh('Mã hàng'),
                    appTh('Nhóm hàng'),
                    appTh('Giá bán',  align: TextAlign.right),
                    appTh('Giá vốn',  align: TextAlign.right),
                    appTh('Tồn kho',  align: TextAlign.center, width: 80),
                    appTh('Thao tác', align: TextAlign.center, width: 100),
                  ]),
                  const Divider(),

                  // Rows
                  Expanded(
                    child: ListView.separated(
                      itemCount: paged.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (ctx, i) {
                        final p = paged[i];
                        return Container(
                          color: appRowColor(i),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(children: [
                            // Product name + image
                            Expanded(
                              flex: 3,
                              child: Row(children: [
                                Container(
                                  width: 38, height: 38,
                                  decoration: BoxDecoration(
                                    color: AppColors.inputFill,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: p.hinhAnh.isNotEmpty
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(
                                            p.hinhAnh.split(',').first.trim(),
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => const Icon(
                                                Icons.image_outlined,
                                                size: 18,
                                                color: AppColors.textMuted),
                                          ),
                                        )
                                      : const Icon(Icons.image_outlined,
                                          size: 18, color: AppColors.textMuted),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(p.tenHang,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                              color: AppColors.textPrimary),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                      if (p.thuongHieu.isNotEmpty)
                                        Text(p.thuongHieu,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textMuted)),
                                    ],
                                  ),
                                ),
                              ]),
                            ),

                            Expanded(
                              child: Text(p.maHang,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                            ),

                            Expanded(child: AppBadge(label: p.nhomHang)),

                            Expanded(
                              child: Text(
                                Utils.formatCurrency(p.giaBan),
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: ctx.primary),
                              ),
                            ),

                            Expanded(
                              child: Text(
                                Utils.formatCurrency(p.giaVon),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary),
                              ),
                            ),

                            SizedBox(
                              width: 80,
                              child: Center(
                                child: AppStockBadge(qty: p.tonKho),
                              ),
                            ),

                            SizedBox(
                              width: 100,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    onPressed: () => _showProductDialog(p),
                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                    color: ctx.primary,
                                    tooltip: 'Sửa',
                                    padding: const EdgeInsets.all(4),
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  ),
                                  IconButton(
                                    onPressed: () => _confirmDelete(p),
                                    icon: const Icon(Icons.delete_outline, size: 18),
                                    color: AppColors.danger,
                                    tooltip: 'Xóa',
                                    padding: const EdgeInsets.all(4),
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  ),
                                ],
                              ),
                            ),
                          ]),
                        );
                      },
                    ),
                  ),

                  // Pagination
                  AppPagination(
                    currentPage:       safePage,
                    totalPages:        totalPages,
                    totalItems:        products.length,
                    startItem:         products.isEmpty ? 0 : start + 1,
                    endItem:           end,
                    pageSize:          _pageSize,
                    itemLabel:         'sản phẩm',
                    onPageChanged:     (p) => setState(() => _currentPage = p),
                    onPageSizeChanged: (s) => setState(() {
                      _pageSize    = s;
                      _currentPage = 0;
                    }),
                  ),
                ]);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable form field ───────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool required;
  final bool numeric;

  const _Field({
    required this.controller,
    required this.label,
    this.required = false,
    this.numeric  = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller:   controller,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(labelText: label, isDense: true),
      validator: required
          ? (v) => (v == null || v.isEmpty) ? 'Không được để trống' : null
          : null,
    );
  }
}