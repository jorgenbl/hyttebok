import 'dart:convert';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../core/errors.dart';
import '../../core/utils/slug.dart';
import '../../domain/models/book.dart';
import '../../domain/models/book_meta.dart';
import 'book_files.dart';
import 'book_storage.dart';

/// Boklagring i minnet – web-versjonens økt-lagring (F17).
///
/// Web har ingen filsystem; bøkene holdes i en mappe i minnet med samme
/// struktur som på disk (via [serializeBookFiles]). Bøkene forsvinner når
/// økten gjør det – appen viser et banner som peker på eksport/import som
/// måte å ta boken med seg på.
class InMemoryBookStorage implements BookStorage {
  final Map<String, Book> _books = {};
  final Map<String, Map<String, Uint8List>> _images = {};

  @override
  Future<String> createBook(String title, {String intro = ''}) async {
    var base = slugify(title);
    if (base.isEmpty) base = 'bok';
    var candidate = base;
    var i = 2;
    while (_books.containsKey(candidate)) {
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
    final metas = _books.values
        .map((book) => BookMeta(
          slug: book.slug,
          title: book.title,
          updatedAt: book.updatedAt,
        ))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return metas;
  }

  @override
  Future<Book> readBook(String slug) async {
    final book = _books[slug];
    if (book == null) throw BookNotFound(slug);
    return book;
  }

  @override
  Future<void> writeBook(Book book) async {
    _books[book.slug] = book;
    _images.putIfAbsent(book.slug, () => {});
  }

  @override
  Future<void> deleteBook(String slug) async {
    _books.remove(slug);
    _images.remove(slug);
  }

  @override
  Future<String> saveImage(
    String bookSlug,
    Uint8List bytes, {
    required String filename,
  }) async {
    final safeName = p.basename(filename); // unngå path-traversal
    final images = _images.putIfAbsent(bookSlug, () => {});
    final relative = 'images/$safeName';
    images[relative] = bytes;
    return relative;
  }

  @override
  Future<Uint8List> readImageBytes(String bookSlug, String relativePath) async {
    final bytes = _images[bookSlug]?[relativePath];
    if (bytes == null) throw ImageNotFound(relativePath);
    return bytes;
  }

  @override
  Future<List<StorageFile>> listBookFiles(String slug) async {
    final book = _books[slug];
    if (book == null) throw BookNotFound(slug);
    final files = <StorageFile>[];
    for (final entry in serializeBookFiles(book).entries) {
      files.add(
        StorageFile(entry.key, Uint8List.fromList(utf8.encode(entry.value))),
      );
    }
    for (final entry in (_images[slug] ?? const <String, Uint8List>{}).entries) {
      files.add(StorageFile(entry.key, entry.value));
    }
    return files;
  }
}
