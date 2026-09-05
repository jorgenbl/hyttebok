import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyttebok/app/app.dart';
import 'package:hyttebok/data/repositories/book_repository.dart';
import 'package:hyttebok/data/services/file_storage_service.dart';
import 'package:hyttebok/domain/models/cabin.dart';
import 'package:hyttebok/domain/models/section.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('hyttebok-widget-');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  FileStorageService makeStorage() =>
      FileStorageService(Directory('${tempDir.path}/books'));

  // testWidgets kjører test-kroppen i en FakeAsync-zone der ekte dart:io
  // fil-I/O ikke fullføres. tester.runAsync kjører kallbacken i en ekte
  // async-zone, slik at både setup-I/O og hvert screens asynkrone load()
  // får fullføre før vi gjentar/pump.
  Future<void> pumpWithLoad(WidgetTester tester, Widget app) async {
    await tester.pumpWidget(app);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
  }

  testWidgets('viser tom tilstand når ingen bøker finnes', (tester) async {
    await pumpWithLoad(
      tester,
      HyttebokApp(repository: BookRepository(makeStorage())),
    );

    expect(find.text('Hyttebøker'), findsOneWidget);
    expect(find.textContaining('Ingen hyttebøker'), findsOneWidget);
  });

  testWidgets('viser eksisterende bok i biblioteket', (tester) async {
    final storage = makeStorage();
    await tester.runAsync(() => storage.createBook('Sommehytta'));

    await pumpWithLoad(
      tester,
      HyttebokApp(repository: BookRepository(storage)),
    );

    expect(find.text('Sommehytta'), findsOneWidget);
  });

  testWidgets('kan åpne en bok og se hytter', (tester) async {
    final storage = makeStorage();
    await tester.runAsync(() async {
      final slug = await storage.createBook('Sommehytta');
      final book = await storage.readBook(slug);
      await storage.writeBook(
        book.copyWith(
          cabins: [
            Cabin(
              slug: 'fjellhytta',
              name: 'Fjellhytta',
              order: 0,
              startRoutines: const Section(
                slug: 'start-rutiner',
                title: 'Åpne-rutiner',
                order: 1,
              ),
              stopRoutines: const Section(
                slug: 'steng-rutiner',
                title: 'Steng-rutiner',
                order: 2,
              ),
            ),
          ],
        ),
      );
    });

    await pumpWithLoad(
      tester,
      HyttebokApp(repository: BookRepository(storage)),
    );

    await tester.tap(find.text('Sommehytta'));
    // Navigasjon starter BookView og dennes asynkrone load().
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    // Fullfør sideovergang og render innholdet (load er ferdig → ingen spinner).
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    await tester.pump();

    expect(find.text('Fjellhytta'), findsOneWidget);
  });
}
