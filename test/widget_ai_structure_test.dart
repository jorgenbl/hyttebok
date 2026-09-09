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
import 'package:hyttebok/domain/models/book.dart';
import 'package:hyttebok/domain/models/cabin.dart';
import 'package:hyttebok/domain/models/section.dart';
import 'package:hyttebok/domain/models/section_type.dart';

class _MemoryKeyStore implements SecureKeyStore {
  final Map<String, String> _map = {};

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

/// Fake AI-klient som streamer forutbestemte chunks.
class _StreamClient implements AiClient {
  _StreamClient(this.chunks, {this.error});

  final List<String> chunks;
  final Object? error;

  @override
  Stream<String> complete({
    required String system,
    required String user,
    String? model,
    int? maxTokens,
  }) {
    if (error != null) return Stream.error(error!);
    return Stream.fromIterable(chunks);
  }

  @override
  Future<bool> ping({String? model}) async => true;
}

/// Begrenset «settle» (unngår uendelige animasjoner som spinner).
Future<void> settleFrames(WidgetTester tester, {int count = 12}) async {
  await tester.pump();
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump();
}

/// La async fil-io-kjeder fullføre.
///
/// Hver `runAsync`-runde lar event-loopet prosessere et steg i kjeden, så
/// kjeder med mange awaits (load → save → load) trenger flere runder enn
/// én save. [done] lar kalleren stoppe så snart den forventede tilstanden er
/// nådd (ellers kjøres hele budsjettet).
Future<void> settleSave(WidgetTester tester, {bool Function()? done}) async {
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    if (done != null && done()) return;
  }
}

Future<void> seedBook(FileStorageService storage) async {
  final book = Book(
    slug: 'sommehytta',
    title: 'Sommehytta',
    updatedAt: DateTime(2026, 1, 1),
    cabins: [
      Cabin(
        slug: 'hytta',
        name: 'Hytta',
        description: 'Trestue på fjellet med peis og båt.',
        order: 0,
        startRoutines: const Section(
          slug: 'start-rutiner',
          title: 'Åpne-rutiner',
          type: SectionType.startRoutines,
          order: 1,
        ),
        stopRoutines: const Section(
          slug: 'steng-rutiner',
          title: 'Steng-rutiner',
          type: SectionType.stopRoutines,
          order: 2,
        ),
      ),
    ],
  );
  await storage.writeBook(book);
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('hyttebok-ai-structure-');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    required AiClientBuilder aiClientBuilder,
    bool withSettings = true,
  }) async {
    final appDir = Directory('${tempDir.path}/app')
      ..createSync(recursive: true);
    final settingsRepo = SettingsRepository(FileTextKeyValueStore(appDir));
    if (withSettings) {
      await tester.runAsync(
        () => settingsRepo.saveAiSettings(
          const AiSettings(
            type: AiProviderType.ollama,
            baseUrl: 'http://localhost:11434/v1',
            model: 'llama3.1',
          ),
        ),
      );
    }
    final storage = FileStorageService(Directory('${tempDir.path}/books'));
    await tester.runAsync(() => seedBook(storage));
    await tester.pumpWidget(
      HyttebokApp(
        repository: BookRepository(storage),
        settings: settingsRepo,
        secureKeyStore: _MemoryKeyStore(),
        aiClientBuilder: aiClientBuilder,
      ),
    );
    await settleFrames(tester);
  }

  Future<void> openCabin(WidgetTester tester) async {
    await tester.tap(find.text('Sommehytta'));
    await settleFrames(tester);
    await tester.tap(find.text('Hytta'));
    await settleFrames(tester);
    expect(find.text('Beskrivelse'), findsOneWidget);
  }

  testWidgets(
    'strukturforslag: streaming → parse → godkjenn → seksjonene vises',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final client = _StreamClient(
        // JSON split i chunks for å teste streaming.
        [
          '{"sections":[{"title":"Ved & peis","type":"notater","hint":"Vedlager og vedkubb"},',
          '{"title":"Sjakk & spill","type":"egen","hint":"Spill og sjakksett"}]}',
        ],
      );
      await pumpApp(tester, aiClientBuilder: (s, k) => client);
      await openCabin(tester);

      // FAB → «Foreslå struktur (AI)».
      await tester.tap(find.byTooltip('Legg til'));
      await settleFrames(tester);
      await tester.tap(find.text('Foreslå struktur (AI)'));
      await settleFrames(tester);

      // Dialogen åpnes med hyttebeskrivelsen prefylt.
      expect(find.text('Foreslå struktur'), findsOneWidget);
      final descField = tester.widget<TextField>(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'Beskriv hytta',
        ),
      );
      expect(descField.controller!.text, 'Trestue på fjellet med peis og båt.');

      // Generer → streaming → parsede seksjoner.
      await tester.tap(find.widgetWithText(FilledButton, 'Generer'));
      await settleFrames(tester);

      expect(find.text('Ved & peis'), findsOneWidget);
      expect(find.text('Sjakk & spill'), findsOneWidget);
      expect(find.text('Vedlager og vedkubb'), findsOneWidget);

      // Godkjenn → seksjonene lander i hytta.
      await tester.tap(find.widgetWithText(FilledButton, 'Opprett seksjoner'));
      await settleSave(
        tester,
        done: () => find.text('Opprett seksjoner').evaluate().isEmpty,
      );
      await settleFrames(tester);

      // Dialogen er lukket; seksjonene vises på hyttesiden.
      expect(find.text('Opprett seksjoner'), findsNothing);
      expect(find.text('Ved & peis'), findsOneWidget);
      expect(find.text('Sjakk & spill'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('strukturforslag: forkast legger ingenting til', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = _StreamClient([
      '{"sections":[{"title":"Ved & peis","type":"notater","hint":"h"}]}',
    ]);
    await pumpApp(tester, aiClientBuilder: (s, k) => client);
    await openCabin(tester);

    await tester.tap(find.byTooltip('Legg til'));
    await settleFrames(tester);
    await tester.tap(find.text('Foreslå struktur (AI)'));
    await settleFrames(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Generer'));
    await settleFrames(tester);
    expect(find.text('Ved & peis'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Forkast'));
    await settleFrames(tester);

    expect(find.text('Ved & peis'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('strukturforslag: feil fra leverandøren vises i dialogen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = _StreamClient(
      [],
      error: AiProviderError(
        'Kan ikke nå AI-leverandøren. Kontroller nettverket – '
        'kjører den lokale leverandøren?',
      ),
    );
    await pumpApp(tester, aiClientBuilder: (s, k) => client);
    await openCabin(tester);

    await tester.tap(find.byTooltip('Legg til'));
    await settleFrames(tester);
    await tester.tap(find.text('Foreslå struktur (AI)'));
    await settleFrames(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Generer'));
    await settleFrames(tester);

    expect(find.textContaining('Kan ikke nå AI-leverandøren'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Prøv igjen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('strukturforslag: uformatert svar → rå tekst + prøv igjen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = _StreamClient(['Her er noen tips:\n1. Ved\n2. Peis']);
    await pumpApp(tester, aiClientBuilder: (s, k) => client);
    await openCabin(tester);

    await tester.tap(find.byTooltip('Legg til'));
    await settleFrames(tester);
    await tester.tap(find.text('Foreslå struktur (AI)'));
    await settleFrames(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Generer'));
    await settleFrames(tester);

    expect(find.textContaining('Kunne ikke tolke svaret'), findsOneWidget);
    expect(find.textContaining('Her er noen tips:'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Prøv igjen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('strukturforslag: AI ikke konfigurert → veiledende melding', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = _StreamClient([]);
    await pumpApp(
      tester,
      aiClientBuilder: (s, k) => client,
      withSettings: false,
    );
    await openCabin(tester);

    await tester.tap(find.byTooltip('Legg til'));
    await settleFrames(tester);
    await tester.tap(find.text('Foreslå struktur (AI)'));
    await settleFrames(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Generer'));
    await settleFrames(tester);

    expect(find.textContaining('AI er ikke konfigurert'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
