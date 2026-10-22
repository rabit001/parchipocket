import 'package:flutter/material.dart';

class PpColors {
  static const Color forest = Color(0xFF126344);
  static const Color forestLight = Color(0xFF1C7854);
  static const Color page = Color(0xFFF6F9F3);
  static const Color card = Colors.white;
  static const Color soft = Color(0xFFDEEFE3);
  static const Color ink = Color(0xFF131F17);
  static const Color secondary = Color(0xFF616F64);
  static const Color border = Color(0xFFDBE3DC);
  static const Color error = Color(0xFFB2332B);
  static const Color errorSoft = Color(0xFFFFEDEC);
  static const Color warning = Color(0xFFFAC85B);
}

ThemeData buildPpTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: PpColors.forest, brightness: Brightness.light).copyWith(
    primary: PpColors.forest,
    onPrimary: Colors.white,
    surface: PpColors.card,
    onSurface: PpColors.ink,
    error: PpColors.error,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: PpColors.page,
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: PpColors.page,
      foregroundColor: PpColors.ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: PpColors.ink),
    ),
    cardTheme: CardThemeData(
      color: PpColors.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: PpColors.border)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      hintStyle: const TextStyle(color: PpColors.secondary, fontSize: 13),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: PpColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: PpColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: PpColors.forest, width: 1.5)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(46),
        backgroundColor: PpColors.forest,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        foregroundColor: PpColors.ink,
        side: const BorderSide(color: PpColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),
    dividerTheme: const DividerThemeData(color: PpColors.border, thickness: 1, space: 1),
  );
}
