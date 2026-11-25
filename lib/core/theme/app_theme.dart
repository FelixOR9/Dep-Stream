import 'package:flutter/material.dart';

/// Identidad visual propia de Dep-Stream (Etapa 0).
///
/// Fondo oscuro deportivo. No copia los colores de StreamMySport ni los de
/// TRANSMITI2: azul noche propio, verde de cancha y ámbar de acento.
class AppTheme {
  static const Color background = Color(0xFF0E1B2E);
  static const Color surface = Color(0xFF1A2A3D);
  static const Color primary = Color(0xFF22A06B);
  static const Color accent = Color(0xFFFFB020);
  static const Color textPrimary = Color(0xFFF2F5F7);
  static const Color textSecondary = Color(0xFFA8B8C8);

  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: surface,
        onPrimary: Colors.white,
        onSurface: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontSize: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: textPrimary),
        bodyLarge: TextStyle(color: textPrimary),
        titleLarge: TextStyle(color: textPrimary),
        titleMedium: TextStyle(color: textPrimary),
        bodySmall: TextStyle(color: textSecondary),
      ),
    );
  }
}
