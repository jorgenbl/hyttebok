import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyttebok/app/app.dart';
import 'package:hyttebok/core/errors.dart';
import 'package:hyttebok/data/repositories/book_repository.dart';
import 'package:hyttebok/data/repositories/settings_repository.dart';
import 'package:hyttebok/data/services/ai_client.dart';
import 'package:hyttebok/data/services/ai_image_client.dart';
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

/// Fake AI-chat-klient (brukes ikke i disse testene, men må leveres).
class _NoopChatClient implements AiClient {
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

/// Fake bilde-klient: returnerer [image], eller kaster [error] om satt.
/// [lastPrompt] lar testen se hva som ble sendt til leverandøren.
class _FakeImageClient implements AiImageClient {
  _FakeImageClient(this.image, {this.error});

  final AiGeneratedImage image;
  final Object? error;
  String? lastPrompt;

  @override
  Future<AiGeneratedImage> generate({required String prompt, String? model}) {
    lastPrompt = prompt;
    if (error != null) return Future.error(error!);
    return Future.value(image);
  }
}

/// 1×1-piksel PNG (gyldig, slik at [Image.memory] i dialogen krasjer ikke).
final Uint8List kTinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
  'AAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

/// Finder for tekstfelt ut fra label (InputDecoration.labelText).
Finder field(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);

/// Begrenset «settle» (unngår uendelige animasjoner som spinner).
Future<void> settleFrames(WidgetTester tester, {int count = 12}) async {
  await tester.pump();
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump();
}

/// La async fil-io (lagring av det genererte bildet) fullføre.
Future<void> settleSave(WidgetTester tester) async {
  for (var i = 0; i < 60; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
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
    tempDir = Directory.systemTemp.createTempSync('hyttebok-ai-image-');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<(SettingsRepository, _MemoryKeyStore)> pumpApp(
    WidgetTester tester, {
    required AiImageClientBuilder imageBuilder,
    bool withSettings = true,
    String? apiKey,
  }) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final appDir = Directory('${tempDir.path}/app')
      ..createSync(recursive: true);
    final settingsRepo = SettingsRepository(FileTextKeyValueStore(appDir));
    if (withSettings) {
      await tester.runAsync(
        () => settingsRepo.saveAiSettings(
          const AiSettings(
            type: AiProviderType.openai,
            baseUrl: 'https://api.openai.com/v1',
            model: 'gpt-image-1',
          ),
        ),
      );
    }
    // Hopp over velkomst-opplæringen i testen.
    await tester.runAsync(settingsRepo.markOnboardingSeen);
    final keyStore = _MemoryKeyStore();
    if (apiKey != null) {
      await keyStore.writeKey(kAiApiKeyKey, apiKey);
    }
    final storage = FileStorageService(Directory('${tempDir.path}/books'));
    await tester.runAsync(() => seedBook(storage));
    await tester.pumpWidget(
      HyttebokApp(
        repository: BookRepository(storage),
        settings: settingsRepo,
        secureKeyStore: keyStore,
        aiClientBuilder: (s, k) => _NoopChatClient(),
        aiImageClientBuilder: imageBuilder,
      ),
    );
    await settleFrames(tester);
    return (settingsRepo, keyStore);
  }

  Future<void> openDescriptionEditor(WidgetTester tester) async {
    await tester.tap(find.text('Sommehytta'));
    await settleFrames(tester);
    await tester.tap(find.text('Hytta'));
    await settleFrames(tester);
    await tester.tap(find.text('Beskrivelse'));
    await settleFrames(tester);
    expect(find.text('Lagre'), findsOneWidget);
  }

  String editorText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  testWidgets(
    'editor: generer bilde med AI → forhåndsvis → innsett i teksten',
    (tester) async {
      final fake = _FakeImageClient(
        AiGeneratedImage(bytes: kTinyPng, extension: 'png'),
      );
      await pumpApp(tester, imageBuilder: (s, k) => fake, apiKey: 'sk-img-1');
      await openDescriptionEditor(tester);
      await tester.enterText(find.byType(TextField), 'Peis og ved');

      // Åpne bilde-dialogen.
      await tester.tap(find.byTooltip('Generer bilde (AI)'));
      await settleFrames(tester);
      expect(find.text('Generer bilde'), findsOneWidget);
      expect(field('Beskriv bildet'), findsOneWidget);

      // Skriv prompt og generer. (Pump mellom enterText og tap slik at
      // «Generer»-knappen får rebuild og blir aktivert.)
      await tester.enterText(field('Beskriv bildet'), 'en trestue om morgenen');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Generer'));
      await settleFrames(tester);

      // Forhåndsvisning av det genererte bildet.
      expect(find.byType(Image), findsWidgets);
      expect(
        find.widgetWithText(FilledButton, 'Innsett i teksten'),
        findsOneWidget,
      );
      expect(fake.lastPrompt, 'en trestue om morgenen');

      // Innsett → bildet lagres i boken, Markdown settes inn i editoren.
      await tester.tap(find.widgetWithText(FilledButton, 'Innsett i teksten'));
      await settleSave(tester);

      final text = editorText(tester);
      final match = RegExp(r'!\[(.*?)\]\((images/[^)]+)\)').firstMatch(text);
      expect(match, isNotNull);
      expect(text, startsWith('Peis og ved![img-'));
      expect(match!.group(1), match.group(2)!.split('/').last);

      // Bildet ligger på disken under bokens images-mappe.
      final file = File('${tempDir.path}/books/sommehytta/${match.group(2)}');
      expect(file.existsSync(), isTrue);
      expect(file.readAsBytesSync(), kTinyPng);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('editor: egen bildeprofil brukes (fallback når den mangler)', (
    tester,
  ) async {
    final own = AiGeneratedImage(bytes: kTinyPng, extension: 'png');
    final fakeOwn = _FakeImageClient(own);
    final fakeStandard = _FakeImageClient(own);
    // Bygger klient basert på hvilken base-URL profilen peker på.
    AiImageClient imageBuilder(AiSettings s, String? k) =>
        s.baseUrl.contains('7860') ? fakeOwn : fakeStandard;

    final (settingsRepo, keyStore) = await pumpApp(
      tester,
      imageBuilder: imageBuilder,
      apiKey: 'sk-std',
    );
    // Sett opp en egen bildeprofil som peker på SD WebUI (port 7860)
    // med nøkkel i formålets eget slott.
    await tester.runAsync(
      () => settingsRepo.saveAiProfile(
        AiPurpose.images,
        const AiSettings(
          type: AiProviderType.custom,
          baseUrl: 'http://localhost:7860',
          model: 'sd-xl',
        ),
      ),
    );
    await keyStore.writeKey(aiApiKeyKeyFor(AiPurpose.images), 'sk-own');
    await openDescriptionEditor(tester);

    await tester.tap(find.byTooltip('Generer bilde (AI)'));
    await settleFrames(tester);
    await tester.enterText(field('Beskriv bildet'), 'en båt i fjøra');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Generer'));
    await settleFrames(tester);

    // Den egen profilen ble brukt (fakeOwn), ikke standardprofilen.
    expect(fakeOwn.lastPrompt, 'en båt i fjøra');
    expect(fakeStandard.lastPrompt, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editor: leverandør-feil vises med «Prøv igjen»', (tester) async {
    final fake = _FakeImageClient(
      AiGeneratedImage(bytes: kTinyPng, extension: 'png'),
      error: AiProviderError(
        'For mange forespørsler til leverandøren. Prøv igjen om litt.',
        statusCode: 429,
      ),
    );
    await pumpApp(tester, imageBuilder: (s, k) => fake, apiKey: 'sk-img-1');
    await openDescriptionEditor(tester);

    await tester.tap(find.byTooltip('Generer bilde (AI)'));
    await settleFrames(tester);
    await tester.enterText(field('Beskriv bildet'), 'en hytte');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Generer'));
    await settleFrames(tester);

    expect(
      find.text('For mange forespørsler til leverandøren. Prøv igjen om litt.'),
      findsOneWidget,
    );
    // «Prøv igjen» går tilbake til inndata-skjermen.
    await tester.tap(find.widgetWithText(FilledButton, 'Prøv igjen'));
    await settleFrames(tester);
    expect(field('Beskriv bildet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editor: manglende API-nøkkel gir feilmelding i dialogen', (
    tester,
  ) async {
    await pumpApp(
      tester,
      imageBuilder: (s, k) =>
          _FakeImageClient(AiGeneratedImage(bytes: kTinyPng, extension: 'png')),
    );
    await openDescriptionEditor(tester);

    await tester.tap(find.byTooltip('Generer bilde (AI)'));
    await settleFrames(tester);
    await tester.enterText(field('Beskriv bildet'), 'en hytte');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Generer'));
    await settleFrames(tester);

    expect(find.textContaining('Ingen API-nøkkel er satt'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editor: uten AI-konfig gir snackbar', (tester) async {
    await pumpApp(
      tester,
      imageBuilder: (s, k) =>
          _FakeImageClient(AiGeneratedImage(bytes: kTinyPng, extension: 'png')),
      withSettings: false,
    );
    await openDescriptionEditor(tester);

    await tester.tap(find.byTooltip('Generer bilde (AI)'));
    await settleFrames(tester);
    expect(find.textContaining('AI er ikke konfigurert'), findsOneWidget);
    expect(find.text('Generer bilde'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
