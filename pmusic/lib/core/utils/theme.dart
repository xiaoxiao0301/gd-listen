import 'package:flutter/material.dart';

/// Warm-tone color palette for the entire app.
class WarmColors {
  WarmColors._();

  static const primary         = Color(0xFFE2A05B);
  static const primaryLight    = Color(0xFFEEC08A);
  static const primaryDark     = Color(0xFFC67D35);
  static const background      = Color(0xFFFFFDF7);
  static const surface         = Color(0xFFFFF8E7);
  static const textPrimary     = Color(0xFF3E2723);
  static const textSecondary   = Color(0xFF795548);
  static const accent          = Color(0xFFE57373); // favorite / delete
  static const divider         = Color(0xFFF0E6D3);
  static const playerGradStart = Color(0xFF5D3A1A); // full-player bg gradient
}

/// Builds the global [ThemeData] for Mobile.
ThemeData buildMobileTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: WarmColors.primary,
      onPrimary: Colors.white,
      secondary: WarmColors.primaryDark,
      surface: WarmColors.surface,
      onSurface: WarmColors.textPrimary,
      error: WarmColors.accent,
    ),
    scaffoldBackgroundColor: WarmColors.background,
    dividerColor: WarmColors.divider,
    // ── AppBar ──────────────────────────────────────────────────────────────
    appBarTheme: const AppBarTheme(
      backgroundColor: WarmColors.background,
      foregroundColor: WarmColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        color: WarmColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    // ── Card ────────────────────────────────────────────────────────────────
    cardTheme: CardThemeData(
      color: WarmColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 0,
      shadowColor: WarmColors.primary.withValues(alpha: 0.12),
    ),
    // ── Input / Search bar ──────────────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: WarmColors.surface,
      hintStyle: const TextStyle(color: WarmColors.textSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: WarmColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    ),
    // ── Slider (progress bar) ───────────────────────────────────────────────
    sliderTheme: const SliderThemeData(
      activeTrackColor: WarmColors.primary,
      inactiveTrackColor: WarmColors.divider,
      thumbColor: WarmColors.primary,
      overlayColor: Color(0x33E2A05B),
      trackHeight: 4,
    ),
    // ── BottomNavigationBar ─────────────────────────────────────────────────
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: WarmColors.background,
      selectedItemColor: WarmColors.primary,
      unselectedItemColor: WarmColors.textSecondary,
      elevation: 8,
      type: BottomNavigationBarType.fixed,
    ),
    // ── Chip (search history tags) ──────────────────────────────────────────
    chipTheme: ChipThemeData(
      backgroundColor: WarmColors.primary.withValues(alpha: 0.12),
      labelStyle: const TextStyle(
        color: WarmColors.primary,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      shape: const StadiumBorder(),
      side: BorderSide.none,
    ),
    // ── FilledButton (primary CTAs) ─────────────────────────────────────────
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: WarmColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    // ── OutlinedButton ──────────────────────────────────────────────────────
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: WarmColors.primary,
        side: const BorderSide(color: WarmColors.primary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
  );
}

/// Builds a TV-scaled variant of the warm theme (1.5× font sizes).
///
/// `TextTheme.apply(fontSizeFactor:)` crashes when any style has a null
/// `fontSize` (the Flutter default). We copy each style individually so
/// only non-null sizes are scaled.
ThemeData buildTvTheme() {
  final base = buildMobileTheme();

  TextStyle scale(TextStyle? s) {
    if (s == null) return const TextStyle(color: WarmColors.textPrimary);
    return s.copyWith(
      fontSize: s.fontSize != null ? s.fontSize! * 1.5 : null,
      color: s.color ?? WarmColors.textPrimary,
    );
  }

  final tt = base.textTheme;
  return base.copyWith(
    textTheme: TextTheme(
      displayLarge: scale(tt.displayLarge),
      displayMedium: scale(tt.displayMedium),
      displaySmall: scale(tt.displaySmall),
      headlineLarge: scale(tt.headlineLarge),
      headlineMedium: scale(tt.headlineMedium),
      headlineSmall: scale(tt.headlineSmall),
      titleLarge: scale(tt.titleLarge),
      titleMedium: scale(tt.titleMedium),
      titleSmall: scale(tt.titleSmall),
      bodyLarge: scale(tt.bodyLarge),
      bodyMedium: scale(tt.bodyMedium),
      bodySmall: scale(tt.bodySmall),
      labelLarge: scale(tt.labelLarge),
      labelMedium: scale(tt.labelMedium),
      labelSmall: scale(tt.labelSmall),
    ),
  );
}
