import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/errors.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/services/ai_client.dart';
import '../../../data/services/ai_settings.dart';
import '../../../data/services/secure_key_store.dart';

/// Status for «Test tilkobling».
enum AiTestState { idle, running, success, failure }

/// Tilstand og kommandoer for AI-innstillingene.
///
/// Hver endring lagres automatisk: ikke-sensitivt til [SettingsRepository],
/// API-nøkkelen til [SecureKeyStore]. Lagringer serieres slik at raske
/// tastetrykk ikke konkurrerer om filen.
///
/// [purpose] bestemmer hvilken profil som redigeres: [AiPurpose.standard]
/// redigerer «ai»-nøkkelen, øvrige formål redigerer sin egen profil
/// (`aiProfiles.<purpose>` + egen nøkkelslot).
class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel(
    this._repo,
    this._keyStore,
    this._clientBuilder, {
    this.purpose = AiPurpose.standard,
  }) {
    _settings = _repo.loadAiProfile(purpose);
  }

  final SettingsRepository _repo;
  final SecureKeyStore _keyStore;
  final AiClientBuilder _clientBuilder;
  final AiPurpose purpose;

  /// API-nøkkel-slotten for den redigerede profilen.
  String get _keySlot => aiApiKeyKeyFor(purpose);

  AiSettings? _settings;
  String _apiKey = '';
  bool _loaded = false;

  AiTestState _testState = AiTestState.idle;
  String _testMessage = '';

  Future<void> _persistChain = Future.value();

  AiSettings? get settings => _settings;
  String get apiKey => _apiKey;
  bool get loaded => _loaded;
  AiTestState get testState => _testState;
  String get testMessage => _testMessage;

  /// Laster API-nøkkel fra sikker lagring. Innstillinger er allerede lest i
  /// konstruktoren.
  Future<void> load() async {
    _apiKey = await _keyStore.readKey(_keySlot) ?? '';
    _loaded = true;
    notifyListeners();
  }

  void _apply(AiSettings next) {
    _settings = next;
    notifyListeners();
    _schedulePersist();
  }

  void setApiKey(String value) {
    _apiKey = value;
    notifyListeners();
    _schedulePersist();
  }

  /// Bytter leverandør og setter base-URL/modell til standardverdiene for
  /// den nye leverandøren (nøkkelen beholdes).
  void setType(AiProviderType type) {
    _apply(
      AiSettings(
        type: type,
        baseUrl: AiSettings.defaultBaseUrlFor(type),
        model: AiSettings.defaultModelFor(type),
        systemPrompt: _settings?.systemPrompt ?? kDefaultAiSystemPrompt,
        maxTokens: _settings?.maxTokens ?? 2048,
        temperature: _settings?.temperature ?? 0.7,
      ),
    );
  }

  void setBaseUrl(String value) => _apply(_current().copyWith(baseUrl: value));
  void setModel(String value) => _apply(_current().copyWith(model: value));
  void setSystemPrompt(String value) =>
      _apply(_current().copyWith(systemPrompt: value));
  void setMaxTokens(int value) => _apply(_current().copyWith(maxTokens: value));
  void setTemperature(double value) =>
      _apply(_current().copyWith(temperature: value));

  AiSettings _current() {
    final s = _settings;
    assert(s != null, 'settings må være satt før kommandoer kan kjøres');
    return s!;
  }

  /// «Test tilkobling»: miniforespørring mot den konfigurerte leverandøren.
  Future<void> testConnection() async {
    final s = _settings;
    if (s == null) return;
    _testState = AiTestState.running;
    _testMessage = '';
    notifyListeners();
    try {
      final apiKey = _apiKey.isEmpty ? null : _apiKey;
      final client = _clientBuilder(s, apiKey);
      await client.ping();
      _testState = AiTestState.success;
      _testMessage = 'Tilkoblet – alt fungerer.';
    } on AiProviderError catch (e) {
      _testState = AiTestState.failure;
      final detail = e.cause is String ? (e.cause as String).trim() : '';
      // Leverandørens egen melding (f.eks. «temperature er ikke støttet»)
      // gjør feilen mulig å diagnosticere.
      _testMessage = detail.isEmpty
          ? e.message
          : '${e.message}\nLeverandøren: $detail';
    } catch (e) {
      _testState = AiTestState.failure;
      _testMessage = 'Uventet feil: $e';
    }
    notifyListeners();
  }

  /// Serierer persistering av innstillinger + nøkkel (i profilen sin slot).
  void _schedulePersist() {
    if (_disposed) return;
    final current = _settings;
    final key = _apiKey;
    final slot = _keySlot;
    _persistChain = _persistChain
        .then((_) async {
          if (current != null) {
            await _repo.saveAiProfile(purpose, current);
          }
          if (key.isEmpty) {
            await _keyStore.deleteKey(slot);
          } else {
            await _keyStore.writeKey(slot, key);
          }
        })
        .catchError((Object _) {
          // Feil ved lagring av innstillinger skal ikke knuse UI-et.
        });
  }

  /// Fjerner formålets egen profil og API-nøkkel slik at det igjen bruker
  /// standardprofilen. Gjør ingenting for standardprofilen.
  Future<void> deleteOwnProfile() async {
    if (purpose == AiPurpose.standard) return;
    await _repo.deleteAiProfile(purpose);
    await _keyStore.deleteKey(_keySlot);
    _settings = null;
    _apiKey = '';
    _testState = AiTestState.idle;
    _testMessage = '';
    notifyListeners();
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
