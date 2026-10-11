import 'package:flutter/material.dart';

class AppColors {
  static const navy = Color(0xFF0D2B6B);
  static const blue = Color(0xFF1976D2);
  static const green = Color(0xFF2E9E5B);
  static const red = Color(0xFFD32F2F);
  static const bg = Color(0xFFF4F7FC);
}

ThemeData buildTheme() {
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c, width: w));
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.blue, primary: AppColors.blue, secondary: AppColors.green),
    scaffoldBackgroundColor: AppColors.bg,
    appBarTheme: const AppBarTheme(backgroundColor: AppColors.navy, foregroundColor: Colors.white, elevation: 0),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.blueGrey.shade50)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border(Colors.blueGrey.shade100),
      enabledBorder: border(Colors.blueGrey.shade100),
      focusedBorder: border(AppColors.blue, 2),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: AppColors.blue.withValues(alpha: 0.12),
    ),
  );
}
