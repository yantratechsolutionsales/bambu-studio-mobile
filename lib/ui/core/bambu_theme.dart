import 'package:material_ui/material_ui.dart';

class BambuColors {
  static const Color green = Color(0xFF00AE42);
  static const Color greenDark = Color(0xFF008A34);
  static const Color greenSoft = Color(0x2600AE42);

  static const Color bgDark = Color(0xFF141618);
  static const Color surfaceDark = Color(0xFF1D2024);
  static const Color surfaceElevated = Color(0xFF262A30);
  static const Color borderDark = Color(0xFF333942);

  static const Color textPrimary = Color(0xFFF1F3F5);
  static const Color textSecondary = Color(0xFF9AA4B2);

  static const Color warning = Color(0xFFFFB300);
  static const Color danger = Color(0xFFEF5350);
  static const Color info = Color(0xFF29B6F6);
}

class BambuTheme {
  static ThemeData darkTheme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: BambuColors.green,
      brightness: Brightness.dark,
      primary: BambuColors.green,
      onPrimary: Colors.white,
      secondary: const Color(0xFF26A69A),
      surface: BambuColors.surfaceDark,
      error: BambuColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: BambuColors.bgDark,
      cardTheme: CardThemeData(
        color: BambuColors.surfaceDark,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: BambuColors.borderDark, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: BambuColors.surfaceDark,
        foregroundColor: BambuColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: BambuColors.surfaceDark,
        indicatorColor: BambuColors.greenSoft,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: BambuColors.green, size: 22);
          }
          return const IconThemeData(color: BambuColors.textSecondary, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: BambuColors.green,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            );
          }
          return const TextStyle(
            color: BambuColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          );
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: BambuColors.surfaceElevated,
        selectedColor: BambuColors.greenSoft,
        side: const BorderSide(color: BambuColors.borderDark),
        labelStyle: const TextStyle(fontSize: 12, color: BambuColors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BambuColors.surfaceElevated,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: BambuColors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: BambuColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: BambuColors.green, width: 1.5),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: BambuColors.green,
        thumbColor: BambuColors.green,
        inactiveTrackColor: BambuColors.borderDark,
      ),
      dividerTheme: const DividerThemeData(
        color: BambuColors.borderDark,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static ThemeData lightTheme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: BambuColors.green,
      brightness: Brightness.light,
      primary: BambuColors.green,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF3F5F7),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFDDE2E8), width: 1),
        ),
      ),
    );
  }
}
