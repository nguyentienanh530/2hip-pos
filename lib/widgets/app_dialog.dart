import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Coloured header bar placed at the top of custom dialogs.
class AppDialogHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final VoidCallback? onClose;
  final Color color;

  const AppDialogHeader({
    super.key,
    required this.title,
    this.icon,
    this.onClose,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold),
            ),
          ),
          if (onClose != null)
            IconButton(
              icon: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 18),
              onPressed: onClose,
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
        ],
      ),
    );
  }
}

/// Shows a standard confirm / delete dialog.
/// Returns `true` when the user confirms, `false` otherwise.
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Xác nhận',
  Color confirmColor = AppColors.danger,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Hủy'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: confirmColor),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result == true;
}

/// Shows a floating error SnackBar.
void showAppError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: AppColors.danger,
    ),
  );
}

/// Shows a floating success SnackBar.
void showAppSuccess(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: AppColors.success,
    ),
  );
}
