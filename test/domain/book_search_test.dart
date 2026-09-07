import 'package:flutter_test/flutter_test.dart';
import 'package:hyttebok/domain/models/book.dart';
import 'package:hyttebok/domain/models/cabin.dart';
import 'package:hyttebok/domain/models/section.dart';
import 'package:hyttebok/domain/models/section_type.dart';
import 'package:hyttebok/domain/models/story.dart';
import 'package:hyttebok/domain/search/book_search.dart';

Book _sampleBook() => Book(
  slug: 'sommehytta',
  title: 'Sommehytta',
  intro: 'Her ligger alt vi må huske om hytta.',
  updatedAt: DateTime(2026, 1, 1),
  cabins: [
    Cabin(
      slug: 'hytta',
      name: 'Fjellhytta',
      location: 'Røros, 638 m.o.h.',
      description: 'En koselig trehytte med peis.',
      startRoutines: const Section(
        slug: 'start-rutiner',
        title: 'Åpne-rutiner',
        type: SectionType.startRoutines,
        order: 1,
        markdown: '- [ ] Slå på strømmen i bryterkassen',
      ),
      stopRoutines: const Section(
        slug: 'steng-rutiner',
        title: 'Steng-rutiner',
        type: SectionType.stopRoutines,
        order: 2,
        markdown: '- [ ] Tøm søpla',
      ),
      sections: [
        const Section(
          slug: 'vann',
          title: 'Vann og el',
          order: 0,
          markdown: 'Vannkranen er i kjelleren. El: 220V.',
        ),
        // Skjult seksjon skal likevel bli funnet (søk i hele boken).
        const Section(
          slug: 'kjeller',
          title: 'Kjeller',
          order: 1,
          markdown: 'Skjult notat om kjelleren.',
          hidden: true,
        ),
      ],
      stories: const [
        Story(
          slug: 'jul-2025',
          title: 'Første jul',
          markdown: 'Peisen sto i fra morgen til kveld.',
          order: 0,
        ),
      ],
    ),
  ],
);

void main() {
  test('tom eller mellomromsquery gir ingen treff', () {
    expect(searchBook(_sampleBook(), ''), isEmpty);
    expect(searchBook(_sampleBook(), '   '), isEmpty);
  });

  test('funner treff i forside (cabinSlug er null)', () {
    final r = searchBook(_sampleBook(), 'må huske');
    expect(r, hasLength(1));
    expect(r.single.title, 'Forsiden');
    expect(r.single.cabinSlug, isNull);
  });

  test('funner hytte etter navn og sted', () {
    expect(
      searchBook(_sampleBook(), 'fjellhytta').map((r) => r.cabinSlug).toList(),
      contains('hytta'),
    );
    expect(
      searchBook(_sampleBook(), 'røros').map((r) => r.title).toList(),
      contains('Fjellhytta'),
    );
  });

  test('funner treff i beskrivelse, rutiner, seksjon og historie', () {
    expect(
      searchBook(_sampleBook(), 'peis').map((r) => r.title).toList(),
      contains('Beskrivelse'),
    );
    expect(
      searchBook(_sampleBook(), 'bryterkassen').map((r) => r.title).toList(),
      contains('Åpne-rutiner'),
    );
    expect(
      searchBook(_sampleBook(), 'kjelleren').map((r) => r.title).toList(),
      contains('Vann og el'),
    );
    expect(
      searchBook(
        _sampleBook(),
        'morgen til kveld',
      ).map((r) => r.location).toList(),
      contains('Fjellhytta · Historier'),
    );
  });

  test('funner også skjulte seksjoner (søk gjelder hele boken)', () {
    final r = searchBook(_sampleBook(), 'skjult notat');
    expect(r, hasLength(1));
    expect(r.single.title, 'Kjeller');
    expect(r.single.cabinSlug, 'hytta');
  });

  test('matching er case-uavhengig', () {
    expect(searchBook(_sampleBook(), 'PEIS'), isNotEmpty);
    expect(searchBook(_sampleBook(), 'Peis'), isNotEmpty);
  });

  test('ingen treff gir tom liste', () {
    expect(searchBook(_sampleBook(), 'banan'), isEmpty);
  });

  test('snippet inneholder matchen', () {
    final r = searchBook(
      _sampleBook(),
      'Vannkranen',
    ).firstWhere((r) => r.title == 'Vann og el');
    expect(r.snippet.toLowerCase(), contains('vannkranen'));
  });
}
