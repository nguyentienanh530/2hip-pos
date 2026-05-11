import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Coloured pill badge — colour is derived from the label hash if not given.
class AppBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final double fontSize;

  const AppBadge({
    super.key,
    required this.label,
    this.color,
    this.fontSize = 11,
  });

  static const _palette = [
    AppColors.success,
    AppColors.orange,
    AppColors.purple,
    AppColors.cyan,
    AppColors.danger,
  ];

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    final palette = [context.primary, ..._palette];
    final c = color ?? palette[label.hashCode.abs() % palette.length];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: fontSize, color: c, fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Simple status badge with explicit colour (e.g. success/warning/danger).
class AppStatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final double fontSize;

  const AppStatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: fontSize, color: color, fontWeight: FontWeight.bold),
        ),
      );
}

/// Stock badge — red when 0, orange when low, green otherwise.
class AppStockBadge extends StatelessWidget {
  final int qty;
  final int lowThreshold;

  const AppStockBadge({super.key, required this.qty, this.lowThreshold = 5});

  @override
  Widget build(BuildContext context) {
    final Color c;
    final String label;
    if (qty == 0) {
      c = AppColors.danger;
      label = 'Hết hàng';
    } else if (qty < lowThreshold) {
      c = AppColors.warning;
      label = '$qty sp';
    } else {
      c = AppColors.success;
      label = '$qty sp';
    }
    return AppStatusBadge(label: label, color: c);
  }
}
