import 'package:flutter/material.dart';

/// Håndterer appens temavalg (system / lys / mørk).
///
/// Holdes i minne for sesjonen. Persistering mellom oppstart krever et
/// innstillingslager (f.eks. `shared_preferences`) og er et oppfølgingspunkt.
class ThemePreference extends ChangeNotifier {
  ThemePreference({ThemeMode initial = ThemeMode.system}) : _mode = initial;

  ThemeMode _mode;

  ThemeMode get mode => _mode;

  void setMode(ThemeMode newMode) {
    if (newMode == _mode) return;
    _mode = newMode;
    notifyListeners();
  }
}
