import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hyttebok/data/services/book_markdown.dart';
import 'package:hyttebok/domain/models/book.dart';
import 'package:hyttebok/domain/models/cabin.dart';
import 'package:hyttebok/domain/models/section.dart';
import 'package:hyttebok/domain/models/section_type.dart';
import 'package:hyttebok/domain/models/story.dart';

/// En «kanonisk» bok der feltene ligger slik parseren produserer dem, slik at
/// round-trip kan testes med nøyaktig likhet. Ingen bilder (ren tekst).
Book _sampleBook() {
  return Book(
    slug: 'sommehytta',
    title: 'Sommehytta',
    intro: 'Velkommen til Sommehytta, vår base i Røros.',
    coverImage: 'images/cover.png',
    cabins: [
      Cabin(
        slug: 'sommehytta',
        name: 'Sommehytta',
        location: 'Røros',
        description: 'En koselig trehytte med peis.\nBygget i 1962.',
        startRoutines: const Section(
          slug: 'start-rutiner',
          title: 'Åpne-rutiner',
          markdown: '1. Lukk husken.\n2. Sjekk fyringsolje.',
          type: SectionType.startRoutines,
          order: 1,
        ),
        stopRoutines: const Section(
          slug: 'steng-rutiner',
          title: 'Steng-rutiner',
          markdown: '1. Tøm søppel.\n2. Snu madrass.',
          type: SectionType.stopRoutines,
          order: 2,
        ),
        sections: const [
          Section(
            slug: 'vann-og-el',
            title: 'Vann og el',
            markdown: 'Vannkranen er i kjelleren. El: 220V i stua.',
            type: SectionType.egen,
            order: 0,
          ),
        ],
        stories: [
          const Story(
            slug: 'jul-2025',
            title: 'Julebesøk 2025',
            author: 'Familien Hansen',
            markdown: 'En herlig helg med god mat.',
            order: 0,
          ),
          Story(
            slug: 'sommer-2026',
            title: 'Sommer 2026',
            date: DateTime(2026, 3, 14),
            author: 'Ola',
            markdown: 'Reparerte taket.',
            order: 1,
          ),
        ],
        order: 0,
      ),
    ],
    updatedAt: DateTime(2026, 1, 1, 10, 30),
  );
}

Future<Book> _roundTrip(Book book, {Uint8List? pngFor}) async {
  final md = await bookToSingleFile(
    book,
    imageBytes: (rel) async =>
        pngFor != null && rel == 'images/fasade.png' ? pngFor : null,
  );
  return singleFileToBook(
    md,
    slug: book.slug,
    saveImage: (name, bytes) async => 'images/$name',
  );
}

void main() {
  group('bookToSingleFile / singleFileToBook (round-trip)', () {
    test('ren tekst gir nøyaktig identisk Book', () async {
      final original = _sampleBook();
      final imported = await _roundTrip(original);
      expect(imported, equals(original));
    });

    test('bok med kun intro og ingen hytter round-tripper', () async {
      final original = Book(
        slug: 'min-bok',
        title: 'Min bok',
        intro: 'Kun en side så langt.',
        updatedAt: DateTime(2026, 1, 1),
      );
      final imported = await _roundTrip(original);
      expect(imported, equals(original));
    });

    test('skjult (hidden) seksjon round-tripper', () async {
      final original = Book(
        slug: 'skjult',
        title: 'Skjult',
        updatedAt: DateTime(2026, 1, 1),
        cabins: [
          Cabin(
            slug: 'hytta',
            name: 'Hytta',
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
                slug: 'synlig',
                title: 'Synlig',
                markdown: 'Synlig seksjon.',
                order: 0,
              ),
              Section(
                slug: 'kjeller',
                title: 'Kjeller',
                markdown: 'Dette er skjult.',
                order: 1,
                hidden: true,
              ),
            ],
            order: 0,
          ),
        ],
      );

      final md = await bookToSingleFile(
        original,
        imageBytes: (_) async => null,
      );
      // Markøren bærer hidden=true for den skjulte seksjonen.
      expect(md, contains('hidden=true'));

      final imported = await _roundTrip(original);
      final sections = imported.cabins.first.sections;
      expect(sections.length, 2);
      expect(sections[0].slug, 'synlig');
      expect(sections[0].hidden, isFalse);
      expect(sections[1].slug, 'kjeller');
      expect(sections[1].hidden, isTrue);
      // Innholdet er likevel bevart (tap-fri).
      expect(sections[1].markdown, 'Dette er skjult.');
    });

    test('norsk tekst og spesialtegn round-tripper i tittel og felt', () async {
      final original = Book(
        slug: 'hjemmet',
        title: 'Hjemmet – ø, æ og å',
        updatedAt: DateTime(2026, 1, 1),
        cabins: [
          Cabin(
            slug: 'hytta',
            name: 'Hytta på Fjelltunet',
            location: 'Løten, Østerdalen',
            description: 'Været var *bra* og temperaturen -12°C.',
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
            order: 0,
          ),
        ],
      );
      final imported = await _roundTrip(original);
      expect(imported, equals(original));
    });

    test(
      'bilde inlines som base64 ved eksport og trekkes ut ved import',
      () async {
        final png = Uint8List.fromList([
          137,
          80,
          78,
          71,
          13,
          10,
          26,
          10,
        ]); // PNG-magi
        final original = Book(
          slug: 'bilder',
          title: 'Bilder',
          updatedAt: DateTime(2026, 1, 1),
          cabins: [
            Cabin(
              slug: 'hytta',
              name: 'Hytta',
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
                  slug: 'galleri',
                  title: 'Galleri',
                  markdown: 'Se fasaden:\n![fasade](images/fasade.png)',
                  images: ['images/fasade.png'],
                  order: 0,
                ),
              ],
              order: 0,
            ),
          ],
        );

        final md = await bookToSingleFile(
          original,
          imageBytes: (rel) async => rel == 'images/fasade.png' ? png : null,
        );

        // Bilder inlines som data-uri (ikke som filreferanse) i Markdown.
        expect(md, contains('data:image/png;base64,'));
        expect(md, contains(base64Encode(png)));
        expect(md, isNot(contains('![fasade](images/fasade.png)')));

        String? savedName;
        Uint8List? savedBytes;
        final imported = await singleFileToBook(
          md,
          slug: 'bilder',
          saveImage: (name, bytes) async {
            savedName = name;
            savedBytes = bytes;
            return 'images/$name';
          },
        );

        // Bytepreservasjon og at Markdown peker på det uttrakne bildet.
        expect(savedBytes, equals(png));
        expect(savedName, equals('imported-0.png'));
        final section = imported.cabins.first.sections.first;
        expect(section.markdown, contains('images/imported-0.png'));
        expect(section.images, equals(['images/imported-0.png']));
      },
    );
  });
}
