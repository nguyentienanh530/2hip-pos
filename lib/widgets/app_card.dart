import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Dark-themed card container used throughout the app.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final Color? color;
  final Color? borderColor;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = 12,
    this.color,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding ?? const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color ?? AppColors.card,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: borderColor ?? AppColors.border),
        ),
        child: child,
      );
}
