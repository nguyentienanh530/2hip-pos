import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? subtitle;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 72, color: AppColors.border),
          const SizedBox(height: 16),
          Text(message,
              style: const TextStyle(
                  fontSize: 18, color: AppColors.textSecondary)),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle!,
                style:
                    const TextStyle(fontSize: 14, color: AppColors.textMuted)),
          ],
        ],
      ),
    );
  }
}
