import 'dart:convert';

import '../services/ai_settings.dart';
import '../services/text_key_value_store.dart';

/// Persisterer appens ikke-sensitve innstillinger som JSON (app-mappen på
/// mobil, `localStorage` på web – se [TextKeyValueStore]-implementasjonene).
///
/// API-nøkler ligger KUN i [SecureKeyStore], aldri her.
class SettingsRepository {
  SettingsRepository(this._store);

  final TextKeyValueStore _store;

  /// Laster AI-innstillinger, eller `null` om ikke konfigurert.
  ///
  /// Korrupt fil behandles som «ikke konfigurert» (ikke feil) – innstillinger
  /// skal aldri blokkere appen.
  AiSettings? loadAiSettings() {
    final raw = _store.load();
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, Object?>) {
        final ai = decoded['ai'];
        if (ai is Map<String, Object?>) {
          return AiSettings.fromJson(ai);
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<void> saveAiSettings(AiSettings settings) async {
    final json = {'ai': settings.toJson()};
    await _store.save(const JsonEncoder.withIndent('  ').convert(json));
  }

  /// Om velkomst-opplæringen allerede er vist. `false` om ingenting er
  /// lagret eller filen er korrupt.
  bool hasSeenOnboarding() {
    final decoded = _readAll();
    return decoded?['onboardingShown'] == true;
  }

  /// Markerer velkomst-opplæringen som vist (beholder øvrige innstillinger).
  Future<void> markOnboardingSeen() async {
    final all = _readAll() ?? <String, Object?>{};
    all['onboardingShown'] = true;
    await _store.save(const JsonEncoder.withIndent('  ').convert(all));
  }

  /// Leser hele innstillingsdokumentet, eller `null` om tom/korrupt.
  Map<String, Object?>? _readAll() {
    final raw = _store.load();
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, Object?>) return decoded;
    } catch (_) {
      // Korrupt fil behandles som «ikke lagret».
    }
    return null;
  }
}
