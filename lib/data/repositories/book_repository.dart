import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart' show PdfPageFormat;

import '../../core/errors.dart';
import '../../domain/models/book.dart';
import '../../domain/models/book_meta.dart';
import '../services/book_files.dart';
import '../services/book_markdown.dart';
import '../services/book_pdf.dart';
import '../services/book_storage.dart';
import '../services/frontmatter.dart';

/// Én sannhetskilde for bøker i datalaget.
///
/// Tynn over [BookStorage]: presenterer domänmodeller og skjuler lagring for
/// ViewModels/Use Cases. `save` skriver boka slik den er gitt (kalleren setter
/// selv `updatedAt`).
///
/// Klassen er **plattform-uavhengig** (ingen `dart:io`): eksport gir byteer,
/// import tar byteer. Mobil skriver byteene til fil (for delingsmenyen) og
/// web laster dem ned – begge deler skjer overfor repoet, ikke i det.
class BookRepository {
  BookRepository(this._storage);

  final BookStorage _storage;

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

  // --------------------------------------------------------------------------
  // Eksport (Fase 2 + F18) – alt som byteer
  // --------------------------------------------------------------------------

  /// Eksporterer boken til én samlet `.md`-fil med base64-inlinede bilder.
  ///
  /// [BookNotFound] hvis [slug] mangler. Manglende bilder hoppes over
  /// (referansen beholdes).
  Future<Uint8List> exportSingleFileBytes(String slug) async {
    final book = await load(slug);
    final md = await bookToSingleFile(
      book,
      imageBytes: (rel) async {
        try {
          return await _storage.readImageBytes(slug, rel);
        } catch (_) {
          return null;
        }
      },
    );
    return Uint8List.fromList(utf8.encode(md));
  }

  /// Eksporterer boken som en `.zip`-pakke (Markdown + `images/` + `cabins/`).
  ///
  /// Alle filer i boken med prefiks `<slug>/` slik at oppakking gir én mappe.
  /// [BookNotFound] hvis [slug] mangler.
  Future<Uint8List> exportZipBytes(String slug) async {
    await load(slug); // validerer at boken finnes
    final files = await _storage.listBookFiles(slug);

    final archive = Archive();
    for (final file in files) {
      archive.addFile(
        ArchiveFile(
          p.posix.join(slug, file.relativePath),
          file.bytes.length,
          file.bytes,
        ),
      );
    }

    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) {
      throw StateError('Kunne ikke lage zip-filen av boken.');
    }
    return Uint8List.fromList(encoded);
  }

  /// Eksporterer boken til PDF-byteer (F18) for utskrift / lagring.
  ///
  /// [pageFormat] styrer sideformat/retning (standard: A4 portrett);
  /// utskriftsdialogen kan be om et annet format ved endret orientering.
  /// [BookNotFound] hvis [slug] mangler. Manglende eller ødelagte bilder
  /// hoppes over (referansen beholdes som tekst).
  Future<Uint8List> exportPdfBytes(
    String slug, {
    PdfPageFormat? pageFormat,
  }) async {
    final book = await load(slug);
    return BookPdfExporter().exportPdf(
      book,
      imageBytes: (rel) async {
        try {
          return await _storage.readImageBytes(slug, rel);
        } catch (_) {
          return null;
        }
      },
      pageFormat: pageFormat ?? PdfPageFormat.standard,
    );
  }

  // --------------------------------------------------------------------------
  // Import (Fase 2) – alt fra byteer
  // --------------------------------------------------------------------------

  /// Importerer en fil fra [bytes] og lager en ny bok.
  ///
  /// Velger riktig importvei ut fra [name]'s endelse: `.md`/`.markdown` →
  /// [importFromMarkdown], `.zip` → [importFromZipBytes]. Returnerer slug til
  /// den nye boken. Kaster [InvalidBookFile] for ukjent filtype eller skadet
  /// innhold.
  Future<String> importFromBytes(String name, Uint8List bytes) async {
    final lower = name.toLowerCase();
    if (lower.endsWith('.md') || lower.endsWith('.markdown')) {
      return importFromMarkdown(utf8.decode(bytes));
    }
    if (lower.endsWith('.zip')) {
      return importFromZipBytes(bytes);
    }
    throw InvalidBookFile('ukjent filtype: $name');
  }

  /// Importerer boken fra en samlet `.md`-streng (fra [bookToSingleFile]).
  ///
  /// Lager en **ny** bok (unikt slug) slik at eksisterende bøker ikke
  /// overskrives. Returnerer slug til den nye boken. Kaster [InvalidBookFile]
  /// for tom eller skadet innhold.
  Future<String> importFromMarkdown(String content) async {
    if (content.trim().isEmpty) {
      throw InvalidBookFile('filen er tom');
    }
    final fm = parseFrontmatter(content);
    final rawTitle = fm.meta['title'] as String?;
    final title = (rawTitle == null || rawTitle.trim().isEmpty)
        ? 'Importert bok'
        : rawTitle.trim();

    final slug = await _storage.createBook(title);
    try {
      final book = await singleFileToBook(
        content,
        slug: slug,
        saveImage: (filename, bytes) =>
            _storage.saveImage(slug, bytes, filename: filename),
      );
      await _storage.writeBook(book);
      return slug;
    } catch (e) {
      await _storage.deleteBook(slug);
      if (e is InvalidBookFile) rethrow;
      throw InvalidBookFile('skadet eller ugyldig markdown-fil');
    }
  }

  /// Importerer boken fra en `.zip`-pakke (fra [exportZipBytes]).
  ///
  /// Pakker ut til minne, finner boken (inngangen med `book.md`), lager en ny
  /// bok og kopierer innholdet. Returnerer slug til den nye boken. Kaster
  /// [InvalidBookFile] for skadet pakke eller manglende `book.md`.
  Future<String> importFromZipBytes(Uint8List bytes) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw InvalidBookFile(
        'kan ikke lese zip-filen (skadet eller feil format)',
      );
    }

    // Finn bokerot: enten `book.md` i røtten, eller én toppmappe med `book.md`.
    String rootPrefix;
    if (archive.files.any((f) => f.name == 'book.md')) {
      rootPrefix = '';
    } else {
      final topDirs = <String>{};
      for (final f in archive.files) {
        final parts = f.name.split('/');
        if (parts.length == 2 && parts[1] == 'book.md') {
          topDirs.add(parts[0]);
        }
      }
      if (topDirs.length != 1) {
        throw InvalidBookFile('zip-filen inneholder ingen gyldig bok');
      }
      rootPrefix = topDirs.first;
    }

    final bookFiles = <String, String>{};
    final imageFiles = <String, Uint8List>{};
    for (final f in archive.files) {
      final rel = rootPrefix.isEmpty
          ? f.name
          : f.name.startsWith('$rootPrefix/')
          ? f.name.substring(rootPrefix.length + 1)
          : f.name;
      if (rel.isEmpty) continue;
      if (rel.endsWith('.md')) {
        bookFiles[rel] = utf8.decode(f.content);
      } else if (rel.startsWith('images/')) {
        imageFiles[rel] = f.content is Uint8List
            ? f.content
            : Uint8List.fromList(f.content);
      }
    }

    final bookMd = bookFiles['book.md'];
    if (bookMd == null) {
      throw InvalidBookFile('zip-filen mangler book.md');
    }
    final fm = parseFrontmatter(bookMd);
    final rawTitle = fm.meta['title'] as String?;
    final title = (rawTitle == null || rawTitle.trim().isEmpty)
        ? 'Importert bok'
        : rawTitle.trim();

    final slug = await _storage.createBook(title);
    try {
      final book = deserializeBookFiles(slug, bookFiles);
      for (final entry in imageFiles.entries) {
        await _storage.saveImage(
          slug,
          entry.value,
          filename: p.posix.basename(entry.key),
        );
      }
      await _storage.writeBook(book);
      return slug;
    } catch (_) {
      await _storage.deleteBook(slug);
      throw InvalidBookFile('zip-filen er mangelfull (kan ikke leses som bok)');
    }
  }

  // --------------------------------------------------------------------------
  // Bilder
  // --------------------------------------------------------------------------

  /// Importerer et plukket bilde [file] inn i boken og returnerer den
  /// relative stien (f.eks. `images/img-20260105-123456-123.jpg`).
  ///
  /// Filen får et unikt navn basert på tidspunkt, slik at to bilder med samme
  /// opprinnelige navn ikke overskriver hverandre.
  Future<String> importImage(String bookSlug, XFile file) async {
    final bytes = await file.readAsBytes();
    final ext = _extensionOf(file.name);
    return _storage.saveImage(bookSlug, bytes, filename: _uniqueImageName(ext));
  }

  /// Lesbar versjon av [BookStorage.readImageBytes]: returnerer `null` i
  /// stedet for å kaste [ImageNotFound], og ignorerer ekstern (http/data)
  /// URL-er. Brukes av Markdown-forhåndsvisning.
  Future<Uint8List?> readImageSafe(String bookSlug, String relativePath) async {
    if (relativePath.isEmpty) return null;
    final uri = Uri.tryParse(relativePath);
    if (uri != null && (uri.isScheme('http') || uri.isScheme('data'))) {
      return null;
    }
    final relative = (uri != null && uri.path.isNotEmpty)
        ? uri.path
        : relativePath;
    try {
      return await _storage.readImageBytes(bookSlug, relative);
    } catch (_) {
      return null;
    }
  }

  // --------------------------------------------------------------------------
  // Hjelpere
  // --------------------------------------------------------------------------

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
