import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/supplier_provider.dart';
import '../models/supplier.dart';
import '../services/excel_service.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final _searchCtrl = TextEditingController();
  String _q = '';
  bool _exporting = false;
  bool _importing = false;

  Future<void> _export(List<Supplier> suppliers) async {
    if (suppliers.isEmpty) {
      showAppError(context, 'Không có nhà cung cấp để xuất');
      return;
    }
    setState(() => _exporting = true);
    try {
      final path = await ExcelService.exportSuppliers(suppliers);
      if (!mounted) return;
      if (path != null) {
        showAppSuccess(context,
            'Đã xuất ${suppliers.length} NCC → $path');
      }
    } catch (e) {
      if (mounted) showAppError(context, 'Lỗi xuất file: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _import() async {
    setState(() => _importing = true);
    try {
      final result = await ExcelService.importSuppliers();
      if (!mounted) return;
      if (result.error != null) {
        showAppError(context, result.error!);
        return;
      }
      if (result.imported == 0 && result.skipped == 0) return;
      final provider = context.read<SupplierProvider>();
      await provider.loadSuppliers();
      if (!mounted) return;
      final msg = result.skipped > 0
          ? 'Đã nhập ${result.imported} NCC, bỏ qua ${result.skipped} trùng mã'
          : 'Đã nhập ${result.imported} nhà cung cấp thành công';
      showAppSuccess(context, msg);
    } catch (e) {
      if (mounted) showAppError(context, 'Lỗi nhập file: $e');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupplierProvider>().loadSuppliers();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Supplier> _filtered(List<Supplier> all) {
    if (_q.isEmpty) return all;
    final q = _q.toLowerCase();
    return all
        .where((s) =>
            s.tenNCC.toLowerCase().contains(q) ||
            (s.maNCC?.toLowerCase().contains(q) ?? false) ||
            (s.soDienThoai?.contains(q) ?? false) ||
            (s.email?.toLowerCase().contains(q) ?? false) ||
            (s.diaChi?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SupplierProvider>(
      builder: (context, provider, _) {
        final list = _filtered(provider.suppliers);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            _buildSearch(),
            _buildStats(provider.suppliers),
            const Divider(height: 1),
            Expanded(
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : list.isEmpty
                      ? _buildEmpty()
                      : _buildList(list),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final suppliers = context.watch<SupplierProvider>().suppliers;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Row(
        children: [
          Icon(Icons.local_shipping,
              color: context.primary, size: 28),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nhà cung cấp',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              Text('Quản lý danh sách nhà cung cấp',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          const Spacer(),
          if (_exporting)
            const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
          else
            Tooltip(
              message: 'Xuất Excel',
              child: IconButton(
                icon: const Icon(Icons.upload_file_outlined),
                onPressed: () => _export(suppliers),
              ),
            ),
          const SizedBox(width: 4),
          if (_importing)
            const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
          else
            Tooltip(
              message: 'Nhập từ Excel',
              child: IconButton(
                icon: const Icon(Icons.download_outlined),
                onPressed: _import,
              ),
            ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.add_business),
            label: const Text('Thêm NCC'),
            onPressed: () => _openForm(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: AppSearchField(
        hint: 'Tìm theo tên, mã NCC, SĐT, email...',
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _q = v),
      ),
    );
  }

  Widget _buildStats(List<Supplier> all) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Row(
        children: [
          _StatCard(
            icon: Icons.local_shipping_outlined,
            label: 'Tổng NCC',
            value: '${all.length}',
            color: context.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return AppEmptyState(
      icon: Icons.local_shipping_outlined,
      message: _q.isNotEmpty
          ? 'Không tìm thấy nhà cung cấp phù hợp'
          : 'Chưa có nhà cung cấp nào',
    );
  }

  Widget _buildList(List<Supplier> list) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      itemCount: list.length,
      itemBuilder: (_, i) => _SupplierCard(
        supplier: list[i],
        onEdit: () => _openForm(context, existing: list[i]),
        onDelete: () => _confirmDelete(context, list[i]),
      ),
    );
  }

  void _openForm(BuildContext context, {Supplier? existing}) {
    showDialog(
      context: context,
      builder: (_) => SupplierFormDialog(existing: existing),
    );
  }

  void _confirmDelete(BuildContext context, Supplier s) async {
    final ok = await showAppConfirmDialog(
      context,
      title: 'Xóa nhà cung cấp',
      message:
          'Xóa nhà cung cấp "${s.tenNCC}"?\nThao tác này không thể hoàn tác.',
      confirmLabel: 'Xóa',
      confirmColor: AppColors.danger,
    );
    if (!ok || !context.mounted) return;
    await context.read<SupplierProvider>().deleteSupplier(s.id);
    if (context.mounted) showAppSuccess(context, 'Đã xóa nhà cung cấp');
  }
}

// ─── Supplier Card ────────────────────────────────────────────────────────────

class _SupplierCard extends StatelessWidget {
  final Supplier supplier;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SupplierCard({
    required this.supplier,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: context.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.local_shipping_outlined,
                  color: context.primary, size: 22),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(supplier.tenNCC,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppColors.textPrimary)),
                      ),
                      if (supplier.maNCC != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                context.primary.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: context.primary
                                    .withValues(alpha: .3)),
                          ),
                          child: Text(supplier.maNCC!,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: context.primary,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 14,
                    children: [
                      if (supplier.soDienThoai != null)
                        _InfoChip(
                            Icons.phone_outlined, supplier.soDienThoai!),
                      if (supplier.email != null)
                        _InfoChip(Icons.email_outlined, supplier.email!),
                      if (supplier.diaChi != null)
                        _InfoChip(Icons.location_on_outlined,
                            supplier.diaChi!),
                      if (supplier.website != null)
                        _InfoChip(
                            Icons.language_outlined, supplier.website!),
                      _InfoChip(
                          Icons.calendar_today_outlined,
                          'Tạo: ${DateFormat('dd/MM/yyyy').format(supplier.createdAt)}'),
                    ],
                  ),
                  if (supplier.ghiChu != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(supplier.ghiChu!,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                ],
              ),
            ),
            // Actions
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Chỉnh sửa',
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  color: context.primary,
                  onPressed: onEdit,
                ),
                IconButton(
                  tooltip: 'Xóa',
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: AppColors.danger,
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Small widgets ────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
              Text(value,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoChip(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textSecondary),
        const SizedBox(width: 3),
        Text(text,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary),
            overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

// ─── Supplier Form Dialog ─────────────────────────────────────────────────────

class SupplierFormDialog extends StatefulWidget {
  final Supplier? existing;
  const SupplierFormDialog({super.key, this.existing});

  @override
  State<SupplierFormDialog> createState() => _SupplierFormDialogState();
}

class _SupplierFormDialogState extends State<SupplierFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _tenCtrl = TextEditingController();
  final _maCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _isSubmitting = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final s = widget.existing!;
      _tenCtrl.text = s.tenNCC;
      _maCtrl.text = s.maNCC ?? '';
      _phoneCtrl.text = s.soDienThoai ?? '';
      _emailCtrl.text = s.email ?? '';
      _addressCtrl.text = s.diaChi ?? '';
      _websiteCtrl.text = s.website ?? '';
      _noteCtrl.text = s.ghiChu ?? '';
    }
  }

  @override
  void dispose() {
    for (final c in [
      _tenCtrl,
      _maCtrl,
      _phoneCtrl,
      _emailCtrl,
      _addressCtrl,
      _websiteCtrl,
      _noteCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppDialogHeader(
              title: _isEditing
                  ? 'Chỉnh sửa nhà cung cấp'
                  : 'Thêm nhà cung cấp',
              icon: _isEditing ? Icons.edit : Icons.add_business,
              onClose: () => Navigator.of(context).pop(),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: _field(
                              _tenCtrl,
                              'Tên nhà cung cấp *',
                              Icons.business,
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Vui lòng nhập tên NCC'
                                      : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: _field(_maCtrl, 'Mã NCC', Icons.tag),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                              child: _field(_phoneCtrl, 'Số điện thoại',
                                  Icons.phone_outlined,
                                  keyboardType: TextInputType.phone)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: _field(_emailCtrl, 'Email',
                                  Icons.email_outlined,
                                  keyboardType:
                                      TextInputType.emailAddress)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _field(_addressCtrl, 'Địa chỉ',
                          Icons.location_on_outlined),
                      const SizedBox(height: 12),
                      _field(_websiteCtrl, 'Website',
                          Icons.language_outlined,
                          keyboardType: TextInputType.url),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _noteCtrl,
                        maxLines: 2,
                        style: const TextStyle(
                            color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Ghi chú',
                          prefixIcon: Icon(Icons.notes_outlined),
                          isDense: true,
                        ),
                      ),
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
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Hủy'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Icon(
                            _isEditing ? Icons.save : Icons.add_business,
                            size: 18),
                    label: Text(_isEditing ? 'Lưu' : 'Thêm NCC'),
                    onPressed: _isSubmitting ? null : _submit,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        isDense: true,
      ),
      validator: validator,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final provider = context.read<SupplierProvider>();
    String? error;

    if (_isEditing) {
      final s = widget.existing!;
      error = await provider.updateSupplier(Supplier(
        id: s.id,
        tenNCC: _tenCtrl.text.trim(),
        maNCC:
            _maCtrl.text.trim().isEmpty ? null : _maCtrl.text.trim(),
        soDienThoai: _phoneCtrl.text.trim().isEmpty
            ? null
            : _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty
            ? null
            : _emailCtrl.text.trim(),
        diaChi: _addressCtrl.text.trim().isEmpty
            ? null
            : _addressCtrl.text.trim(),
        website: _websiteCtrl.text.trim().isEmpty
            ? null
            : _websiteCtrl.text.trim(),
        ghiChu: _noteCtrl.text.trim().isEmpty
            ? null
            : _noteCtrl.text.trim(),
        isActive: s.isActive,
        createdAt: s.createdAt,
      ));
    } else {
      error = await provider.createSupplier(
        tenNCC: _tenCtrl.text.trim(),
        maNCC:
            _maCtrl.text.trim().isEmpty ? null : _maCtrl.text.trim(),
        soDienThoai: _phoneCtrl.text.trim().isEmpty
            ? null
            : _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty
            ? null
            : _emailCtrl.text.trim(),
        diaChi: _addressCtrl.text.trim().isEmpty
            ? null
            : _addressCtrl.text.trim(),
        website: _websiteCtrl.text.trim().isEmpty
            ? null
            : _websiteCtrl.text.trim(),
        ghiChu: _noteCtrl.text.trim().isEmpty
            ? null
            : _noteCtrl.text.trim(),
      );
    }

    if (mounted) {
      if (error == null) {
        Navigator.of(context).pop();
        showAppSuccess(
            context,
            _isEditing
                ? 'Đã cập nhật nhà cung cấp'
                : 'Đã thêm nhà cung cấp thành công');
      } else {
        setState(() => _isSubmitting = false);
        showAppError(context, error);
      }
    }
  }
}
