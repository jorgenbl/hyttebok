import 'dart:typed_data';

import '../../domain/models/book.dart';
import '../../domain/models/book_meta.dart';

/// Én fil i bokens mappestruktur: relativ sti (posix-skråstreker) + innhold.
class StorageFile {
  const StorageFile(this.relativePath, this.bytes);

  /// Relativ sti relatert bokens rot, f.eks. `cabins/hytta/cabin.md`.
  final String relativePath;

  final Uint8List bytes;
}

/// Lagring for hyttebøker.
///
/// Nativt implementeres av [FileStorageService] (mappestruktur på disk via
/// `dart:io`); på web av [InMemoryBookStorage] (økt i minnet). Bøker er
/// platform-uavhengige: alt som trengs er disse operasjonene.
abstract interface class BookStorage {
  /// Oppretter en tom bok og returnerer slug (unik ved kollisjon).
  Future<String> createBook(String title, {String intro});

  /// List metadata for alle bøker, nyest først.
  Future<List<BookMeta>> listBooks();

  /// Les en hel bok. Kaster [BookNotFound]/[CorruptBook] fra feilklassen.
  Future<Book> readBook(String slug);

  /// Skriv en hel bok (full synkronisering; bilder beholdes).
  Future<void> writeBook(Book book);

  /// Slett en bok og alt innhold.
  Future<void> deleteBook(String slug);

  /// Lagrer et bilde under `images/` og returnerer relativ sti.
  Future<String> saveImage(
    String bookSlug,
    Uint8List bytes, {
    required String filename,
  });

  /// Les et bilde gitt en relativ sti relatert boka. Kaster [ImageNotFound].
  Future<Uint8List> readImageBytes(String bookSlug, String relativePath);

  /// Alle filene i boken (Markdown + bilder) som [StorageFile]-liste.
  /// Kaster [BookNotFound] hvis boka mangler.
  Future<List<StorageFile>> listBookFiles(String slug);
}
