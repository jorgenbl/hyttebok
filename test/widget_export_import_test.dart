import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyttebok/app/app.dart';
import 'package:hyttebok/data/repositories/book_repository.dart';
import 'package:hyttebok/data/services/book_markdown.dart';
import 'package:hyttebok/data/services/file_picker_service.dart';
import 'package:hyttebok/data/services/file_storage_service.dart';
import 'package:hyttebok/domain/models/book.dart';

/// Fake som hopper over `file_picker`-kanalen og returnerer en forhåndsvalgt
/// fil. Gjør import-testen uavhengig av plattformkanaler.
class _FakeFilePickerService extends FilePickerService {
  _FakeFilePickerService(this.next);

  final PickedBookFile? next;

  @override
  Future<PickedBookFile?> pickBookFile({
    String? dialogTitle,
    List<String> allowedExtensions = const ['md', 'zip'],
  }) async => next;
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('hyttebok-wid-');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  FileStorageService makeStorage() =>
      FileStorageService(Directory('${tempDir.path}/books'));

  Future<void> pumpWithLoad(WidgetTester tester, Widget app) async {
    await tester.pumpWidget(app);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
  }

  testWidgets('bok-siden har del-/eksportmeny', (tester) async {
    final storage = makeStorage();
    await tester.runAsync(() => storage.createBook('Sommehytta'));

    await pumpWithLoad(
      tester,
      HyttebokApp(repository: BookRepository(storage)),
    );

    // Åpne boka.
    await tester.tap(find.text('Sommehytta'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    await tester.pump();
    expect(find.byTooltip('Del / eksporter'), findsOneWidget);

    // Åpne delingsmenyen.
    await tester.tap(find.byTooltip('Del / eksporter'));
    await tester.pumpAndSettle();
    expect(find.text('Del som Markdown (.md)'), findsOneWidget);
    expect(find.text('Del som mappe (.zip)'), findsOneWidget);
  });

  testWidgets('kan importere en bok fra fil i biblioteket', (tester) async {
    final storage = makeStorage();

    // Generer en gyldig énfil-.md-bok og skriv til temp.
    final mdPath = '${tempDir.path}/importert.md';
    await tester.runAsync(() async {
      final book = Book(
        slug: 'temp',
        title: 'Importert hytte',
        updatedAt: DateTime(2026, 1, 1),
      );
      final md = await bookToSingleFile(book, imageBytes: (_) async => null);
      await File(mdPath).writeAsString(md);
    });

    final fakePicker = _FakeFilePickerService(
      PickedBookFile(path: mdPath, name: 'importert.md'),
    );

    await pumpWithLoad(
      tester,
      HyttebokApp(repository: BookRepository(storage), filePicker: fakePicker),
    );
    expect(find.byTooltip('Importer bok'), findsOneWidget);

    // Trykk import. Importen gjør ekte fil-I/O i en fire-and-forget-future.
    await tester.tap(find.byTooltip('Importer bok'));
    await tester.pump(); // La gesten påtrygge (onPressed) fullføres.
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 120)),
      );
      await tester.pump();
      await tester.pump();
      if (find.text('Importert hytte').evaluate().isNotEmpty) break;
    }

    // Navigert inn i den importerte boka.
    expect(find.text('Importert hytte'), findsOneWidget);
    expect(find.byTooltip('Del / eksporter'), findsOneWidget);
  });
}
