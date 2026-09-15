import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyttebok/app/app.dart';
import 'package:hyttebok/data/repositories/book_repository.dart';
import 'package:hyttebok/data/repositories/settings_repository.dart';
import 'package:hyttebok/data/services/file_storage_service.dart';
import 'package:hyttebok/data/services/file_text_key_value_store.dart';
import 'package:hyttebok/data/services/secure_key_store.dart';
import 'package:hyttebok/data/services/speech_to_text_service.dart';
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

/// Fake dikteringstjeneste: returnerer [result], eller kaster [error] om satt.
/// [listenCalls]/[stopCalls] lar testen se hva som ble kalt.
class _FakeSpeech extends SpeechToTextService {
  _FakeSpeech({this.result, this.error});

  final String? result;
  final Object? error;
  int listenCalls = 0;
  int stopCalls = 0;

  @override
  Future<String?> listen() async {
    listenCalls++;
    if (error != null) throw error!;
    return result;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }
}

/// Begrenset «settle» (unngår uendelige animasjoner som spinner).
Future<void> settleFrames(WidgetTester tester, {int count = 12}) async {
  await tester.pump();
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump();
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
    tempDir = Directory.systemTemp.createTempSync('hyttebok-dictation-');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    required SpeechToTextService speech,
  }) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final appDir = Directory('${tempDir.path}/app')
      ..createSync(recursive: true);
    final settingsRepo = SettingsRepository(FileTextKeyValueStore(appDir));
    // Hopp over velkomst-opplæringen i testen.
    await tester.runAsync(settingsRepo.markOnboardingSeen);

    final storage = FileStorageService(Directory('${tempDir.path}/books'));
    await tester.runAsync(() => seedBook(storage));
    await tester.pumpWidget(
      HyttebokApp(
        repository: BookRepository(storage),
        settings: settingsRepo,
        secureKeyStore: _MemoryKeyStore(),
        speechToText: speech,
      ),
    );
    await settleFrames(tester);
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
    'editor: diktert tekst settes inn på cursorposisjonen (mellomrom foran)',
    (tester) async {
      final speech = _FakeSpeech(result: 'og båt');
      await pumpApp(tester, speech: speech);
      await openDescriptionEditor(tester);
      await tester.enterText(find.byType(TextField), 'Peis');

      // Trykk på mikrofon-knappen.
      await tester.tap(find.byTooltip('Diktering'));
      await settleFrames(tester);

      expect(speech.listenCalls, 1);
      expect(editorText(tester), 'Peis og båt');
      // Knappen er tilbake i idle-tilstand etter sesjonen.
      expect(find.byTooltip('Diktering'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('editor: diktering i tom tekst setter inn uten foran-mellomrom', (
    tester,
  ) async {
    final speech = _FakeSpeech(result: 'God hytte');
    await pumpApp(tester, speech: speech);
    await openDescriptionEditor(tester);
    // Feltet har fra før en beskrivelse; tøm den slik at cursor står i start
    // og ingen foran-mellomrom skal settes inn.
    await tester.enterText(find.byType(TextField), '');
    await settleFrames(tester);

    await tester.tap(find.byTooltip('Diktering'));
    await settleFrames(tester);

    expect(editorText(tester), 'God hytte');
    expect(tester.takeException(), isNull);
  });

  testWidgets('editor: manglende mikrofon-rettighet gir snackbar', (
    tester,
  ) async {
    final speech = _FakeSpeech(
      error: const DictationException(
        'Mikrofon-tillatelse er ikke gitt. Tillat tilgang i enhetens '
        'innstillinger.',
      ),
    );
    await pumpApp(tester, speech: speech);
    await openDescriptionEditor(tester);
    // Tøm den forinnstilledte beskrivelsen slik at vi kan sjekke at ingen
    // tekst settes inn.
    await tester.enterText(find.byType(TextField), '');
    await settleFrames(tester);

    await tester.tap(find.byTooltip('Diktering'));
    await settleFrames(tester);

    expect(
      find.textContaining('Mikrofon-tillatelse er ikke gitt'),
      findsOneWidget,
    );
    // Ingen tekst ble satt inn.
    expect(editorText(tester), isEmpty);
    // Knappen er tilbake i idle-tilstand (ingen pågående sesjon).
    expect(find.byTooltip('Diktering'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editor: tom diktering gir ingen innsatt tekst', (tester) async {
    final speech = _FakeSpeech(result: null);
    await pumpApp(tester, speech: speech);
    await openDescriptionEditor(tester);
    await tester.enterText(find.byType(TextField), 'Peis');

    await tester.tap(find.byTooltip('Diktering'));
    await settleFrames(tester);

    expect(speech.listenCalls, 1);
    expect(editorText(tester), 'Peis');
    expect(tester.takeException(), isNull);
  });
}
