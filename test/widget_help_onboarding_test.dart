import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyttebok/app/app.dart';
import 'package:hyttebok/data/repositories/book_repository.dart';
import 'package:hyttebok/data/repositories/settings_repository.dart';
import 'package:hyttebok/data/services/file_storage_service.dart';
import 'package:hyttebok/data/services/text_key_value_store.dart';

/// Minnebaseret [TextKeyValueStore] (ingen fil-io i disse testene).
class _MemoryTextStore implements TextKeyValueStore {
  String? value;

  @override
  String? load() => value;

  @override
  Future<void> save(String value) async {
    this.value = value;
  }
}

/// Begrenset «settle»: pump et antall rammer med tidsfremskudd.
Future<void> settleFrames(WidgetTester tester, {int count = 12}) async {
  await tester.pump();
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump();
}

Widget buildApp(SettingsRepository? settings, String tempPath) {
  return HyttebokApp(
    repository: BookRepository(
      FileStorageService(Directory('$tempPath/books')),
    ),
    settings: settings,
  );
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('hyttebok-help-');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  testWidgets('viser velkomst-opplæring første gang og åpner appen etterpå', (
    tester,
  ) async {
    final store = _MemoryTextStore();
    final repo = SettingsRepository(store);

    await tester.pumpWidget(buildApp(repo, tempDir.path));
    await settleFrames(tester);

    // Opplæringen er synlig, appen er ikke det.
    expect(find.text('Velkommen til Hyttebok'), findsOneWidget);
    expect(find.text('Ferdig'), findsOneWidget);
    expect(find.text('Hyttebøker'), findsNothing);
    expect(repo.hasSeenOnboarding(), isFalse);

    // Ferdig → appen åpnes og flagget er persistert.
    await tester.tap(find.text('Ferdig'));
    await settleFrames(tester);

    expect(find.text('Hyttebøker'), findsOneWidget);
    expect(find.text('Velkommen til Hyttebok'), findsNothing);
    expect(repo.hasSeenOnboarding(), isTrue);
    expect(store.value, contains('"onboardingShown": true'));
  });

  testWidgets('viser ikke opplæringen når den allerede er stengt', (
    tester,
  ) async {
    final store = _MemoryTextStore();
    final repo = SettingsRepository(store);
    await repo.markOnboardingSeen();

    await tester.pumpWidget(buildApp(repo, tempDir.path));
    await settleFrames(tester);

    expect(find.text('Hyttebøker'), findsOneWidget);
    expect(find.text('Velkommen til Hyttebok'), findsNothing);
  });

  testWidgets('uten innstillingslagring vises ingen opplæring', (tester) async {
    await tester.pumpWidget(buildApp(null, tempDir.path));
    await settleFrames(tester);

    expect(find.text('Hyttebøker'), findsOneWidget);
    expect(find.text('Velkommen til Hyttebok'), findsNothing);
  });

  testWidgets('opplæringen har fem sider og «Kom i gang» på siste', (
    tester,
  ) async {
    final store = _MemoryTextStore();

    await tester.pumpWidget(buildApp(SettingsRepository(store), tempDir.path));
    await settleFrames(tester);

    expect(find.text('Velkommen til Hyttebok'), findsOneWidget);
    expect(find.text('Ferdig'), findsOneWidget);

    // Stryk frem til siste side.
    for (var i = 0; i < 4; i++) {
      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await settleFrames(tester);
    }

    expect(find.text('Eksport og sikkerhetskopi'), findsOneWidget);
    expect(find.text('Kom i gang'), findsOneWidget);
    expect(find.text('Ferdig'), findsNothing);

    // «Kom i gang» avslutter også.
    await tester.tap(find.text('Kom i gang'));
    await settleFrames(tester);
    expect(find.text('Hyttebøker'), findsOneWidget);
  });

  testWidgets('hjelp kan åpnes fra biblioteket', (tester) async {
    await tester.pumpWidget(buildApp(null, tempDir.path));
    await settleFrames(tester);
    expect(find.text('Hyttebøker'), findsOneWidget);

    await tester.tap(find.byTooltip('Hjelp'));
    await settleFrames(tester);

    // Tittel + innhold fra veiledningen.
    expect(find.text('Hjelp'), findsOneWidget);
    expect(find.text('1. Kom i gang'), findsOneWidget);
    expect(find.text('10. Vanlige spørsmål'), findsOneWidget);
    expect(
      find.textContaining('Ingen kopier sendes til noen server.'),
      findsOneWidget,
    );
  });
}
