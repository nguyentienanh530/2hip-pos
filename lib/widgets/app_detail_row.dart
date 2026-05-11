import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A label / value row used in detail panels (e.g. order detail).
class AppDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;
  final double valueFontSize;

  const AppDetailRow(
    this.label,
    this.value, {
    super.key,
    this.bold = false,
    this.valueColor,
    this.valueFontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: valueFontSize,
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
