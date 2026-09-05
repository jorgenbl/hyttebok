import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hyttebok/core/errors.dart';
import 'package:hyttebok/core/utils/slug.dart';
import 'package:hyttebok/data/services/file_storage_service.dart';
import 'package:hyttebok/data/services/frontmatter.dart';
import 'package:hyttebok/domain/models/book.dart';
import 'package:hyttebok/domain/models/cabin.dart';
import 'package:hyttebok/domain/models/section.dart';
import 'package:hyttebok/domain/models/section_type.dart';
import 'package:hyttebok/domain/models/story.dart';

void main() {
  late Directory tempDir;
  late FileStorageService storage;

  Directory bookDir(String slug) => Directory('${tempDir.path}/$slug');

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('hyttebok-test-');
    storage = FileStorageService(tempDir);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Book sampleBook() => Book(
    slug: 'sommehytta',
    title: 'Sommehytta',
    intro: 'Velkommen til boka vår.',
    coverImage: 'images/fasade.png',
    updatedAt: DateTime(2026, 9, 5, 12, 0, 0),
    cabins: [
      Cabin(
        slug: 'fjellhytta',
        name: 'Fjellhytta, Røros',
        location: 'Røros, 638 m.o.h.',
        description: 'Beskrivelse av hytta.',
        order: 0,
        startRoutines: Section(
          slug: 'start-rutiner',
          title: 'Åpne-rutiner',
          type: SectionType.startRoutines,
          order: 1,
          markdown: '- [ ] Slå på strømmen\n- [ ] Tenn peis',
        ),
        stopRoutines: Section(
          slug: 'steng-rutiner',
          title: 'Steng-rutiner',
          type: SectionType.stopRoutines,
          order: 2,
          markdown: '- [ ] Tøm søpla',
        ),
        sections: [
          Section(
            slug: 'ved',
            title: 'Ved',
            type: SectionType.notater,
            order: 3,
            markdown: 'Om lag 4 sekk gjenstår.',
            images: ['images/ved.jpg'],
          ),
        ],
        stories: [
          Story(
            slug: '2023-12-23-forste-jul',
            title: 'Første jul',
            date: DateTime(2023, 12, 23),
            author: 'Jorgen & Ingrid',
            markdown: 'En koselig jul.',
            images: ['images/peisen.jpg'],
            order: 0,
          ),
        ],
      ),
    ],
  );

  group('round-trip', () {
    test('writeBook → readBook gir en likeverdig bok', () async {
      final book = sampleBook();
      await storage.saveImage(
        'sommehytta',
        Uint8List.fromList([1, 2, 3]),
        filename: 'fasade.png',
      );
      await storage.writeBook(book);

      final read = await storage.readBook('sommehytta');
      expect(read, equals(book));
    });

    test('bilder kan leses tilbake byte-for-byte', () async {
      final bytes = Uint8List.fromList([7, 8, 9]);
      await storage.saveImage('sommehytta', bytes, filename: 'peisen.jpg');
      await storage.writeBook(sampleBook());

      final readBack = await storage.readImageBytes(
        'sommehytta',
        'images/peisen.jpg',
      );
      expect(readBack, equals(bytes));
    });
  });

  group('createBook / listBooks', () {
    test('oppretter bok med slugifisert navn', () async {
      final slug = await storage.createBook('Sommehytta', intro: 'Hei');
      expect(slug, equals('sommehytta'));
      final meta = await storage.listBooks();
      expect(meta, hasLength(1));
      expect(meta.single.slug, equals('sommehytta'));
      expect(meta.single.title, equals('Sommehytta'));
    });

    test('unik slug ved navnekollisjon', () async {
      final a = await storage.createBook('Sommehytta');
      final b = await storage.createBook('Sommehytta');
      expect(a, isNot(equals(b)));
      final slugs = (await storage.listBooks()).map((m) => m.slug).toList();
      expect(slugs, containsAll([a, b]));
    });
  });

  group('deleteBook', () {
    test('fjerner boka og mappen', () async {
      final slug = await storage.createBook('Test');
      await storage.deleteBook(slug);
      expect(await storage.listBooks(), isEmpty);
      expect(bookDir(slug).existsSync(), isFalse);
    });
  });

  group('feil', () {
    test('readBook kaster BookNotFound for ukjent slug', () async {
      expect(storage.readBook('finnes-ikke'), throwsA(isA<BookNotFound>()));
    });

    test('readImageBytes kaster ImageNotFound for manglende bilde', () async {
      await storage.createBook('Test');
      expect(
        storage.readImageBytes('test', 'images/banant.jpg'),
        throwsA(isA<ImageNotFound>()),
      );
    });
  });

  group('frontmatter', () {
    test('withFrontmatter → parseFrontmatter round-trip', () {
      final raw = withFrontmatter({
        'type': 'book',
        'title': 'Hei, verden',
        'version': 1,
      }, 'Brødtekst');
      final fm = parseFrontmatter(raw);
      expect(fm.meta['type'], equals('book'));
      expect(fm.meta['title'], equals('Hei, verden'));
      expect(fm.meta['version'], equals(1));
      expect(fm.body, equals('Brødtekst'));
    });

    test('fil uten frontmatter behandles som ren brødtekst', () {
      final fm = parseFrontmatter('Bare tekst\nuten metadata');
      expect(fm.meta, isEmpty);
      expect(fm.body, equals('Bare tekst\nuten metadata'));
    });
  });

  group('slugify', () {
    test('folder norske bokstaver og fjerner spesialtegn', () {
      expect(slugify('Fjellhytta, Røros'), equals('fjellhytta-roros'));
      expect(slugify('  Min   Hytte  '), equals('min-hytte'));
      expect(slugify('Æble & Øl'), equals('aeble-ol'));
    });
  });
}
