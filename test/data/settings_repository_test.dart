import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hyttebok/data/repositories/settings_repository.dart';
import 'package:hyttebok/data/services/ai_settings.dart';
import 'package:hyttebok/data/services/file_text_key_value_store.dart';

void main() {
  late Directory tempDir;
  late SettingsRepository repo;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('hyttebok-settings-');
    repo = SettingsRepository(FileTextKeyValueStore(tempDir));
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('loadAiSettings returner null når fil mangler', () {
    expect(repo.loadAiSettings(), isNull);
  });

  test('round-trip: lagre og laste AI-innstillinger', () async {
    const settings = AiSettings(
      type: AiProviderType.openai,
      baseUrl: 'https://api.openai.com/v1',
      model: 'gpt-4o-mini',
      systemPrompt: 'Mitt prompt',
      maxTokens: 1024,
      temperature: 0.5,
    );
    await repo.saveAiSettings(settings);
    final loaded = repo.loadAiSettings();
    expect(loaded, isNotNull);
    expect(loaded, settings);
  });

  test('filen legges som settings.json i baseDirectory', () async {
    await repo.saveAiSettings(
      const AiSettings(
        type: AiProviderType.ollama,
        baseUrl: 'http://localhost:11434/v1',
        model: 'llama3.1',
      ),
    );
    expect(File('${tempDir.path}/settings.json').existsSync(), isTrue);
  });

  test('ødelagt JSON behandles som «ikke konfigurert»', () {
    File('${tempDir.path}/settings.json').writeAsStringSync('{ikke-json');
    expect(repo.loadAiSettings(), isNull);
  });

  test('feilantyd topptype (ikkje Map) behandles som «ikke konfigurert»', () {
    File('${tempDir.path}/settings.json').writeAsStringSync('[1, 2, 3]');
    expect(repo.loadAiSettings(), isNull);
  });

  test('ukjente felter i «ai»-objektet ignoreres', () async {
    File('${tempDir.path}/settings.json').writeAsStringSync('''
{"ai": {"type": "ollama", "baseUrl": "http://localhost:11434/v1", "model": "llama3.1", "noeNytt": true}}
''');
    final loaded = repo.loadAiSettings();
    expect(loaded, isNotNull);
    expect(loaded!.type, AiProviderType.ollama);
  });
}
