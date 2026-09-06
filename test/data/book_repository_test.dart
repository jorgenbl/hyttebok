import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hyttebok/core/errors.dart';
import 'package:hyttebok/data/repositories/book_repository.dart';
import 'package:hyttebok/data/services/file_storage_service.dart';
import 'package:hyttebok/domain/models/book.dart';
import 'package:hyttebok/domain/models/cabin.dart';
import 'package:hyttebok/domain/models/section.dart';
import 'package:hyttebok/domain/models/section_type.dart';
import 'package:hyttebok/domain/models/story.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('hyttebok-repo-');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('BookRepository.importImage', () {
    test(
      'lagrer bildet under images/ og kan leses tilbake byte-for-byte',
      () async {
        final storage = FileStorageService(Directory('${tempDir.path}/books'));
        final repo = BookRepository(storage);
        final slug = await storage.createBook('Sommehytta');

        final src = File('${tempDir.path}/kilde.jpg')
          ..writeAsBytesSync([1, 2, 3, 4, 5]);

        final rel = await repo.importImage(slug, XFile(src.path));

        expect(rel.startsWith('images/'), isTrue);
        final bytes = await storage.readImageBytes(slug, rel);
        expect(bytes, [1, 2, 3, 4, 5]);
      },
    );

    test('gir unikt filnavn ved gjentatte import med samme kilde', () async {
      final storage = FileStorageService(Directory('${tempDir.path}/books'));
      final repo = BookRepository(storage);
      final slug = await storage.createBook('Sommehytta');

      final src = File('${tempDir.path}/samme.jpg')..writeAsBytesSync([9]);
      final a = await repo.importImage(slug, XFile(src.path));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final b = await repo.importImage(slug, XFile(src.path));

      expect(a, isNot(equals(b)));
    });
  });

  group('BookRepository eksport/import (Fase 2)', () {
    // Oppretter en bok med en hytte, en bilde-seksjon og en historie.
    Future<String> seedBook(
      FileStorageService storage, {
      required String title,
      required String location,
      required String imageExt,
      required Uint8List imageBytes,
    }) async {
      final slug = await storage.createBook(title);
      final book = Book(
        slug: slug,
        title: title,
        intro: 'Vår hytte i $location.',
        cabins: [
          Cabin(
            slug: slug,
            name: title,
            location: location,
            description: 'Koselig hytte med peis.',
            startRoutines: const Section(
              slug: 'start-rutiner',
              title: 'Åpne-rutiner',
              markdown: '1. Lukk husken.',
              type: SectionType.startRoutines,
              order: 1,
            ),
            stopRoutines: const Section(
              slug: 'steng-rutiner',
              title: 'Steng-rutiner',
              markdown: '1. Tøm søppel.',
              type: SectionType.stopRoutines,
              order: 2,
            ),
            sections: [
              Section(
                slug: 'galleri',
                title: 'Galleri',
                markdown: '![fasade](images/fasade.$imageExt)',
                images: ['images/fasade.$imageExt'],
                order: 0,
              ),
            ],
            stories: [
              const Story(
                slug: 'h-1',
                title: 'Helg',
                author: 'Ola',
                markdown: 'God tur.',
                order: 0,
              ),
            ],
            order: 0,
          ),
        ],
        updatedAt: DateTime.now(),
      );
      await storage.writeBook(book);
      await storage.saveImage(slug, imageBytes, filename: 'fasade.$imageExt');
      return slug;
    }

    test(
      'exportSingleFile + importFromMarkdown bevarer innhold og bilder',
      () async {
        final storage = FileStorageService(Directory('${tempDir.path}/books'));
        final exportDir = Directory('${tempDir.path}/export');
        final repo = BookRepository(storage, exportDir: exportDir);

        final slug = await seedBook(
          storage,
          title: 'Sommehytta',
          location: 'Røros',
          imageExt: 'jpg',
          imageBytes: Uint8List.fromList([1, 2, 3, 4, 5]),
        );

        final mdPath = await repo.exportSingleFile(slug);
        expect(File(mdPath).existsSync(), isTrue);
        expect(mdPath, endsWith('.md'));

        final content = File(mdPath).readAsStringSync();
        expect(content, contains('data:image/jpeg;base64,'));

        final newSlug = await repo.importFromMarkdown(content);
        expect(newSlug, isNot(equals(slug)));

        final imported = await storage.readBook(newSlug);
        expect(imported.title, equals('Sommehytta'));
        expect(imported.intro, equals('Vår hytte i Røros.'));
        final cabin = imported.cabins.single;
        expect(cabin.name, equals('Sommehytta'));
        expect(cabin.location, equals('Røros'));
        expect(cabin.description, contains('Koselig hytte med peis.'));
        expect(cabin.stories.single.title, equals('Helg'));

        // Bildet er trukket ut til en ny fil; bytepreservasjon + Markdown peker på den.
        final section = cabin.sections.first;
        final newRef = section.images.single;
        expect(newRef, startsWith('images/'));
        expect(
          File('${storage.bookRootPath(newSlug)}/$newRef').readAsBytesSync(),
          equals([1, 2, 3, 4, 5]),
        );
        expect(section.markdown, contains(newRef));
      },
    );

    test('exportZip + importFromZip round-tripper med bilder', () async {
      final storage = FileStorageService(Directory('${tempDir.path}/books2'));
      final exportDir = Directory('${tempDir.path}/export2');
      final repo = BookRepository(storage, exportDir: exportDir);

      final slug = await seedBook(
        storage,
        title: 'Vinterhytta',
        location: 'Dombås',
        imageExt: 'png',
        imageBytes: Uint8List.fromList([9, 8, 7, 6]),
      );

      final zipPath = await repo.exportZip(slug);
      expect(File(zipPath).existsSync(), isTrue);
      expect(zipPath, endsWith('.zip'));

      final newSlug = await repo.importFromZip(zipPath);
      expect(newSlug, isNot(equals(slug)));

      final imported = await storage.readBook(newSlug);
      final cabin = imported.cabins.single;
      expect(cabin.name, equals('Vinterhytta'));
      expect(cabin.location, equals('Dombås'));
      expect(cabin.description, equals('Koselig hytte med peis.'));

      // I zip-mappen kopieres bildene slik de er (ingen omnavngivning).
      final ref = cabin.sections.first.images.single;
      expect(ref, equals('images/fasade.png'));
      expect(
        File('${storage.bookRootPath(newSlug)}/$ref').readAsBytesSync(),
        equals([9, 8, 7, 6]),
      );
    });

    test('importFromMarkdown kaster InvalidBookFile for tom innhold', () async {
      final storage = FileStorageService(Directory('${tempDir.path}/books3'));
      final repo = BookRepository(storage);
      await expectLater(
        repo.importFromMarkdown('   \n  '),
        throwsA(isA<InvalidBookFile>()),
      );
    });

    test('importFromPath kaster InvalidBookFile for ukjent filtype', () async {
      final storage = FileStorageService(Directory('${tempDir.path}/books4'));
      final repo = BookRepository(storage);
      final txt = File('${tempDir.path}/note.txt')
        ..writeAsStringSync('heisann');
      await expectLater(
        repo.importFromPath(txt.path),
        throwsA(isA<InvalidBookFile>()),
      );
    });

    test('importFromZip kaster InvalidBookFile for ikke-zip', () async {
      final storage = FileStorageService(Directory('${tempDir.path}/books5'));
      final repo = BookRepository(storage);
      final fake = File('${tempDir.path}/fake.zip')
        ..writeAsStringSync('ikkje ei zip');
      await expectLater(
        repo.importFromZip(fake.path),
        throwsA(isA<InvalidBookFile>()),
      );
    });
  });
}
