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

  test('saveAiSettings beholder øvrige nøkkel (onboardingShown)', () async {
    await repo.markOnboardingSeen();
    await repo.saveAiSettings(
      const AiSettings(
        type: AiProviderType.ollama,
        baseUrl: 'http://localhost:11434/v1',
        model: 'llama3.1',
      ),
    );
    expect(repo.hasSeenOnboarding(), isTrue);
    expect(repo.loadAiSettings(), isNotNull);
  });

  group('AI-profiler per formål', () {
    const standard = AiSettings(
      type: AiProviderType.openai,
      baseUrl: 'https://api.openai.com/v1',
      model: 'gpt-4o-mini',
    );
    const writingOwn = AiSettings(
      type: AiProviderType.ollama,
      baseUrl: 'http://localhost:11434/v1',
      model: 'llama3.1',
    );

    test('round-trip: lagre og laste egen profil', () async {
      await repo.saveAiProfile(AiPurpose.writing, writingOwn);
      expect(repo.loadAiProfile(AiPurpose.writing), writingOwn);
    });

    test('loadAiProfile(standard) er lik loadAiSettings', () async {
      await repo.saveAiSettings(standard);
      expect(repo.loadAiProfile(AiPurpose.standard), standard);
      expect(repo.loadAiProfile(AiPurpose.standard), repo.loadAiSettings());
    });

    test('ingen egen profil → null (fallback avgjøres av kaller)', () {
      expect(repo.loadAiProfile(AiPurpose.writing), isNull);
      expect(repo.loadAiProfile(AiPurpose.structure), isNull);
      expect(repo.loadAiProfile(AiPurpose.images), isNull);
    });

    test('egen profil isoleres fra standardprofilen', () async {
      await repo.saveAiSettings(standard);
      await repo.saveAiProfile(AiPurpose.writing, writingOwn);
      expect(repo.loadAiSettings(), standard);
      expect(repo.loadAiProfile(AiPurpose.writing), writingOwn);
      expect(repo.loadAiProfile(AiPurpose.structure), isNull);
    });

    test('flere formål kan ha hver sin profil', () async {
      await repo.saveAiProfile(AiPurpose.writing, writingOwn);
      await repo.saveAiProfile(
        AiPurpose.structure,
        const AiSettings(
          type: AiProviderType.lmstudio,
          baseUrl: 'http://localhost:1234/v1',
          model: 'local-model',
        ),
      );
      expect(repo.loadAiProfile(AiPurpose.writing), writingOwn);
      expect(
        repo.loadAiProfile(AiPurpose.structure)!.type,
        AiProviderType.lmstudio,
      );
    });

    test('lagre egen profil beholder standardprofilen og onboarding', () async {
      await repo.markOnboardingSeen();
      await repo.saveAiSettings(standard);
      await repo.saveAiProfile(AiPurpose.writing, writingOwn);
      expect(repo.hasSeenOnboarding(), isTrue);
      expect(repo.loadAiSettings(), standard);
      expect(repo.loadAiProfile(AiPurpose.writing), writingOwn);
    });

    test('deleteAiProfile fjerner bare den aktuelle profilen', () async {
      await repo.saveAiProfile(AiPurpose.writing, writingOwn);
      await repo.saveAiProfile(AiPurpose.images, standard);
      await repo.deleteAiProfile(AiPurpose.writing);
      expect(repo.loadAiProfile(AiPurpose.writing), isNull);
      expect(repo.loadAiProfile(AiPurpose.images), standard);
    });

    test('deleteAiProfile fjerner tom «aiProfiles»-nøkkel', () async {
      await repo.saveAiProfile(AiPurpose.writing, writingOwn);
      await repo.deleteAiProfile(AiPurpose.writing);
      final raw = File('${tempDir.path}/settings.json').readAsStringSync();
      expect(raw, isNot(contains('aiProfiles')));
    });

    test('deleteAiProfile er et no-op for standardprofilen', () async {
      await repo.saveAiSettings(standard);
      await repo.deleteAiProfile(AiPurpose.standard);
      expect(repo.loadAiSettings(), standard);
    });

    test('deleteAiProfile uten egen profil gjør ingenting', () async {
      await repo.deleteAiProfile(AiPurpose.writing);
      expect(repo.loadAiProfile(AiPurpose.writing), isNull);
    });

    test('gammalt single-key-format lastes fortsatt', () {
      File('${tempDir.path}/settings.json').writeAsStringSync('''
{"ai": {"type": "anthropic", "baseUrl": "https://api.anthropic.com/v1", "model": "claude-sonnet-5"}}
''');
      expect(repo.loadAiSettings()!.type, AiProviderType.anthropic);
      expect(repo.loadAiProfile(AiPurpose.writing), isNull);
    });
  });
}
