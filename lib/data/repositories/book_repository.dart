import 'dart:io';

import 'package:image_picker/image_picker.dart' show XFile;
import 'package:path/path.dart' as p;

import '../../domain/models/book.dart';
import '../../domain/models/book_meta.dart';
import '../services/file_storage_service.dart';

/// Én sannhetskilde for bøker i datalaget.
///
/// Tynn over [FileStorageService]: presenterer domänmodeller og skjuler fil-io
/// for ViewModels/Use Cases. `save` skriver boka slik den er gitt (kalleren setter
/// selv `updatedAt`).
class BookRepository {
  BookRepository(this._storage);

  final FileStorageService _storage;

  /// Alle bøker (metadata), nyest først.
  Future<List<BookMeta>> listBooks() => _storage.listBooks();

  /// Last en hel bok. Kaster [BookNotFound]/[CorruptBook] fra underlying service.
  Future<Book> load(String slug) => _storage.readBook(slug);

  /// Opprett en tom bok, returnerer slug.
  Future<String> create(String title, {String intro = ''}) =>
      _storage.createBook(title, intro: intro);

  /// Skriv en hel bok (full synkronisering).
  Future<void> save(Book book) => _storage.writeBook(book);

  /// Slett en bok.
  Future<void> delete(String slug) => _storage.deleteBook(slug);

  /// Importerer et plukket bilde [file] inn i boken og returnerer den
  /// relative stien (f.eks. `images/img-20260105-123456-123.jpg`).
  ///
  /// Filen får et unikt navn basert på tidspunkt, slik at to bilder med samme
  /// opprinnelige navn ikke overskriver hverandre.
  Future<String> importImage(String bookSlug, XFile file) async {
    final bytes = await file.readAsBytes();
    final ext = _extensionOf(file.name);
    final relative = await _storage.saveImage(
      bookSlug,
      bytes,
      filename: _uniqueImageName(ext),
    );
    return relative;
  }

  /// Løser opp en relativ bildesti (f.eks. `images/foo.jpg`) til en absolutt
  /// sti dersom filen finnes; ellers `null`. Brukes av Markdown-forhåndsvisning.
  String? resolveImagePath(String bookSlug, String relativePath) {
    if (relativePath.isEmpty) return null;
    final uri = Uri.tryParse(relativePath);
    if (uri != null && (uri.isScheme('http') || uri.isScheme('data'))) {
      return null;
    }
    final relative = (uri != null && uri.path.isNotEmpty)
        ? uri.path
        : relativePath;
    final file = File(p.join(_storage.bookRootPath(bookSlug), relative));
    return file.existsSync() ? file.path : null;
  }

  String _extensionOf(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '.jpg';
    return name.substring(dot).toLowerCase();
  }

  String _uniqueImageName(String ext) {
    final now = DateTime.now().toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp =
        '${now.year}${two(now.month)}${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}'
        '-${now.millisecond.toString().padLeft(3, '0')}';
    return 'img-$stamp$ext';
  }
}
