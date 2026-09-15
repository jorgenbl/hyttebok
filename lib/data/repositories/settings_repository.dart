import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../services/ai_settings.dart';
import '../services/text_key_value_store.dart';

/// Persisterer appens ikke-sensitve innstillinger som JSON (app-mappen på
/// mobil, `localStorage` på web – se [TextKeyValueStore]-implementasjonene).
///
/// API-nøkler ligger KUN i [SecureKeyStore], aldri her.
///
/// Arver [ChangeNotifier] slik at UI som viser innstillinger (f.eks.
/// oversikten over AI-profiler) kan oppdatere seg når en skrive-operasjon
/// fullfører – også når skriften skjer fra en annen rute.
class SettingsRepository extends ChangeNotifier {
  SettingsRepository(this._store);

  final TextKeyValueStore _store;

  /// Laster standard-AI-profilen, eller `null` om ikke konfigurert.
  ///
  /// Korrupt fil behandles som «ikke konfigurert» (ikke feil) – innstillinger
  /// skal aldri blokkere appen.
  AiSettings? loadAiSettings() {
    final ai = _readAll()?['ai'];
    if (ai is Map<String, Object?>) {
      return AiSettings.fromJson(ai);
    }
    return null;
  }

  /// Standardprofilen lagres under «ai»-nøkkelen (les-juster-skriv, så
  /// øvrige innstillinger beholdes).
  Future<void> saveAiSettings(AiSettings settings) async {
    final all = _readAll() ?? <String, Object?>{};
    all['ai'] = settings.toJson();
    await _saveAll(all);
  }

  /// Laster AI-profilen for [purpose].
  ///
  /// [AiPurpose.standard] leser «ai»-nøkkelen; øvrige formål leser
  /// `aiProfiles.<purpose>`. Returnerer `null` om ingen egen profil er satt –
  /// kalleren faller da tilbake til standardprofilen.
  AiSettings? loadAiProfile(AiPurpose purpose) {
    if (purpose == AiPurpose.standard) return loadAiSettings();
    final profiles = _readAll()?['aiProfiles'];
    if (profiles is Map<String, Object?>) {
      final own = profiles[purpose.name];
      if (own is Map<String, Object?>) {
        return AiSettings.fromJson(own);
      }
    }
    return null;
  }

  /// Lagrer AI-profilen for [purpose] (les-juster-skriv).
  Future<void> saveAiProfile(AiPurpose purpose, AiSettings settings) async {
    final all = _readAll() ?? <String, Object?>{};
    if (purpose == AiPurpose.standard) {
      all['ai'] = settings.toJson();
    } else {
      final existing = all['aiProfiles'];
      final profiles = existing is Map<String, Object?>
          ? Map<String, Object?>.from(existing)
          : <String, Object?>{};
      profiles[purpose.name] = settings.toJson();
      all['aiProfiles'] = profiles;
    }
    await _saveAll(all);
  }

  /// Fjerner egen profil for [purpose] slik at formålet bruker
  /// standardprofilen igjen. Gjør ingenting for [AiPurpose.standard] eller om
  /// ingen egen profil finnes.
  Future<void> deleteAiProfile(AiPurpose purpose) async {
    if (purpose == AiPurpose.standard) return;
    final all = _readAll();
    final profiles = all?['aiProfiles'];
    if (profiles is! Map<String, Object?> ||
        !profiles.containsKey(purpose.name)) {
      return;
    }
    final rest = Map<String, Object?>.from(profiles)..remove(purpose.name);
    final updated = Map<String, Object?>.from(all!);
    if (rest.isEmpty) {
      updated.remove('aiProfiles');
    } else {
      updated['aiProfiles'] = rest;
    }
    await _saveAll(updated);
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
    await _saveAll(all);
  }

  /// Skriver hele innstillingsdokumentet som formatert JSON og varsler
  /// interessenter (UI som viser innstillingene).
  Future<void> _saveAll(Map<String, Object?> all) async {
    await _store.save(const JsonEncoder.withIndent('  ').convert(all));
    notifyListeners();
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
