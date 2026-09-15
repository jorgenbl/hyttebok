import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyttebok/app/app.dart';
import 'package:hyttebok/core/widgets/book_image.dart';
import 'package:hyttebok/core/widgets/cabin_illustration.dart';
import 'package:hyttebok/data/repositories/book_repository.dart';
import 'package:hyttebok/data/services/file_storage_service.dart';
import 'package:hyttebok/data/services/image_picker_service.dart';
import 'package:image_picker/image_picker.dart';

/// Bokens forside: tegnet hyttemotiv som standard, omslagsbilde når det er
/// satt, og flyt for å endre/fjerne omslag.
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
    tempDir = Directory.systemTemp.createTempSync('hyttebok-cover-');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  FileStorageService makeStorage() =>
      FileStorageService(Directory('${tempDir.path}/books'));

  Future<String> seedBook(FileStorageService storage) async {
    final slug = await storage.createBook('Sommehytta');
    return slug;
  }

  Future<void> pumpWithLoad(WidgetTester tester, Widget app) async {
    await tester.pumpWidget(app);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
  }

  /// Åpner boka fra biblioteket og venter til den er lastet.
  Future<void> openBook(WidgetTester tester) async {
    await tester.tap(find.text('Sommehytta'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(find.text('Forsiden / intro'), findsOneWidget);
  }

  /// Venter til [check] (mot ekte data på disk) blir sann: hver iterasjon
  /// gir det ekte event loopet et vindu til å fullføre fil-I/O i appens
  /// async-kjede, og [pump] tømmer køen for fortsettelsen i test-zonen.
  /// En kjede (import + lagre + last) kan ta mange slike vinder, så antallet
  /// kan ikke holdes fast.
  Future<void> waitUntilIo(
    WidgetTester tester,
    Future<bool> Function() check, {
    int maxIterations = 60,
  }) async {
    for (var i = 0; i < maxIterations; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pump();
      final ok = await tester.runAsync(check);
      if (ok ?? false) {
        // Disktilstanden er satt, men appens kjede er fortsatt ett steg bak
        // (skrivet fullført, last/notify ikke kjørt). Gi den noen vinder til
        // å fange opp, og UI-et til å bygge seg på ny.
        for (var j = 0; j < 4; j++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await tester.pump();
        }
        return;
      }
    }
  }

  /// Gyldig 1×1 PNG – nok til at Image.memory klarer å dekodere.
  const List<int> kTinyPng = [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
    0x54, 0x78, 0xDA, 0x63, 0x64, 0x60, 0xF8, 0x5F,
    0x0F, 0x00, 0x02, 0x87, 0x01, 0x80, 0xEB, 0x47,
    0xBA, 0x92, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45,
    0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ];

  testWidgets('bok uten omslag viser tegnet hyttemotiv', (tester) async {
    final storage = makeStorage();
    await tester.runAsync(() => seedBook(storage));
    await pumpWithLoad(
      tester,
      HyttebokApp(repository: BookRepository(storage)),
    );
    await openBook(tester);

    expect(find.byType(CabinIllustration), findsOneWidget);
    expect(find.byType(BookImage), findsNothing);
  });

  testWidgets('kan sette omslag fra galleri', (tester) async {
    final storage = makeStorage();
    late String slug;
    await tester.runAsync(() async {
      slug = await seedBook(storage);
      await File('${tempDir.path}/omslag.jpg').writeAsBytes(kTinyPng);
    });
    final fakePicker = _FakeImagePickerService(
      XFile('${tempDir.path}/omslag.jpg'),
    );

    await pumpWithLoad(
      tester,
      HyttebokApp(repository: BookRepository(storage), imagePicker: fakePicker),
    );
    await openBook(tester);

    expect(find.byType(CabinIllustration), findsOneWidget);

    // Omslagsmeny → Endre omslag → Fra galleri.
    await tester.tap(find.byTooltip('Omslag'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Endre omslag'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fra galleri'));
    await tester.pump();

    // Import + lagring gjør ekte fil-I/O i flere trinn; vent til omslaget
    // faktisk er satt på disk.
    await waitUntilIo(tester, () async {
      final b = await storage.readBook(slug);
      return b.coverImage != null;
    });

    // Bildet er satt som omslag og illustrasjonen er borte.
    expect(find.byType(BookImage), findsOneWidget);
    expect(find.byType(CabinIllustration), findsNothing);
    final book = await tester.runAsync(() => storage.readBook(slug));
    expect(book, isNotNull);
    expect(book!.coverImage, startsWith('images/'));
  });

  testWidgets('kan fjerne omslag – illustrasjonen kommer tilbake', (
    tester,
  ) async {
    final storage = makeStorage();
    late String slug;
    await tester.runAsync(() async {
      slug = await seedBook(storage);
      // Ekte bildefil + coverImage slik at BookImage kan laste bildet.
      final bookDir = Directory('${storage.bookRootPath(slug)}/images');
      await bookDir.create(recursive: true);
      await File('${bookDir.path}/omslag.png').writeAsBytes(kTinyPng);
      final book = await storage.readBook(slug);
      await storage.writeBook(book.copyWith(coverImage: 'images/omslag.png'));
    });

    await pumpWithLoad(
      tester,
      HyttebokApp(repository: BookRepository(storage)),
    );
    await openBook(tester);

    expect(find.byType(BookImage), findsOneWidget);

    // Omslagsmeny → Fjern omslag.
    await tester.tap(find.byTooltip('Omslag'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fjern omslag'));
    await tester.pump();

    // Lagringen gjør ekte fil-I/O; vent til omslaget er fjernet på disk.
    await waitUntilIo(tester, () async {
      final b = await storage.readBook(slug);
      return b.coverImage == null;
    });

    expect(find.byType(CabinIllustration), findsOneWidget);
    final book = await tester.runAsync(() => storage.readBook(slug));
    expect(book, isNotNull);
    expect(book!.coverImage, isNull);
  });
}
