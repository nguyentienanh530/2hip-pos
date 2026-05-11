import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' show DateFormat;
import '../utils.dart';
import '../providers/order_provider.dart';
import '../providers/product_provider.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../services/excel_service.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String _filter = 'all';
  String _search = '';
  Order? _selected;
  bool _exporting = false;

  List<Order> _filterOrders(List<Order> all) {
    final now = DateTime.now();
    var list = all.where((o) {
      if (_filter == 'today') {
        return o.ngayTao.year == now.year &&
            o.ngayTao.month == now.month &&
            o.ngayTao.day == now.day;
      }
      if (_filter == 'month') {
        return o.ngayTao.year == now.year && o.ngayTao.month == now.month;
      }
      return true;
    }).toList();

    if (_search.trim().isNotEmpty) {
      final q = _search.toLowerCase();
      list = list
          .where((o) =>
              o.tenKhach.toLowerCase().contains(q) ||
              o.id.toLowerCase().contains(q) ||
              o.ghiChu.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  Future<void> _export(List<Order> orders) async {
    if (orders.isEmpty) {
      showAppError(context, 'Không có đơn hàng để xuất');
      return;
    }
    setState(() => _exporting = true);
    try {
      final path = await ExcelService.exportOrders(orders);
      if (!mounted) return;
      if (path != null) {
        showAppSuccess(context, 'Đã xuất ${orders.length} đơn → $path');
      }
    } catch (e) {
      if (mounted) showAppError(context, 'Lỗi xuất file: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _deleteOrder(Order order) async {
    final orderProvider = context.read<OrderProvider>();
    final productProvider = context.read<ProductProvider>();
    final ok = await showAppConfirmDialog(
      context,
      title: 'Xác nhận xóa',
      message:
          'Xóa đơn #${order.id.substring(0, 8).toUpperCase()}?\nTồn kho sẽ được hoàn lại.',
      confirmLabel: 'Xóa',
      confirmColor: AppColors.danger,
    );
    if (!ok || !mounted) return;
    try {
      await orderProvider.deleteOrder(order.id);
      await productProvider.reloadProducts();
      if (!mounted) return;
      setState(() => _selected = null);
      showAppSuccess(context, 'Đã xóa đơn hàng');
    } catch (e) {
      if (mounted) showAppError(context, 'Lỗi: $e');
    }
  }

  Future<void> _editOrder(Order order) async {
    final orderProvider = context.read<OrderProvider>();
    final productProvider = context.read<ProductProvider>();
    final products = productProvider.allProducts;
    final updated = await showDialog<Order>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _EditOrderDialog(
        order: order,
        products: products,
        orderProvider: orderProvider,
      ),
    );
    if (updated == null || !mounted) return;
    await productProvider.reloadProducts();
    if (!mounted) return;
    setState(() => _selected = updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch Sử Đơn Hàng'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: () => context.read<OrderProvider>().loadOrders(),
          ),
          Consumer<OrderProvider>(
            builder: (_, provider, __) {
              final orders = _filterOrders(provider.orders);
              return _exporting
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.upload_file_outlined),
                      tooltip: 'Xuất Excel',
                      onPressed: () => _export(orders),
                    );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<OrderProvider>(
        builder: (ctx, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = _filterOrders(provider.orders);
          final stats = provider.stats;

          return Column(
            children: [
              // ── Stats + filter bar ──────────────────────────────────────
              Container(
                color: AppColors.card,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    _StatChip(
                      label: 'Hôm nay',
                      value: Utils.formatCurrency(stats['hom_nay'] ?? 0),
                      color: context.primary,
                    ),
                    const SizedBox(width: 20),
                    _StatChip(
                      label: 'Tháng này',
                      value: Utils.formatCurrency(stats['thang_nay'] ?? 0),
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 20),
                    _StatChip(
                      label: 'Tổng đơn',
                      value: '${stats['so_don'] ?? 0}',
                      color: AppColors.warning,
                    ),
                    const Spacer(),
                    AppSearchField(
                      hint: 'Tìm đơn hàng...',
                      width: 200,
                      onChanged: (v) => setState(() => _search = v),
                    ),
                    const SizedBox(width: 12),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'all', label: Text('Tất cả')),
                        ButtonSegment(
                            value: 'today', label: Text('Hôm nay')),
                        ButtonSegment(
                            value: 'month', label: Text('Tháng này')),
                      ],
                      selected: {_filter},
                      onSelectionChanged: (s) =>
                          setState(() => _filter = s.first),
                      style: ButtonStyle(
                        textStyle: WidgetStateProperty.all(
                            const TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // ── Main content ────────────────────────────────────────────
              Expanded(
                child: orders.isEmpty
                    ? const AppEmptyState(
                        icon: Icons.receipt_long_outlined,
                        message: 'Chưa có đơn hàng nào',
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── Left: order list ──────────────────────────
                          SizedBox(
                            width: 380,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: orders.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 6),
                              itemBuilder: (_, i) {
                                final o = orders[i];
                                final active = _selected?.id == o.id;
                                return _OrderCard(
                                  order: o,
                                  active: active,
                                  onTap: () =>
                                      setState(() => _selected = o),
                                );
                              },
                            ),
                          ),
                          const VerticalDivider(width: 1),

                          // ── Right: detail panel ───────────────────────
                          Expanded(
                            child: _selected == null
                                ? const AppEmptyState(
                                    icon: Icons.touch_app_outlined,
                                    message:
                                        'Chọn đơn hàng để xem chi tiết',
                                  )
                                : _OrderDetail(
                                    key: ValueKey(_selected!.id),
                                    order: _selected!,
                                    onClose: () =>
                                        setState(() => _selected = null),
                                    onDelete: () =>
                                        _deleteOrder(_selected!),
                                    onEdit: () => _editOrder(_selected!),
                                  ),
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Order list card ───────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  final Order order;
  final bool active;
  final VoidCallback onTap;

  const _OrderCard({
    required this.order,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: active
            ? context.primary.withValues(alpha: .12)
            : AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: active ? context.primary : AppColors.border,
          width: active ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.check_circle,
                        color: AppColors.success, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Đơn #${order.id.substring(0, 8).toUpperCase()}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppColors.textPrimary),
                    ),
                  ),
                  Text(
                    Utils.formatCurrency(order.tongTien),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: context.primary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.person_outline,
                      size: 12, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(order.tenKhach,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  const Spacer(),
                  const Icon(Icons.access_time,
                      size: 12, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('HH:mm dd/MM').format(order.ngayTao),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
              if (order.loiNhuan > 0) ...[
                const SizedBox(height: 4),
                Text(
                  'Lợi nhuận: ${Utils.formatCurrency(order.loiNhuan)}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.success),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Order detail panel ────────────────────────────────────────────────────────

class _OrderDetail extends StatelessWidget {
  final Order order;
  final VoidCallback onClose;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _OrderDetail({
    super.key,
    required this.order,
    required this.onClose,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: const BoxDecoration(
            color: AppColors.card,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Icon(Icons.receipt_long,
                  color: context.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Đơn #${order.id.substring(0, 8).toUpperCase()}',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(width: 12),
              const AppStatusBadge(
                  label: 'Hoàn thành', color: AppColors.success),
              const Spacer(),
              Text(
                DateFormat('HH:mm  dd/MM/yyyy').format(order.ngayTao),
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.edit_outlined,
                    size: 18, color: context.primary),
                tooltip: 'Sửa đơn hàng',
                onPressed: onEdit,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: AppColors.danger),
                tooltip: 'Xóa đơn hàng',
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.close,
                    size: 18, color: AppColors.textSecondary),
                onPressed: onClose,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer info
                if (order.tenKhach != 'Khách lẻ' ||
                    order.khachHangId != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.cardAlt,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline,
                            size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Text(order.tenKhach,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppColors.textPrimary)),
                      ],
                    ),
                  ),

                // Items table
                const Text('Sản phẩm',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      // Table header
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: const BoxDecoration(
                          color: AppColors.cardAlt,
                          borderRadius: BorderRadius.vertical(
                              top: Radius.circular(7)),
                        ),
                        child: const Row(
                          children: [
                            Expanded(
                                flex: 4,
                                child: Text('Tên hàng',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textSecondary))),
                            SizedBox(
                                width: 50,
                                child: Text('SL',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textSecondary))),
                            SizedBox(
                                width: 100,
                                child: Text('Đơn giá',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textSecondary))),
                            SizedBox(
                                width: 100,
                                child: Text('Thành tiền',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textSecondary))),
                          ],
                        ),
                      ),
                      ...order.items.asMap().entries.map((e) {
                        final item = e.value;
                        final last = e.key == order.items.length - 1;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            border: last
                                ? null
                                : const Border(
                                    top: BorderSide(
                                        color: AppColors.border)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(item.tenHang,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textPrimary)),
                                    if (item.giaVon > 0)
                                      Text(
                                        'Vốn: ${Utils.formatCurrency(item.giaVon)}',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color:
                                                AppColors.textSecondary),
                                      ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 50,
                                child: Text('x${item.soLuong}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textPrimary)),
                              ),
                              SizedBox(
                                width: 100,
                                child: Text(
                                    Utils.formatCurrency(item.donGia),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textPrimary)),
                              ),
                              SizedBox(
                                width: 100,
                                child: Text(
                                    Utils.formatCurrency(item.thanhTien),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary)),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Payment summary
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardAlt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      AppDetailRow('Tổng tiền hàng',
                          Utils.formatCurrency(order.tongTienHang)),
                      if (order.giamGia > 0)
                        AppDetailRow('Giảm giá',
                            '- ${Utils.formatCurrency(order.giamGia)}',
                            valueColor: AppColors.warning),
                      AppDetailRow(
                          'Khách cần trả',
                          Utils.formatCurrency(order.tongTien),
                          bold: true,
                          valueColor: context.primary,
                          valueFontSize: 16),
                      const Divider(height: 16),
                      const AppDetailRow('Phương thức', 'Tiền mặt'),
                      AppDetailRow(
                          'Khách đưa', Utils.formatCurrency(order.khachDua)),
                      AppDetailRow('Tiền thừa',
                          Utils.formatCurrency(order.tienThua),
                          valueColor: AppColors.success),
                      if (order.tongVon > 0) ...[
                        const Divider(height: 16),
                        AppDetailRow('Tổng vốn',
                            Utils.formatCurrency(order.tongVon),
                            valueColor: AppColors.warning),
                        AppDetailRow(
                            'Lợi nhuận',
                            Utils.formatCurrency(order.loiNhuan),
                            bold: true,
                            valueColor: order.loiNhuan >= 0
                                ? AppColors.success
                                : AppColors.danger),
                      ],
                      if (order.ghiChu.isNotEmpty) ...[
                        const Divider(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Ghi chú: ',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary)),
                            Expanded(
                              child: Text(order.ghiChu,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic,
                                      color: AppColors.textPrimary)),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Edit order dialog ─────────────────────────────────────────────────────────

class _EditItem {
  final String productId;
  final String tenHang;
  final int giaVon;
  late final TextEditingController soLuongCtrl;
  late final TextEditingController donGiaCtrl;

  _EditItem({
    required this.productId,
    required this.tenHang,
    required int soLuong,
    required int donGia,
    required this.giaVon,
  }) {
    soLuongCtrl = TextEditingController(text: soLuong.toString());
    donGiaCtrl = TextEditingController(text: donGia.toString());
  }

  void dispose() {
    soLuongCtrl.dispose();
    donGiaCtrl.dispose();
  }

  int get soLuong => int.tryParse(soLuongCtrl.text) ?? 1;
  int get donGia => int.tryParse(donGiaCtrl.text) ?? 0;
  int get thanhTien => soLuong * donGia;
  int get tongVonItem => soLuong * giaVon;
}

class _EditOrderDialog extends StatefulWidget {
  final Order order;
  final List<Product> products;
  final OrderProvider orderProvider;

  const _EditOrderDialog({
    required this.order,
    required this.products,
    required this.orderProvider,
  });

  @override
  State<_EditOrderDialog> createState() => _EditOrderDialogState();
}

class _EditOrderDialogState extends State<_EditOrderDialog> {
  final _discountCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  late List<_EditItem> _items;
  int _discount = 0;
  bool _saving = false;

  // productId → original qty in order (deducted from stock when created)
  late final Map<String, int> _originalQty;
  // productId → Product for stock lookup
  late final Map<String, Product> _productMap;

  @override
  void initState() {
    super.initState();
    _items = widget.order.items
        .map((i) => _EditItem(
              productId: i.productId,
              tenHang: i.tenHang,
              soLuong: i.soLuong,
              donGia: i.donGia,
              giaVon: i.giaVon,
            ))
        .toList();
    _discount = widget.order.giamGia;
    if (_discount > 0) _discountCtrl.text = _discount.toString();
    _originalQty = {
      for (final i in widget.order.items) i.productId: i.soLuong
    };
    _productMap = {for (final p in widget.products) p.id: p};
  }

  // Max usable qty = current stock + original qty (restored before update)
  int _maxQty(String productId) {
    final p = _productMap[productId];
    final original = _originalQty[productId] ?? 0;
    if (p == null) return original;
    return p.tonKho + original;
  }

  @override
  void dispose() {
    _discountCtrl.dispose();
    _searchCtrl.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  int get _tongTienHang => _items.fold(0, (s, i) => s + i.thanhTien);
  int get _tongVon => _items.fold(0, (s, i) => s + i.tongVonItem);
  int get _khachCanTra =>
      (_tongTienHang - _discount).clamp(0, double.maxFinite).toInt();

  void _addProduct(Product p) {
    final max = _maxQty(p.id);
    final idx = _items.indexWhere((i) => i.productId == p.id);
    final currentQty = idx >= 0 ? _items[idx].soLuong : 0;
    if (currentQty >= max) {
      showAppError(
          context, '${p.tenHang}: không đủ tồn kho (tối đa $max)');
      _searchCtrl.clear();
      return;
    }
    setState(() {
      if (idx >= 0) {
        _items[idx].soLuongCtrl.text = '${_items[idx].soLuong + 1}';
      } else {
        _items.add(_EditItem(
          productId: p.id,
          tenHang: p.tenHang,
          soLuong: 1,
          donGia: p.giaBan,
          giaVon: p.giaVon,
        ));
      }
    });
    _searchCtrl.clear();
  }

  Future<void> _save() async {
    if (_items.isEmpty) {
      showAppError(context, 'Đơn hàng phải có ít nhất 1 sản phẩm');
      return;
    }
    setState(() => _saving = true);
    try {
      final newItemMaps = _items
          .map((i) => {
                'product_id': i.productId,
                'ten_hang': i.tenHang,
                'so_luong': i.soLuong,
                'don_gia': i.donGia,
                'thanh_tien': i.thanhTien,
                'gia_von': i.giaVon,
              })
          .toList();
      final newOrderItems = _items
          .map((i) => OrderItem(
                productId: i.productId,
                tenHang: i.tenHang,
                soLuong: i.soLuong,
                donGia: i.donGia,
                thanhTien: i.thanhTien,
                giaVon: i.giaVon,
              ))
          .toList();
      final updated = await widget.orderProvider.updateOrder(
        widget.order,
        newItems: newOrderItems,
        newItemMaps: newItemMaps,
        tongTien: _khachCanTra,
        tongVon: _tongVon,
        giamGia: _discount,
        khachDua: widget.order.khachDua,
        tienThua: widget.order.tienThua,
        ghiChu: widget.order.ghiChu,
      );
      if (mounted) Navigator.pop(context, updated);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showAppError(context, 'Lỗi: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: SizedBox(
        width: 860,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──────────────────────────────────────────────────
            AppDialogHeader(
              title:
                  'Sửa đơn #${widget.order.id.substring(0, 8).toUpperCase()}',
              icon: Icons.edit,
              onClose: () => Navigator.pop(context),
            ),

            // ── Search bar ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              child: Autocomplete<Product>(
                optionsBuilder: (v) {
                  if (v.text.isEmpty) return [];
                  final q = v.text.toLowerCase();
                  return widget.products.where((p) =>
                      p.dangKinhDoanh &&
                      (p.tenHang.toLowerCase().contains(q) ||
                          p.maHang.toLowerCase().contains(q) ||
                          p.maVach.toLowerCase().contains(q)));
                },
                displayStringForOption: (p) => p.tenHang,
                fieldViewBuilder: (ctx, ctrl, fn, _) => TextField(
                  controller: ctrl,
                  focusNode: fn,
                  style:
                      const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Tìm sản phẩm để thêm...',
                    prefixIcon: Icon(Icons.search, size: 18),
                  ),
                ),
                optionsViewBuilder: (ctx, onSelected, options) => Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    color: AppColors.card,
                    elevation: 4,
                    borderRadius: BorderRadius.circular(6),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                          maxWidth: 500, maxHeight: 240),
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        separatorBuilder: (_, __) => const Divider(
                            height: 1, color: AppColors.border),
                        itemBuilder: (_, i) {
                          final p = options.elementAt(i);
                          return ListTile(
                            dense: true,
                            title: Text(p.tenHang,
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textPrimary)),
                            subtitle: Text(
                                'Có thể thêm: ${_maxQty(p.id)}  •  ${Utils.formatCurrency(p.giaBan)}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary)),
                            onTap: () => onSelected(p),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                onSelected: _addProduct,
              ),
            ),

            // ── Items table ──────────────────────────────────────────────
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: _items.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Chưa có sản phẩm nào',
                          style: TextStyle(
                              color: AppColors.textSecondary)),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          // table header
                          Container(
                            color: AppColors.cardAlt,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            child: const Row(
                              children: [
                                Expanded(
                                    flex: 4,
                                    child: Text('Tên hàng',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors
                                                .textSecondary))),
                                SizedBox(
                                    width: 120,
                                    child: Text('Số lượng',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors
                                                .textSecondary))),
                                SizedBox(
                                    width: 110,
                                    child: Text('Đơn giá',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors
                                                .textSecondary))),
                                SizedBox(
                                    width: 110,
                                    child: Text('Thành tiền',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors
                                                .textSecondary))),
                                SizedBox(width: 32),
                              ],
                            ),
                          ),
                          const Divider(
                              height: 1, color: AppColors.border),
                          ...List.generate(_items.length, (i) {
                            final item = _items[i];
                            final maxQty = _maxQty(item.productId);
                            return Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 4,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(item.tenHang,
                                                style: const TextStyle(
                                                    fontSize: 13,
                                                    color: AppColors
                                                        .textPrimary)),
                                            Text(
                                              'Tối đa: $maxQty',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: item.soLuong >=
                                                          maxQty
                                                      ? AppColors.warning
                                                      : AppColors
                                                          .textSecondary),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Qty controls
                                      SizedBox(
                                        width: 120,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            AppQtyButton(
                                              icon: Icons.remove,
                                              onTap: () =>
                                                  setState(() {
                                                if (item.soLuong > 1) {
                                                  item.soLuongCtrl
                                                      .text =
                                                      '${item.soLuong - 1}';
                                                } else {
                                                  item.dispose();
                                                  _items.removeAt(i);
                                                }
                                              }),
                                            ),
                                            SizedBox(
                                              width: 40,
                                              child: TextField(
                                                controller:
                                                    item.soLuongCtrl,
                                                textAlign:
                                                    TextAlign.center,
                                                keyboardType:
                                                    TextInputType.number,
                                                inputFormatters: [
                                                  FilteringTextInputFormatter
                                                      .digitsOnly
                                                ],
                                                style: const TextStyle(
                                                    fontSize: 13,
                                                    color: AppColors
                                                        .textPrimary),
                                                decoration:
                                                    const InputDecoration(
                                                  isDense: true,
                                                  contentPadding:
                                                      EdgeInsets.symmetric(
                                                          vertical: 4,
                                                          horizontal: 2),
                                                ),
                                                onChanged: (v) {
                                                  final q =
                                                      int.tryParse(v) ??
                                                          1;
                                                  if (q > maxQty) {
                                                    item.soLuongCtrl
                                                        .text =
                                                        '$maxQty';
                                                    showAppError(
                                                        context,
                                                        '${item.tenHang}: tối đa $maxQty');
                                                  }
                                                  setState(() {});
                                                },
                                              ),
                                            ),
                                            AppQtyButton(
                                              icon: Icons.add,
                                              onTap: () {
                                                if (item.soLuong >=
                                                    maxQty) {
                                                  showAppError(
                                                      context,
                                                      '${item.tenHang}: tối đa $maxQty');
                                                  return;
                                                }
                                                setState(() {
                                                  item.soLuongCtrl
                                                      .text =
                                                      '${item.soLuong + 1}';
                                                });
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Price field
                                      SizedBox(
                                        width: 110,
                                        child: TextField(
                                          controller: item.donGiaCtrl,
                                          textAlign: TextAlign.right,
                                          keyboardType:
                                              TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly
                                          ],
                                          style: const TextStyle(
                                              fontSize: 13,
                                              color:
                                                  AppColors.textPrimary),
                                          decoration:
                                              const InputDecoration(
                                            isDense: true,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                    vertical: 4,
                                                    horizontal: 4),
                                          ),
                                          onChanged: (_) =>
                                              setState(() {}),
                                        ),
                                      ),
                                      // Total
                                      SizedBox(
                                        width: 110,
                                        child: Text(
                                          Utils.formatCurrency(item.thanhTien),
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: context.primary),
                                        ),
                                      ),
                                      // Delete row
                                      IconButton(
                                        icon: const Icon(
                                            Icons.delete_outline,
                                            size: 16,
                                            color: AppColors.danger),
                                        padding: EdgeInsets.zero,
                                        constraints:
                                            const BoxConstraints(
                                                minWidth: 32,
                                                minHeight: 32),
                                        onPressed: () => setState(() {
                                          item.dispose();
                                          _items.removeAt(i);
                                        }),
                                      ),
                                    ],
                                  ),
                                ),
                                if (i < _items.length - 1)
                                  const Divider(
                                      height: 1,
                                      color: AppColors.border,
                                      indent: 12),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
            ),

            const Divider(height: 1, color: AppColors.border),

            // ── Summary + discount ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  const Text('Giảm giá: ',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textPrimary)),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _discountCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 4),
                        suffixText: 'đ',
                      ),
                      onChanged: (v) => setState(() {
                        _discount = (int.tryParse(v) ?? 0)
                            .clamp(0, _tongTienHang);
                      }),
                    ),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Tổng tiền hàng: ${Utils.formatCurrency(_tongTienHang)}',
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary),
                      ),
                      if (_discount > 0)
                        Text(
                          'Giảm giá: - ${Utils.formatCurrency(_discount)}',
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.warning),
                        ),
                      Text(
                        'Khách cần trả: ${Utils.formatCurrency(_khachCanTra)}',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: context.primary),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Action buttons ───────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                border:
                    Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed:
                        _saving ? null : () => Navigator.pop(context),
                    child: const Text('Hủy'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                        : const Icon(Icons.save_outlined, size: 16),
                    label: const Text('Lưu thay đổi'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stat chip ─────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary)),
        Text(value,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color)),
      ],
    );
  }
}