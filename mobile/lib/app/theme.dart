import 'package:flutter/material.dart';

abstract final class QrColors {
  static const background = Color(0xFF171A16);
  static const surface = Color(0xFF222620);
  static const border = Color(0xFF383E34);
  static const accent = Color(0xFFF2FF00);
  static const muted = Color(0xFFB4BAAD);
  static const error = Color(0xFFFFB4AB);
}

ThemeData buildQrTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: const ColorScheme.dark(
    primary: QrColors.accent, onPrimary: QrColors.background,
    surface: QrColors.surface, onSurface: Color(0xFFF5F7F1),
    error: QrColors.error,
  ),
  scaffoldBackgroundColor: QrColors.background,
  appBarTheme: const AppBarTheme(
    backgroundColor: QrColors.background, surfaceTintColor: Colors.transparent),
  inputDecorationTheme: InputDecorationTheme(
    filled: true, fillColor: QrColors.surface,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: QrColors.border)),
  ),
  filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
    minimumSize: const Size.fromHeight(54),
    textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
  outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
    minimumSize: const Size.fromHeight(52),
    side: const BorderSide(color: QrColors.border))),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: QrColors.background, indicatorColor: QrColors.accent,
    iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
      color: states.contains(WidgetState.selected)
        ? QrColors.background : QrColors.muted)),
    labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11)),
  ),
);
