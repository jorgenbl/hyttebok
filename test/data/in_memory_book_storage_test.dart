import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hyttebok/core/errors.dart';
import 'package:hyttebok/data/services/book_files.dart';
import 'package:hyttebok/data/services/in_memory_book_storage.dart';
import 'package:hyttebok/domain/models/book.dart';
import 'package:hyttebok/domain/models/cabin.dart';
import 'package:hyttebok/domain/models/section.dart';
import 'package:hyttebok/domain/models/section_type.dart';
import 'package:hyttebok/domain/models/story.dart';

/// Web-lagringen ([InMemoryBookStorage]) må gi nøyaktig samme atferd som
/// filbasert lagring: full round-trip av bok + bilder.
void main() {
  Book testBook({List<Cabin> cabins = const []}) => Book(
    slug: 'sommehytta',
    title: 'Sommehytta',
    intro: 'Vår hytte i Røros.',
    cabins: cabins,
    updatedAt: DateTime(2026, 7, 4),
  );

  Cabin testCabin() => Cabin(
    slug: 'hytta',
    name: 'Fjellhytta',
    location: 'Røros, 638 m.o.h.',
    description: 'Koselig hytte med peis.',
    startRoutines: const Section(
      slug: 'start-rutiner',
      title: 'Åpne-rutiner',
      type: SectionType.startRoutines,
      markdown: '- [ ] Slå på vannet\n- [x] Sjekk dørene',
      order: 1,
    ),
    stopRoutines: const Section(
      slug: 'steng-rutiner',
      title: 'Steng-rutiner',
      type: SectionType.stopRoutines,
      markdown: '- [ ] Søppel ned',
      order: 2,
    ),
    sections: const [
      Section(
        slug: 'strøm',
        title: 'Strøm & brytere',
        markdown: 'Hovedbryteren er i kjelleren.',
        order: 0,
      ),
    ],
    stories: [
      Story(
        slug: 'jul',
        title: 'Julebesøk',
        date: DateTime(2025, 12, 24),
        author: 'Kari',
        markdown: 'Det snørte fint i år.',
        order: 0,
      ),
    ],
    order: 0,
  );

  test('create + read round-tripper en tom bok', () async {
    final storage = InMemoryBookStorage();
    final slug = await storage.createBook('Sommehytta');
    expect(slug, 'sommehytta');

    final book = await storage.readBook(slug);
    expect(book.title, 'Sommehytta');
    expect(book.cabins, isEmpty);
  });

  test('slug-kollisjon suffikses -2, -3', () async {
    final storage = InMemoryBookStorage();
    final a = await storage.createBook('Sommehytta');
    final b = await storage.createBook('Sommehytta');
    expect(a, 'sommehytta');
    expect(b, 'sommehytta-2');
  });

  test('full bok (hytte + seksjoner + historie) round-tripper', () async {
    final storage = InMemoryBookStorage();
    final slug = await storage.createBook('Sommehytta');
    final book = await storage.readBook(slug);
    await storage.writeBook(
      book.copyWith(cabins: [testCabin()]),
    );

    final read = await storage.readBook(slug);
    final cabin = read.cabins.single;
    expect(cabin.name, 'Fjellhytta');
    expect(cabin.location, 'Røros, 638 m.o.h.');
    expect(cabin.startRoutines.markdown, contains('Slå på vannet'));
    expect(cabin.stopRoutines.markdown, contains('Søppel ned'));
    expect(cabin.sections.single.title, 'Strøm & brytere');
    expect(cabin.stories.single.title, 'Julebesøk');
    expect(cabin.stories.single.date, DateTime(2025, 12, 24));
    expect(cabin.stories.single.author, 'Kari');
  });

  test('writeBook synkroniserer: fjernet hytte forsvinner', () async {
    final storage = InMemoryBookStorage();
    final slug = await storage.createBook('Sommehytta');
    final withCabin = (await storage.readBook(slug)).copyWith(
      cabins: [testCabin()],
    );
    await storage.writeBook(withCabin);
    expect((await storage.readBook(slug)).cabins, hasLength(1));

    await storage.writeBook(withCabin.copyWith(cabins: const []));
    expect((await storage.readBook(slug)).cabins, isEmpty);
  });

  test('bilder lagres og leses byte-for-byte', () async {
    final storage = InMemoryBookStorage();
    final slug = await storage.createBook('Sommehytta');
    final bytes = Uint8List.fromList([1, 2, 3, 4]);

    final rel = await storage.saveImage(slug, bytes, filename: 'fasade.jpg');
    expect(rel, 'images/fasade.jpg');

    final read = await storage.readImageBytes(slug, rel);
    expect(read, [1, 2, 3, 4]);
  });

  test('manglende bilde kaster ImageNotFound', () async {
    final storage = InMemoryBookStorage();
    final slug = await storage.createBook('Sommehytta');
    expect(
      () => storage.readImageBytes(slug, 'images/finnes-ikke.jpg'),
      throwsA(isA<ImageNotFound>()),
    );
  });

  test('path-traversal i filnavn beskjæres til base-navn', () async {
    final storage = InMemoryBookStorage();
    final slug = await storage.createBook('Sommehytta');
    final rel = await storage.saveImage(
      slug,
      Uint8List.fromList([1]),
      filename: '../../skadet.png',
    );
    expect(rel, 'images/skadet.png');
  });

  test('listBooks sorterer nyest først', () async {
    final storage = InMemoryBookStorage();
    final a = await storage.createBook('A');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final b = await storage.createBook('B');

    final metas = await storage.listBooks();
    expect(metas.map((m) => m.slug).toList(), [b, a]);
  });

  test('deleteBook fjerner bok og bilder', () async {
    final storage = InMemoryBookStorage();
    final slug = await storage.createBook('Sommehytta');
    await storage.saveImage(slug, Uint8List.fromList([1]), filename: 'x.jpg');

    await storage.deleteBook(slug);
    expect(() => storage.readBook(slug), throwsA(isA<BookNotFound>()));
    expect(
      () => storage.readImageBytes(slug, 'images/x.jpg'),
      throwsA(isA<ImageNotFound>()),
    );
  });

  test('listBookFiles gir Markdown + bilder (zip-eksport)', () async {
    final storage = InMemoryBookStorage();
    final slug = await storage.createBook('Sommehytta');
    final book = await storage.readBook(slug);
    await storage.writeBook(book.copyWith(cabins: [testCabin()]));
    await storage.saveImage(
      slug,
      Uint8List.fromList([9, 8, 7]),
      filename: 'fasade.png',
    );

    final files = await storage.listBookFiles(slug);
    final names = files.map((f) => f.relativePath).toSet();
    expect(names, contains('book.md'));
    expect(names, contains('cabins/hytta/cabin.md'));
    expect(names, contains('cabins/hytta/start-rutiner.md'));
    expect(names, contains('cabins/hytta/steng-rutiner.md'));
    expect(names, contains('cabins/hytta/strøm.md'));
    expect(names, contains('cabins/hytta/historier/jul.md'));
    expect(names, contains('images/fasade.png'));

    final image = files.firstWhere((f) => f.relativePath == 'images/fasade.png');
    expect(image.bytes, [9, 8, 7]);
  });

  test('manglende bok kaster BookNotFound fra listBookFiles', () async {
    final storage = InMemoryBookStorage();
    expect(
      () => storage.listBookFiles('finnes-ikke'),
      throwsA(isA<BookNotFound>()),
    );
  });

  test('serializeBookFiles og deserializeBookFiles er inverse', () async {
    final book = testBook(cabins: [testCabin()]);
    final files = serializeBookFiles(book);
    final back = deserializeBookFiles(book.slug, files);
    expect(back.title, book.title);
    expect(back.intro, book.intro);
    expect(back.updatedAt, book.updatedAt);
    expect(back.cabins.single.name, book.cabins.single.name);
    expect(
      back.cabins.single.startRoutines.markdown,
      book.cabins.single.startRoutines.markdown,
    );
  });
}
