import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get darkFantasy {
    const parchment = Color(0xFFE2C58F);
    const gold = Color(0xFFD6B36A);
    const ink = Color(0xFF0B0D10);
    const panel = Color(0xFF151A20);
    const panel2 = Color(0xFF1B2128);

    final scheme = ColorScheme.fromSeed(
      seedColor: gold,
      brightness: Brightness.dark,
      primary: gold,
      secondary: parchment,
      surface: panel,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: ink,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0F1318),
        foregroundColor: parchment,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: panel2,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0x33D6B36A)),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF0F1318),
        selectedItemColor: gold,
        unselectedItemColor: Color(0xFF7E868E),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: panel,
        contentTextStyle: const TextStyle(color: parchment),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: panel2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0x33D6B36A)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0x33D6B36A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: gold),
        ),
      ),
    );
  }
}
