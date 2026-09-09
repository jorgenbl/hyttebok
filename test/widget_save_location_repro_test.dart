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

/// Regressjonstest for «Lagre på Sted»-fløten (dialog → async fil-io →
/// rebuild av side med dialogen fortsatt i treet under ut-animationen).
///
/// Opprinnelig skrevet for å reprodusere en sporadisk
/// «_dependents.isEmpty: is not true»-assert (InheritedElement.debugDeactivated)
/// på simulatoren; asserten reproduseres ikke under FakeAsync, men testen
/// dekker nøyaktig den brukerfløten og fanger en gjenoppstått feil her.
///
/// Viktig: etter «Lagre» må fil-io få fullføre MENS dialogens ut-animation
/// fortsatt kjører (slik det skjer på ekte enhet) — rebuilden skjer da med
/// dialogen fortsatt i treet. Bruk [settleSave] (runAsync + pump uten tid),
/// ikke pump med tidsfremskudd, for io-kjeden.
void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('hyttebok-repro-');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  FileStorageService makeStorage() =>
      FileStorageService(Directory('${tempDir.path}/books'));

  Future<void> seedBook(FileStorageService storage) async {
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
        ),
      ],
    );
    await storage.writeBook(book);
  }

  /// Navigering: la fil-io (synkron) + 300 ms-side-overgang fullføre.
  Future<void> settleNav(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    await tester.pump();
  }

  /// La async fil-io-kjeder (writeBook med create/delete/writeAsString)
  /// fullføre: runAsync-vinduer + pump UTEN tidsfremskudd.
  /// Hver runde lar event-loopet prosessere et steg i kjeden; kjeder med
  /// mange awaits trenger flere runder enn én save.
  Future<void> settleSave(WidgetTester tester) async {
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
  }

  testWidgets('mal-fløte: lagre sted i «Ny hytte fra mal»', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = makeStorage();
    await tester.runAsync(() => storage.createBook('Sommehytta'));
    await tester.pumpWidget(HyttebokApp(repository: BookRepository(storage)));
    await settleNav(tester);

    // Åpne boka.
    await tester.tap(find.text('Sommehytta'));
    await settleNav(tester);
    expect(find.byTooltip('Ny hytte'), findsOneWidget);

    // FAB → «Ny hytte fra mal».
    await tester.tap(find.byTooltip('Ny hytte'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ny hytte fra mal'));
    await tester.pumpAndSettle();

    // Navn-dialog → Lagre.
    await tester.enterText(find.byType(TextField), 'Fjellhytta');
    await tester.tap(find.widgetWithText(FilledButton, 'Lagre'));
    await tester.pumpAndSettle();

    // Sted-dialog → Lagre (brukerens eksakte handling).
    expect(find.text('Sted (valgfritt)'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Røros, 638 m.o.h.');
    await tester.tap(find.widgetWithText(FilledButton, 'Lagre'));
    await tester.pump();

    // Enhetstid: fil-io (~10 ms) fullfører mens ut-animation (200 ms)
    // kjører → rebuild skjer med dialogen fortsatt i treet.
    await settleSave(tester);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Navigert inn i den nye hytta; la lasting fullføre.
    await settleSave(tester);

    expect(find.text('Fjellhytta'), findsWidgets);
    expect(find.text('Røros, 638 m.o.h.'), findsOneWidget);
  });

  testWidgets('hytte-side: lagre sted via «Sted»-tilet', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = makeStorage();
    await tester.runAsync(() => seedBook(storage));
    await tester.pumpWidget(HyttebokApp(repository: BookRepository(storage)));
    await settleNav(tester);

    // Åpne bok → hytte.
    await tester.tap(find.text('Sommehytta'));
    await settleNav(tester);
    await tester.tap(find.text('Hytta'));
    await settleNav(tester);
    expect(find.text('Sted'), findsOneWidget);

    // «Sted»-tile → dialog → Lagre.
    await tester.tap(find.text('Sted'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Røros, 638 m.o.h.');
    await tester.tap(find.widgetWithText(FilledButton, 'Lagre'));
    await tester.pump();

    // Enhetstid: fil-io fullfører mens ut-animation kjører.
    await settleSave(tester);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Røros, 638 m.o.h.'), findsOneWidget);
  });
}
