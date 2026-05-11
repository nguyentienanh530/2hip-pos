import 'dart:math' show max;
import 'package:flutter/material.dart';
import 'package:nha_sach_thao_nguyen/utils.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:fl_chart/fl_chart.dart';
import '../providers/product_provider.dart';
import '../providers/order_provider.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../theme/app_theme.dart';

enum _Period { today, week, month, year }

// ─────────────────────────────────────────────────────────────────────────────

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  _Period _period = _Period.today;

  DateTimeRange _range() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (_period) {
      _Period.today => DateTimeRange(start: today, end: now),
      _Period.week =>
        DateTimeRange(start: today.subtract(const Duration(days: 6)), end: now),
      _Period.month =>
        DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
      _Period.year => DateTimeRange(start: DateTime(now.year, 1, 1), end: now),
    };
  }

  List<Order> _filter(List<Order> all) {
    final r = _range();
    return all
        .where((o) => !o.ngayTao.isBefore(r.start) && !o.ngayTao.isAfter(r.end))
        .toList();
  }

  String _periodLabel() => switch (_period) {
        _Period.today => 'Hôm nay',
        _Period.week => '7 ngày qua',
        _Period.month => 'Tháng này',
        _Period.year => 'Năm nay',
      };

  // ── Computations ────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _topProducts(List<Order> orders) {
    final map = <String, Map<String, dynamic>>{};
    for (final o in orders) {
      for (final item in o.items) {
        final m = map.putIfAbsent(
            item.productId,
            () => {
                  'tenHang': item.tenHang,
                  'soLuong': 0,
                  'doanhThu': 0,
                });
        m['soLuong'] = (m['soLuong'] as int) + item.soLuong;
        m['doanhThu'] = (m['doanhThu'] as int) + item.thanhTien;
      }
    }
    return (map.values.toList()
          ..sort(
              (a, b) => (b['soLuong'] as int).compareTo(a['soLuong'] as int)))
        .take(8)
        .toList();
  }

  List<Map<String, dynamic>> _sellerStats(List<Order> orders) {
    final map = <String, Map<String, dynamic>>{};
    for (final o in orders) {
      final seller = o.nguoiTao.isEmpty ? '(Không rõ)' : o.nguoiTao;
      final m = map.putIfAbsent(
          seller,
          () => {
                'nguoiTao': seller,
                'soDon': 0,
                'doanhThu': 0,
                'loiNhuan': 0,
              });
      m['soDon'] = (m['soDon'] as int) + 1;
      m['doanhThu'] = (m['doanhThu'] as int) + o.tongTien;
      m['loiNhuan'] = (m['loiNhuan'] as int) + o.loiNhuan;
    }
    return map.values.toList()
      ..sort((a, b) => (b['doanhThu'] as int).compareTo(a['doanhThu'] as int));
  }

  Map<DateTime, int> _dailyRevenue(List<Order> all) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final map = {
      for (int i = 29; i >= 0; i--) today.subtract(Duration(days: i)): 0
    };
    for (final o in all) {
      final d = DateTime(o.ngayTao.year, o.ngayTao.month, o.ngayTao.day);
      if (map.containsKey(d)) map[d] = map[d]! + o.tongTien;
    }
    return map;
  }

  Map<int, int> _monthlyRevenue(List<Order> all) {
    final year = DateTime.now().year;
    final map = {for (int m = 1; m <= 12; m++) m: 0};
    for (final o in all) {
      if (o.ngayTao.year == year)
        map[o.ngayTao.month] = map[o.ngayTao.month]! + o.tongTien;
    }
    return map;
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer2<ProductProvider, OrderProvider>(
      builder: (context, products, orders, _) {
        final filtered = _filter(orders.orders);
        final revenue = filtered.fold(0, (s, o) => s + o.tongTien);
        final cost = filtered.fold(0, (s, o) => s + o.tongVon);
        final profit = revenue - cost;
        final cnt = filtered.length;
        final avg = cnt > 0 ? revenue ~/ cnt : 0;
        final soldQty =
            filtered.expand((o) => o.items).fold(0, (s, i) => s + i.soLuong);

        final lowStock =
            (products.allProducts.where((p) => p.tonKho < 5).toList()
              ..sort((a, b) => a.tonKho.compareTo(b.tonKho)));

        final topProd = _topProducts(filtered);
        final sellerStats = _sellerStats(filtered);
        final daily = _dailyRevenue(orders.orders);
        final monthly = _monthlyRevenue(orders.orders);

        return Scaffold(
          backgroundColor: AppColors.bg,
          appBar: _buildAppBar(context, orders),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Period filter ─────────────────────────────────────────
                _PeriodFilter(
                  selected: _period,
                  onChanged: (p) => setState(() => _period = p),
                ),
                const SizedBox(height: 20),

                // ── KPI row 1 ─────────────────────────────────────────────
                Row(children: [
                  Expanded(
                      child: _KpiCard(
                    label: 'Doanh thu',
                    value: Utils.formatCurrency(revenue.toDouble()),
                    icon: Icons.payments_outlined,
                    color: context.primary,
                    subtitle: _periodLabel(),
                  )),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _KpiCard(
                    label: 'Số đơn hàng',
                    value: '$cnt',
                    icon: Icons.receipt_long_outlined,
                    color: AppColors.cyan,
                    subtitle: 'Đơn hoàn thành',
                  )),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _KpiCard(
                    label: 'Lợi nhuận',
                    value:
                        '${profit < 0 ? "-" : ""}${Utils.formatCurrency(profit.toDouble())}',
                    icon: profit >= 0
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    color: profit >= 0 ? AppColors.success : AppColors.danger,
                    subtitle: 'Doanh thu − Vốn',
                  )),
                ]),
                const SizedBox(height: 12),

                // ── KPI row 2 ─────────────────────────────────────────────
                Row(children: [
                  Expanded(
                      child: _KpiCard(
                    label: 'TB/đơn hàng',
                    value: Utils.formatCurrency(avg.toDouble()),
                    icon: Icons.calculate_outlined,
                    color: AppColors.purple,
                    subtitle: 'Giá trị trung bình',
                  )),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _KpiCard(
                    label: 'SP đã bán',
                    value: '$soldQty sp',
                    icon: Icons.sell_outlined,
                    color: AppColors.orange,
                    subtitle: 'Tổng số lượng bán ra',
                  )),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _KpiCard(
                    label: 'Tồn kho thấp',
                    value: '${lowStock.length} sp',
                    icon: Icons.warning_amber_rounded,
                    color: lowStock.isEmpty
                        ? AppColors.success
                        : AppColors.warning,
                    subtitle: 'Dưới 5 sản phẩm',
                  )),
                ]),
                const SizedBox(height: 20),

                // ── Charts row ────────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _DailyChart(data: daily)),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: _MonthlyChart(data: monthly)),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Top products + Low stock ───────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        flex: 3,
                        child: _TopProductsCard(items: topProd)),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: _LowStockCard(lowStock: lowStock)),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Seller stats ──────────────────────────────────────────
                _SellerStatsCard(
                  sellers: sellerStats,
                  periodLabel: _periodLabel(),
                ),
                const SizedBox(height: 20),

                // ── Recent orders ─────────────────────────────────────────
                _RecentOrdersCard(
                  orders: orders.orders.take(10).toList(),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  AppBar _buildAppBar(BuildContext context, OrderProvider orders) {
    return AppBar(
      backgroundColor: AppColors.card,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      title: Row(children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: context.primary.withValues(alpha: .2),
            borderRadius: BorderRadius.circular(8),
          ),
          child:
              Icon(Icons.dashboard_rounded, color: context.primary, size: 18),
        ),
        const SizedBox(width: 10),
        const Text(
          'Tổng Quan',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ]),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Làm mới',
          onPressed: () => context.read<OrderProvider>().refreshStats(),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

// ── Period filter ─────────────────────────────────────────────────────────────

class _PeriodFilter extends StatelessWidget {
  final _Period selected;
  final ValueChanged<_Period> onChanged;
  const _PeriodFilter({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const labels = {
      _Period.today: 'Hôm nay',
      _Period.week: '7 ngày',
      _Period.month: 'Tháng này',
      _Period.year: 'Năm nay',
    };
    return Row(
      children: _Period.values.map((p) {
        final active = p == selected;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => onChanged(p),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: active ? context.primary : AppColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: active ? context.primary : AppColors.border),
              ),
              child: Text(
                labels[p]!,
                style: TextStyle(
                  color: active ? Colors.white : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── KPI card ──────────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final String label, value, subtitle;
  final IconData icon;
  final Color color;
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 4),
              Text(value,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              Text(subtitle,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── Dark card wrapper ─────────────────────────────────────────────────────────

class _DarkCard extends StatelessWidget {
  final Widget child;
  const _DarkCard({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      );
}

// ── Compact number formatter ──────────────────────────────────────────────────

String _compact(double v) {
  if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(1)}B';
  if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
  if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(0)}K';
  return v.toStringAsFixed(0);
}

// ── Daily revenue line chart ──────────────────────────────────────────────────

class _DailyChart extends StatelessWidget {
  final Map<DateTime, int> data;
  const _DailyChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final spots = entries
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.value.toDouble()))
        .toList();
    final rawMax =
        entries.isEmpty ? 0 : entries.map((e) => e.value).reduce(max);
    final maxY = max(10000.0, rawMax * 1.25);

    return _DarkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.show_chart_rounded, color: context.primary, size: 18),
            const SizedBox(width: 8),
            const Text('Doanh thu 30 ngày gần đây',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
          ]),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touchedSpots) => touchedSpots
                      .map((spot) => LineTooltipItem(
                            Utils.formatCurrency(spot.y),
                            const TextStyle(color: Colors.white),
                          ))
                      .toList(),
                )),
                minY: 0,
                maxY: maxY.toDouble(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: AppColors.border, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 5,
                      getTitlesWidget: (val, _) {
                        final idx = val.toInt();
                        if (idx % 5 != 0 || idx >= entries.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            DateFormat('dd/MM').format(entries[idx].key),
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget: (val, meta) {
                        if (val == 0 || val == meta.max)
                          return const SizedBox.shrink();
                        return Text(
                          _compact(val),
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 10),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: context.primary,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: context.primary.withValues(alpha: .08),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Monthly revenue bar chart ─────────────────────────────────────────────────

class _MonthlyChart extends StatelessWidget {
  final Map<int, int> data;
  const _MonthlyChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final rawMax = data.values.isEmpty ? 0 : data.values.reduce(max);
    final maxY = max(10000.0, rawMax * 1.25);

    return _DarkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.bar_chart_rounded,
                color: AppColors.success, size: 18),
            const SizedBox(width: 8),
            Text('Doanh thu ${now.year}',
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
          ]),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                barTouchData:
                    BarTouchData(touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final val = rod.toY.toInt();
                    return BarTooltipItem(
                      Utils.formatCurrency(val.toDouble()),
                      const TextStyle(color: Colors.white),
                    );
                  },
                )),
                maxY: maxY.toDouble(),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, _) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'T${val.toInt()}',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 10),
                        ),
                      ),
                    ),
                  ),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                barGroups: data.entries
                    .map((e) => BarChartGroupData(
                          x: e.key,
                          barRods: [
                            BarChartRodData(
                              toY: e.value.toDouble(),
                              color: e.key == now.month
                                  ? context.primary
                                  : AppColors.border,
                              width: 14,
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4)),
                            ),
                          ],
                        ))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Top products ──────────────────────────────────────────────────────────────

class _TopProductsCard extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const _TopProductsCard({required this.items});

  @override
  Widget build(BuildContext context) {
    const rankColors = [
      Color(0xFFFFD700),
      Color(0xFFC0C0C0),
      Color(0xFFCD7F32)
    ];

    return _DarkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.emoji_events_outlined,
                color: AppColors.warning, size: 18),
            SizedBox(width: 8),
            Text('Top sản phẩm bán chạy',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
          ]),
          const SizedBox(height: 16),
          if (items.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Chưa có dữ liệu cho kỳ này',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            )
          else
            ...items.asMap().entries.map((entry) {
              final idx = entry.key;
              final p = entry.value;
              final rankColor = idx < 3 ? rankColors[idx] : AppColors.textMuted;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(children: [
                  SizedBox(
                    width: 22,
                    child: Text(
                      '${idx + 1}',
                      style: TextStyle(
                          color: rankColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      p['tenHang'] as String,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: .15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${p['soLuong']} sp',
                          style: const TextStyle(
                              color: AppColors.success,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(Utils.formatCurrency(p['doanhThu'] as num),
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 11)),
                    ],
                  ),
                ]),
              );
            }),
        ],
      ),
    );
  }
}

// ── Low stock ─────────────────────────────────────────────────────────────────

class _LowStockCard extends StatelessWidget {
  final List<Product> lowStock;
  const _LowStockCard({required this.lowStock});

  @override
  Widget build(BuildContext context) {
    return _DarkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.inventory_2_outlined,
                color: AppColors.warning, size: 18),
            const SizedBox(width: 8),
            const Text('Tồn kho thấp',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
            const Spacer(),
            if (lowStock.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: .2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${lowStock.length}',
                  style: const TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
              ),
          ]),
          const SizedBox(height: 16),
          if (lowStock.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(children: [
                  Icon(Icons.check_circle_outline_rounded,
                      color: AppColors.success, size: 40),
                  SizedBox(height: 8),
                  Text('Kho hàng ổn định',
                      style: TextStyle(color: AppColors.textSecondary)),
                ]),
              ),
            )
          else
            ...lowStock.take(10).map((p) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: p.tonKho == 0
                            ? AppColors.danger
                            : AppColors.warning,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        p.tenHang,
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (p.tonKho == 0
                                ? AppColors.danger
                                : AppColors.warning)
                            .withValues(alpha: .15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        p.tonKho == 0 ? 'Hết hàng' : '${p.tonKho} sp',
                        style: TextStyle(
                          fontSize: 11,
                          color: p.tonKho == 0
                              ? AppColors.danger
                              : AppColors.warning,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ]),
                )),
        ],
      ),
    );
  }
}

// ── Recent orders ─────────────────────────────────────────────────────────────

class _RecentOrdersCard extends StatelessWidget {
  final List<Order> orders;
  const _RecentOrdersCard({required this.orders});

  @override
  Widget build(BuildContext context) {
    return _DarkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.history_rounded, color: context.primary, size: 18),
            const SizedBox(width: 8),
            const Text('Đơn hàng gần đây',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
          ]),
          const SizedBox(height: 16),
          if (orders.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Chưa có đơn hàng',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            )
          else ...[
            // Header row
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Expanded(
                    flex: 3,
                    child: Text('Khách hàng',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12))),
                Expanded(
                    flex: 2,
                    child: Text('Thời gian',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12))),
                Expanded(
                    flex: 2,
                    child: Text('Tổng tiền',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                        textAlign: TextAlign.right)),
                Expanded(
                    child: Text('Lợi nhuận',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                        textAlign: TextAlign.right)),
              ]),
            ),
            const Divider(color: AppColors.border, height: 1),
            ...orders.map((o) => Column(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(children: [
                      Expanded(
                        flex: 3,
                        child: Row(children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: .15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                                Icons.check_circle_outline_rounded,
                                color: AppColors.success,
                                size: 16),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              o.tenKhach,
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ]),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          DateFormat('HH:mm dd/MM').format(o.ngayTao),
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          Utils.formatCurrency(o.tongTien),
                          style: TextStyle(
                              color: context.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          o.tongVon > 0 ? Utils.formatCurrency(o.loiNhuan) : '—',
                          style: TextStyle(
                            fontSize: 12,
                            color: o.tongVon > 0
                                ? (o.loiNhuan >= 0
                                    ? AppColors.success
                                    : AppColors.danger)
                                : AppColors.textMuted,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ]),
                  ),
                  const Divider(color: AppColors.cardAlt, height: 1),
                ])),
          ],
        ],
      ),
    );
  }
}

// ── Seller stats card ─────────────────────────────────────────────────────────

class _SellerStatsCard extends StatelessWidget {
  final List<Map<String, dynamic>> sellers;
  final String periodLabel;

  const _SellerStatsCard({
    required this.sellers,
    required this.periodLabel,
  });

  @override
  Widget build(BuildContext context) {
    return _DarkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.people_alt_outlined,
                color: AppColors.cyan, size: 18),
            const SizedBox(width: 8),
            const Text('Doanh thu theo nhân viên',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.cyan.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(periodLabel,
                  style: const TextStyle(
                      color: AppColors.cyan,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 14),
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.cardAlt,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(children: [
              Expanded(
                flex: 3,
                child: Text('Nhân viên',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                        letterSpacing: 0.4)),
              ),
              SizedBox(
                width: 70,
                child: Text('Đơn',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                        letterSpacing: 0.4)),
              ),
              SizedBox(
                width: 130,
                child: Text('Doanh thu',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                        letterSpacing: 0.4)),
              ),
              SizedBox(
                width: 130,
                child: Text('Lợi nhuận',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                        letterSpacing: 0.4)),
              ),
            ]),
          ),
          const SizedBox(height: 4),
          if (sellers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('Chưa có dữ liệu cho kỳ này',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
              ),
            )
          else
            ...sellers.asMap().entries.map((entry) {
              final idx = entry.key;
              final s = entry.value;
              final revenue = s['doanhThu'] as int;
              final profit = s['loiNhuan'] as int;
              final orders = s['soDon'] as int;
              final name = s['nguoiTao'] as String;

              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: idx.isEven
                      ? Colors.transparent
                      : AppColors.cardAlt.withValues(alpha: .4),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(children: [
                  Expanded(
                    flex: 3,
                    child: Row(children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.cyan.withValues(alpha: .15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                                color: AppColors.cyan,
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(name,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                  ),
                  SizedBox(
                    width: 70,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: context.primary.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text('$orders đơn',
                          style: TextStyle(
                              fontSize: 11,
                              color: context.primary,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                  SizedBox(
                    width: 130,
                    child: Text(Utils.formatCurrency(revenue),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                  ),
                  SizedBox(
                    width: 130,
                    child: Text(
                      profit >= 0
                          ? Utils.formatCurrency(profit)
                          : '-${Utils.formatCurrency(profit.abs())}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: profit >= 0
                              ? AppColors.success
                              : AppColors.danger),
                    ),
                  ),
                ]),
              );
            }),
        ],
      ),
    );
  }
}
