import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../providers/product_provider.dart';
import '../providers/order_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/auth_provider.dart';
import '../models/product.dart';
import '../models/customer.dart';
import '../models/cart_item.dart';
import '../theme/app_theme.dart';
import '../utils.dart';
import '../widgets/widgets.dart';

// ── Per-invoice session ───────────────────────────────────────────────────────

class _Session {
  final int id;
  Customer? customer;
  final Map<String, CartItem> items = {};
  int discount = 0;
  String ghiChu = '';
  String paymentMethod = 'cash';
  int paymentAmount = 0;

  _Session(this.id);

  String get label => 'Hóa đơn $id';

  void addProduct(Product p) {
    if (items.containsKey(p.id)) {
      items[p.id]!.soLuong++;
    } else {
      items[p.id] = CartItem(product: p);
    }
  }

  void removeProduct(String productId) => items.remove(productId);

  void increaseQty(String productId) {
    if (items.containsKey(productId)) items[productId]!.soLuong++;
  }

  void decreaseQty(String productId) {
    final item = items[productId];
    if (item == null) return;
    if (item.soLuong > 1) {
      item.soLuong--;
    } else {
      items.remove(productId);
    }
  }

  void setQty(String productId, int qty) {
    if (qty <= 0) {
      items.remove(productId);
    } else if (items.containsKey(productId)) {
      items[productId]!.soLuong = qty;
    }
  }

  void setPrice(String productId, int price) {
    if (items.containsKey(productId)) {
      items[productId]!.donGia = price;
    }
  }

  List<CartItem> get itemList => items.values.toList();
  int get tongTienHang => items.values.fold(0, (s, i) => s + i.thanhTien);
  int get tongSoLuong => items.values.fold(0, (s, i) => s + i.soLuong);
  int get tongVon => items.values.fold(0, (s, i) => s + i.tongVon);
  int get khachCanTra =>
      (tongTienHang - discount).clamp(0, double.maxFinite).toInt();
  int get tienThua =>
      (paymentAmount - khachCanTra).clamp(0, double.maxFinite).toInt();
}

// ── Main screen ───────────────────────────────────────────────────────────────

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  int _nextId = 1;
  late List<_Session> _sessions;
  int _sessionIdx = 0;

  final Map<int, TextEditingController> _paymentCtrls = {};
  final Map<int, TextEditingController> _discountCtrls = {};
  final Map<int, TextEditingController> _noteCtrls = {};

  DateTime _now = DateTime.now();
  Timer? _clockTimer;

  _Session get _current => _sessions[_sessionIdx];

  TextEditingController _paymentCtrl([_Session? s]) => _paymentCtrls
      .putIfAbsent((s ?? _current).id, () => TextEditingController());

  TextEditingController _discountCtrl([_Session? s]) => _discountCtrls
      .putIfAbsent((s ?? _current).id, () => TextEditingController());

  TextEditingController _noteCtrl([_Session? s]) =>
      _noteCtrls.putIfAbsent((s ?? _current).id, () => TextEditingController());

  @override
  void initState() {
    super.initState();
    _sessions = [_Session(_nextId++)];
    _clockTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => setState(() => _now = DateTime.now()),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerProvider>().loadCustomers();
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    for (final c in [
      ..._paymentCtrls.values,
      ..._discountCtrls.values,
      ..._noteCtrls.values,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Session management ────────────────────────────────────────────────────

  void _addSession() => setState(() {
        _sessions.add(_Session(_nextId++));
        _sessionIdx = _sessions.length - 1;
      });

  void _closeSession(int idx) {
    setState(() {
      final s = _sessions[idx];
      _paymentCtrls.remove(s.id)?.dispose();
      _discountCtrls.remove(s.id)?.dispose();
      _noteCtrls.remove(s.id)?.dispose();
      _sessions.removeAt(idx);
      if (_sessions.isEmpty) {
        _nextId = 2;
        _sessions.add(_Session(1));
      }
      _sessionIdx =
          _sessionIdx >= _sessions.length ? _sessions.length - 1 : _sessionIdx;
    });
  }

  void _resetSession(_Session s) {
    s.items.clear();
    s.customer = null;
    s.discount = 0;
    s.ghiChu = '';
    s.paymentMethod = 'cash';
    s.paymentAmount = 0;
    _paymentCtrls[s.id]?.clear();
    _discountCtrls[s.id]?.clear();
    _noteCtrls[s.id]?.clear();
  }

  // ── Payment ───────────────────────────────────────────────────────────────

  Future<void> _doPayment() async {
    final s = _current;
    if (s.items.isEmpty) {
      showAppError(context, 'Chưa có sản phẩm trong hóa đơn');
      return;
    }
    final orderProvider = context.read<OrderProvider>();
    final productProvider = context.read<ProductProvider>();
    final nguoiTao = context.read<AuthProvider>().currentUser?.username ?? '';

    final tongTien = s.khachCanTra;
    final khachDua = s.paymentAmount > 0 ? s.paymentAmount : tongTien;
    final tienThua = (khachDua - tongTien).clamp(0, double.maxFinite).toInt();

    try {
      await orderProvider.createOrder(
        cartItems: s.itemList,
        tongTien: tongTien,
        tongVon: s.tongVon,
        khachDua: khachDua,
        tienThua: tienThua,
        ghiChu: s.ghiChu,
        khachHangId: s.customer?.id,
        tenKhach: s.customer?.tenKhachHang ?? 'Khách lẻ',
        giamGia: s.discount,
        nguoiTao: nguoiTao,
      );
      await productProvider.reloadProducts();
      if (!mounted) return;
      setState(() => _resetSession(s));
      showAppSuccess(
        context,
        'Thanh toán thành công! Tiền thừa: ${Utils.formatCurrency(tienThua)}',
      );
    } catch (e) {
      if (!mounted) return;
      showAppError(context, 'Lỗi: $e');
    }
  }

  // ── Quick amounts ─────────────────────────────────────────────────────────

  List<int> _quickAmounts(int total) {
    if (total == 0) return [100000, 200000, 500000, 1000000];
    final amounts = <int>{total};
    for (final round in [1000, 5000, 10000]) {
      final r = ((total / round).ceil()) * round;
      if (r > total) amounts.add(r);
    }
    for (final a in [100000, 200000, 500000, 1000000]) {
      if (a >= total) amounts.add(a);
    }
    return (amounts.toList()..sort()).take(5).toList();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<ProductProvider>(
      builder: (context, productProvider, _) => Scaffold(
        body: Focus(
          autofocus: true,
          onKeyEvent: (_, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            if (event.logicalKey == LogicalKeyboardKey.f3) {
              _searchFocus.requestFocus();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.f4) {
              _pickCustomer(_current);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Column(
            children: [
              _buildTopBar(productProvider),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _buildLeftPanel()),
                    _buildRightPanel(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────

  Widget _buildTopBar(ProductProvider pp) {
    return Container(
      height: 48,
      color: const Color(0xFF1E3A5F),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          SizedBox(
            width: 280,
            child: _ProductSearchBar(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              products: pp.allProducts.where((p) => p.dangKinhDoanh).toList(),
              onSelected: (p) {
                final qty = _current.items[p.id]?.soLuong ?? 0;
                if (qty >= p.tonKho) {
                  showAppError(
                    context,
                    '${p.tenHang}: không đủ tồn kho (tối đa ${p.tonKho})',
                  );
                } else {
                  setState(() => _current.addProduct(p));
                }
                _searchCtrl.clear();
                _searchFocus.requestFocus();
              },
            ),
          ),
          const SizedBox(width: 4),
          _TopIconBtn(
            icon: Icons.qr_code_scanner,
            tooltip: 'Quét mã vạch (F3)',
            onPressed: () => _showBarcodeDialog(pp),
          ),
          const SizedBox(width: 6),
          _VertDivider(),
          const SizedBox(width: 4),
          // Invoice tabs
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ..._sessions.asMap().entries.map(
                        (e) => _buildTab(e.key, e.value),
                      ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: InkWell(
                      onTap: _addSession,
                      borderRadius: BorderRadius.circular(4),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Icon(Icons.add, size: 18, color: Colors.white54),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _VertDivider(),
          const SizedBox(width: 4),
          _TopIconBtn(
            icon: Icons.refresh,
            onPressed: () => context.read<OrderProvider>().refreshStats(),
          ),
          _TopIconBtn(
            icon: Icons.print_outlined,
            onPressed: () => _printReceipt(_current),
          ),
          const SizedBox(width: 4),
          _VertDivider(),
          const SizedBox(width: 10),
          const Icon(
            Icons.account_circle_outlined,
            size: 20,
            color: Colors.white70,
          ),
          const SizedBox(width: 6),
          Text(
            DateFormat('HH:mm  dd/MM').format(_now),
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 4),
          _TopIconBtn(icon: Icons.menu, onPressed: () {}),
        ],
      ),
    );
  }

  Widget _buildTab(int idx, _Session s) {
    final active = idx == _sessionIdx;
    return GestureDetector(
      onTap: () => setState(() => _sessionIdx = idx),
      child: Padding(
        padding: const EdgeInsets.only(left: 4, top: 6),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color:
                  active ? AppColors.card : Colors.white.withValues(alpha: .08),
              border: active
                  ? Border(
                      top: BorderSide(color: context.primary, width: 2),
                      left: const BorderSide(color: AppColors.border),
                      right: const BorderSide(color: AppColors.border),
                    )
                  : null,
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.receipt_outlined,
                  size: 13,
                  color: active ? context.primary : Colors.white38,
                ),
                const SizedBox(width: 5),
                Text(
                  s.label,
                  style: TextStyle(
                    fontSize: 12,
                    color: active ? AppColors.textPrimary : Colors.white54,
                    fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                if (_sessions.length > 1) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _closeSession(idx),
                    child: Icon(
                      Icons.close,
                      size: 12,
                      color: active ? AppColors.textSecondary : Colors.white24,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Left panel ────────────────────────────────────────────────────────────

  Widget _buildLeftPanel() {
    return Column(
      children: [
        Expanded(child: _buildOrderTable()),
        _buildNoteBar(),
      ],
    );
  }

  Widget _buildOrderTable() {
    final s = _current;
    final items = s.itemList;

    return Container(
      color: AppColors.card,
      child: Column(
        children: [
          // Table header
          Container(
            color: AppColors.cardAlt,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: const Row(
              children: [
                SizedBox(
                  width: 26,
                  child: Text(
                    '#',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                SizedBox(width: 28),
                Expanded(
                  flex: 4,
                  child: Text(
                    'SẢN PHẨM',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                SizedBox(
                  width: 124,
                  child: Text(
                    'SỐ LƯỢNG',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: Text(
                    'ĐƠN GIÁ',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                SizedBox(
                  width: 110,
                  child: Text(
                    'THÀNH TIỀN',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                SizedBox(width: 32),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: items.isEmpty
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.cardAlt,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.shopping_cart_outlined,
                          size: 40,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Chưa có sản phẩm',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Tìm hoặc quét mã vạch để thêm hàng',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (_, i) => _buildOrderRow(s, i, items[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderRow(_Session s, int idx, CartItem item) {
    final p = item.product;
    return Container(
      decoration: BoxDecoration(
        color: appRowColor(idx),
        border: const Border(
          bottom: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Row number
          SizedBox(
            width: 26,
            child: Text(
              '${idx + 1}',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
          // Delete
          SizedBox(
            width: 28,
            height: 28,
            child: IconButton(
              icon: const Icon(
                Icons.close,
                size: 14,
                color: AppColors.textMuted,
              ),
              padding: EdgeInsets.zero,
              hoverColor: AppColors.danger.withValues(alpha: .15),
              onPressed: () => setState(() => s.removeProduct(p.id)),
            ),
          ),
          // Name + meta
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.tenHang,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (p.maHang.isNotEmpty) ...[
                      Text(
                        p.maHang,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: (p.tonKho <= 5
                                ? AppColors.warning
                                : AppColors.success)
                            .withValues(alpha: .15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Tồn: ${p.tonKho}',
                        style: TextStyle(
                          fontSize: 10,
                          color: p.tonKho <= 5
                              ? AppColors.warning
                              : AppColors.success,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Qty control group
          SizedBox(
            width: 124,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _QtyBtn(
                  icon: Icons.remove,
                  onPressed: () => setState(() => s.decreaseQty(p.id)),
                ),
                Container(
                  width: 44,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: _InlineIntField(
                    value: item.soLuong,
                    onChanged: (v) {
                      final clamped = v.clamp(1, p.tonKho);
                      setState(() => s.setQty(p.id, clamped));
                      if (v > p.tonKho) {
                        showAppError(
                          context,
                          '${p.tenHang}: tối đa ${p.tonKho}',
                        );
                      }
                    },
                  ),
                ),
                _QtyBtn(
                  icon: Icons.add,
                  onPressed: () {
                    if (item.soLuong >= p.tonKho) {
                      showAppError(context, '${p.tenHang}: tối đa ${p.tonKho}');
                      return;
                    }
                    setState(() => s.increaseQty(p.id));
                  },
                ),
              ],
            ),
          ),
          // Unit price (editable)
          SizedBox(
            width: 100,
            child: _InlineIntField(
              value: item.donGia,
              textAlign: TextAlign.right,
              onChanged: (v) => setState(() => s.setPrice(p.id, v)),
              formatter: NumberFormat('#,###', 'vi_VN'),
            ),
          ),
          // Row total
          SizedBox(
            width: 110,
            child: Text(
              Utils.formatCurrency(item.thanhTien),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: context.primary,
              ),
            ),
          ),
          const SizedBox(width: 32),
        ],
      ),
    );
  }

  Widget _buildNoteBar() {
    final s = _current;
    return Container(
      height: 40,
      decoration: const BoxDecoration(
        color: AppColors.cardAlt,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(
            Icons.notes_outlined,
            size: 15,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _noteCtrl(s),
              decoration: const InputDecoration(
                hintText: 'Ghi chú đơn hàng...',
                hintStyle: TextStyle(fontSize: 12, color: AppColors.textMuted),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 4),
                filled: false,
              ),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
              onChanged: (v) => s.ghiChu = v,
            ),
          ),
        ],
      ),
    );
  }

  // ── Right panel ───────────────────────────────────────────────────────────

  Widget _buildRightPanel() {
    final s = _current;
    return Container(
      width: 360,
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          _buildRightHeader(s),
          _buildCustomerRow(s),
          const Divider(height: 1),
          Expanded(child: _buildCheckoutBody(s)),
          _buildBottomButtons(s),
        ],
      ),
    );
  }

  Widget _buildRightHeader(_Session s) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      color: AppColors.cardAlt,
      child: Row(
        children: [
          const Icon(
            Icons.store_outlined,
            size: 15,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 6),
          const Text(
            'admin',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          const Icon(
            Icons.access_time_outlined,
            size: 13,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 4),
          Text(
            DateFormat('HH:mm  dd/MM/yyyy').format(_now),
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerRow(_Session s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _pickCustomer(s),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.inputFill,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: s.customer != null
                        ? context.primary.withValues(alpha: .5)
                        : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      s.customer != null
                          ? Icons.person
                          : Icons.person_search_outlined,
                      size: 15,
                      color: s.customer != null
                          ? context.primary
                          : AppColors.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.customer?.tenKhachHang ?? 'Khách lẻ  (F4 để tìm)',
                        style: TextStyle(
                          fontSize: 12,
                          color: s.customer != null
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                          fontWeight: s.customer != null
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (s.customer != null)
                      GestureDetector(
                        onTap: () => setState(() => s.customer = null),
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Thêm khách mới',
            child: InkWell(
              onTap: () => _showQuickAddCustomer(s),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: context.primary.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: context.primary.withValues(alpha: .3),
                  ),
                ),
                child: Icon(
                  Icons.person_add_outlined,
                  size: 16,
                  color: context.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutBody(_Session s) {
    final payCtrl = _paymentCtrl(s);
    final disCtrl = _discountCtrl(s);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Subtotal row ──────────────────────────────────────────────
          _SummaryRow(
            label: 'Tổng tiền hàng',
            trailing: '${s.tongSoLuong} sp',
            value: Utils.formatCurrency(s.tongTienHang),
          ),
          const SizedBox(height: 6),

          // ── Discount row ──────────────────────────────────────────────
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Giảm giá',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: disCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    hintText: '0',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    suffixText: 'đ',
                    suffixStyle: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  onChanged: (v) {
                    final val = int.tryParse(v) ?? 0;
                    setState(() => s.discount = val.clamp(0, s.tongTienHang));
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Total card ────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  context.primary.withValues(alpha: .25),
                  context.primary.withValues(alpha: .12),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: context.primary.withValues(alpha: .4),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'KHÁCH CẦN TRẢ',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        Utils.formatCurrency(s.khachCanTra),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: context.primary,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                if (s.tongSoLuong > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: context.primary.withValues(alpha: .2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${s.tongSoLuong} sản phẩm',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Payment method ────────────────────────────────────────────
          const Text(
            'Phương thức thanh toán',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          _buildPaymentMethods(s),
          const SizedBox(height: 14),

          // ── Payment amount input ──────────────────────────────────────
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Khách thanh toán',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              SizedBox(
                width: 130,
                child: TextField(
                  controller: payCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    hintText: '0',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    suffixText: 'đ',
                    suffixStyle: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  onChanged: (v) =>
                      setState(() => s.paymentAmount = int.tryParse(v) ?? 0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Quick amounts ─────────────────────────────────────────────
          _buildQuickAmounts(s, payCtrl),
          const SizedBox(height: 14),
          const Divider(color: AppColors.border),
          const SizedBox(height: 10),

          // ── Change ────────────────────────────────────────────────────
          if (s.tienThua > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: .3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 16,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Tiền thừa trả khách',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    Utils.formatCurrency(s.tienThua),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Tiền thừa trả khách',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                ),
                Text(
                  Utils.formatCurrency(s.tienThua),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethods(_Session s) {
    const methods = [
      ('cash', Icons.payments_outlined, 'Tiền mặt'),
      ('bank', Icons.account_balance_outlined, 'C.khoản'),
      ('card', Icons.credit_card_outlined, 'Thẻ'),
    ];
    return Row(
      children: methods.map((m) {
        final active = s.paymentMethod == m.$1;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => s.paymentMethod = m.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: EdgeInsets.only(right: m.$1 != 'card' ? 6 : 0),
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: active ? context.primary : AppColors.inputFill,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: active ? context.primary : AppColors.border,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    m.$2,
                    size: 18,
                    color: active ? Colors.white : AppColors.textSecondary,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    m.$3,
                    style: TextStyle(
                      fontSize: 11,
                      color: active ? Colors.white : AppColors.textSecondary,
                      fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQuickAmounts(_Session s, TextEditingController payCtrl) {
    final amounts = _quickAmounts(s.khachCanTra);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: amounts.map((a) {
        final isExact = a == s.khachCanTra && s.khachCanTra > 0;
        final isSelected = s.paymentAmount == a;
        return GestureDetector(
          onTap: () => setState(() {
            s.paymentAmount = a;
            payCtrl.text = a.toString();
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? context.primary.withValues(alpha: .2)
                  : isExact
                      ? AppColors.success.withValues(alpha: .1)
                      : AppColors.inputFill,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? context.primary
                    : isExact
                        ? AppColors.success.withValues(alpha: .5)
                        : AppColors.border,
              ),
            ),
            child: Text(
              Utils.formatCurrency(a),
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    isExact || isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? context.primary
                    : isExact
                        ? AppColors.success
                        : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomButtons(_Session s) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // THANH TOÁN — primary full-width button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              onPressed: _doPayment,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.payments_outlined, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'THANH TOÁN',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  if (s.khachCanTra > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        Utils.formatCurrency(s.khachCanTra),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Secondary row: Print + Reset
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.border),
                      foregroundColor: AppColors.textSecondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () => _printReceipt(s),
                    icon: const Icon(Icons.print_outlined, size: 15),
                    label: const Text(
                      'In hoá đơn',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: AppColors.danger.withValues(alpha: .4),
                      ),
                      foregroundColor: AppColors.danger,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () => setState(() => _resetSession(s)),
                    icon: const Icon(Icons.delete_sweep_outlined, size: 15),
                    label: const Text(
                      'Xoá đơn',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  void _showBarcodeDialog(ProductProvider pp) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quét mã vạch'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Nhập hoặc quét mã vạch...',
            prefixIcon: Icon(Icons.qr_code),
          ),
          onSubmitted: (v) {
            Navigator.pop(ctx);
            final found =
                pp.allProducts.where((p) => p.maVach == v.trim()).firstOrNull;
            if (found != null) {
              final qty = _current.items[found.id]?.soLuong ?? 0;
              if (qty >= found.tonKho) {
                showAppError(
                  context,
                  '${found.tenHang}: không đủ tồn kho (tối đa ${found.tonKho})',
                );
              } else {
                setState(() => _current.addProduct(found));
              }
            } else {
              showAppError(context, 'Không tìm thấy sản phẩm với mã: $v');
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _pickCustomer(_Session s) {
    showDialog(
      context: context,
      builder: (ctx) => _CustomerPickerDialog(
        onSelected: (c) {
          setState(() => s.customer = c);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _showQuickAddCustomer(_Session s) {
    showDialog(
      context: context,
      builder: (ctx) => _AddCustomerDialog(
        onSaved: (customer) {
          setState(() => s.customer = customer);
          showAppSuccess(context, 'Đã thêm khách: ${customer.tenKhachHang}');
        },
      ),
    );
  }

  // ── Print to installed printer ────────────────────────────────────────────

  Future<void> _printReceipt(_Session s) async {
    if (s.items.isEmpty) {
      showAppError(context, 'Hóa đơn chưa có sản phẩm');
      return;
    }
    final nguoiTao = context.read<AuthProvider>().currentUser?.username ?? '';
    try {
      // Use Arial from Windows system fonts — supports Vietnamese, always
      // available offline, no download required.
      final fontData = await File('C:/Windows/Fonts/arial.ttf').readAsBytes();
      final fontBoldData = await File(
        'C:/Windows/Fonts/arialbd.ttf',
      ).readAsBytes();
      final font = pw.Font.ttf(fontData.buffer.asByteData());
      final fontBold = pw.Font.ttf(fontBoldData.buffer.asByteData());

      await Printing.layoutPdf(
        name: s.label,
        onLayout: (format) => _buildReceiptDoc(
          s: s,
          format: format,
          font: font,
          fontBold: fontBold,
          nguoiTao: nguoiTao,
        ),
      );
    } catch (e) {
      if (mounted) showAppError(context, 'Lỗi in: $e');
    }
  }

  Future<Uint8List> _buildReceiptDoc({
    required _Session s,
    required PdfPageFormat format,
    required pw.Font font,
    required pw.Font fontBold,
    String nguoiTao = '',
  }) async {
    const methodLabels = {
      'cash': 'Tiền mặt',
      'bank': 'Chuyển khoản',
      'card': 'Thẻ',
    };
    final dateFmt = DateFormat('HH:mm  dd/MM/yyyy');
    final now = DateTime.now();

    pw.TextStyle s_(double size, {bool bold = false}) =>
        pw.TextStyle(font: bold ? fontBold : font, fontSize: size);

    pw.Widget row(
      String label,
      String value, {
      double size = 10,
      bool bold = false,
    }) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(label, style: s_(size, bold: bold)),
              ),
              pw.Text(value, style: s_(size, bold: bold)),
            ],
          ),
        );

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────
            pw.Center(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('NHÀ SÁCH THẢO NGUYÊN',
                      style: s_(14, bold: true),
                      textAlign: pw.TextAlign.center),
                  pw.SizedBox(height: 3),
                  pw.Text('HÓA ĐƠN BÁN HÀNG', style: s_(11, bold: true)),
                  pw.SizedBox(height: 2),
                  pw.Text(dateFmt.format(now), style: s_(9)),
                  if (nguoiTao.isNotEmpty) ...[
                    pw.SizedBox(height: 1),
                    pw.Text('Thu ngân: $nguoiTao', style: s_(9)),
                  ],
                ],
              ),
            ),
            pw.Divider(height: 10),

            // ── Customer ──────────────────────────────────────────────
            pw.Text(
              'Khách: ${s.customer?.tenKhachHang ?? 'Khách lẻ'}',
              style: s_(10),
            ),
            if (s.customer?.dienThoai.isNotEmpty == true)
              pw.Text('ĐT: ${s.customer!.dienThoai}', style: s_(9)),
            pw.Divider(height: 10),

            // ── Items header ──────────────────────────────────────────
            pw.Row(
              children: [
                pw.Expanded(
                    child: pw.Text(
                  'SL',
                  style: s_(9, bold: true),
                  textAlign: pw.TextAlign.center,
                )),
                pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      'Đơn giá',
                      style: s_(9, bold: true),
                      textAlign: pw.TextAlign.right,
                    )),
                pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      'T.Tiền',
                      style: s_(9, bold: true),
                      textAlign: pw.TextAlign.right,
                    )),
              ],
            ),
            pw.Divider(height: 4),

            // ── Items ─────────────────────────────────────────────────
            ...s.itemList.map(
              (item) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3),
                  child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(item.product.tenHang, style: s_(10)),
                        pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Expanded(
                              child: pw.Text(
                                '${item.soLuong}',
                                style: s_(10),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                            pw.Expanded(
                              flex: 2,
                              child: pw.Text(
                                Utils.formatCurrency(item.donGia),
                                style: s_(9),
                                textAlign: pw.TextAlign.right,
                              ),
                            ),
                            pw.Expanded(
                              flex: 2,
                              child: pw.Text(
                                Utils.formatCurrency(item.thanhTien),
                                style: s_(10, bold: true),
                                textAlign: pw.TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      ])),
            ),
            pw.Divider(height: 10),

            // ── Totals ────────────────────────────────────────────────
            row('Tổng tiền hàng:', Utils.formatCurrency(s.tongTienHang)),
            if (s.discount > 0)
              row('Giảm giá:', '- ${Utils.formatCurrency(s.discount)}'),
            pw.SizedBox(height: 4),
            row(
              'KHÁCH CẦN TRẢ:',
              Utils.formatCurrency(s.khachCanTra),
              size: 13,
              bold: true,
            ),
            pw.Divider(height: 10),

            // ── Payment ───────────────────────────────────────────────
            row(
              'Phương thức:',
              methodLabels[s.paymentMethod] ?? s.paymentMethod,
            ),
            if (s.paymentAmount > 0) ...[
              row('Khách đưa:', Utils.formatCurrency(s.paymentAmount)),
              row('Tiền thừa:', Utils.formatCurrency(s.tienThua), bold: true),
            ],

            // ── Note ──────────────────────────────────────────────────
            if (s.ghiChu.isNotEmpty) ...[
              pw.SizedBox(height: 6),
              pw.Text(
                'Ghi chú: ${s.ghiChu}',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 9,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ],

            // ── Footer ────────────────────────────────────────────────
            pw.SizedBox(height: 16),
            pw.Center(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'Cảm ơn quý khách đã mua hàng!',
                    style: s_(10, bold: true),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text('Hẹn gặp lại!', style: s_(9)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return doc.save();
  }
}

// ── Summary row helper ────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final String label;
  final String? trailing;
  final String value;

  const _SummaryRow({required this.label, this.trailing, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        if (trailing != null) ...[
          Text(
            trailing!,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(width: 12),
        ],
        Text(
          value,
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
        ),
      ],
    );
  }
}

// ── Customer picker dialog ────────────────────────────────────────────────────

class _CustomerPickerDialog extends StatefulWidget {
  final ValueChanged<Customer> onSelected;
  const _CustomerPickerDialog({required this.onSelected});

  @override
  State<_CustomerPickerDialog> createState() => _CustomerPickerDialogState();
}

class _CustomerPickerDialogState extends State<_CustomerPickerDialog> {
  final _ctrl = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 420,
        height: 500,
        child: Column(
          children: [
            AppDialogHeader(
              icon: Icons.person_search_outlined,
              title: 'Chọn khách hàng',
              onClose: () => Navigator.pop(context),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: AppSearchField(
                controller: _ctrl,
                hint: 'Tìm theo tên hoặc số điện thoại...',
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Consumer<CustomerProvider>(
                builder: (_, cp, __) {
                  final q = _search.toLowerCase();
                  final list = cp.customers
                      .where(
                        (c) =>
                            c.tenKhachHang.toLowerCase().contains(q) ||
                            c.dienThoai.contains(q),
                      )
                      .toList();
                  if (list.isEmpty) {
                    return const AppEmptyState(
                      icon: Icons.person_off_outlined,
                      message: 'Không tìm thấy khách hàng',
                    );
                  }
                  return ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final c = list[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: context.primary.withValues(
                            alpha: .15,
                          ),
                          child: Text(
                            c.tenKhachHang[0],
                            style: TextStyle(
                              color: context.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          c.tenKhachHang,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          c.dienThoai,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                        onTap: () => widget.onSelected(c),
                      );
                    },
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

// ── Product search bar ────────────────────────────────────────────────────────

class _ProductSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<Product> products;
  final ValueChanged<Product> onSelected;

  const _ProductSearchBar({
    required this.controller,
    required this.focusNode,
    required this.products,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<Product>(
      textEditingController: controller,
      focusNode: focusNode,
      optionsBuilder: (tv) {
        final q = tv.text.toLowerCase();
        if (q.isEmpty) return const [];
        return products.where(
          (p) =>
              p.tenHang.toLowerCase().contains(q) ||
              p.maHang.toLowerCase().contains(q) ||
              p.maVach.contains(q),
        );
      },
      displayStringForOption: (p) => p.tenHang,
      fieldViewBuilder: (ctx, ctrl, fn, onFieldSubmitted) => TextField(
        controller: ctrl,
        focusNode: fn,
        onSubmitted: (text) {
          final q = text.trim();
          if (q.isEmpty) return;
          final match =
              products.where((p) => p.maVach == q || p.maHang == q).firstOrNull;
          if (match != null) {
            onSelected(match);
            return;
          }
          onFieldSubmitted();
        },
        decoration: InputDecoration(
          hintText: 'Tìm hàng hóa (F3)...',
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
          prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
          filled: true,
          fillColor: Colors.white.withValues(alpha: .12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 10,
          ),
          isDense: true,
        ),
        style: const TextStyle(color: Colors.white, fontSize: 13),
        cursorColor: Colors.white70,
      ),
      optionsViewBuilder: (ctx, onSelect, options) {
        final list = options.toList();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: AppColors.card,
            elevation: 12,
            shadowColor: Colors.black54,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 340, maxWidth: 440),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final p = list[i];
                  final oos = p.tonKho <= 0;
                  return ListTile(
                    dense: true,
                    leading: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: (oos ? AppColors.danger : context.primary)
                            .withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        oos
                            ? Icons.remove_shopping_cart_outlined
                            : Icons.inventory_2_outlined,
                        size: 16,
                        color: oos ? AppColors.danger : context.primary,
                      ),
                    ),
                    title: Text(
                      p.tenHang,
                      style: TextStyle(
                        fontSize: 13,
                        color:
                            oos ? AppColors.textMuted : AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      '${p.maHang.isNotEmpty ? p.maHang : 'No code'}  •  Tồn: ${p.tonKho}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                    trailing: Text(
                      Utils.formatCurrency(p.giaBan),
                      style: TextStyle(
                        color: context.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    onTap: oos ? null : () => onSelect(p),
                  );
                },
              ),
            ),
          ),
        );
      },
      onSelected: onSelected,
    );
  }
}

// ── Top bar icon button ───────────────────────────────────────────────────────

class _TopIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  const _TopIconBtn({
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 34,
        height: 34,
        child: IconButton(
          icon: Icon(icon, color: Colors.white60, size: 17),
          tooltip: tooltip,
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          hoverColor: Colors.white.withValues(alpha: .1),
        ),
      );
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 22, color: Colors.white12);
}

// ── Quantity +/- button ───────────────────────────────────────────────────────

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  const _QtyBtn({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 28,
        height: 28,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            side: const BorderSide(color: AppColors.border),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          onPressed: onPressed,
          child: Icon(icon, size: 14, color: AppColors.textSecondary),
        ),
      );
}

// ── Inline editable int field ─────────────────────────────────────────────────

class _InlineIntField extends StatefulWidget {
  final int value;
  final TextAlign textAlign;
  final ValueChanged<int> onChanged;
  final NumberFormat? formatter;

  const _InlineIntField({
    required this.value,
    this.textAlign = TextAlign.center,
    required this.onChanged,
    this.formatter,
  });

  @override
  State<_InlineIntField> createState() => _InlineIntFieldState();
}

class _InlineIntFieldState extends State<_InlineIntField> {
  late final TextEditingController _ctrl;
  late final FocusNode _focusNode;
  bool _focused = false;

  String _formatted(int v) => widget.formatter?.format(v) ?? v.toString();

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()
      ..addListener(() {
        if (_focusNode.hasFocus == _focused) return;
        _focused = _focusNode.hasFocus;
        if (widget.formatter == null) return;
        // Switch between formatted display and raw digits for editing
        final newText =
            _focused ? widget.value.toString() : _formatted(widget.value);
        _ctrl.value = _ctrl.value.copyWith(
          text: newText,
          selection: TextSelection(baseOffset: 0, extentOffset: newText.length),
        );
      });
    _ctrl = TextEditingController(text: _formatted(widget.value));
  }

  @override
  void didUpdateWidget(_InlineIntField old) {
    super.didUpdateWidget(old);
    // For qty (no formatter): always sync external changes.
    // For price (formatter): only sync when not focused to avoid clobbering user input.
    if (widget.value != old.value && (widget.formatter == null || !_focused)) {
      final newText = _formatted(widget.value);
      _ctrl.value = _ctrl.value.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _ctrl,
        focusNode: _focusNode,
        textAlign: widget.textAlign,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        ),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        onChanged: (v) {
          final parsed = int.tryParse(v);
          if (parsed != null) widget.onChanged(parsed);
        },
        onTap: () => _ctrl.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _ctrl.text.length,
        ),
      );
}

// ── Add Customer Dialog ───────────────────────────────────────────────────────

class _AddCustomerDialog extends StatefulWidget {
  final ValueChanged<Customer> onSaved;
  const _AddCustomerDialog({required this.onSaved});

  @override
  State<_AddCustomerDialog> createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends State<_AddCustomerDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  final _maCtrl = TextEditingController();
  final _tenCtrl = TextEditingController();
  final _dienThoaiCtrl = TextEditingController();
  final _diaChiCtrl = TextEditingController();
  final _khuVucCtrl = TextEditingController();
  final _phuongXaCtrl = TextEditingController();
  final _nhomCtrl = TextEditingController();
  final _ngaySinhCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _facebookCtrl = TextEditingController();
  final _ghiChuCtrl = TextEditingController();
  String _gioiTinh = '';

  final _congTyCtrl = TextEditingController();
  final _maSoThueCtrl = TextEditingController();
  final _diaChiCtyCtrl = TextEditingController();
  final _emailCtyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    for (final c in [
      _maCtrl,
      _tenCtrl,
      _dienThoaiCtrl,
      _diaChiCtrl,
      _khuVucCtrl,
      _phuongXaCtrl,
      _nhomCtrl,
      _ngaySinhCtrl,
      _emailCtrl,
      _facebookCtrl,
      _ghiChuCtrl,
      _congTyCtrl,
      _maSoThueCtrl,
      _diaChiCtyCtrl,
      _emailCtyCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      _tabCtrl.animateTo(0);
      return;
    }
    setState(() => _saving = true);
    final cp = context.read<CustomerProvider>();
    final err = await cp.createCustomer(
      maKhachHang: _maCtrl.text.trim().isEmpty ? null : _maCtrl.text.trim(),
      tenKhachHang: _tenCtrl.text.trim(),
      dienThoai: _dienThoaiCtrl.text.trim(),
      diaChi: _diaChiCtrl.text.trim(),
      khuVuc: _khuVucCtrl.text.trim(),
      phuongXa: _phuongXaCtrl.text.trim(),
      nhomKhachHang: _nhomCtrl.text.trim(),
      ngaySinh: _ngaySinhCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      facebook: _facebookCtrl.text.trim(),
      ghiChu: _ghiChuCtrl.text.trim(),
      gioiTinh: _gioiTinh,
      congTy: _congTyCtrl.text.trim(),
      maSoThue: _maSoThueCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      showAppError(context, 'Lỗi: $err');
      return;
    }
    final added = cp.allCustomers.first;
    Navigator.pop(context);
    widget.onSaved(added);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: SizedBox(
        width: 720,
        height: 560,
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    const Text(
                      'Thêm khách hàng',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(width: 1, height: 16, color: AppColors.border),
                    const SizedBox(width: 12),
                    const Text(
                      'Chi nhánh trung tâm',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              TabBar(
                controller: _tabCtrl,
                isScrollable: true,
                labelColor: context.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: context.primary,
                tabs: const [
                  Tab(text: 'Thông tin chung'),
                  Tab(text: 'Thông tin xuất hóa đơn'),
                ],
              ),
              const Divider(height: 1),
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [_buildGeneralTab(), _buildInvoiceTab()],
                ),
              ),
              // Footer
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Hủy'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Lưu khách hàng'),
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

  Widget _buildGeneralTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.cardAlt,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(
                  Icons.person,
                  size: 44,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: context.primary),
                  foregroundColor: context.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {},
                child: const Text('Chọn ảnh', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Field(label: 'Mã khách hàng', ctrl: _maCtrl, hint: 'Tự động'),
                _Field(
                  label: 'Tên khách hàng',
                  ctrl: _tenCtrl,
                  hint: 'Bắt buộc',
                  autofocus: true,
                  required: true,
                ),
                _Field(
                  label: 'Điện thoại',
                  ctrl: _dienThoaiCtrl,
                  type: TextInputType.phone,
                ),
                _Field(label: 'Địa chỉ', ctrl: _diaChiCtrl),
                _Field(label: 'Khu vực', ctrl: _khuVucCtrl),
                _Field(label: 'Phường xã', ctrl: _phuongXaCtrl),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Field(label: 'Nhóm khách hàng', ctrl: _nhomCtrl),
                _Field(
                  label: 'Ngày sinh',
                  ctrl: _ngaySinhCtrl,
                  hint: 'dd/MM/yyyy',
                ),
                Row(
                  children: [
                    _GenderPill(
                      label: 'Nam',
                      selected: _gioiTinh == 'Nam',
                      onTap: () => setState(
                        () => _gioiTinh = _gioiTinh == 'Nam' ? '' : 'Nam',
                      ),
                    ),
                    const SizedBox(width: 12),
                    _GenderPill(
                      label: 'Nữ',
                      selected: _gioiTinh == 'Nữ',
                      onTap: () => setState(
                        () => _gioiTinh = _gioiTinh == 'Nữ' ? '' : 'Nữ',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _Field(
                  label: 'Email',
                  ctrl: _emailCtrl,
                  type: TextInputType.emailAddress,
                ),
                _Field(label: 'Facebook', ctrl: _facebookCtrl),
                _Field(label: 'Ghi chú', ctrl: _ghiChuCtrl, maxLines: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: [
                _Field(label: 'Tên công ty', ctrl: _congTyCtrl),
                _Field(label: 'Địa chỉ công ty', ctrl: _diaChiCtyCtrl),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              children: [
                _Field(label: 'Mã số thuế', ctrl: _maSoThueCtrl),
                _Field(
                  label: 'Email công ty',
                  ctrl: _emailCtyCtrl,
                  type: TextInputType.emailAddress,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Form field ────────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final String hint;
  final TextInputType type;
  final bool required;
  final bool autofocus;
  final int maxLines;

  const _Field({
    required this.label,
    required this.ctrl,
    this.hint = '',
    this.type = TextInputType.text,
    this.required = false,
    this.autofocus = false,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 3),
        TextFormField(
          controller: ctrl,
          autofocus: autofocus,
          keyboardType: type,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint.isNotEmpty ? hint : null,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
          ),
          validator: required
              ? (v) => (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null
              : null,
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

// ── Gender pill ───────────────────────────────────────────────────────────────

class _GenderPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _GenderPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? context.primary : AppColors.border,
                  width: 1.5,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: context.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style:
                  const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
          ],
        ),
      );
}
