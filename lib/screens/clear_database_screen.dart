import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/database_service.dart';
import '../providers/auth_provider.dart';
import '../providers/product_provider.dart';
import '../providers/order_provider.dart';
import '../providers/supplier_provider.dart';
import '../providers/import_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';

class ClearDatabaseScreen extends StatefulWidget {
  const ClearDatabaseScreen({super.key});

  @override
  State<ClearDatabaseScreen> createState() => _ClearDatabaseScreenState();
}

class _ClearDatabaseScreenState extends State<ClearDatabaseScreen> {
  final _db = DatabaseService();

  bool _clearProducts = false;
  bool _clearOrders = false;
  bool _clearSuppliers = false;
  bool _clearImports = false;
  bool _loading = false;
  bool _loadingCounts = true;
  bool _exportLoading = false;
  bool _importLoading = false;

  int _productCount = 0;
  int _orderCount = 0;
  int _supplierCount = 0;
  int _importCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    setState(() => _loadingCounts = true);
    final results = await Future.wait([
      _db.countProducts(),
      _db.countOrders(),
      _db.countSuppliers(),
      _db.countImportOrders(),
    ]);
    if (mounted) {
      setState(() {
        _productCount = results[0];
        _orderCount = results[1];
        _supplierCount = results[2];
        _importCount = results[3];
        _loadingCounts = false;
      });
    }
  }

  bool get _hasSelection =>
      _clearProducts || _clearOrders || _clearSuppliers || _clearImports;

  // ── Export ────────────────────────────────────────────────────────────────

  Future<void> _exportDb() async {
    setState(() => _exportLoading = true);
    try {
      final srcPath = await _db.getDbPath();
      final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final destPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Xuất cơ sở dữ liệu',
        fileName: 'nha_sach_backup_$stamp.db',
        type: FileType.custom,
        allowedExtensions: ['db'],
      );
      if (destPath == null || !mounted) return;
      await File(srcPath).copy(destPath);
      if (mounted) showAppSuccess(context, 'Xuất DB thành công:\n$destPath');
    } catch (e) {
      if (mounted) showAppError(context, 'Lỗi xuất DB: $e');
    } finally {
      if (mounted) setState(() => _exportLoading = false);
    }
  }

  // ── Import ────────────────────────────────────────────────────────────────

  Future<void> _importDb() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Chọn file cơ sở dữ liệu',
      type: FileType.custom,
      allowedExtensions: ['db'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final srcPath = result.files.first.path;
    if (srcPath == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 24),
            SizedBox(width: 10),
            Text('Xác nhận nhập DB',
                style: TextStyle(color: AppColors.textPrimary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Toàn bộ dữ liệu hiện tại sẽ bị thay thế bởi file đã chọn. '
              'Thao tác này không thể hoàn tác.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.cardAlt,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.insert_drive_file_outlined,
                      size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      srcPath.split(Platform.pathSeparator).last,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Nhập ngay'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _importLoading = true);
    final authProvider = context.read<AuthProvider>();
    final navigator = Navigator.of(context);
    try {
      final destPath = await _db.getDbPath();
      await _db.closeAndReset();
      await File(srcPath).copy(destPath);
      await authProvider.logout();
      navigator.pushNamedAndRemoveUntil('/login', (_) => false);
    } catch (e) {
      if (mounted) {
        setState(() => _importLoading = false);
        showAppError(context, 'Lỗi nhập DB: $e');
      }
    }
  }

  Future<void> _confirmAndClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: AppColors.danger, size: 26),
            SizedBox(width: 10),
            Text('Xác nhận xóa dữ liệu'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Các dữ liệu sau sẽ bị xóa vĩnh viễn:'),
            const SizedBox(height: 14),
            if (_clearProducts)
              _confirmRow(Icons.inventory_2_outlined, ctx.primary,
                  'Sản phẩm', _productCount),
            if (_clearOrders)
              _confirmRow(Icons.receipt_long_outlined, AppColors.success,
                  'Đơn hàng', _orderCount),
            if (_clearImports)
              _confirmRow(Icons.move_to_inbox_outlined, AppColors.purple,
                  'Nhập hàng', _importCount),
            if (_clearSuppliers)
              _confirmRow(Icons.local_shipping_outlined, AppColors.warning,
                  'Nhà cung cấp', _supplierCount),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.danger.withValues(alpha: .4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.error_outline,
                      color: AppColors.danger, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Hành động này không thể hoàn tác!',
                    style: TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa ngay'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _executeClear();
  }

  Widget _confirmRow(IconData icon, Color color, String label, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Text(label),
          const SizedBox(width: 6),
          Text(
            '($count bản ghi)',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Future<void> _executeClear() async {
    setState(() => _loading = true);

    final productProvider = context.read<ProductProvider>();
    final orderProvider = context.read<OrderProvider>();
    final supplierProvider = context.read<SupplierProvider>();
    final importProvider = context.read<ImportProvider>();

    try {
      if (_clearOrders) await _db.clearOrders();
      if (_clearImports) await _db.clearImportOrders();
      if (_clearSuppliers) await _db.clearSuppliers();
      if (_clearProducts) await _db.clearProducts();

      if (mounted) {
        if (_clearProducts) await productProvider.reloadProducts();
        if (_clearOrders) await orderProvider.loadOrders();
        if (_clearSuppliers) await supplierProvider.loadSuppliers();
        if (_clearImports) await importProvider.loadOrders();
      }

      setState(() {
        _clearProducts = false;
        _clearOrders = false;
        _clearSuppliers = false;
        _clearImports = false;
      });

      await _loadCounts();

      if (mounted) showAppSuccess(context, 'Đã xóa dữ liệu thành công');
    } catch (e) {
      if (mounted) showAppError(context, 'Lỗi khi xóa dữ liệu: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            color: AppColors.card,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            child: Row(
              children: [
                Icon(Icons.storage_outlined,
                    size: 28, color: context.primary),
                const SizedBox(width: 12),
                const Text(
                  'Quản lý DB',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary),
                ),
                if (_loadingCounts) ...[
                  const SizedBox(width: 16),
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Backup / Restore ──────────────────────────────────
                    const Text(
                      'Sao lưu & Phục hồi',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionCard(
                            icon: Icons.upload_file_outlined,
                            color: context.primary,
                            title: 'Xuất DB',
                            subtitle: 'Lưu file .db ra máy tính để sao lưu',
                            loading: _exportLoading,
                            onPressed: _exportDb,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionCard(
                            icon: Icons.download_outlined,
                            color: AppColors.success,
                            title: 'Nhập DB',
                            subtitle:
                                'Khôi phục từ file .db đã sao lưu trước đó',
                            loading: _importLoading,
                            onPressed: _importDb,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    const Divider(color: AppColors.border),
                    const SizedBox(height: 20),

                    // Warning banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.warning.withValues(alpha: .4)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: AppColors.warning),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Chọn loại dữ liệu cần xóa. Dữ liệu bị xóa sẽ không thể khôi phục. '
                              'Chỉ quản trị viên mới có quyền thực hiện thao tác này.',
                              style: TextStyle(color: AppColors.warning),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Selection cards
                    _buildCard(
                      icon: Icons.inventory_2_outlined,
                      iconColor: context.primary,
                      title: 'Sản phẩm',
                      subtitle: 'Xóa toàn bộ danh mục sản phẩm khỏi hệ thống',
                      count: _productCount,
                      selected: _clearProducts,
                      onChanged: (v) =>
                          setState(() => _clearProducts = v ?? false),
                    ),
                    const SizedBox(height: 12),
                    _buildCard(
                      icon: Icons.receipt_long_outlined,
                      iconColor: AppColors.success,
                      title: 'Đơn hàng',
                      subtitle: 'Xóa toàn bộ lịch sử đơn bán hàng',
                      count: _orderCount,
                      selected: _clearOrders,
                      onChanged: (v) =>
                          setState(() => _clearOrders = v ?? false),
                    ),
                    const SizedBox(height: 12),
                    _buildCard(
                      icon: Icons.local_shipping_outlined,
                      iconColor: AppColors.warning,
                      title: 'Nhà cung cấp',
                      subtitle: 'Xóa toàn bộ danh sách nhà cung cấp',
                      count: _supplierCount,
                      selected: _clearSuppliers,
                      onChanged: (v) =>
                          setState(() => _clearSuppliers = v ?? false),
                    ),
                    const SizedBox(height: 12),
                    _buildCard(
                      icon: Icons.move_to_inbox_outlined,
                      iconColor: AppColors.purple,
                      title: 'Nhập hàng',
                      subtitle: 'Xóa toàn bộ lịch sử đơn nhập hàng',
                      count: _importCount,
                      selected: _clearImports,
                      onChanged: (v) =>
                          setState(() => _clearImports = v ?? false),
                    ),
                    const SizedBox(height: 32),

                    // Action button
                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _hasSelection
                              ? AppColors.danger
                              : AppColors.border,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: (_hasSelection && !_loading)
                            ? _confirmAndClear
                            : null,
                        icon: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.delete_forever),
                        label: const Text(
                          'Xóa dữ liệu đã chọn',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool loading,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: loading ? null : onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: loading
                    ? Padding(
                        padding: const EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: color),
                      )
                    : Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required int count,
    required bool selected,
    required ValueChanged<bool?> onChanged,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? AppColors.danger : AppColors.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => onChanged(!selected),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Checkbox(
                value: selected,
                onChanged: onChanged,
                activeColor: AppColors.danger,
                side: const BorderSide(color: AppColors.border),
              ),
              const SizedBox(width: 8),
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.cardAlt,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  _loadingCounts ? '...' : '$count bản ghi',
                  style: TextStyle(
                    color: count > 0
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}