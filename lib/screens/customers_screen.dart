import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/customer_provider.dart';
import '../providers/auth_provider.dart';
import '../models/customer.dart';
import '../enums/user_role.dart';
import '../services/excel_service.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _searchCtrl = TextEditingController();
  bool _isImporting = false;
  bool _isExporting = false;
  String _typeFilter = '';
  int _currentPage = 0;
  int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerProvider>().loadCustomers();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Role helpers ──────────────────────────────────────────────────────────

  bool _canEdit(BuildContext context) {
    final role = context.read<AuthProvider>().currentUser?.role;
    return role == UserRole.admin || role == UserRole.manager;
  }

  bool _canCreate(BuildContext context) {
    final role = context.read<AuthProvider>().currentUser?.role;
    return role == UserRole.admin ||
        role == UserRole.manager ||
        role == UserRole.cashier;
  }

  // ── Import / Export ───────────────────────────────────────────────────────

  Future<void> _import() async {
    setState(() => _isImporting = true);
    try {
      final result = await ExcelService.importCustomers();
      if (!mounted) return;
      if (result.error != null) {
        showAppError(context, result.error!);
        return;
      }
      if (result.customers.isEmpty && result.skipped == 0) return;
      final provider = context.read<CustomerProvider>();
      await provider.importCustomers(result.customers);
      if (mounted) {
        showAppSuccess(
            context,
            'Đã nhập ${result.customers.length} khách hàng'
            '${result.skipped > 0 ? ', bỏ qua ${result.skipped} trùng mã' : ''}');
      }
    } catch (e) {
      if (mounted) showAppError(context, 'Lỗi: $e');
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _export() async {
    final customers = context.read<CustomerProvider>().allCustomers;
    if (customers.isEmpty) {
      showAppError(context, 'Không có khách hàng để xuất!');
      return;
    }
    setState(() => _isExporting = true);
    try {
      final path = await ExcelService.exportCustomers(customers);
      if (mounted && path != null) {
        showAppSuccess(
            context, 'Đã xuất ${customers.length} khách hàng ra $path');
      }
    } catch (e) {
      if (mounted) showAppError(context, 'Lỗi: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ── CRUD dialogs ──────────────────────────────────────────────────────────

  void _showAddEdit([Customer? existing]) {
    final isEdit = existing != null;
    String loaiKhach = existing?.loaiKhach ?? 'ca_nhan';

    final tenCtrl =
        TextEditingController(text: existing?.tenKhachHang ?? '');
    final maCtrl =
        TextEditingController(text: existing?.maKhachHang ?? '');
    final dtCtrl =
        TextEditingController(text: existing?.dienThoai ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final dcCtrl = TextEditingController(text: existing?.diaChi ?? '');
    final ctyCtrl = TextEditingController(text: existing?.congTy ?? '');
    final mstCtrl =
        TextEditingController(text: existing?.maSoThue ?? '');
    final nhomCtrl =
        TextEditingController(text: existing?.nhomKhachHang ?? '');
    final gcCtrl = TextEditingController(text: existing?.ghiChu ?? '');
    String gioiTinh = existing?.gioiTinh ?? '';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => Dialog(
          child: SizedBox(
            width: 580,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppDialogHeader(
                  title: isEdit
                      ? 'Sửa khách hàng'
                      : 'Thêm khách hàng mới',
                  icon: isEdit
                      ? Icons.edit_outlined
                      : Icons.person_add_outlined,
                  onClose: () => Navigator.pop(ctx),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Loại khách
                          Row(children: [
                            const Text('Loại khách:',
                                style: TextStyle(
                                    color: AppColors.textPrimary)),
                            const SizedBox(width: 12),
                            ChoiceChip(
                              label: const Text('Cá nhân'),
                              selected: loaiKhach == 'ca_nhan',
                              onSelected: (_) =>
                                  setDlg(() => loaiKhach = 'ca_nhan'),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('Công ty'),
                              selected: loaiKhach == 'cong_ty',
                              onSelected: (_) =>
                                  setDlg(() => loaiKhach = 'cong_ty'),
                            ),
                          ]),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(
                                child: _Field(
                                    ctrl: tenCtrl,
                                    label: 'Tên khách hàng *',
                                    required: true)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: _Field(
                                    ctrl: maCtrl,
                                    label: 'Mã khách hàng')),
                          ]),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(
                                child: _Field(
                                    ctrl: dtCtrl,
                                    label: 'Điện thoại')),
                            const SizedBox(width: 12),
                            Expanded(
                                child: _Field(
                                    ctrl: emailCtrl, label: 'Email')),
                          ]),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: gioiTinh.isEmpty
                                    ? null
                                    : gioiTinh,
                                decoration: _inputDeco('Giới tính'),
                                dropdownColor: AppColors.card,
                                style: const TextStyle(
                                    color: AppColors.textPrimary),
                                items: ['Nam', 'Nữ']
                                    .map((g) => DropdownMenuItem(
                                        value: g, child: Text(g)))
                                    .toList(),
                                onChanged: (v) =>
                                    setDlg(() => gioiTinh = v ?? ''),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                                child: _Field(
                                    ctrl: nhomCtrl,
                                    label: 'Nhóm khách hàng')),
                          ]),
                          const SizedBox(height: 12),
                          _Field(ctrl: dcCtrl, label: 'Địa chỉ'),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(
                                child: _Field(
                                    ctrl: ctyCtrl, label: 'Công ty')),
                            const SizedBox(width: 12),
                            Expanded(
                                child: _Field(
                                    ctrl: mstCtrl,
                                    label: 'Mã số thuế')),
                          ]),
                          const SizedBox(height: 12),
                          _Field(
                              ctrl: gcCtrl,
                              label: 'Ghi chú',
                              maxLines: 3),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  decoration: const BoxDecoration(
                      border: Border(
                          top: BorderSide(color: AppColors.border))),
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
                          final provider =
                              context.read<CustomerProvider>();
                          if (isEdit) {
                            final updated = Customer(
                              id: existing.id,
                              maKhachHang: maCtrl.text.trim().isEmpty
                                  ? existing.maKhachHang
                                  : maCtrl.text.trim(),
                              tenKhachHang: tenCtrl.text.trim(),
                              loaiKhach: loaiKhach,
                              dienThoai: dtCtrl.text.trim(),
                              email: emailCtrl.text.trim(),
                              diaChi: dcCtrl.text.trim(),
                              khuVuc: existing.khuVuc,
                              phuongXa: existing.phuongXa,
                              congTy: ctyCtrl.text.trim(),
                              maSoThue: mstCtrl.text.trim(),
                              soCMND: existing.soCMND,
                              ngaySinh: existing.ngaySinh,
                              gioiTinh: gioiTinh,
                              facebook: existing.facebook,
                              nhomKhachHang: nhomCtrl.text.trim(),
                              ghiChu: gcCtrl.text.trim(),
                              nguoiTao: existing.nguoiTao,
                              ngayTao: existing.ngayTao,
                            );
                            await provider.updateCustomer(updated);
                          } else {
                            final err = await provider.createCustomer(
                              tenKhachHang: tenCtrl.text.trim(),
                              loaiKhach: loaiKhach,
                              dienThoai: dtCtrl.text.trim(),
                              email: emailCtrl.text.trim(),
                              diaChi: dcCtrl.text.trim(),
                              congTy: ctyCtrl.text.trim(),
                              maSoThue: mstCtrl.text.trim(),
                              gioiTinh: gioiTinh,
                              nhomKhachHang: nhomCtrl.text.trim(),
                              ghiChu: gcCtrl.text.trim(),
                              maKhachHang: maCtrl.text.trim(),
                            );
                            if (err != null && ctx.mounted) {
                              showAppError(ctx, 'Lỗi: $err');
                              return;
                            }
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: Text(isEdit
                            ? 'Lưu thay đổi'
                            : 'Thêm khách hàng'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(Customer c) async {
    final ok = await showAppConfirmDialog(
      context,
      title: 'Xác nhận xóa',
      message: 'Xóa khách hàng "${c.tenKhachHang}"?',
      confirmLabel: 'Xóa',
      confirmColor: AppColors.danger,
    );
    if (!ok || !mounted) return;
    await context.read<CustomerProvider>().deleteCustomer(c.id);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final canEdit = _canEdit(context);
    final canCreate = _canCreate(context);
    final dateFmt = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Khách hàng'),
        automaticallyImplyLeading: false,
        actions: [
          if (canEdit) ...[
            if (_isImporting)
              const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2)))
            else
              TextButton.icon(
                onPressed: _import,
                icon: const Icon(Icons.upload_file, color: Colors.white),
                label: const Text('Nhập Excel',
                    style: TextStyle(color: Colors.white)),
              ),
            const SizedBox(width: 4),
            if (_isExporting)
              const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2)))
            else
              TextButton.icon(
                onPressed: _export,
                icon: const Icon(Icons.download, color: Colors.white),
                label: const Text('Xuất Excel',
                    style: TextStyle(color: Colors.white)),
              ),
            const SizedBox(width: 4),
          ],
          if (canCreate)
            ElevatedButton.icon(
              onPressed: () => _showAddEdit(),
              icon: const Icon(Icons.person_add),
              label: const Text('Thêm mới'),
            ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Filter bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: AppSearchField(
                    hint: 'Tìm theo tên, SĐT, email, mã khách hàng...',
                    onChanged: (v) {
                      context.read<CustomerProvider>().setSearch(v);
                      setState(() => _currentPage = 0);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _typeFilter.isEmpty ? null : _typeFilter,
                  hint: const Text('Tất cả loại'),
                  underline: const SizedBox(),
                  dropdownColor: AppColors.card,
                  style:
                      const TextStyle(color: AppColors.textPrimary),
                  items: const [
                    DropdownMenuItem(
                        value: '', child: Text('Tất cả loại')),
                    DropdownMenuItem(
                        value: 'ca_nhan', child: Text('Cá nhân')),
                    DropdownMenuItem(
                        value: 'cong_ty', child: Text('Công ty')),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _typeFilter = v ?? '';
                      _currentPage = 0;
                    });
                    context
                        .read<CustomerProvider>()
                        .setTypeFilter(v ?? '');
                  },
                ),
              ],
            ),
          ),

          // Table
          Expanded(
            child: Consumer<CustomerProvider>(
              builder: (ctx, provider, _) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final customers = provider.customers;
                final totalPages =
                    (customers.length / _pageSize).ceil().clamp(1, 99999);
                final safePage = _currentPage.clamp(0, totalPages - 1);
                final start = safePage * _pageSize;
                final end =
                    (start + _pageSize).clamp(0, customers.length);
                final paged = customers.sublist(start, end);

                return Column(
                  children: [
                    // Header row
                    AppTableHeader(cells: [
                      appTh('Mã KH', width: 110),
                      appTh('Loại', width: 88),
                      appTh('Tên khách hàng', flex: 2),
                      appTh('Điện thoại'),
                      appTh('Email'),
                      appTh('Địa chỉ / Ghi chú', flex: 2),
                      appTh('Nhóm'),
                      if (canEdit)
                        appTh('Thao tác',
                            width: 80, align: TextAlign.center),
                    ]),

                    // Rows
                    Expanded(
                      child: paged.isEmpty
                          ? const AppEmptyState(
                              icon: Icons.people_outline,
                              message: 'Chưa có khách hàng',
                            )
                          : ListView.separated(
                              itemCount: paged.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (rowCtx, i) {
                                final c = paged[i];
                                return Container(
                                  color: appRowColor(i),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  child: Row(children: [
                                    SizedBox(
                                      width: 110,
                                      child: Text(c.maKhachHang,
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: rowCtx.primary)),
                                    ),
                                    SizedBox(
                                      width: 88,
                                      child: AppBadge(
                                        label: c.loaiKhach == 'cong_ty'
                                            ? 'Công ty'
                                            : 'Cá nhân',
                                        color: c.loaiKhach == 'cong_ty'
                                            ? AppColors.purple
                                            : rowCtx.primary,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(c.tenKhachHang,
                                              style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.w600,
                                                  fontSize: 13),
                                              maxLines: 1,
                                              overflow:
                                                  TextOverflow.ellipsis),
                                          Text(
                                              dateFmt.format(c.ngayTao),
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors
                                                      .textSecondary)),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                        child: Text(c.dienThoai,
                                            style: const TextStyle(
                                                fontSize: 13))),
                                    Expanded(
                                        child: Text(c.email,
                                            style: const TextStyle(
                                                fontSize: 12),
                                            maxLines: 1,
                                            overflow:
                                                TextOverflow.ellipsis)),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                          c.diaChi.isNotEmpty
                                              ? c.diaChi
                                              : c.ghiChu,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors
                                                  .textSecondary),
                                          maxLines: 2,
                                          overflow:
                                              TextOverflow.ellipsis),
                                    ),
                                    Expanded(
                                        child: c.nhomKhachHang.isNotEmpty
                                            ? AppBadge(
                                                label: c.nhomKhachHang)
                                            : const SizedBox()),
                                    if (canEdit)
                                      SizedBox(
                                        width: 80,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            IconButton(
                                              onPressed: () =>
                                                  _showAddEdit(c),
                                              icon: const Icon(
                                                  Icons.edit_outlined,
                                                  size: 18),
                                              color: rowCtx.primary,
                                              padding:
                                                  const EdgeInsets.all(4),
                                              constraints:
                                                  const BoxConstraints(
                                                      minWidth: 32,
                                                      minHeight: 32),
                                              tooltip: 'Sửa',
                                            ),
                                            IconButton(
                                              onPressed: () =>
                                                  _confirmDelete(c),
                                              icon: const Icon(
                                                  Icons.delete_outline,
                                                  size: 18),
                                              color: AppColors.danger,
                                              padding:
                                                  const EdgeInsets.all(4),
                                              constraints:
                                                  const BoxConstraints(
                                                      minWidth: 32,
                                                      minHeight: 32),
                                              tooltip: 'Xóa',
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
                      currentPage: safePage,
                      totalPages: totalPages,
                      totalItems: customers.length,
                      startItem: customers.isEmpty ? 0 : start + 1,
                      endItem: end,
                      pageSize: _pageSize,
                      onPageChanged: (p) =>
                          setState(() => _currentPage = p),
                      onPageSizeChanged: (s) => setState(() {
                        _pageSize = s;
                        _currentPage = 0;
                      }),
                      itemLabel: 'khách hàng',
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

InputDecoration _inputDeco(String label) => InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );

class _Field extends StatelessWidget {
  const _Field({
    required this.ctrl,
    required this.label,
    this.required = false,
    this.maxLines = 1,
  });
  final TextEditingController ctrl;
  final String label;
  final bool required;
  final int maxLines;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: _inputDeco(label),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null
            : null,
      );
}
