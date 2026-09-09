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
  _StreamClient(this.chunks);

  final List<String> chunks;

  @override
  Stream<String> complete({
    required String system,
    required String user,
    String? model,
    int? maxTokens,
  }) {
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
    tempDir = Directory.systemTemp.createTempSync('hyttebok-ai-editor-');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<void> pumpApp(
    WidgetTester tester,
    AiClientBuilder aiClientBuilder,
  ) async {
    final appDir = Directory('${tempDir.path}/app')
      ..createSync(recursive: true);
    final settingsRepo = SettingsRepository(FileTextKeyValueStore(appDir));
    await tester.runAsync(
      () => settingsRepo.saveAiSettings(
        const AiSettings(
          type: AiProviderType.ollama,
          baseUrl: 'http://localhost:11434/v1',
          model: 'llama3.1',
        ),
      ),
    );
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

  String editorText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  testWidgets('editor: generer rutineliste i åpne-rutiner → innsett', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = _StreamClient(['- [ ] Tenn peis\n', '- [ ] Slå på lyset']);
    await pumpApp(tester, (s, k) => client);
    await openCabin(tester);

    // Åpne «Åpne-rutiner» i editoren.
    await tester.tap(find.text('Åpne-rutiner'));
    await settleFrames(tester);
    expect(find.text('Lagre'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Tenn peis');

    // AI-menyen: rutine-valget finnes for start-rutiner.
    await tester.tap(find.byTooltip('AI-hjelp'));
    await settleFrames(tester);
    expect(find.text('Utvid teksten'), findsOneWidget);
    expect(find.text('Omskriv teksten'), findsOneWidget);
    expect(find.text('Oppsummer teksten'), findsOneWidget);
    expect(find.text('Generer rutineliste'), findsOneWidget);

    // Generer rutineliste → streaming → innsett.
    await tester.tap(find.text('Generer rutineliste'));
    await settleFrames(tester);
    expect(find.widgetWithText(FilledButton, 'Innsett'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Innsett'));
    await settleFrames(tester);

    expect(editorText(tester), '- [ ] Tenn peis\n- [ ] Slå på lyset');
    expect(tester.takeException(), isNull);
  });

  testWidgets('editor: utvid beskrivelse → innsett erstatter hele teksten; '
      'rutine-valget fraværende for beskrivelse', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = _StreamClient(['Peis og ved – utvidet med detaljer.']);
    await pumpApp(tester, (s, k) => client);
    await openCabin(tester);

    // Åpne «Beskrivelse» i editoren.
    await tester.tap(find.text('Beskrivelse'));
    await settleFrames(tester);
    expect(find.text('Lagre'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Peis og ved');

    // AI-menyen: ingen rutine-generering for beskrivelse.
    await tester.tap(find.byTooltip('AI-hjelp'));
    await settleFrames(tester);
    expect(find.text('Generer rutineliste'), findsNothing);
    expect(find.text('Utvid teksten'), findsOneWidget);

    await tester.tap(find.text('Utvid teksten'));
    await settleFrames(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Innsett'));
    await settleFrames(tester);

    expect(editorText(tester), 'Peis og ved – utvidet med detaljer.');
    expect(tester.takeException(), isNull);
  });

  testWidgets('editor: forkast i AI-dialogen endrer ikke teksten', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = _StreamClient(['Ny tekst fra AI']);
    await pumpApp(tester, (s, k) => client);
    await openCabin(tester);

    await tester.tap(find.text('Beskrivelse'));
    await settleFrames(tester);
    await tester.enterText(find.byType(TextField), 'Uendret tekst');

    await tester.tap(find.byTooltip('AI-hjelp'));
    await settleFrames(tester);
    await tester.tap(find.text('Omskriv teksten'));
    await settleFrames(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Forkast'));
    await settleFrames(tester);

    expect(editorText(tester), 'Uendret tekst');
    expect(tester.takeException(), isNull);
  });
}
