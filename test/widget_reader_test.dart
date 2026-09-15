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
import 'package:hyttebok/domain/models/story.dart';

/// Finder for tekst i Markdown-innholdet. MarkdownBody med
/// `selectable: true` renderer avsnitt som SelectableText.rich (ikke som
/// vanlig RichText), så begge variantene skal sjekkes.
Finder doc(String text) => find.byWidgetPredicate((w) {
  if (w is RichText) return w.text.toPlainText().contains(text);
  if (w is SelectableText) {
    final t = w.data ?? w.textSpan?.toPlainText();
    return t?.contains(text) ?? false;
  }
  return false;
});

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('hyttebok-reader-');
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
      intro: 'Her ligger alt vi må huske om hyttene.',
      updatedAt: DateTime(2026, 1, 1),
      cabins: [
        Cabin(
          slug: 'fjellhytta',
          name: 'Fjellhytta',
          location: 'Røros, 638 m.o.h.',
          description: 'Denne hytta er fra 1962.',
          order: 0,
          startRoutines: const Section(
            slug: 'start-rutiner',
            title: 'Åpne-rutiner',
            type: SectionType.startRoutines,
            order: 1,
            markdown: '- [ ] Sjekk at dørene er låst',
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
            Section(
              slug: 'hemmelig',
              title: 'Skjult notat',
              order: 1,
              markdown: 'Kodelåsen er 1234.',
              hidden: true,
            ),
          ],
          stories: [
            Story(
              slug: 'forste-jul',
              title: 'Første jul',
              date: DateTime(2025, 12, 24),
              author: 'Familien',
              markdown: 'Det snødde hele dagen.',
              order: 0,
            ),
          ],
        ),
        Cabin(
          slug: 'sjohytta',
          name: 'Sjøhytta',
          location: 'Lillehammer, 98 m.o.h.',
          description: 'Hytta ved innsjøen.',
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
          sections: const [
            Section(
              slug: 'brygge',
              title: 'Brygga',
              order: 0,
              markdown: 'Brygga er 20 meter lang.',
            ),
          ],
        ),
      ],
    );
    await storage.writeBook(book);
  }

  /// Starter appen og lar asynkront load() fullføre.
  Future<void> pumpWithLoad(WidgetTester tester, Widget app) async {
    await tester.pumpWidget(app);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
  }

  /// Pomper inntil [condition] er sant eller budsjettet er oppbrukt.
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
    await tester.pumpAndSettle();
  }

  /// Åpner boka fra biblioteket og venter til den er fullt lastet.
  Future<void> openBook(WidgetTester tester) async {
    await tester.tap(find.text('Sommehytta'));
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

  /// Lesevisningen bruker lazy ListView: drar (ruller) til [marker] er
  /// synlig, deretter la rulle-animasjonen og nye bygg fullføre.
  Future<void> scrollReaderTo(WidgetTester tester, Finder marker) async {
    final scrollArea = find.byKey(const ValueKey('reader-scroll'));
    var guard = 0;
    while (marker.evaluate().isEmpty && guard < 60) {
      await tester.drag(scrollArea, const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 50));
      guard++;
    }
    await tester.pump(const Duration(milliseconds: 100));
  }

  void largeView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('les boka: alt innhold fra alle hytter i én samlet visning', (
    tester,
  ) async {
    largeView(tester);
    final storage = makeStorage();
    await tester.runAsync(() => seed(storage));
    await pumpWithLoad(
      tester,
      HyttebokApp(repository: BookRepository(storage)),
    );

    await openBook(tester);

    // Åpne lesevisningen fra bok-siden.
    await tester.tap(find.byTooltip('Les boka'));
    await settleUntil(
      tester,
      () => doc('Denne hytta er fra 1962.').evaluate().isNotEmpty,
    );

    // Toppen: bokmeta, intro og Fjellhytta.
    expect(find.text('Hyttebok · sist endret 01. januar 2026'), findsOneWidget);
    expect(doc('Her ligger alt vi må huske om hyttene.'), findsOneWidget);
    expect(find.text('Fjellhytta'), findsOneWidget);
    expect(find.text('Røros, 638 m.o.h.'), findsOneWidget);
    expect(doc('Denne hytta er fra 1962.'), findsOneWidget);
    expect(find.text('Åpne-rutiner'), findsOneWidget);
    expect(doc('Sjekk at dørene er låst'), findsOneWidget);

    // Ruller gjennom resten av Fjellhytta.
    await scrollReaderTo(tester, find.text('Vann og el'));
    expect(doc('Vannkranen er i kjelleren. El: 220V.'), findsOneWidget);

    await scrollReaderTo(tester, find.text('Skjult notat'));
    expect(doc('Kodelåsen er 1234.'), findsOneWidget);

    await scrollReaderTo(tester, find.text('Historier'));
    expect(find.text('Første jul'), findsOneWidget);
    expect(find.text('2025-12-24 · Familien'), findsOneWidget);
    expect(doc('Det snødde hele dagen.'), findsOneWidget);

    // Sjøhytta i samme samling.
    await scrollReaderTo(tester, find.text('Sjøhytta'));
    expect(find.text('Lillehammer, 98 m.o.h.'), findsOneWidget);
    expect(doc('Hytta ved innsjøen.'), findsOneWidget);

    await scrollReaderTo(tester, find.text('Brygga'));
    expect(doc('Brygga er 20 meter lang.'), findsOneWidget);

    // Tomme seksjoner (steng-rutiner hos begge hytter) vises ikke.
    expect(find.text('Steng-rutiner'), findsNothing);

    // Tilbake-knappen leder tilbake til bok-siden.
    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await settleUntil(
      tester,
      () => find.byTooltip('Søk i boka').evaluate().isNotEmpty,
    );
  });

  testWidgets('les hytta: kun valgte hytte vises', (tester) async {
    largeView(tester);
    final storage = makeStorage();
    await tester.runAsync(() => seed(storage));
    await pumpWithLoad(
      tester,
      HyttebokApp(repository: BookRepository(storage)),
    );

    await openBook(tester);

    // Åpne Fjellhytta.
    await tester.tap(find.text('Fjellhytta'));
    await settleUntil(
      tester,
      () => find.byTooltip('Les hytta').evaluate().isNotEmpty,
    );

    // Åpne lesevisningen fra hytte-siden.
    await tester.tap(find.byTooltip('Les hytta'));
    await settleUntil(
      tester,
      () => doc('Denne hytta er fra 1962.').evaluate().isNotEmpty,
    );

    // Fjellhyttas innhold (AppBar-tittel + dokument-overskrift).
    expect(find.text('Fjellhytta'), findsNWidgets(2));
    expect(find.text('Røros, 638 m.o.h.'), findsOneWidget);
    expect(doc('Denne hytta er fra 1962.'), findsOneWidget);
    expect(find.text('Åpne-rutiner'), findsOneWidget);
    expect(doc('Sjekk at dørene er låst'), findsOneWidget);

    await scrollReaderTo(tester, find.text('Skjult notat'));
    expect(doc('Kodelåsen er 1234.'), findsOneWidget);

    // Verken Sjøhytta eller bokens intro skal vises.
    expect(find.text('Sjøhytta'), findsNothing);
    expect(doc('Brygga er 20 meter lang.'), findsNothing);
    expect(doc('Her ligger alt vi må huske om hyttene.'), findsNothing);

    // Tilbake-knappen leder tilbake til hytte-siden.
    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await settleUntil(
      tester,
      () => find.byTooltip('Les hytta').evaluate().isNotEmpty,
    );
  });
}
