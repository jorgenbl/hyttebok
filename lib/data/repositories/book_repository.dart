import 'dart:io';

import 'package:archive/archive.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/errors.dart';
import '../../domain/models/book.dart';
import '../../domain/models/book_meta.dart';
import '../services/book_markdown.dart';
import '../services/file_storage_service.dart';
import '../services/frontmatter.dart';

/// Én sannhetskilde for bøker i datalaget.
///
/// Tynn over [FileStorageService]: presenterer domänmodeller og skjuler fil-io
/// for ViewModels/Use Cases. `save` skriver boka slik den er gitt (kalleren setter
/// selv `updatedAt`).
///
/// Eksport- og importmetodene skriver til en eksportmappe (standard: systemtemp).
/// [exportDir] kan settes for å styre målet, f.eks. i tester.
class BookRepository {
  BookRepository(this._storage, {Directory? exportDir})
    : _exportDir = exportDir; // ignore: prefer_initializing_formals

  final FileStorageService _storage;
  final Directory? _exportDir;

  /// Mappeneksporterte filer legges i. Skaper seg selv ved behov.
  Future<Directory> _getExportDir() async {
    final base = _exportDir ?? await getTemporaryDirectory();
    final dir = Directory(p.join(base.path, 'hyttebok-eksport'));
    await dir.create(recursive: true);
    return dir;
  }

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
  // Eksport og import (Fase 2)
  // --------------------------------------------------------------------------

  /// Eksporterer boken til én samlet `.md`-fil med base64-inlinede bilder.
  ///
  /// Returnerer absolutt sti til den skrevne filen. [BookNotFound] hvis [slug]
  /// mangler. Manglende bilder hoppes over (referansen beholdes).
  Future<String> exportSingleFile(String slug) async {
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
    final dir = await _getExportDir();
    final file = File(p.join(dir.path, '${_fileSafe(book.title)}.md'));
    await file.writeAsString(md);
    return file.path;
  }

  /// Eksporterer boken som en `.zip`-pakke (Markdown + `images/` + `cabins/`).
  ///
  /// Returnerer absolutt sti til zip-filen. [BookNotFound] hvis [slug] mangler.
  Future<String> exportZip(String slug) async {
    final book = await load(slug);
    final bookDir = Directory(_storage.bookRootPath(slug));
    if (!bookDir.existsSync()) throw BookNotFound(slug);

    final archive = Archive();
    for (final file in _walkFiles(bookDir)) {
      final rel = p.relative(file.path, from: bookDir.path);
      // Prefiks <slug>/ slik at oppakking gir én mappe.
      final entry = ArchiveFile.bytes(
        p.join(slug, rel),
        file.readAsBytesSync(),
      );
      archive.add(entry);
    }

    final dir = await _getExportDir();
    final file = File(p.join(dir.path, '${_fileSafe(book.title)}.zip'));
    await file.writeAsBytes(ZipEncoder().encodeBytes(archive));
    return file.path;
  }

  /// Importerer én fil fra [path] (absolutt sti) og lager en ny bok.
  ///
  /// Velger riktig importvei ut fra filtype: `.md`/`.markdown` →
  /// [importFromMarkdown], `.zip` → [importFromZip]. Returnerer slug til den
  /// nye boken. Kaster [InvalidBookFile] for ukjent filtype eller skadet innhold.
  Future<String> importFromPath(String path) async {
    final file = File(path);
    if (!file.existsSync()) throw InvalidBookFile('filen finnes ikke');
    final name = p.basename(path).toLowerCase();
    if (name.endsWith('.md') || name.endsWith('.markdown')) {
      return importFromMarkdown(file.readAsStringSync());
    }
    if (name.endsWith('.zip')) {
      return importFromZip(path);
    }
    throw InvalidBookFile('ukjent filtype: ${p.basename(path)}');
  }

  /// Importerer boken fra en samlet `.md`-streng (fra [bookToSingleFile]).
  ///
  /// Lager en **ny** bok (unikt slug) slik at eksisterende bøker ikke overskrives.
  /// Returnerer slug til den nye boken. Kaster [InvalidBookFile] for tom eller
  /// skadet innhold.
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

  /// Importerer boken fra en `.zip`-pakke (fra [exportZip]).
  ///
  /// Pakker ut til en temp-mappe, finner boken (mappen med `book.md`), lager en
  /// ny bok og kopierer innholdet. Returnerer slug til den nye boken. Kaster
  /// [InvalidBookFile] for skadet pakke eller manglende `book.md`.
  Future<String> importFromZip(String zipPath) async {
    final zipFile = File(zipPath);
    if (!zipFile.existsSync()) throw InvalidBookFile('zip-filen finnes ikke');

    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zipFile.readAsBytesSync());
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

    final tempParent = await Directory.systemTemp.createTemp('hyttebok-zip-');
    try {
      final bookRootDir = Directory(p.join(tempParent.path, 'bok'));
      await bookRootDir.create(recursive: true);

      for (final f in archive.files) {
        final rel = rootPrefix.isEmpty
            ? f.name
            : f.name.startsWith('$rootPrefix/')
            ? f.name.substring(rootPrefix.length + 1)
            : f.name;
        if (rel.isEmpty) continue;
        final target = File(p.join(bookRootDir.path, rel));
        await target.parent.create(recursive: true);
        target.writeAsBytesSync(f.content);
      }

      final bookMd = File(p.join(bookRootDir.path, 'book.md'));
      if (!bookMd.existsSync()) {
        throw InvalidBookFile('zip-filen mangler book.md');
      }
      final fm = parseFrontmatter(bookMd.readAsStringSync());
      final rawTitle = fm.meta['title'] as String?;
      final title = (rawTitle == null || rawTitle.trim().isEmpty)
          ? 'Importert bok'
          : rawTitle.trim();

      final newSlug = await _storage.createBook(title);
      _copyDirectory(bookRootDir, Directory(_storage.bookRootPath(newSlug)));

      // Les boken tilbake gjennom det sanne lageret (validerer strukturen).
      try {
        await _storage.readBook(newSlug);
      } catch (_) {
        await _storage.deleteBook(newSlug);
        throw InvalidBookFile(
          'zip-filen er mangelfull (kan ikke leses som bok)',
        );
      }
      return newSlug;
    } finally {
      if (tempParent.existsSync()) tempParent.deleteSync(recursive: true);
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

  /// Filsystem-trygt filnavn fra en tittel (fjerner tegn som er ulovlig i navn).
  String _fileSafe(String s) {
    var out = s.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
    out = out.replaceAll(RegExp(r'\s+'), ' ');
    if (out.isEmpty) return 'bok';
    return out;
  }

  /// Alle filer under [dir] (rekursivt).
  Iterable<File> _walkFiles(Directory dir) sync* {
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is File) yield entity;
    }
  }

  /// Kopierer alt innhold i [source] inn i [target] (rekursivt, overskriver).
  ///
  /// Egen implementasjon siden `Directory.copyRecursively` ikke finnes i alle
  /// SDK-bygde; er deterministisk og testbar.
  void _copyDirectory(Directory source, Directory target) {
    if (!target.existsSync()) target.createSync(recursive: true);
    for (final entity in source.listSync(followLinks: false)) {
      if (entity is File) {
        entity.copySync(p.join(target.path, p.basename(entity.path)));
      } else if (entity is Directory) {
        _copyDirectory(
          entity,
          Directory(p.join(target.path, p.basename(entity.path))),
        );
      }
    }
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
