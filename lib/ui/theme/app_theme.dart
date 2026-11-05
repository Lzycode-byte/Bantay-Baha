import 'package:flutter/material.dart';

class AppTheme {
  static const Color brandBlue = Color(0xFF155EEF);
  static const Color deepNavy = Color(0xFF172B4D);
  static const Color warningAmber = Color(0xFFE6A100);
  static const Color danger = Color(0xFFD92D20);
  static const Color success = Color(0xFF138A57);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: brandBlue,
      brightness: Brightness.light,
      primary: brandBlue,
      surface: Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF6F8FB),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF6F8FB),
        foregroundColor: deepNavy,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      textTheme: Typography.material2021().black.apply(
        bodyColor: deepNavy,
        displayColor: deepNavy,
      ),
    );
  }

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: brandBlue,
      brightness: Brightness.dark,
      surface: const Color(0xFF101828),
    ),
    scaffoldBackgroundColor: const Color(0xFF0B1220),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF101828),
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF101828),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    textTheme: Typography.material2021().white.apply(
      bodyColor: const Color(0xFFE4E7EC),
      displayColor: Colors.white,
    ),
  );
}
