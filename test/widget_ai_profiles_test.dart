import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyttebok/app/app.dart';
import 'package:hyttebok/data/repositories/book_repository.dart';
import 'package:hyttebok/data/repositories/settings_repository.dart';
import 'package:hyttebok/data/services/ai_client.dart';
import 'package:hyttebok/data/services/ai_settings.dart';
import 'package:hyttebok/data/services/file_storage_service.dart';
import 'package:hyttebok/data/services/file_text_key_value_store.dart';
import 'package:hyttebok/data/services/secure_key_store.dart';

/// Minneste basert [SecureKeyStore] (ingen method channels i widget-tester).
class _MemoryKeyStore implements SecureKeyStore {
  final Map<String, String> _map = {};

  /// Alle nøkkler slik de er lagret (for å sjekke per-formål-slottene).
  Map<String, String> get all => Map.unmodifiable(_map);

  @override
  Future<String?> readKey(String key) async => _map[key];

  @override
  Future<void> writeKey(String key, String value) async {
    _map[key] = value;
  }

  @override
  Future<void> deleteKey(String key) async {
    _map.remove(key);
  }
}

/// Fake AI-klient: ingen streaming; ping alltid vellykket.
class _FakeAiClient implements AiClient {
  @override
  Stream<String> complete({
    required String system,
    required String user,
    String? model,
    int? maxTokens,
  }) {
    return const Stream.empty();
  }

  @override
  Future<bool> ping({String? model}) async => true;
}

/// Finder for tekstfelt ut fra label (InputDecoration.labelText).
Finder field(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);

/// Begrenset «settle»: pump et antall rammer med tidsfremskudd.
Future<void> settleFrames(WidgetTester tester, {int count = 12}) async {
  await tester.pump();
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump();
}

/// La async fil-io-kjeder (settings-lagring) fullføre.
Future<void> settleSave(WidgetTester tester) async {
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('hyttebok-ai-profiles-');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets(
    'profil per formål: oversikt, egen profil med egen nøkkel, sletting',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final appDir = Directory('${tempDir.path}/app')
        ..createSync(recursive: true);
      final settingsRepo = SettingsRepository(FileTextKeyValueStore(appDir));
      // Prefill: standardprofilen er Anthropic (slik at en egen OpenAI-profil
      // for skrivehjelp er tydelig adskilt).
      await tester.runAsync(
        () => settingsRepo.saveAiSettings(
          const AiSettings(
            type: AiProviderType.anthropic,
            baseUrl: 'https://api.anthropic.com/v1',
            model: 'claude-sonnet-5',
          ),
        ),
      );
      // Hopp over velkomst-opplæringen i testen.
      await tester.runAsync(settingsRepo.markOnboardingSeen);
      final keyStore = _MemoryKeyStore();
      await keyStore.writeKey(kAiApiKeyKey, 'sk-std-111');

      await tester.pumpWidget(
        HyttebokApp(
          repository: BookRepository(
            FileStorageService(Directory('${tempDir.path}/books')),
          ),
          settings: settingsRepo,
          secureKeyStore: keyStore,
          aiClientBuilder: (s, k) => _FakeAiClient(),
        ),
      );
      await settleFrames(tester);

      // Inn til innstillingssiden (standardprofilen).
      await tester.tap(find.byTooltip('Innstillinger'));
      await settleFrames(tester);

      // Oversikten over formålsprofiler: alle bruker standardprofilen.
      expect(find.text('Profiler per formål'), findsOneWidget);
      expect(find.text('Skrivehjelp'), findsOneWidget);
      expect(find.text('Strukturforslag'), findsOneWidget);
      expect(find.text('Bildegenerering'), findsOneWidget);
      expect(
        find.text('Standard: Anthropic (Claude) (claude-sonnet-5)'),
        findsNWidgets(3),
      );

      // Inn til skrivehjelp-profilen.
      await tester.tap(find.text('Skrivehjelp'));
      await settleFrames(tester);
      expect(find.text('AI – Skrivehjelp'), findsOneWidget);
      expect(find.text('Ingen egen profil'), findsOneWidget);
      expect(
        find.textContaining(
          'standardprofilen: Anthropic (Claude) (claude-sonnet-5)',
        ),
        findsOneWidget,
      );

      // Opprett egen profil: start med lokal leverandør, bytt til OpenAI
      // for å få et API-nøkkel-felt.
      await tester.tap(find.textContaining('Sett opp lokal leverandør'));
      await settleFrames(tester);
      await tester.tap(find.text('Ollama (lokal)'));
      await settleFrames(tester);
      await tester.tap(find.text('OpenAI'));
      await settleFrames(tester);
      expect(field('API-nøkkel'), findsOneWidget);

      // Egen API-nøkkel: skal lande i skrivehjelp-slotten, ikke i
      // standardprofilens.
      await tester.enterText(field('API-nøkkel'), 'sk-writing-456');
      await settleSave(tester);

      expect(keyStore.all['ai.apiKey.writing'], 'sk-writing-456');
      expect(keyStore.all[kAiApiKeyKey], 'sk-std-111');
      final writingProfile = settingsRepo.loadAiProfile(AiPurpose.writing);
      expect(writingProfile, isNotNull);
      expect(writingProfile!.type, AiProviderType.openai);
      // Standardprofilen er urørt.
      expect(settingsRepo.loadAiSettings()!.type, AiProviderType.anthropic);

      // Tilbake til standard-skjermen: skrivehjelp vises med egen profil.
      await tester.pageBack();
      await settleFrames(tester);
      expect(find.text('Egen: OpenAI (gpt-4o-mini)'), findsOneWidget);
      expect(
        find.text('Standard: Anthropic (Claude) (claude-sonnet-5)'),
        findsNWidgets(2),
      );

      // Inn igjen og fjern egen profil.
      await tester.tap(find.text('Skrivehjelp'));
      await settleFrames(tester);
      await tester.tap(find.text('Fjern egen profil'));
      await settleFrames(tester);
      expect(find.text('Fjerne egen profil?'), findsOneWidget);
      await tester.tap(find.text('Fjern'));
      await settleSave(tester);

      // Intro-kortet er tilbake; profilen og nøkkelslotten er borte,
      // standardprofilen og dens nøkkel er intakt.
      expect(find.text('Ingen egen profil'), findsOneWidget);
      expect(settingsRepo.loadAiProfile(AiPurpose.writing), isNull);
      expect(keyStore.all.containsKey('ai.apiKey.writing'), isFalse);
      expect(keyStore.all[kAiApiKeyKey], 'sk-std-111');
      expect(settingsRepo.loadAiSettings()!.type, AiProviderType.anthropic);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'profil per formål: egen profil uten standard fallback tilgjengelig',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final appDir = Directory('${tempDir.path}/app')
        ..createSync(recursive: true);
      final settingsRepo = SettingsRepository(FileTextKeyValueStore(appDir));
      // Hopp over velkomst-opplæringen i testen.
      await tester.runAsync(settingsRepo.markOnboardingSeen);
      final keyStore = _MemoryKeyStore();

      await tester.pumpWidget(
        HyttebokApp(
          repository: BookRepository(
            FileStorageService(Directory('${tempDir.path}/books')),
          ),
          settings: settingsRepo,
          secureKeyStore: keyStore,
          aiClientBuilder: (s, k) => _FakeAiClient(),
        ),
      );
      await settleFrames(tester);

      await tester.tap(find.byTooltip('Innstillinger'));
      await settleFrames(tester);

      // Ingen AI konfigurert: alle formål vises som «Ikke konfigurert».
      expect(find.text('Ikke konfigurert'), findsNWidgets(3));

      // Strukturforslags-profilen: introen forteller at ingenting er satt.
      await tester.tap(find.text('Strukturforslag'));
      await settleFrames(tester);
      expect(find.text('AI – Strukturforslag'), findsOneWidget);
      expect(find.text('Ingen egen profil'), findsOneWidget);
      expect(
        find.textContaining('ingen AI-profil (ikke konfigurert)'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
