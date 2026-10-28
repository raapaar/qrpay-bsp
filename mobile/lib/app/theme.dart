import 'package:flutter/material.dart';

abstract final class QrColors {
  static const background = Color(0xFF161D28);
  static const surface = Color(0xFF212E3E);
  static const border = Color(0xFF354459);
  static const accent = Color(0xFFDFE94B);
  static const blue = Color(0xFF4C66EE);
  static const muted = Color(0xFFAFBCCB);
  static const error = Color(0xFFFFB4AB);
}

ThemeData buildQrTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  fontFamily: 'DMSans',
  colorScheme: const ColorScheme.dark(
    primary: QrColors.accent,
    onPrimary: QrColors.background,
    secondary: QrColors.blue,
    surface: QrColors.surface,
    error: QrColors.error,
  ),
  scaffoldBackgroundColor: QrColors.background,
  appBarTheme: const AppBarTheme(
    backgroundColor: QrColors.background,
    surfaceTintColor: Colors.transparent,
    centerTitle: true,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: QrColors.surface,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: QrColors.border),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      textStyle: const TextStyle(
        fontFamily: 'DMSans',
        fontWeight: FontWeight.w700,
        fontSize: 15,
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(50),
      side: const BorderSide(color: QrColors.border),
    ),
  ),
);
