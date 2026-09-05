import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../core/errors.dart';
import '../../core/utils/slug.dart';
import '../../domain/models/book.dart';
import '../../domain/models/book_meta.dart';
import '../../domain/models/cabin.dart';
import '../../domain/models/section.dart';
import '../../domain/models/section_type.dart';
import '../../domain/models/story.dart';
import 'frontmatter.dart';

/// Formatversjon for bokens lagringsformat (se `docs/markdown-format.md`).
const int kFormatVersion = 1;

/// Tjenest som abstraherer alt filsystem-io for hyttebøker.
///
/// En **bok er en mappe** med `book.md`, `images/` og `cabins/`. Klassen er
/// platform-uavhengig (bruker `dart:io`) og fullt testbar. Basis-mappen gis i
/// konstruktoren: på enheten skal den komme fra `path_provider`; i tester fra en
/// temp-mappe.
class FileStorageService {
  FileStorageService(this._baseDirectory);

  final Directory _baseDirectory;

  // --------------------------------------------------------------------------
  // Bøker
  // --------------------------------------------------------------------------

  Directory _bookDir(String slug) =>
      Directory(p.join(_baseDirectory.path, slug));

  /// Absolutt mappe for boken (brukes til å løse opp lokale bilder).
  String bookRootPath(String slug) => p.join(_baseDirectory.path, slug);

  /// Oppretter en tom bok og returnerer slug.
  ///
  /// Sørger for at slug er unik ved å suffikse `-2`, `-3`, … ved kollisjon.
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

  /// List metadata for alle bøker (leser kun `book.md`-frontmatter per mappe).
  ///
  /// Sortert etter [BookMeta.updatedAt], nyest først.
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

  /// Les en hel bok som en [Book].
  ///
  /// Kaster [BookNotFound] hvis mappa mangler, [CorruptBook] hvis `book.md` mangler.
  Future<Book> readBook(String slug) async {
    final bookDir = _bookDir(slug);
    if (!bookDir.existsSync()) throw BookNotFound(slug);
    final bookFile = File(p.join(bookDir.path, 'book.md'));
    if (!bookFile.existsSync()) throw CorruptBook(slug);

    final fm = parseFrontmatter(bookFile.readAsStringSync());
    final title = (fm.meta['title'] as String?) ?? slug;
    final coverRaw = fm.meta['cover'] as String?;
    final cover = (coverRaw == null || coverRaw.isEmpty) ? null : coverRaw;
    final updatedAt =
        _parseDateTime(fm.meta['updated']) ?? bookFile.lastModifiedSync();
    final intro = fm.body;

    final cabins = <Cabin>[];
    final cabinsDir = Directory(p.join(bookDir.path, 'cabins'));
    if (cabinsDir.existsSync()) {
      for (final entity in cabinsDir.listSync()) {
        if (entity is! Directory) continue;
        cabins.add(_readCabin(entity, p.basename(entity.path)));
      }
    }
    cabins.sort((a, b) => a.order.compareTo(b.order));

    return Book(
      slug: slug,
      title: title,
      intro: intro,
      coverImage: cover,
      cabins: cabins,
      updatedAt: updatedAt,
    );
  }

  /// Skriv en hel bok (full synkronisering av strukturen).
  ///
  /// `book.md` og `cabins/` skrives på nytt og stemmer nøyaktig mot [book].
  /// Mappa `images/` beholdes (bilder legges til via [saveImage]).
  Future<void> writeBook(Book book) async {
    final bookDir = _bookDir(book.slug);
    await bookDir.create(recursive: true);
    await Directory(p.join(bookDir.path, 'images')).create(recursive: true);

    // Nullstill cabins/ slik at fjernet innhold forsvinner, så skriv på nytt.
    final cabinsDir = Directory(p.join(bookDir.path, 'cabins'));
    if (cabinsDir.existsSync()) {
      await cabinsDir.delete(recursive: true);
    }
    await cabinsDir.create(recursive: true);

    final meta = <String, Object?>{
      'type': 'book',
      'title': book.title,
      if (book.coverImage != null) 'cover': book.coverImage,
      'version': kFormatVersion,
      'updated': book.updatedAt.toIso8601String(),
    };
    await File(p.join(bookDir.path, 'book.md'))
        .writeAsString(withFrontmatter(meta, book.intro));

    for (final cabin in book.cabins) {
      await _writeCabin(cabinsDir, cabin);
    }
  }

  /// Slett en bok og hele mappen.
  Future<void> deleteBook(String slug) async {
    final bookDir = _bookDir(slug);
    if (bookDir.existsSync()) {
      await bookDir.delete(recursive: true);
    }
  }

  // --------------------------------------------------------------------------
  // Bilder
  // --------------------------------------------------------------------------

  /// Lagrer et bilde under `<bok>/images/` og returnerer relativ sti (f.eks. `images/foo.jpg`).
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

  /// Les et bilde gitt en relativ sti relatert til boka (f.eks. `images/foo.jpg`).
  Future<Uint8List> readImageBytes(String bookSlug, String relativePath) async {
    final file = File(p.join(_bookDir(bookSlug).path, relativePath));
    if (!file.existsSync()) throw ImageNotFound(relativePath);
    return file.readAsBytesSync();
  }

  // --------------------------------------------------------------------------
  // Hytter
  // --------------------------------------------------------------------------

  Future<void> _writeCabin(Directory cabinsDir, Cabin cabin) async {
    final cabinDir = Directory(p.join(cabinsDir.path, cabin.slug));
    await cabinDir.create(recursive: true);

    final meta = <String, Object?>{
      'type': 'cabin',
      'title': cabin.name,
      if (cabin.location != null) 'location': cabin.location,
      'order': cabin.order,
    };
    await File(p.join(cabinDir.path, 'cabin.md'))
        .writeAsString(withFrontmatter(meta, cabin.description));

    await _writeSectionFile(cabinDir, 'start-rutiner', cabin.startRoutines);
    await _writeSectionFile(cabinDir, 'steng-rutiner', cabin.stopRoutines);
    for (final section in cabin.sections) {
      await _writeSectionFile(cabinDir, section.slug, section);
    }

    if (cabin.stories.isNotEmpty) {
      final storiesDir = Directory(p.join(cabinDir.path, 'historier'));
      await storiesDir.create(recursive: true);
      for (final story in cabin.stories) {
        await _writeStoryFile(storiesDir, story);
      }
    }
  }

  Cabin _readCabin(Directory cabinDir, String slug) {
    final cabinFile = File(p.join(cabinDir.path, 'cabin.md'));
    final fm = parseFrontmatter(cabinFile.readAsStringSync());
    final name = (fm.meta['title'] as String?) ?? slug;
    final location = (fm.meta['location'] as String?);
    final order = (fm.meta['order'] as int?) ?? 0;
    final description = fm.body;

    final startRoutines = _readSectionFile(
      File(p.join(cabinDir.path, 'start-rutiner.md')),
      'start-rutiner',
      defaultType: SectionType.startRoutines,
      defaultTitle: 'Åpne-rutiner',
    );
    final stopRoutines = _readSectionFile(
      File(p.join(cabinDir.path, 'steng-rutiner.md')),
      'steng-rutiner',
      defaultType: SectionType.stopRoutines,
      defaultTitle: 'Steng-rutiner',
    );

    final sections = <Section>[];
    for (final entity in cabinDir.listSync()) {
      if (entity is! File || !entity.path.endsWith('.md')) continue;
      final base = p.basenameWithoutExtension(entity.path);
      if (base == 'cabin' ||
          base == 'start-rutiner' ||
          base == 'steng-rutiner') {
        continue;
      }
      sections.add(_readSectionFile(entity, base));
    }
    sections.sort((a, b) => a.order.compareTo(b.order));

    final stories = <Story>[];
    final storiesDir = Directory(p.join(cabinDir.path, 'historier'));
    if (storiesDir.existsSync()) {
      for (final entity in storiesDir.listSync()) {
        if (entity is! File || !entity.path.endsWith('.md')) continue;
        stories.add(
          _readStoryFile(entity, p.basenameWithoutExtension(entity.path)),
        );
      }
    }
    stories.sort((a, b) => a.order.compareTo(b.order));

    return Cabin(
      slug: slug,
      name: name,
      location: location,
      description: description,
      startRoutines: startRoutines,
      stopRoutines: stopRoutines,
      sections: sections,
      stories: stories,
      order: order,
    );
  }

  // --------------------------------------------------------------------------
  // Seksjoner og historier
  // --------------------------------------------------------------------------

  Future<void> _writeSectionFile(
    Directory cabinDir,
    String filename,
    Section section,
  ) async {
    final meta = <String, Object?>{
      'type': 'section',
      'section': section.type.wireName,
      'title': section.title,
      'order': section.order,
      if (section.images.isNotEmpty) 'images': section.images,
    };
    await File(p.join(cabinDir.path, '$filename.md'))
        .writeAsString(withFrontmatter(meta, section.markdown));
  }

  Section _readSectionFile(
    File file,
    String slug, {
    SectionType? defaultType,
    String? defaultTitle,
  }) {
    final fm = parseFrontmatter(file.readAsStringSync());
    final type = SectionType.fromWireName(
      (fm.meta['section'] as String?) ?? defaultType?.wireName,
    );
    return Section(
      slug: slug,
      title: (fm.meta['title'] as String?) ?? defaultTitle ?? slug,
      markdown: fm.body,
      images: _parseImages(fm.meta['images']),
      type: type,
      order: (fm.meta['order'] as int?) ?? 0,
    );
  }

  Future<void> _writeStoryFile(Directory storiesDir, Story story) async {
    final meta = <String, Object?>{
      'type': 'story',
      'title': story.title,
      if (story.date != null) 'date': _formatDate(story.date),
      if (story.author != null) 'author': story.author,
      if (story.images.isNotEmpty) 'images': story.images,
      'order': story.order,
    };
    await File(p.join(storiesDir.path, '${story.slug}.md'))
        .writeAsString(withFrontmatter(meta, story.markdown));
  }

  Story _readStoryFile(File file, String slug) {
    final fm = parseFrontmatter(file.readAsStringSync());
    return Story(
      slug: slug,
      title: (fm.meta['title'] as String?) ?? slug,
      date: _parseDateTime(fm.meta['date']),
      author: (fm.meta['author'] as String?),
      markdown: fm.body,
      images: _parseImages(fm.meta['images']),
      order: (fm.meta['order'] as int?) ?? 0,
    );
  }

  // --------------------------------------------------------------------------
  // Hjelpere
  // --------------------------------------------------------------------------

  List<String> _parseImages(Object? value) {
    if (value == null) return const [];
    if (value is List) return value.map((e) => e.toString()).toList();
    return [value.toString()];
  }

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

  String _formatDate(DateTime? date) {
    final d = date!;
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }
}
