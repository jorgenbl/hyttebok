import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hyttebok/data/repositories/book_repository.dart';
import 'package:hyttebok/data/services/file_storage_service.dart';
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
}
