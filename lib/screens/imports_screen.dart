import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' show DateFormat;
import '../utils.dart';
import 'package:uuid/uuid.dart';
import '../providers/import_provider.dart';
import '../providers/supplier_provider.dart';
import '../providers/product_provider.dart';
import '../models/import_order.dart';
import '../models/supplier.dart';
import '../models/product.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';

const _uuid = Uuid();

class ImportsScreen extends StatefulWidget {
  const ImportsScreen({super.key});

  @override
  State<ImportsScreen> createState() => _ImportsScreenState();
}

class _ImportsScreenState extends State<ImportsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ImportProvider>().loadOrders();
      context.read<SupplierProvider>().loadSuppliers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Icon(Icons.move_to_inbox, color: context.primary, size: 28),
          const SizedBox(width: 12),
          const Text(
            'Nhập hàng hóa',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => _openCreateDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Tạo phiếu nhập'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Consumer<ImportProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (provider.orders.isEmpty) {
          return const AppEmptyState(
            icon: Icons.inbox_outlined,
            message: 'Chưa có phiếu nhập nào',
            subtitle: 'Nhấn "Tạo phiếu nhập" để bắt đầu',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: provider.orders.length,
          itemBuilder: (context, index) => _ImportOrderCard(
            order: provider.orders[index],
            onDelete: () => _deleteOrder(provider.orders[index]),
            onEdit: () => _editOrder(provider.orders[index]),
          ),
        );
      },
    );
  }

  void _openCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        child: _ImportFormDialog(
          onSaved: () async {
            await context.read<ProductProvider>().reloadProducts();
          },
        ),
      ),
    );
  }

  Future<void> _deleteOrder(ImportOrder order) async {
    final importProvider = context.read<ImportProvider>();
    final productProvider = context.read<ProductProvider>();
    final ok = await showAppConfirmDialog(
      context,
      title: 'Xác nhận xóa',
      message:
          'Xóa phiếu nhập #${order.id.substring(0, 8).toUpperCase()}?\nTồn kho sẽ được hoàn lại.',
      confirmLabel: 'Xóa',
    );
    if (!ok || !mounted) return;
    try {
      await importProvider.deleteOrder(order.id);
      await productProvider.reloadProducts();
      if (mounted) showAppSuccess(context, 'Đã xóa phiếu nhập');
    } catch (e) {
      if (mounted) showAppError(context, 'Lỗi: $e');
    }
  }

  Future<void> _editOrder(ImportOrder order) async {
    final importProvider = context.read<ImportProvider>();
    final productProvider = context.read<ProductProvider>();
    final items = await importProvider.loadItems(order.id);
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        child: _ImportFormDialog(
          editOrder: order,
          editItems: items,
          onSaved: () async {
            await productProvider.reloadProducts();
          },
        ),
      ),
    );
  }
}

// ── Order card ────────────────────────────────────────────────────────────────

class _ImportOrderCard extends StatelessWidget {
  final ImportOrder order;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _ImportOrderCard({
    required this.order,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetail(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: context.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.receipt_long,
                    color: context.primary, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          order.tenNCC ?? 'Không có NCC',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: AppColors.textPrimary),
                        ),
                        const SizedBox(width: 8),
                        AppStatusBadge(
                          label: order.trangThai == 'da_nhap'
                              ? 'Đã nhập'
                              : order.trangThai,
                          color: AppColors.success,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('dd/MM/yyyy HH:mm').format(order.ngayNhap),
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Utils.formatCurrency(order.tongTien),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: context.primary,
                    ),
                  ),
                  if (order.tienShip > 0)
                    Text(
                      'Ship: ${Utils.formatCurrency(order.tienShip)}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textMuted),
                    ),
                  Text(
                    'ID: ${order.id.substring(0, 8)}',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  IconButton(
                    icon: Icon(Icons.edit_outlined,
                        size: 18, color: context.primary),
                    tooltip: 'Sửa phiếu nhập',
                    onPressed: onEdit,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: AppColors.danger),
                    tooltip: 'Xóa phiếu nhập',
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _OrderDetailDialog(order: order),
    );
  }
}

// ── Detail dialog ─────────────────────────────────────────────────────────────

class _OrderDetailDialog extends StatefulWidget {
  final ImportOrder order;
  const _OrderDetailDialog({required this.order});

  @override
  State<_OrderDetailDialog> createState() => _OrderDetailDialogState();
}

class _OrderDetailDialogState extends State<_OrderDetailDialog> {
  List<ImportOrderItem>? _items;

  @override
  void initState() {
    super.initState();
    context
        .read<ImportProvider>()
        .loadItems(widget.order.id)
        .then((items) => setState(() => _items = items));
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 680,
        constraints: const BoxConstraints(maxHeight: 620),
        padding: const EdgeInsets.all(24),
        color: AppColors.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppDialogHeader(
              icon: Icons.receipt_long,
              title: 'Chi tiết phiếu nhập',
              onClose: () => Navigator.pop(context),
            ),
            const SizedBox(height: 4),
            AppDetailRow('Nhà cung cấp', o.tenNCC ?? 'Không có'),
            AppDetailRow('Ngày nhập',
                DateFormat('dd/MM/yyyy HH:mm').format(o.ngayNhap)),
            if (o.tienShip > 0)
              AppDetailRow('Tiền ship', Utils.formatCurrency(o.tienShip)),
            AppDetailRow('Tổng tiền', Utils.formatCurrency(o.tongTien)),
            if (o.ghiChu != null) AppDetailRow('Ghi chú', o.ghiChu!),
            const SizedBox(height: 12),
            const Text('Danh sách hàng hóa',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Expanded(
              child: _items == null
                  ? const Center(child: CircularProgressIndicator())
                  : _items!.isEmpty
                      ? const Center(
                          child: Text('Không có sản phẩm',
                              style:
                                  TextStyle(color: AppColors.textSecondary)))
                      : _buildItemsTable(),
            ),
          ],
        ),
      ),
    );
  }

  int _effectiveDonGia(ImportOrderItem item) {
    final goodsTotal = widget.order.tongTien - widget.order.tienShip;
    if (goodsTotal <= 0 || widget.order.tienShip <= 0) return item.donGia;
    final shipForRow =
        (widget.order.tienShip * item.thanhTien / goodsTotal).round();
    final shipPerUnit =
        item.soLuong > 0 ? (shipForRow / item.soLuong).round() : 0;
    return item.donGia + shipPerUnit;
  }

  Widget _buildItemsTable() {
    final hasShip = widget.order.tienShip > 0;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.cardAlt,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Expanded(
                  flex: 4,
                  child: Text('Tên hàng',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.textPrimary))),
              const SizedBox(
                  width: 60,
                  child: Text('SL',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.textPrimary),
                      textAlign: TextAlign.right)),
              const SizedBox(
                  width: 110,
                  child: Text('Đơn giá nhập',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.textPrimary),
                      textAlign: TextAlign.right)),
              if (hasShip)
                const SizedBox(
                    width: 110,
                    child: Text('Giá vốn (có ship)',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: AppColors.success),
                        textAlign: TextAlign.right)),
              const SizedBox(
                  width: 110,
                  child: Text('Thành tiền',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.textPrimary),
                      textAlign: TextAlign.right)),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _items!.length,
            itemBuilder: (context, i) {
              final item = _items![i];
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: appRowColor(i),
                  border: const Border(
                      bottom: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                        flex: 4,
                        child: Text(item.tenHang,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textPrimary))),
                    SizedBox(
                        width: 60,
                        child: Text('${item.soLuong}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textPrimary))),
                    SizedBox(
                        width: 110,
                        child: Text(Utils.formatCurrency(item.donGia),
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textPrimary))),
                    if (hasShip)
                      SizedBox(
                          width: 110,
                          child: Text(
                            Utils.formatCurrency(_effectiveDonGia(item)),
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.success,
                                fontWeight: FontWeight.w500),
                          )),
                    SizedBox(
                        width: 110,
                        child: Text(Utils.formatCurrency(item.thanhTien),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: context.primary))),
                  ],
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: context.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (widget.order.tienShip > 0) ...[
                Text(
                    'Hàng hóa: ${Utils.formatCurrency(widget.order.tongTien - widget.order.tienShip)}  +  Ship: ${Utils.formatCurrency(widget.order.tienShip)}  =  ',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ] else
                const Text('Tổng cộng: ',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
              Text(
                Utils.formatCurrency(widget.order.tongTien),
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: context.primary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Import form (dùng chung cho tạo mới và sửa) ───────────────────────────────

class _ImportRow {
  Product? product;
  late final TextEditingController soLuongCtrl;
  late final TextEditingController donGiaCtrl;
  late final TextEditingController tenHangCtrl;

  _ImportRow({ImportOrderItem? existing}) {
    soLuongCtrl =
        TextEditingController(text: existing?.soLuong.toString() ?? '1');
    donGiaCtrl =
        TextEditingController(text: existing?.donGia.toString() ?? '0');
    tenHangCtrl = TextEditingController(text: existing?.tenHang ?? '');
  }

  int get soLuong => int.tryParse(soLuongCtrl.text.replaceAll(',', '')) ?? 0;
  int get donGia => int.tryParse(donGiaCtrl.text.replaceAll(',', '')) ?? 0;
  int get thanhTien => soLuong * donGia;

  void dispose() {
    soLuongCtrl.dispose();
    donGiaCtrl.dispose();
    tenHangCtrl.dispose();
  }
}

class _ImportFormDialog extends StatefulWidget {
  final ImportOrder? editOrder;
  final List<ImportOrderItem>? editItems;
  final Future<void> Function() onSaved;

  const _ImportFormDialog({
    this.editOrder,
    this.editItems,
    required this.onSaved,
  });

  bool get isEdit => editOrder != null;

  @override
  State<_ImportFormDialog> createState() => _ImportFormDialogState();
}

class _ImportFormDialogState extends State<_ImportFormDialog> {
  Supplier? _selectedSupplier;
  DateTime _ngayNhap = DateTime.now();
  final _ghiChuCtrl = TextEditingController();
  final _shipCtrl = TextEditingController(text: '0');
  final List<_ImportRow> _rows = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEdit) {
      final o = widget.editOrder!;
      _ngayNhap = o.ngayNhap;
      _ghiChuCtrl.text = o.ghiChu ?? '';
      _shipCtrl.text = o.tienShip.toString();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final suppliers = context.read<SupplierProvider>().suppliers;
        setState(() {
          _selectedSupplier =
              suppliers.where((s) => s.id == o.supplierId).firstOrNull;
        });
      });
      if (widget.editItems != null) {
        for (final item in widget.editItems!) {
          _rows.add(_ImportRow(existing: item));
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final products = context.read<ProductProvider>().products;
          for (int i = 0;
              i < widget.editItems!.length && i < _rows.length;
              i++) {
            final item = widget.editItems![i];
            if (item.productId != null) {
              final matching = products.where((p) => p.id == item.productId);
              if (matching.isNotEmpty) {
                _rows[i].product = matching.first;
              }
            }
          }
        });
      }
      if (_rows.isEmpty) _addRow();
    } else {
      _addRow();
    }
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    _ghiChuCtrl.dispose();
    _shipCtrl.dispose();
    super.dispose();
  }

  void _addRow() => setState(() => _rows.add(_ImportRow()));

  void _removeRow(int index) {
    _rows[index].dispose();
    setState(() => _rows.removeAt(index));
  }

  int get _tienShip => int.tryParse(_shipCtrl.text.replaceAll(',', '')) ?? 0;
  int get _tongHang => _rows.fold(0, (sum, r) => sum + r.thanhTien);
  int get _grandTotal => _tongHang + _tienShip;

  List<int> _shipPerUnit(List<_ImportRow> rows) {
    if (_tienShip == 0 || _tongHang == 0) {
      return List.filled(rows.length, 0);
    }
    int allocated = 0;
    final result = <int>[];
    for (int i = 0; i < rows.length - 1; i++) {
      final r = rows[i];
      final shipForRow = (_tienShip * r.thanhTien / _tongHang).round();
      final perUnit = r.soLuong > 0 ? (shipForRow / r.soLuong).round() : 0;
      result.add(perUnit);
      allocated += perUnit * r.soLuong;
    }
    final last = rows.last;
    final remaining = _tienShip - allocated;
    result.add(last.soLuong > 0 ? (remaining / last.soLuong).round() : 0);
    return result;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _ngayNhap,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _ngayNhap = picked);
  }

  Future<void> _save() async {
    final validRows = _rows
        .where((r) =>
            r.tenHangCtrl.text.trim().isNotEmpty &&
            r.soLuong > 0 &&
            r.donGia >= 0)
        .toList();
    if (validRows.isEmpty) {
      showAppError(context, 'Vui lòng thêm ít nhất một mặt hàng hợp lệ');
      return;
    }

    setState(() => _saving = true);
    try {
      final shipList = _shipPerUnit(validRows);
      final provider = context.read<ImportProvider>();
      final productProvider = context.read<ProductProvider>();

      for (final r in validRows) {
        if (r.product == null) {
          final id = _uuid.v4();
          final newProduct = Product(
            id: id,
            maHang: '',
            tenHang: r.tenHangCtrl.text.trim(),
            giaBan: r.donGia,
            giaVon: r.donGia,
            tonKho: 0,
          );
          await productProvider.addProduct(newProduct);
          r.product = newProduct;
        }
      }

      final items = List.generate(validRows.length, (i) {
        final r = validRows[i];
        return ImportOrderItem(
          importOrderId: widget.editOrder?.id ?? '',
          productId: r.product!.id,
          tenHang: r.tenHangCtrl.text.trim(),
          soLuong: r.soLuong,
          donGia: r.donGia,
          thanhTien: r.donGia * r.soLuong,
        );
      });

      final giaVonMap = {
        for (var i = 0; i < validRows.length; i++)
          validRows[i].product!.id: validRows[i].donGia + shipList[i],
      };

      if (widget.isEdit) {
        await provider.updateOrder(
          widget.editOrder!,
          newItems: items,
          tienShip: _tienShip,
          ghiChu: _ghiChuCtrl.text,
          supplierId: _selectedSupplier?.id,
          tenNCC: _selectedSupplier?.tenNCC,
          ngayNhap: _ngayNhap,
          giaVonMap: giaVonMap,
        );
      } else {
        await provider.createOrder(
          supplierId: _selectedSupplier?.id,
          tenNCC: _selectedSupplier?.tenNCC,
          ngayNhap: _ngayNhap,
          ghiChu: _ghiChuCtrl.text,
          items: items,
          tienShip: _tienShip,
          giaVonMap: giaVonMap,
        );
      }

      await widget.onSaved();

      if (mounted) {
        showAppSuccess(
          context,
          widget.isEdit
              ? 'Cập nhật phiếu nhập thành công'
              : 'Tạo phiếu nhập thành công',
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) showAppError(context, 'Lỗi: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final shipPerUnit = _shipPerUnit(_rows);
    return SizedBox(
      width: 900,
      height: 740,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppDialogHeader(
              icon: widget.isEdit ? Icons.edit_outlined : Icons.add_box_outlined,
              title: widget.isEdit
                  ? 'Sửa phiếu nhập #${widget.editOrder!.id.substring(0, 8).toUpperCase()}'
                  : 'Tạo phiếu nhập hàng',
              onClose: _saving ? null : () => Navigator.pop(context),
            ),
            // Supplier + Date
            Row(
              children: [
                Expanded(child: _buildSupplierDropdown()),
                const SizedBox(width: 16),
                _buildDatePicker(),
              ],
            ),
            const SizedBox(height: 16),
            // Items header
            Row(
              children: [
                const Text('Danh sách hàng hóa',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addRow,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Thêm dòng'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _buildTableHeader(),
            Expanded(
              child: ListView.builder(
                itemCount: _rows.length,
                itemBuilder: (context, i) => _buildItemRow(i, shipPerUnit[i]),
              ),
            ),
            const Divider(color: AppColors.border),
            // Footer
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _ghiChuCtrl,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Ghi chú',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 170,
                  child: TextField(
                    controller: _shipCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Tiền ship (₫)',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixIcon:
                          Icon(Icons.local_shipping_outlined, size: 18),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (_tienShip > 0) ...[
                      Text('Hàng: ${Utils.formatCurrency(_tongHang)}',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                      Text('Ship: ${Utils.formatCurrency(_tienShip)}',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ] else
                      const Text('Tổng tiền nhập:',
                          style: TextStyle(color: AppColors.textSecondary)),
                    Text(
                      Utils.formatCurrency(_grandTotal),
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: context.primary),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save),
                  label: Text(_saving
                      ? 'Đang lưu...'
                      : widget.isEdit
                          ? 'Lưu thay đổi'
                          : 'Lưu phiếu'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierDropdown() {
    final suppliers = context.read<SupplierProvider>().suppliers;
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Nhà cung cấp',
        border: OutlineInputBorder(),
        isDense: true,
        prefixIcon: Icon(Icons.local_shipping_outlined),
      ),
      child: DropdownButton<Supplier?>(
        value: _selectedSupplier,
        isExpanded: true,
        underline: const SizedBox(),
        isDense: true,
        dropdownColor: AppColors.card,
        style: const TextStyle(color: AppColors.textPrimary),
        items: [
          const DropdownMenuItem<Supplier?>(
            value: null,
            child: Text('Không có nhà cung cấp',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ...suppliers.map((s) => DropdownMenuItem<Supplier?>(
                value: s,
                child: Text(s.tenNCC),
              )),
        ],
        onChanged: (v) => setState(() => _selectedSupplier = v),
      ),
    );
  }

  Widget _buildDatePicker() {
    return SizedBox(
      width: 200,
      child: InkWell(
        onTap: _pickDate,
        borderRadius: BorderRadius.circular(8),
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Ngày nhập',
            border: OutlineInputBorder(),
            isDense: true,
            prefixIcon: Icon(Icons.calendar_today_outlined),
          ),
          child: Text(
            DateFormat('dd/MM/yyyy').format(_ngayNhap),
            style: const TextStyle(
                fontSize: 14, color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    final hasShip = _tienShip > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.cardAlt,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: Row(
        children: [
          const Expanded(
              flex: 4,
              child: Text('Tên hàng hóa *',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: AppColors.textPrimary))),
          const SizedBox(width: 8),
          const SizedBox(
              width: 80,
              child: Text('Số lượng *',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: AppColors.textPrimary),
                  textAlign: TextAlign.center)),
          const SizedBox(width: 8),
          const SizedBox(
              width: 110,
              child: Text('Đơn giá (₫) *',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: AppColors.textPrimary),
                  textAlign: TextAlign.center)),
          const SizedBox(width: 8),
          if (hasShip) ...[
            const SizedBox(
                width: 110,
                child: Text('Giá vốn (ship)',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: AppColors.success),
                    textAlign: TextAlign.right)),
            const SizedBox(width: 8),
          ],
          const SizedBox(
              width: 110,
              child: Text('Thành tiền',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: AppColors.textPrimary),
                  textAlign: TextAlign.right)),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildItemRow(int index, int shipPerUnit) {
    final row = _rows[index];
    final hasShip = _tienShip > 0;
    return StatefulBuilder(
      builder: (ctx, setRowState) {
        void rebuild() => setState(() {});
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: appRowColor(index),
            border: const Border(
                bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: _ProductSelector(row: row, onChanged: rebuild),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: row.soLuongCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  onChanged: (_) => rebuild(),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: row.donGiaCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  onChanged: (_) => rebuild(),
                ),
              ),
              const SizedBox(width: 8),
              if (hasShip) ...[
                SizedBox(
                  width: 110,
                  child: Text(
                    Utils.formatCurrency(row.donGia + shipPerUnit),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.success,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              SizedBox(
                width: 110,
                child: Text(
                  Utils.formatCurrency(row.thanhTien),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: ctx.primary),
                ),
              ),
              SizedBox(
                width: 40,
                child: IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppColors.danger, size: 20),
                  onPressed:
                      _rows.length > 1 ? () => _removeRow(index) : null,
                  padding: EdgeInsets.zero,
                  tooltip: 'Xóa dòng',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Product selector ──────────────────────────────────────────────────────────

class _ProductSelector extends StatelessWidget {
  final _ImportRow row;
  final VoidCallback onChanged;

  const _ProductSelector({required this.row, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: row.tenHangCtrl,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Tên hàng hóa...',
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        suffixIcon: Tooltip(
          message: 'Chọn sản phẩm',
          child: IconButton(
            icon: const Icon(Icons.search, size: 18),
            padding: EdgeInsets.zero,
            onPressed: () => _openProductSearch(context),
          ),
        ),
      ),
      onChanged: (_) => onChanged(),
    );
  }

  void _openProductSearch(BuildContext context) async {
    final products = context.read<ProductProvider>().products;
    final result = await showDialog<Product>(
      context: context,
      builder: (_) => _ProductSearchDialog(products: products),
    );
    if (result != null) {
      row.product = result;
      row.tenHangCtrl.text = result.tenHang;
      if (result.giaVon > 0) {
        row.donGiaCtrl.text = result.giaVon.toString();
      }
      onChanged();
    }
  }
}

// ── Product search dialog ─────────────────────────────────────────────────────

class _ProductSearchDialog extends StatefulWidget {
  final List<Product> products;
  const _ProductSearchDialog({required this.products});

  @override
  State<_ProductSearchDialog> createState() => _ProductSearchDialogState();
}

class _ProductSearchDialogState extends State<_ProductSearchDialog> {
  final _searchCtrl = TextEditingController();
  List<Product> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.products;
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = widget.products
          .where((p) =>
              p.tenHang.toLowerCase().contains(q) ||
              p.maHang.toLowerCase().contains(q) ||
              p.maVach.toLowerCase().contains(q))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 480,
        constraints: const BoxConstraints(maxHeight: 520),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            AppDialogHeader(
              icon: Icons.search,
              title: 'Chọn sản phẩm',
              onClose: () => Navigator.pop(context),
            ),
            AppSearchField(
              controller: _searchCtrl,
              hint: 'Tìm theo tên, mã hàng, mã vạch...',
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _filtered.isEmpty
                  ? const AppEmptyState(
                      icon: Icons.search_off,
                      message: 'Không tìm thấy sản phẩm',
                    )
                  : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (context, i) {
                        final p = _filtered[i];
                        return ListTile(
                          dense: true,
                          title: Text(p.tenHang,
                              style: const TextStyle(
                                  color: AppColors.textPrimary)),
                          subtitle: Text(
                            '${p.maHang} • Tồn: ${p.tonKho} • Giá vốn: ${Utils.formatCurrency(p.giaVon)}',
                            style: const TextStyle(
                                color: AppColors.textSecondary),
                          ),
                          trailing: const Icon(Icons.chevron_right,
                              color: AppColors.textMuted),
                          onTap: () => Navigator.pop(context, p),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
