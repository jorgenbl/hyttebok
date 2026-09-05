import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyttebok/app/app.dart';
import 'package:hyttebok/data/repositories/book_repository.dart';
import 'package:hyttebok/data/services/file_storage_service.dart';
import 'package:hyttebok/data/services/image_picker_service.dart';
import 'package:hyttebok/domain/models/cabin.dart';
import 'package:hyttebok/domain/models/section.dart';
import 'package:hyttebok/ui/features/editor/editor.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

/// Fake som hopper over kamera/galleri-plugin og returnerer et forhåndsvalgt
/// bilde. Gjør editor-testen uavhengig av plattformkanaler.
class _FakeImagePickerService extends ImagePickerService {
  _FakeImagePickerService(this.nextFile);

  final XFile? nextFile;

  @override
  Future<XFile?> pickFromGallery() async => nextFile;

  @override
  Future<XFile?> takePhoto() async => nextFile;
}

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

  testWidgets('kan legge til bilde fra galleri i editoren', (tester) async {
    final storage = makeStorage();
    final srcPath = '${tempDir.path}/foto.jpg';
    late String slug;
    // Ekte fil-I/O (opprette bok + kildebilde) i en ekte async-zone.
    await tester.runAsync(() async {
      slug = await storage.createBook('Sommehytta');
      await File(srcPath).writeAsBytes([10, 20, 30, 40]);
    });
    final fakePicker = _FakeImagePickerService(XFile(srcPath));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<BookRepository>.value(value: BookRepository(storage)),
          Provider<ImagePickerService>.value(value: fakePicker),
        ],
        child: MaterialApp(
          home: EditorView(
            input: EditorInput(
              title: 'Beskrivelse',
              initialValue: '',
              bookSlug: slug,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Fra galleri'));
    // Importen gjør ekte fil-I/O i en fire-and-forget-future. La den
    // fullføre over flere omganger (bounded – henger aldri).
    String? text;
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 120)),
      );
      await tester.pump();
      text = tester.widget<TextField>(find.byType(TextField)).controller?.text;
      if (text?.contains('![') ?? false) break;
    }

    expect(text, contains('!['));
    expect(text, contains('](images/'));

    // Bildet skal faktisk være lagret i boken.
    final imagesDir = Directory('${storage.bookRootPath(slug)}/images');
    final saved = await tester.runAsync(() async {
      if (!imagesDir.existsSync()) return 0;
      return imagesDir.listSync().length;
    });
    expect(saved, 1);
  });
}
