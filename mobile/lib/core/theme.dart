import 'package:flutter/material.dart';
import 'api_client.dart';

class AppColors {
  static const navy = Color(0xFF0B2E6B);
  static const blue = Color(0xFF00A3E0);
  static const green = Color(0xFF4CAF50);
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
      elevation: 8,
      height: 68,
      indicatorColor: AppColors.blue.withValues(alpha: 0.16),
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide(color: Colors.blueGrey.shade100),
      selectedColor: AppColors.blue.withValues(alpha: 0.18),
      backgroundColor: Colors.white,
    ),
  );
}

/// Modo claro / oscuro de toda la app. Se recuerda entre sesiones (clave 'pref_dark').
class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final instance = ThemeController._();
  ThemeMode mode = ThemeMode.light;

  Future<void> load() async {
    try {
      mode = (await ApiClient().readPref('pref_dark')) == '1' ? ThemeMode.dark : ThemeMode.light;
    } catch (_) {}
  }

  Future<void> toggle() async {
    mode = mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    try {
      await ApiClient().savePref('pref_dark', mode == ThemeMode.dark ? '1' : '0');
    } catch (_) {}
  }
}

/// Colores que cambian según el tema (dependen del contexto, así se redibujan al cambiar).
extension ThemeColors on BuildContext {
  bool get dark => Theme.of(this).brightness == Brightness.dark;
  Color get ink => dark ? const Color(0xFFE8EEFB) : AppColors.navy; // títulos
  Color get muted => dark ? const Color(0xFF9FB0CC) : Colors.blueGrey.shade500; // texto secundario
  Color get surface => dark ? const Color(0xFF16233A) : Colors.white; // tarjetas
  Color get line => dark ? const Color(0xFF263754) : Colors.blueGrey.shade50; // bordes suaves
}

ThemeData buildDarkTheme() {
  const bg = Color(0xFF0B1220), card = Color(0xFF16233A), field = Color(0xFF1B2A44), edge = Color(0xFF2A3B5C);
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c, width: w));
  final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.blue, primary: AppColors.blue, secondary: AppColors.green, brightness: Brightness.dark);
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme.copyWith(surface: card),
    scaffoldBackgroundColor: bg,
    appBarTheme: const AppBarTheme(backgroundColor: AppColors.navy, foregroundColor: Colors.white, elevation: 0),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: edge)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: field,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border(edge),
      enabledBorder: border(edge),
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
      backgroundColor: const Color(0xFF101B30),
      elevation: 8,
      height: 68,
      indicatorColor: AppColors.blue.withValues(alpha: 0.28),
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: const BorderSide(color: edge),
      selectedColor: AppColors.blue.withValues(alpha: 0.30),
      backgroundColor: card,
    ),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: card),
    dialogTheme: DialogThemeData(backgroundColor: card),
  );
}
