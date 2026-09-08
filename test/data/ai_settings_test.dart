import 'package:flutter_test/flutter_test.dart';

import 'package:hyttebok/data/services/ai_settings.dart';

void main() {
  group('AiSettings', () {
    test('defaultBaseUrlFor per leverandør', () {
      expect(
        AiSettings.defaultBaseUrlFor(AiProviderType.openai),
        'https://api.openai.com/v1',
      );
      expect(
        AiSettings.defaultBaseUrlFor(AiProviderType.anthropic),
        'https://api.anthropic.com/v1',
      );
      expect(
        AiSettings.defaultBaseUrlFor(AiProviderType.ollama),
        'http://localhost:11434/v1',
      );
      expect(
        AiSettings.defaultBaseUrlFor(AiProviderType.lmstudio),
        'http://localhost:1234/v1',
      );
      expect(AiSettings.defaultBaseUrlFor(AiProviderType.custom), isEmpty);
    });

    test('defaultModelFor per leverandør', () {
      expect(AiSettings.defaultModelFor(AiProviderType.openai), 'gpt-4o-mini');
      expect(
        AiSettings.defaultModelFor(AiProviderType.anthropic),
        'claude-3-5-haiku-latest',
      );
      expect(AiSettings.defaultModelFor(AiProviderType.ollama), 'llama3.1');
      expect(
        AiSettings.defaultModelFor(AiProviderType.lmstudio),
        'local-model',
      );
      expect(AiSettings.defaultModelFor(AiProviderType.custom), isEmpty);
    });

    test('toJson/fromJson round-trip', () {
      const original = AiSettings(
        type: AiProviderType.openai,
        baseUrl: 'https://api.openai.com/v1',
        model: 'gpt-4o-mini',
        systemPrompt: 'Mitt eget prompt',
        maxTokens: 512,
        temperature: 1.2,
      );
      final restored = AiSettings.fromJson(original.toJson());
      expect(restored.toJson(), original.toJson());
      expect(restored.type, original.type);
      expect(restored.baseUrl, original.baseUrl);
      expect(restored.model, original.model);
      expect(restored.systemPrompt, original.systemPrompt);
      expect(restored.maxTokens, original.maxTokens);
      expect(restored.temperature, original.temperature);
    });

    test('fromJson tolererer ukjent leverandørtype og tomme verdier', () {
      final restored = AiSettings.fromJson({
        'type': 'mystisk-leverandør',
        'baseUrl': '',
        'model': '',
      });
      expect(restored.type, AiProviderType.ollama);
      expect(restored.baseUrl, 'http://localhost:11434/v1');
      expect(restored.model, 'llama3.1');
    });

    test('fromJson behandler manglende filfelter med standarder', () {
      final restored = AiSettings.fromJson({});
      expect(restored.type, AiProviderType.ollama);
      expect(restored.systemPrompt, kDefaultAiSystemPrompt);
      expect(restored.maxTokens, 2048);
      expect(restored.temperature, 0.7);
    });

    test('isLocal for loopback-URL-er', () {
      AiSettings settingsFor(String baseUrl) =>
          AiSettings(type: AiProviderType.ollama, baseUrl: baseUrl, model: 'm');
      expect(settingsFor('http://localhost:11434/v1').isLocal, isTrue);
      expect(settingsFor('http://127.0.0.1:11434/v1').isLocal, isTrue);
      expect(settingsFor('http://[::1]:11434/v1').isLocal, isTrue);
      expect(settingsFor('http://192.168.1.5:11434/v1').isLocal, isFalse);
      expect(settingsFor('https://api.openai.com/v1').isLocal, isFalse);
    });

    test('needsApiKey kun for cloud-leverandører', () {
      AiSettings settingsFor(AiProviderType type) =>
          AiSettings(type: type, baseUrl: 'x', model: 'm');
      expect(settingsFor(AiProviderType.openai).needsApiKey, isTrue);
      expect(settingsFor(AiProviderType.anthropic).needsApiKey, isTrue);
      expect(settingsFor(AiProviderType.custom).needsApiKey, isTrue);
      expect(settingsFor(AiProviderType.ollama).needsApiKey, isFalse);
      expect(settingsFor(AiProviderType.lmstudio).needsApiKey, isFalse);
    });

    test('copyWith endrer kun oppgitte felter', () {
      const original = AiSettings(
        type: AiProviderType.ollama,
        baseUrl: 'http://localhost:11434/v1',
        model: 'llama3.1',
      );
      final copy = original.copyWith(model: 'llama3.2');
      expect(copy.model, 'llama3.2');
      expect(copy.type, AiProviderType.ollama);
      expect(copy.baseUrl, original.baseUrl);
    });

    test('description viser type og URL (uten nøkkel)', () {
      const s = AiSettings(
        type: AiProviderType.ollama,
        baseUrl: 'http://localhost:11434/v1',
        model: 'm',
      );
      expect(s.description, 'Ollama (lokal) (http://localhost:11434/v1)');
    });
  });
}
