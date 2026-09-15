import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyttebok/app/app.dart';
import 'package:hyttebok/core/utils/swipe_delete.dart';
import 'package:hyttebok/data/repositories/book_repository.dart';
import 'package:hyttebok/data/services/file_storage_service.dart';
import 'package:hyttebok/domain/models/book.dart';
import 'package:hyttebok/domain/models/cabin.dart';
import 'package:hyttebok/domain/models/section.dart';
import 'package:hyttebok/domain/models/section_type.dart';

/// Sveip-sletting: boken/hytten forsvinner med det samme, men slettes ikke
/// fysisk før tidsvinduet går ut uten angre – «Angre» er derfor alltid gratis.
void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('hyttebok-swipe-');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  FileStorageService makeStorage() =>
      FileStorageService(Directory('${tempDir.path}/books'));

  Future<void> seed(FileStorageService storage) async {
    await storage.writeBook(
      Book(
        slug: 'behold-meg',
        title: 'Behold meg',
        intro: '',
        updatedAt: DateTime(2026, 1, 2),
        cabins: const [],
      ),
    );
    await storage.writeBook(
      Book(
        slug: 'til-sletting',
        title: 'Til sletting',
        intro: '',
        updatedAt: DateTime(2026, 1, 1),
        cabins: [
          Cabin(
            slug: 'fjellhytta',
            name: 'Fjellhytta',
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
          Cabin(
            slug: 'sjohytta',
            name: 'Sjøhytta',
            order: 1,
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
      ),
    );
  }

  /// Starter appen og lar asynkront load() (fil-I/O) fullføre.
  Future<void> pumpWithLoad(WidgetTester tester, Widget app) async {
    await tester.pumpWidget(app);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
  }

  /// Gir det ekte event loopet tid til å fullføre fil-I/O.
  Future<void> flushIo(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
    }
  }

  Future<List<String>> slugsInStorage(
    BookRepository repo,
    WidgetTester tester,
  ) async {
    final slugs = await tester.runAsync(() async {
      final books = await repo.listBooks();
      return books.map((m) => m.slug).toList();
    });
    return slugs!;
  }

  testWidgets('sveip sletter bok – «Angre» gjenoppretter den', (tester) async {
    final storage = makeStorage();
    final repo = BookRepository(storage);
    await tester.runAsync(() => seed(storage));
    await pumpWithLoad(tester, HyttebokApp(repository: repo));

    expect(find.text('Til sletting'), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('bok-til-sletting')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();

    // Boka forsvinner fra listen, og «Angre»-meldingen vises.
    expect(find.byKey(const ValueKey('bok-til-sletting')), findsNothing);
    expect(find.text('Angre'), findsOneWidget);
    expect(find.text('Til sletting'), findsNothing);

    // Angre: boka kommer tilbake – ingenting er slettet.
    await tester.tap(find.text('Angre'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bok-til-sletting')), findsOneWidget);
    expect(await slugsInStorage(repo, tester), contains('til-sletting'));
  });

  testWidgets('sveip-sletting uten angre slettes fysisk etter tidsvinduet', (
    tester,
  ) async {
    final storage = makeStorage();
    final repo = BookRepository(storage);
    await tester.runAsync(() => seed(storage));
    await pumpWithLoad(tester, HyttebokApp(repository: repo));

    await tester.drag(
      find.byKey(const ValueKey('bok-til-sletting')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bok-til-sletting')), findsNothing);

    // La tidsvinduet gå ut uten angre – da slettes boka fysisk.
    await tester.pump(swipeDeleteCommitDelay + const Duration(seconds: 1));
    await flushIo(tester);

    expect(find.text('Til sletting'), findsNothing);
    final slugs = await slugsInStorage(repo, tester);
    expect(slugs, isNot(contains('til-sletting')));
    expect(slugs, contains('behold-meg'));
  });

  testWidgets('sveip sletter hytte – «Angre» gjenoppretter den', (
    tester,
  ) async {
    final storage = makeStorage();
    final repo = BookRepository(storage);
    await tester.runAsync(() => seed(storage));
    await pumpWithLoad(tester, HyttebokApp(repository: repo));

    // Åpner boka og venter til den er fullt lastet.
    await tester.tap(find.text('Til sletting'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(find.byTooltip('Søk i boka'), findsOneWidget);
    expect(find.text('Sjøhytta'), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('hytte-sjohytta')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();

    // Hytta forsvinner fra listen, og «Angre»-meldingen vises.
    expect(find.byKey(const ValueKey('hytte-sjohytta')), findsNothing);
    expect(find.text('Sjøhytta'), findsNothing);
    expect(find.text('Angre'), findsOneWidget);

    // Angre: hytta kommer tilbake – ingenting er slettet.
    await tester.tap(find.text('Angre'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('hytte-sjohytta')), findsOneWidget);

    final book = await tester.runAsync(() => repo.load('til-sletting'));
    expect(book, isNotNull);
    expect(
      book!.cabins.map((c) => c.slug),
      containsAll(['fjellhytta', 'sjohytta']),
    );
  });
}
