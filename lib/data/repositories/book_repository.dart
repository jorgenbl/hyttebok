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
}
