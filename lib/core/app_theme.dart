import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const bodyFont = 'Inter';
  static const displayFont = 'SpaceGrotesk';
  static const fontFallback = [
    'NotoSansDevanagari',
    'Noto Color Emoji',
    'Apple Color Emoji',
  ];
  static const primary = Color(0xFFED405A);
  static const foreground = Color(0xFF1D2025);
  static const muted = Color(0xFFF4F4F5);
  static const mutedForeground = Color(0xFF6B7280);
  static const border = Color(0xFFE4E4E7);
  static const destructive = Color(0xFFEF4444);
  static const heroDark = Color(0xFF1A212D);
  static const heroGradientEnd = Color(0xFF1D283A);
  static const radius = 12.0;

  static final light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: bodyFont,
    fontFamilyFallback: fontFallback,
    colorScheme: const ColorScheme.light(
      primary: primary,
      onPrimary: Colors.white,
      secondary: muted,
      onSecondary: foreground,
      error: destructive,
      onError: Colors.white,
      surface: Colors.white,
      onSurface: foreground,
      surfaceContainerHighest: muted,
      onSurfaceVariant: mutedForeground,
      outline: border,
      outlineVariant: border,
    ),
    scaffoldBackgroundColor: Colors.white,
    dividerColor: border,
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xD9FFF1F3),
      foregroundColor: foreground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 3,
      shadowColor: Color(0x241D2025),
      centerTitle: false,
      toolbarHeight: 60,
      shape: Border(bottom: BorderSide(color: Color(0x40ED405A))),
      iconTheme: IconThemeData(color: foreground, size: 22),
      actionsIconTheme: IconThemeData(color: foreground, size: 22),
      titleTextStyle: TextStyle(
        color: foreground,
        fontFamily: displayFont,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 64,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: primary.withValues(alpha: 0.14),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? primary
              : mutedForeground,
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? primary
              : mutedForeground,
          size: 23,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: const BorderSide(color: border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius - 2),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius - 2),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius - 2),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: muted,
      selectedColor: primary,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: primary,
      unselectedLabelColor: mutedForeground,
      indicatorColor: primary,
      dividerColor: border,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        color: foreground,
        fontFamily: displayFont,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: TextStyle(
        color: foreground,
        fontFamily: displayFont,
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: TextStyle(
        color: foreground,
        fontFamily: displayFont,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: TextStyle(
        color: foreground,
        fontFamily: displayFont,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: TextStyle(
        color: foreground,
        fontFamily: displayFont,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: TextStyle(
        color: foreground,
        fontFamily: displayFont,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(color: foreground),
      bodyMedium: TextStyle(color: foreground),
      bodySmall: TextStyle(color: mutedForeground),
    ),
  );
}
