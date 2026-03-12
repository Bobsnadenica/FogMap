import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get darkFantasy {
    const parchment = Color(0xFFE7D3A7);
    const gold = Color(0xFFD6B36A);
    const brass = Color(0xFF9E6A2A);
    const ink = Color(0xFF0B0D10);
    const shadow = Color(0xFF07080A);
    const panel = Color(0xFF151A20);
    const panel2 = Color(0xFF1B2128);
    const muted = Color(0xFF9EA5AC);

    final scheme = ColorScheme.fromSeed(
      seedColor: gold,
      brightness: Brightness.dark,
      primary: gold,
      secondary: parchment,
      surface: panel,
    );

    final baseText = ThemeData.dark().textTheme.apply(
          bodyColor: const Color(0xFFF1ECE2),
          displayColor: parchment,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: ink,
      canvasColor: shadow,
      dividerColor: const Color(0x26D6B36A),
      textTheme: baseText.copyWith(
        headlineSmall: baseText.headlineSmall?.copyWith(
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
        titleLarge: baseText.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
        titleMedium: baseText.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        bodySmall: baseText.bodySmall?.copyWith(
          color: const Color(0xFFBCA587),
          height: 1.35,
        ),
        labelLarge: baseText.labelLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0F1318),
        foregroundColor: parchment,
        centerTitle: true,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: parchment,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
      cardTheme: CardThemeData(
        color: panel2,
        elevation: 1,
        shadowColor: shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0x33D6B36A)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: panel2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0x33D6B36A)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF0F1318),
        indicatorColor: const Color(0x26D6B36A),
        elevation: 0,
        height: 72,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? gold : muted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected) ? parchment : muted,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w500,
            letterSpacing: states.contains(WidgetState.selected) ? 0.4 : 0,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: panel,
        contentTextStyle: const TextStyle(color: parchment),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: gold,
        linearMinHeight: 8,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: ink,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: parchment,
          side: const BorderSide(color: Color(0x55D6B36A)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: parchment,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: gold,
        foregroundColor: ink,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? ink : parchment,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? gold
                : const Color(0xFF20170F),
          ),
          side: WidgetStateProperty.all(
            const BorderSide(color: Color(0x55D6B36A)),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: panel2,
        labelStyle: const TextStyle(color: muted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
      listTileTheme: const ListTileThemeData(
        iconColor: parchment,
        textColor: parchment,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: brass.withValues(alpha: 0.14),
        side: const BorderSide(color: Color(0x33D6B36A)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        labelStyle: const TextStyle(
          color: parchment,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
