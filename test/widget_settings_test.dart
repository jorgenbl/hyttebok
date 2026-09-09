import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyttebok/app/app.dart';
import 'package:hyttebok/core/errors.dart';
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

  String? get stored => _map[kAiApiKeyKey];

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

/// Fake AI-klient: [complete] gir ikke noe, [ping] gir [pingOutcome]
/// (boolean) eller kaster (Exception).
class _FakeAiClient implements AiClient {
  _FakeAiClient(this.pingOutcome);

  final Object pingOutcome;

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
  Future<bool> ping({String? model}) async {
    final outcome = pingOutcome;
    if (outcome is Exception) throw outcome;
    return outcome as bool;
  }
}

/// Finder for tekstfelt ut fra label (InputDecoration.labelText).
Finder field(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);

/// Begrenset «settle»: pump et antall rammer med tidsfremskudd.
///
/// Brukes i stedet for [WidgetTester.pumpAndSettle] fordi
/// [CircularProgressIndicator]/skelett-puls vil animere uendelig.
Future<void> settleFrames(WidgetTester tester, {int count = 12}) async {
  await tester.pump();
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump();
}

/// La async fil-io-kjeder (settings-lagring) fullføre.
///
/// Hver `runAsync`-runde lar event-loopet prosessere et steg i kjeden;
/// kjeder med mange awaits trenger flere runder enn én save.
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
    tempDir = Directory.systemTemp.createTempSync('hyttebok-settings-');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets(
    'innstillinger: intro → lokal oppsett → cloud → nøkkel → test → persistert',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final appDir = Directory('${tempDir.path}/app')
        ..createSync(recursive: true);
      final settingsRepo = SettingsRepository(FileTextKeyValueStore(appDir));
      final keyStore = _MemoryKeyStore();
      final fakeClient = _FakeAiClient(true);

      await tester.pumpWidget(
        HyttebokApp(
          repository: BookRepository(
            FileStorageService(Directory('${tempDir.path}/books')),
          ),
          settings: settingsRepo,
          secureKeyStore: keyStore,
          aiClientBuilder: (s, k) => fakeClient,
        ),
      );
      await settleFrames(tester);

      // Til innstillingssiden fra bibliotek-menyen.
      await tester.tap(find.byTooltip('Innstillinger'));
      await settleFrames(tester);

      // Ingen leverandør ennå: intro-kort.
      expect(find.text('AI-hjelp'), findsOneWidget);
      expect(find.textContaining('Sett opp lokal leverandør'), findsOneWidget);

      // Sett opp lokal leverandør → formet dukker opp.
      await tester.tap(find.textContaining('Sett opp lokal leverandør'));
      await settleFrames(tester);

      expect(
        find.byType(DropdownButtonFormField<AiProviderType>),
        findsOneWidget,
      );
      expect(find.text('Ollama (lokal)'), findsOneWidget);
      expect(
        find.text('Lokal – dataene forlater ikke enheten.'),
        findsOneWidget,
      );
      expect(field('Base-URL'), findsOneWidget);
      expect(
        tester.widget<TextField>(field('Base-URL')).controller!.text,
        'http://localhost:11434/v1',
      );
      expect(field('API-nøkkel'), findsNothing);

      // Test tilkobling (fake: vellykket).
      await tester.tap(find.text('Test tilkobling'));
      await settleFrames(tester);
      expect(find.text('Tilkoblet – alt fungerer.'), findsOneWidget);

      // Bytt leverandør til OpenAI (cloud): standard-URL/modell + nøkkel-felt.
      await tester.tap(find.text('Ollama (lokal)'));
      await settleFrames(tester);
      await tester.tap(find.text('OpenAI'));
      await settleFrames(tester);

      expect(
        find.text('Cloud – dataene sendes til leverandøren.'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(field('Base-URL')).controller!.text,
        'https://api.openai.com/v1',
      );
      expect(
        tester.widget<TextField>(field('Modell')).controller!.text,
        'gpt-4o-mini',
      );
      expect(field('API-nøkkel'), findsOneWidget);

      // Skriv inn nøkkel; den skal lande i sikker lagring, ikke i filen.
      await tester.enterText(field('API-nøkkel'), 'sk-test-123');
      await settleSave(tester);

      expect(keyStore.stored, 'sk-test-123');
      final json = File('${appDir.path}/settings.json').readAsStringSync();
      expect(json, isNot(contains('sk-test-123')));

      // Innstillingene er persistert (uten nøkkel).
      final loaded = settingsRepo.loadAiSettings();
      expect(loaded, isNotNull);
      expect(loaded!.type, AiProviderType.openai);
      expect(loaded.baseUrl, 'https://api.openai.com/v1');
      expect(loaded.model, 'gpt-4o-mini');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('test tilkobling: feil fra leverandøren vises vennlig', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final appDir = Directory('${tempDir.path}/app')
      ..createSync(recursive: true);
    final settingsRepo = SettingsRepository(FileTextKeyValueStore(appDir));
    // Prefill: OpenAI-konfigurert, ingen nøkkel.
    await tester.runAsync(
      () => settingsRepo.saveAiSettings(
        const AiSettings(
          type: AiProviderType.openai,
          baseUrl: 'https://api.openai.com/v1',
          model: 'gpt-4o-mini',
        ),
      ),
    );
    final keyStore = _MemoryKeyStore();
    final fakeClient = _FakeAiClient(
      AiProviderError(
        'Ugyldig eller manglende API-nøkkel. Sjekk AI-innstillingene.',
      ),
    );

    await tester.pumpWidget(
      HyttebokApp(
        repository: BookRepository(
          FileStorageService(Directory('${tempDir.path}/books')),
        ),
        settings: settingsRepo,
        secureKeyStore: keyStore,
        aiClientBuilder: (s, k) => fakeClient,
      ),
    );
    await settleFrames(tester);

    await tester.tap(find.byTooltip('Innstillinger'));
    await settleFrames(tester);

    // Prefylt form (innstillingene finnes fra før).
    expect(find.text('OpenAI'), findsOneWidget);
    expect(field('API-nøkkel'), findsOneWidget);

    await tester.tap(find.text('Test tilkobling'));
    await settleFrames(tester);
    expect(
      find.text('Ugyldig eller manglende API-nøkkel. Sjekk AI-innstillingene.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
