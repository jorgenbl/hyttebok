import 'package:flutter/material.dart';

/// Fellese tema for Hyttebok (Material 3, "hyttegrønn" seed).
class AppTheme {
  AppTheme._();

  static const Color seed = Color(0xFF4E6E4E);

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
    );
  }
}
