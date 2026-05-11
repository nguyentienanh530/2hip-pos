import 'package:flutter/material.dart';

extension ThemeColors on BuildContext {
  Color get primary => Theme.of(this).colorScheme.primary;
}

// ── Colour palette ────────────────────────────────────────────────────────────

abstract final class AppColors {
  // Surfaces
  static const bg        = Color(0xFF111827);
  static const card      = Color(0xFF1F2937);
  static const cardAlt   = Color(0xFF192435);
  static const inputFill = Color(0xFF1E2736);
  static const navBg     = Color(0xFF1E293B);

  // Borders
  static const border    = Color(0xFF374151);

  // Brand / accent
  static const primary   = Color(0xFF3B82F6);
  static const success   = Color(0xFF10B981);
  static const warning   = Color(0xFFF59E0B);
  static const danger    = Color(0xFFEF4444);
  static const cyan      = Color(0xFF06B6D4);
  static const purple    = Color(0xFF8B5CF6);
  static const orange    = Color(0xFFF97316);

  // Text
  static const textPrimary   = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF9CA3AF);
  static const textMuted     = Color(0xFF6B7280);
}

// ── ThemeData ─────────────────────────────────────────────────────────────────

abstract final class AppTheme {
  static ThemeData get dark => darkWithPrimary(AppColors.primary);

  static ThemeData darkWithPrimary(Color primary) {
    // Local aliases so the body stays concise
    const bg        = AppColors.bg;
    const card      = AppColors.card;
    const inputFill = AppColors.inputFill;
    const navBg     = AppColors.navBg;
    const border    = AppColors.border;
    const danger    = AppColors.danger;
    const cyan      = AppColors.cyan;
    const textPri   = AppColors.textPrimary;
    const textSec   = AppColors.textSecondary;
    const textMut   = AppColors.textMuted;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Roboto',

      scaffoldBackgroundColor: bg,
      canvasColor: card,

      colorScheme: ColorScheme.dark(
        surface:                 bg,
        surfaceContainerHighest: card,
        primary:                 primary,
        onPrimary:               Colors.white,
        secondary:               cyan,
        onSecondary:             Colors.white,
        error:                   danger,
        onError:                 Colors.white,
        onSurface:               textPri,
        onSurfaceVariant:        textSec,
        outline:                 border,
        outlineVariant:          border,
      ),

      textTheme: const TextTheme(
        bodyLarge:   TextStyle(color: textPri),
        bodyMedium:  TextStyle(color: textPri),
        bodySmall:   TextStyle(color: textSec),
        titleLarge:  TextStyle(color: textPri, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: textPri, fontWeight: FontWeight.w600),
        titleSmall:  TextStyle(color: textPri),
        labelLarge:  TextStyle(color: textPri),
        labelMedium: TextStyle(color: textSec),
        labelSmall:  TextStyle(color: textMut),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor:  card,
        foregroundColor:  textPri,
        elevation:        0,
        surfaceTintColor: Colors.transparent,
        iconTheme:        IconThemeData(color: textSec),
        actionsIconTheme: IconThemeData(color: textSec),
        titleTextStyle:   TextStyle(
          color: textPri,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: 'Roboto',
        ),
      ),

      cardTheme: const CardThemeData(
        color:     card,
        elevation: 0,
        margin:    EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: border),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled:     true,
        fillColor:  inputFill,
        labelStyle: const TextStyle(color: textSec),
        hintStyle:  const TextStyle(color: textMut),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: danger),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPri,
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: textSec),
      ),

      dialogTheme: const DialogThemeData(
        backgroundColor:  card,
        surfaceTintColor: Colors.transparent,
        elevation:        0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: border),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: border, thickness: 1, space: 1,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: inputFill,
        contentTextStyle: const TextStyle(color: textPri),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),

      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: navBg,
        selectedIconTheme:   const IconThemeData(color: Colors.white),
        unselectedIconTheme: const IconThemeData(color: textSec),
        selectedLabelTextStyle:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelTextStyle:
            const TextStyle(color: textSec, fontSize: 12),
        indicatorColor: primary.withValues(alpha: 0.15),
        useIndicator:   true,
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? primary : inputFill,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Colors.white : textSec,
          ),
          side: WidgetStateProperty.all(const BorderSide(color: border)),
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 12, fontFamily: 'Roboto'),
          ),
        ),
      ),

      listTileTheme: const ListTileThemeData(
        textColor: textPri,
        iconColor: textSec,
        tileColor: card,
      ),

      iconTheme: const IconThemeData(color: textSec),

      popupMenuTheme: PopupMenuThemeData(
        color: card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: border),
        ),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(color: textPri, fontSize: 13),
        ),
      ),
    );
  }
}
