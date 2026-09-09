import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hyttebok/data/services/book_pdf.dart';
import 'package:hyttebok/domain/models/book.dart';
import 'package:hyttebok/domain/models/cabin.dart';
import 'package:hyttebok/domain/models/section.dart';
import 'package:hyttebok/domain/models/section_type.dart';
import 'package:hyttebok/domain/models/story.dart';

/// 1×1-piksels PNG (gyldig, rød piksel).
final Uint8List tinyPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // signature
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
  0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, // IDAT
  0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
  0x00, 0x03, 0x01, 0x01, 0x00, 0x18, 0xDD, 0x8D,
  0xBB, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, // IEND
  0x44, 0xAE, 0x42, 0x60,
]);

Book testBook({List<Cabin> cabins = const []}) => Book(
  slug: 'sommehytta',
  title: 'Sommehytta',
  intro: 'Velkommen til **hytta**. Vi holder det pent.',
  cabins: cabins,
  updatedAt: DateTime(2026, 7, 4),
);

Cabin testCabin() => Cabin(
  slug: 'hytta',
  name: 'Fjellhytta',
  location: 'Røros, 638 m.o.h.',
  description:
      'En koselig hytte i skogen.\n\n> Husk å feie peisen før sesongen.',
  startRoutines: const Section(
    slug: 'start-rutiner',
    title: 'Åpne-rutiner',
    type: SectionType.startRoutines,
    markdown:
        '- [ ] Slå på vannet\n- [x] Sjekk at dørene låses\n- Ta av skoene',
  ),
  stopRoutines: const Section(
    slug: 'steng-rutiner',
    title: 'Steng-rutiner',
    type: SectionType.stopRoutines,
    markdown: '- [ ] Steng vannet\n- [ ] Søppel ned til boksen',
  ),
  sections: const [
    Section(
      slug: 'strøm',
      title: 'Strøm & brytere',
      markdown: 'Hovedbryteren er i kjelleren.\n\n- Sikringer: boks på veggen',
    ),
  ],
  stories: [
    Story(
      slug: 'jul',
      title: 'Julebesøk',
      date: DateTime(2025, 12, 24),
      author: 'Kari',
      markdown: 'Det snørte fint i år.',
    ),
  ],
);

void main() {
  group('BookPdfExporter', () {
    test('fullbok lager gyldige PDF-byteer', () async {
      final bytes = await BookPdfExporter().exportPdf(
        testBook(cabins: [testCabin()]),
      );
      expect(bytes, isNotEmpty);
      // PDF-overskrift: %PDF
      expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
      // En fullbok bør bli en betydelig PDF.
      expect(bytes.length, greaterThan(1500));
    });

    test('tom bok (kun tittel) lager gyldig PDF', () async {
      final bytes = await BookPdfExporter().exportPdf(
        testBook(cabins: const []),
      );
      expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
    });

    test('bilde i markdown inlines i PDF-en', () async {
      final book = Book(
        slug: 'bilder',
        title: 'Bok med bilder',
        intro: 'Her er fasaden:\n\n![Fasaden](images/fasade.png)',
        updatedAt: DateTime(2026, 1, 1),
      );
      final without = await BookPdfExporter().exportPdf(book);

      final withImage = await BookPdfExporter().exportPdf(
        book,
        imageBytes: (rel) async {
          if (rel == 'images/fasade.png') return tinyPng;
          return null;
        },
      );

      // Bildet legger til bytes og et bilde-objekt i PDF-en (PDF-pakken
      // koder bildestreømmen selv, så råe PNG-bytes finnes ikke i strømmen).
      expect(withImage.length, greaterThan(without.length));
      expect(
        String.fromCharCodes(withImage).contains('/Image'),
        isTrue,
        reason: 'PDF-en bør inneholde et bilde-objekt',
      );
    });

    test('manglende bildefil faller tilbake til alt-tekst uten feil', () async {
      final book = Book(
        slug: 'mangler',
        title: 'Bok',
        intro: '![Fasaden](images/finnes-ikke.png)',
        updatedAt: DateTime(2026, 1, 1),
      );
      final bytes = await BookPdfExporter().exportPdf(
        book,
        imageBytes: (_) async => null,
      );
      expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
    });

    test('feilende imageBytes-kall knuser ikke eksporten', () async {
      final book = Book(
        slug: 'feil',
        title: 'Bok',
        intro: '![x](images/broken.png)',
        updatedAt: DateTime(2026, 1, 1),
      );
      final bytes = await BookPdfExporter().exportPdf(
        book,
        imageBytes: (_) async => throw StateError('disk feil'),
      );
      expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
    });

    test('uidentisk bildebytter hoppes over (decode-feil)', () async {
      final book = Book(
        slug: 'skrott',
        title: 'Bok',
        intro: '![x](images/skrott.png)',
        updatedAt: DateTime(2026, 1, 1),
      );
      final bytes = await BookPdfExporter().exportPdf(
        book,
        imageBytes: (_) async => Uint8List.fromList([1, 2, 3]),
      );
      expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
    });
  });
}
