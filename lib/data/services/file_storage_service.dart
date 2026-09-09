import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../core/errors.dart';
import '../../core/utils/slug.dart';
import '../../domain/models/book.dart';
import '../../domain/models/book_meta.dart';
import 'book_files.dart';
import 'book_storage.dart';
import 'frontmatter.dart';

export 'book_files.dart' show kFormatVersion;

/// Tjenest som abstraherer alt filsystem-io for hyttebøker (mobil/desktop).
///
/// En **bok er en mappe** med `book.md`, `images/` og `cabins/`.
/// Serialiseringen av selve mappestrukturen ligger i [serializeBookFiles]/
/// [deserializeBookFiles] (ren, testbar og delt med web-lagringen); denne
/// klassen bare putter kartet på disk. Basis-mappen gis i konstruktoren: på
/// enheten skal den komme fra `path_provider`; i tester fra en temp-mappe.
class FileStorageService implements BookStorage {
  FileStorageService(this._baseDirectory);

  final Directory _baseDirectory;

  // --------------------------------------------------------------------------
  // Bøker
  // --------------------------------------------------------------------------

  Directory _bookDir(String slug) =>
      Directory(p.join(_baseDirectory.path, slug));

  /// Absolutt mappe for boken (brukes til å løse opp lokale bilder).
  String bookRootPath(String slug) => p.join(_baseDirectory.path, slug);

  @override
  Future<String> createBook(String title, {String intro = ''}) async {
    var base = slugify(title);
    if (base.isEmpty) base = 'bok';
    var candidate = base;
    var i = 2;
    while (_bookDir(candidate).existsSync()) {
      candidate = '$base-$i';
      i++;
    }
    final book = Book(
      slug: candidate,
      title: title.trim().isEmpty ? candidate : title,
      intro: intro,
      updatedAt: DateTime.now(),
    );
    await writeBook(book);
    return candidate;
  }

  @override
  Future<List<BookMeta>> listBooks() async {
    if (!_baseDirectory.existsSync()) return const [];
    final metas = <BookMeta>[];
    for (final entity in _baseDirectory.listSync()) {
      if (entity is! Directory) continue;
      final bookFile = File(p.join(entity.path, 'book.md'));
      if (!bookFile.existsSync()) continue;
      final fm = parseFrontmatter(bookFile.readAsStringSync());
      final title = (fm.meta['title'] as String?) ?? p.basename(entity.path);
      final updatedAt =
          _parseDateTime(fm.meta['updated']) ?? bookFile.lastModifiedSync();
      metas.add(
        BookMeta(
          slug: p.basename(entity.path),
          title: title,
          updatedAt: updatedAt,
        ),
      );
    }
    metas.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return metas;
  }

  @override
  Future<Book> readBook(String slug) async {
    final bookDir = _bookDir(slug);
    if (!bookDir.existsSync()) throw BookNotFound(slug);
    if (!File(p.join(bookDir.path, 'book.md')).existsSync()) {
      throw CorruptBook(slug);
    }

    final files = <String, String>{};
    for (final entity in bookDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.md')) continue;
      files[_relativePosix(bookDir.path, entity.path)] = entity
          .readAsStringSync();
    }
    return deserializeBookFiles(slug, files);
  }

  @override
  Future<void> writeBook(Book book) async {
    final bookDir = _bookDir(book.slug);
    await bookDir.create(recursive: true);
    await Directory(p.join(bookDir.path, 'images')).create(recursive: true);

    // Nullstill cabins/ slik at fjernet innhold forsvinner, så skriv på nytt.
    final cabinsDir = Directory(p.join(bookDir.path, 'cabins'));
    if (cabinsDir.existsSync()) {
      await cabinsDir.delete(recursive: true);
    }

    for (final entry in serializeBookFiles(book).entries) {
      final file = File(p.join(bookDir.path, entry.key));
      await file.parent.create(recursive: true);
      await file.writeAsString(entry.value);
    }
  }

  @override
  Future<void> deleteBook(String slug) async {
    final bookDir = _bookDir(slug);
    if (bookDir.existsSync()) {
      await bookDir.delete(recursive: true);
    }
  }

  // --------------------------------------------------------------------------
  // Bilder
  // --------------------------------------------------------------------------

  @override
  Future<String> saveImage(
    String bookSlug,
    Uint8List bytes, {
    required String filename,
  }) async {
    final safeName = p.basename(filename); // unngå path-traversal
    final imagesDir = Directory(p.join(_bookDir(bookSlug).path, 'images'));
    await imagesDir.create(recursive: true);
    await File(p.join(imagesDir.path, safeName)).writeAsBytes(bytes);
    return 'images/$safeName';
  }

  @override
  Future<Uint8List> readImageBytes(String bookSlug, String relativePath) async {
    final file = File(p.join(_bookDir(bookSlug).path, relativePath));
    if (!file.existsSync()) throw ImageNotFound(relativePath);
    return file.readAsBytesSync();
  }

  // --------------------------------------------------------------------------
  // Alle filer (zip-eksport)
  // --------------------------------------------------------------------------

  @override
  Future<List<StorageFile>> listBookFiles(String slug) async {
    final bookDir = _bookDir(slug);
    if (!bookDir.existsSync()) throw BookNotFound(slug);
    final files = <StorageFile>[];
    for (final entity in bookDir.listSync(recursive: true)) {
      if (entity is! File) continue;
      files.add(
        StorageFile(
          _relativePosix(bookDir.path, entity.path),
          entity.readAsBytesSync(),
        ),
      );
    }
    return files;
  }

  /// Relativ sti med posiks-skråstreker (filene i boka bruker alltid `/`).
  static String _relativePosix(String from, String path) {
    final rel = path.substring(from.length + 1);
    return rel.split(p.separator).join('/');
  }

  // --------------------------------------------------------------------------
  // Hjelpere
  // --------------------------------------------------------------------------

  DateTime? _parseDateTime(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      final s = value.trim();
      if (s.isEmpty) return null;
      try {
        return DateTime.parse(s);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
