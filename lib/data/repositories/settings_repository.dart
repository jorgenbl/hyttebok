import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../services/ai_settings.dart';

/// Persisterer appens ikke-sensitve innstillinger som JSON i app-mappen.
///
/// API-nøkler ligger KUN i [SecureKeyStore], aldri her.
class SettingsRepository {
  SettingsRepository(Directory baseDirectory)
    : _file = File(p.join(baseDirectory.path, 'settings.json'));

  final File _file;

  /// Laster AI-innstillinger, eller `null` om ikke konfigurert.
  ///
  /// Korrupt fil behandles som «ikke konfigurert» (ikke feil) – innstillinger
  /// skal aldri blokkere appen.
  AiSettings? loadAiSettings() {
    if (!_file.existsSync()) return null;
    try {
      final decoded = jsonDecode(_file.readAsStringSync());
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
    await _file.parent.create(recursive: true);
    final json = {'ai': settings.toJson()};
    await _file.writeAsString(const JsonEncoder.withIndent('  ').convert(json));
  }
}
