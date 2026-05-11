import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppSearchField extends StatelessWidget {
  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final double? width;

  const AppSearchField({
    super.key,
    this.controller,
    this.hint = 'Tìm kiếm...',
    this.onChanged,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    Widget field = TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded,
            size: 18, color: AppColors.textMuted),
        fillColor: AppColors.inputFill,
        filled: true,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: context.primary, width: 1.5),
        ),
      ),
    );
    if (width != null) return SizedBox(width: width, child: field);
    return field;
  }
}
