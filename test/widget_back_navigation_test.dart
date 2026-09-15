import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyttebok/app/app.dart';
import 'package:hyttebok/data/repositories/book_repository.dart';
import 'package:hyttebok/data/services/book_markdown.dart';
import 'package:hyttebok/data/services/file_picker_service.dart';
import 'package:hyttebok/data/services/file_storage_service.dart';
import 'package:hyttebok/domain/models/book.dart';
import 'package:hyttebok/domain/models/cabin.dart';
import 'package:hyttebok/domain/models/section.dart';
import 'package:hyttebok/domain/models/section_type.dart';

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

/// Regressjonstester for tilbake-navigasjon.
///
/// Tidligere brukte flere flukter `context.go(...)`, som nullstiller
/// go_router sin rute-stakk. Da fantes det ingen route «under» boka/hytten,
/// og AppBar-en viste ingen tilbake-knapp – brukeren var fast inne i boka
/// uten vei tilbake til biblioteket. Disse testene sikrer at tilbake-knappen
/// finnes og faktisk navigerer tilbake.
void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('hyttebok-back-');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  FileStorageService makeStorage() =>
      FileStorageService(Directory('${tempDir.path}/books'));

  /// Starter appen og lar asynkront load() fullføre (ekte fil-I/O via
  /// runAsync, siden testWidgets kjører i en FakeAsync-zone).
  Future<void> pumpWithLoad(WidgetTester tester, Widget app) async {
    await tester.pumpWidget(app);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
  }

  /// Pomper inntil [condition] er sant eller budsjettet er oppbrukt.
  /// Brukes for å la asynkront fil-I/O + navigasjon fullføre.
  Future<void> settleUntil(
    WidgetTester tester,
    bool Function() condition, {
    int iterations = 40,
  }) async {
    for (var i = 0; i < iterations; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 120)),
      );
      await tester.pump();
      if (condition()) return;
    }
    // La eventuelle pågående animasjoner/frames fullføre før videre interaksjon.
    await tester.pumpAndSettle();
  }

  /// Åpner [title] fra biblioteket og venter til boka er fullt lastet
  /// (AppBar-handlingen «Søk i boka» finnes kun i den lastede bok-visningen).
  ///
  /// Én runAsync-runde lar bokens fil-I/O fullføre; deretter et fast antall
  /// pumps slik at også rute-overgangen er fullført før videre interaksjon
  /// (mønsteret i de øvrige widget-testene – å tappe midt i overgangen gir
  /// feilaktig hit-test).
  Future<void> openBookFromLibrary(WidgetTester tester, String title) async {
    await tester.tap(find.text(title));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    await tester.pump();
    expect(find.byTooltip('Søk i boka'), findsOneWidget);
  }

  void expectBackButton(WidgetTester tester) {
    expect(
      find.byType(BackButton),
      findsOneWidget,
      reason: 'Forventet en tilbake-knapp i AppBar-en',
    );
  }

  testWidgets('ny opprettet bok: kan gå tilbake til biblioteket', (
    tester,
  ) async {
    await pumpWithLoad(
      tester,
      HyttebokApp(repository: BookRepository(makeStorage())),
    );

    // Opprett en ny bok.
    await tester.tap(find.byTooltip('Ny bok'));
    await tester.pumpAndSettle();
    final textField = tester.widget<TextField>(find.byType(TextField));
    textField.controller!.text = 'Sommehytta';
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    // Navigert inn i den nye boka (fullt lastet).
    await settleUntil(
      tester,
      () => find.byTooltip('Søk i boka').evaluate().isNotEmpty,
    );
    expect(find.text('Sommehytta'), findsWidgets);

    // Regresjon: tilbake-knappen må finnes (var borte med context.go).
    expectBackButton(tester);

    // Trykk tilbake → lander i biblioteket.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await settleUntil(
      tester,
      () => find.text('Hyttebøker').evaluate().isNotEmpty,
    );
    expect(find.text('Hyttebøker'), findsOneWidget);
  });

  testWidgets('importert bok: kan gå tilbake til biblioteket', (tester) async {
    final storage = makeStorage();

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
      PickedBookFile(
        name: 'importert.md',
        bytes: File(mdPath).readAsBytesSync(),
      ),
    );

    await pumpWithLoad(
      tester,
      HyttebokApp(repository: BookRepository(storage), filePicker: fakePicker),
    );

    // Importer boka.
    await tester.tap(find.byTooltip('Importer bok'));
    await tester.pump();
    await settleUntil(
      tester,
      () => find.byTooltip('Søk i boka').evaluate().isNotEmpty,
    );
    expect(find.text('Importert hytte'), findsOneWidget);

    // Regresjon: tilbake-knappen må finnes (var borte med context.go).
    expectBackButton(tester);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await settleUntil(
      tester,
      () => find.text('Hyttebøker').evaluate().isNotEmpty,
    );
    expect(find.text('Hyttebøker'), findsOneWidget);
  });

  testWidgets('åpnet eksisterende bok: kan gå tilbake til biblioteket', (
    tester,
  ) async {
    final storage = makeStorage();
    await tester.runAsync(() => storage.createBook('Sommehytta'));

    await pumpWithLoad(
      tester,
      HyttebokApp(repository: BookRepository(storage)),
    );

    await openBookFromLibrary(tester, 'Sommehytta');

    expectBackButton(tester);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await settleUntil(
      tester,
      () => find.text('Hyttebøker').evaluate().isNotEmpty,
    );
    expect(find.text('Hyttebøker'), findsOneWidget);
  });

  testWidgets('ny opprettet hytte: kan gå tilbake til boka', (tester) async {
    final storage = makeStorage();
    await tester.runAsync(() => storage.createBook('Sommehytta'));

    await pumpWithLoad(
      tester,
      HyttebokApp(repository: BookRepository(storage)),
    );

    await openBookFromLibrary(tester, 'Sommehytta');

    // Opprett en ny hytte fra boka.
    await tester.tap(find.byTooltip('Ny hytte'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tom hytte'));
    await tester.pumpAndSettle();
    final textField = tester.widget<TextField>(find.byType(TextField));
    textField.controller!.text = 'Fjellhytta';
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    // Navigert inn i den nye hytta (fullt lastet).
    await settleUntil(tester, () => find.text('Sted').evaluate().isNotEmpty);
    expect(find.text('Fjellhytta'), findsWidgets);

    // Regresjon: tilbake-knappen må finnes (var borte med context.go).
    expectBackButton(tester);

    // Trykk tilbake → lander i boka (ikke biblioteket, ikke ute av appen).
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await settleUntil(
      tester,
      () => find.byTooltip('Søk i boka').evaluate().isNotEmpty,
    );
    expect(find.byTooltip('Søk i boka'), findsOneWidget);
  });

  testWidgets('hytte åpnet fra søk: kan gå tilbake til søket', (tester) async {
    final storage = makeStorage();
    await tester.runAsync(() async {
      await storage.writeBook(
        Book(
          slug: 'sommehytta',
          title: 'Sommehytta',
          intro: 'Hytteboka.',
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
                  markdown: 'Vannkranen er i kjelleren.',
                ),
              ],
            ),
          ],
        ),
      );
    });

    await pumpWithLoad(
      tester,
      HyttebokApp(repository: BookRepository(storage)),
    );

    await openBookFromLibrary(tester, 'Sommehytta');

    // Søk og åpne en hytte fra et treff.
    await tester.tap(find.byTooltip('Søk i boka'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'vannkranen');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vann og el'));
    await tester.pumpAndSettle();
    await settleUntil(tester, () => find.text('Sted').evaluate().isNotEmpty);

    // Vi er inne i hytta.
    expect(find.text('Hytta'), findsWidgets);
    expectBackButton(tester);

    // Trykk tilbake → lander i søket (ikke boka, ikke biblioteket).
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await settleUntil(
      tester,
      () => find.text('Vann og el').evaluate().isNotEmpty,
    );
    expect(find.text('Vann og el'), findsOneWidget);
  });
}
