import 'package:flutter/material.dart';

// ─── Palette ────────────────────────────────────────────────────────────────
// Deep space dark UI, electric violet as the primary accent,
// amber as the discovery/unlock signal color.
// Inspired by satellite imagery at night — city grids glowing.
class RMColors {
  RMColors._();

  static const background = Color(0xFF0A0A0F);    // near-black with blue cast
  static const surface    = Color(0xFF13131A);    // card surfaces
  static const surfaceAlt = Color(0xFF1C1C27);    // elevated surfaces
  static const border     = Color(0xFF2A2A3A);    // subtle borders

  static const primary    = Color(0xFF7B61FF);    // electric violet
  static const primaryDim = Color(0xFF3D2FA0);    // dimmed violet for bg
  static const accent     = Color(0xFFFFB830);    // amber — unlock signal
  static const danger     = Color(0xFFFF4D6D);    // errors
  static const success    = Color(0xFF00E5A0);    // unlocked state

  static const textPrimary   = Color(0xFFF0F0F8);
  static const textSecondary = Color(0xFF8888A8);
  static const textHint      = Color(0xFF44445A);
}

// ─── Theme ──────────────────────────────────────────────────────────────────
class RMTheme {
  RMTheme._();

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: RMColors.background,
    colorScheme: const ColorScheme.dark(
      surface: RMColors.surface,
      primary: RMColors.primary,
      secondary: RMColors.accent,
      error: RMColors.danger,
      onSurface: RMColors.textPrimary,
      onPrimary: Colors.white,
      outline: RMColors.border,
    ),
    cardTheme: CardThemeData(
      color: RMColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: RMColors.border, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: RMColors.background,
      foregroundColor: RMColors.textPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: RMColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: RMColors.surface,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: RMColors.surface,
      indicatorColor: RMColors.primaryDim,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 11, color: RMColors.textSecondary),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: RMColors.surfaceAlt,
      labelStyle: const TextStyle(color: RMColors.textSecondary),
      hintStyle: const TextStyle(color: RMColors.textHint),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: RMColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: RMColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: RMColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: RMColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: RMColors.primary,
        side: const BorderSide(color: RMColors.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        minimumSize: const Size(0, 48),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: RMColors.surfaceAlt,
      selectedColor: RMColors.primaryDim,
      labelStyle: const TextStyle(color: RMColors.textPrimary, fontSize: 13),
      side: const BorderSide(color: RMColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    textTheme: const TextTheme(
      displayMedium: TextStyle(
        color: RMColors.textPrimary,
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.0,
      ),
      headlineMedium: TextStyle(
        color: RMColors.textPrimary,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      titleLarge: TextStyle(
        color: RMColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleMedium: TextStyle(
        color: RMColors.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(
        color: RMColors.textPrimary,
        fontSize: 15,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        color: RMColors.textSecondary,
        fontSize: 13,
        height: 1.4,
      ),
      bodySmall: TextStyle(
        color: RMColors.textSecondary,
        fontSize: 11,
        letterSpacing: 0.2,
      ),
      labelSmall: TextStyle(
        color: RMColors.textHint,
        fontSize: 10,
        letterSpacing: 0.5,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}
