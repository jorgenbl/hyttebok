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
    tempDir = Directory.systemTemp.createTempSync('hyttebok-reorder-');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  FileStorageService makeStorage() =>
      FileStorageService(Directory('${tempDir.path}/books'));

  Future<void> seedCabinWithSections(FileStorageService storage) async {
    final book = Book(
      slug: 'sommehytta',
      title: 'Sommehytta',
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
            Section(slug: 'a', title: 'Seksjon A', order: 0, markdown: 'A'),
            Section(slug: 'b', title: 'Seksjon B', order: 1, markdown: 'B'),
            Section(slug: 'c', title: 'Seksjon C', order: 2, markdown: 'C'),
          ],
        ),
      ],
    );
    await storage.writeBook(book);
  }

  Future<void> pumpWithLoad(WidgetTester tester, Widget app) async {
    await tester.pumpWidget(app);
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 120)),
      );
      await tester.pump();
    }
  }

  /// La fil-io + lasting fullføre (fire-and-forget-futures i VM-ene).
  Future<void> flush(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 120)),
      );
      await tester.pump();
    }
  }

  double? top(WidgetTester tester, String text) {
    final f = find.text(text);
    if (f.evaluate().isEmpty) return null;
    return tester.getTopLeft(f).dy;
  }

  Future<void> openSectionMenu(WidgetTester tester, String sectionTitle) async {
    final card = find
        .ancestor(of: find.text(sectionTitle), matching: find.byType(Card))
        .first;
    await tester.tap(
      find.descendant(of: card, matching: find.byTooltip('Alternativer')),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('kan flytte og skjule/vis igjen seksjoner', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = makeStorage();
    await tester.runAsync(() => seedCabinWithSections(storage));
    await pumpWithLoad(
      tester,
      HyttebokApp(repository: BookRepository(storage)),
    );

    // Åpne bok → hytte.
    await tester.tap(find.text('Sommehytta'));
    await flush(tester);
    await tester.tap(find.text('Hytta'));
    await flush(tester);

    // Startrekkefølge: A, B, C.
    expect(top(tester, 'Seksjon A')! < top(tester, 'Seksjon B')!, isTrue);
    expect(top(tester, 'Seksjon B')! < top(tester, 'Seksjon C')!, isTrue);

    // Flytt «Seksjon B» ned → A, C, B.
    await openSectionMenu(tester, 'Seksjon B');
    await tester.tap(find.text('Flytt ned'));
    await tester.pumpAndSettle();
    await flush(tester);
    expect(top(tester, 'Seksjon A')! < top(tester, 'Seksjon C')!, isTrue);
    expect(top(tester, 'Seksjon C')! < top(tester, 'Seksjon B')!, isTrue);

    // Skjul «Seksjon C» → forsvinner fra synlige, dukker opp under «Skjulte».
    await openSectionMenu(tester, 'Seksjon C');
    await tester.tap(find.text('Skjul'));
    await tester.pumpAndSettle();
    await flush(tester);
    expect(find.text('Skjulte seksjoner'), findsOneWidget);
    expect(find.text('Seksjon C'), findsOneWidget); // beholdes (skjult)

    // Vis igjen «Seksjon C» → tilbake i synlig liste.
    await openSectionMenu(tester, 'Seksjon C');
    await tester.tap(find.text('Vis igjen'));
    await tester.pumpAndSettle();
    await flush(tester);
    expect(find.text('Skjulte seksjoner'), findsNothing);
    expect(find.text('Seksjon C'), findsOneWidget);
  });
}
