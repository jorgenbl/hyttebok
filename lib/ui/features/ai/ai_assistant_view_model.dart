import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/errors.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/services/ai_client.dart';
import '../../../data/services/secure_key_store.dart';

/// Fase i en AI-kjøring.
enum AiRunState { idle, running, done, error }

/// Felles streaming-motor for AI-funksjonene (strukturforslag,
/// skrivehjelp, rutinelister).
///
/// Bygger klient fra de gjeldende innstillingene, streamer svar-teksten
/// inkrementelt (én [notifyListeners] per chunk) og kan avbrytes til enhver
/// tid. Instanser er en-gangs per dialog: opprett én per dialog/rute.
class AiAssistantViewModel extends ChangeNotifier {
  AiAssistantViewModel(this._settings, this._keyStore, this._clientBuilder);

  final SettingsRepository _settings;
  final SecureKeyStore _keyStore;
  final AiClientBuilder _clientBuilder;

  AiRunState _state = AiRunState.idle;
  String _text = '';
  String _errorMessage = '';
  StreamSubscription<String>? _sub;
  bool _disposed = false;

  AiRunState get state => _state;

  /// Hittil mottatt svar-tekst.
  String get text => _text;
  String get errorMessage => _errorMessage;

  /// Kjører en prompt ([system] + [user]). Eventuelt pågående kjøring
  /// avbrytes først. [model] kan overstyre den konfigurerte modellen.
  Future<void> run({
    required String system,
    required String user,
    String? model,
  }) async {
    _cancelStream();

    final settings = _settings.loadAiSettings();
    if (settings == null) {
      _fail('AI er ikke konfigurert. Åpne Innstillinger → AI.');
      return;
    }
    final apiKey = (await _keyStore.readKey(kAiApiKeyKey)) ?? '';
    if (_disposed) return;
    if (settings.needsApiKey && apiKey.isEmpty) {
      _fail(
        'Ingen API-nøkkel er satt. Skriv den inn under Innstillinger → AI.',
      );
      return;
    }

    _state = AiRunState.running;
    _text = '';
    _errorMessage = '';
    notifyListeners();

    final client = _clientBuilder(settings, apiKey.isEmpty ? null : apiKey);
    _sub = client
        .complete(system: system, user: user, model: model)
        .listen(
          (chunk) {
            _text += chunk;
            notifyListeners();
          },
          onError: (Object e) {
            _sub = null;
            if (_disposed) return;
            _fail(e is AiProviderError ? e.message : 'Uventet feil: $e');
          },
          onDone: () {
            _sub = null;
            if (_disposed) return;
            if (_state == AiRunState.running) {
              _state = AiRunState.done;
              notifyListeners();
            }
          },
        );
  }

  void _fail(String message) {
    _state = AiRunState.error;
    _errorMessage = message;
    notifyListeners();
  }

  /// Avbryter pågående kjøring (hvis noen) og går tilbake til tom tilstand.
  void cancel() {
    _cancelStream();
    if (_state == AiRunState.running && !_disposed) {
      _state = AiRunState.idle;
      _text = '';
      _errorMessage = '';
      notifyListeners();
    }
  }

  void _cancelStream() {
    final sub = _sub;
    _sub = null;
    unawaited(sub?.cancel());
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelStream();
    super.dispose();
  }
}
