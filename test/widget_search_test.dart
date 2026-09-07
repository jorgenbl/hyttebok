import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyttebok/app/app.dart';
import 'package:hyttebok/data/repositories/book_repository.dart';
import 'package:hyttebok/data/services/file_storage_service.dart';
import 'package:hyttebok/domain/models/book.dart';
import 'package:hyttebok/domain/models/cabin.dart';
import 'package:hyttebok/domain/models/section.dart';
import 'package:hyttebok/domain/models/section_type.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('hyttebok-search-');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  FileStorageService makeStorage() =>
      FileStorageService(Directory('${tempDir.path}/books'));

  Future<void> seed(FileStorageService storage) async {
    final book = Book(
      slug: 'sommehytta',
      title: 'Sommehytta',
      intro: 'Her ligger alt vi må huske om hytta.',
      updatedAt: DateTime(2026, 1, 1),
      cabins: [
        Cabin(
          slug: 'hytta',
          name: 'Hytta',
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
          sections: const [
            Section(
              slug: 'vann',
              title: 'Vann og el',
              order: 0,
              markdown: 'Vannkranen er i kjelleren. El: 220V.',
            ),
          ],
        ),
      ],
    );
    await storage.writeBook(book);
  }

  Future<void> flush(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 120)),
      );
      await tester.pump();
    }
  }

  testWidgets('søk i boka funner innhold og navigerer til hytta', (
    tester,
  ) async {
    final storage = makeStorage();
    await tester.runAsync(() => seed(storage));
    await tester.pumpWidget(HyttebokApp(repository: BookRepository(storage)));
    await flush(tester);

    // Åpne boka.
    await tester.tap(find.text('Sommehytta'));
    await flush(tester);
    expect(find.byTooltip('Søk i boka'), findsOneWidget);

    // Åpne søk og skriv en query.
    await tester.tap(find.byTooltip('Søk i boka'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'vannkranen');
    await tester.pumpAndSettle();

    // Treffen for seksjonen vises.
    expect(find.text('Vann og el'), findsOneWidget);

    // Trykk på treffet → navigerer til hytta.
    await tester.tap(find.text('Vann og el'));
    await tester.pumpAndSettle();
    await flush(tester);
    expect(find.text('Hytta'), findsWidgets);
  });
}
