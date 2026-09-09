/// Ren serialisering av en bok til mappestruktur (relativ sti → markdown-tekst)
/// og tilbake.
///
/// Platform-uavhengig (ingen `dart:io`): [FileStorageService] skriver kartet
/// til disk, [InMemoryBookStorage] holder det i minnet, og zip-eksport bruker
/// kartet direkte. Strukturlag er altså ett sted kun.
library;

import '../../core/errors.dart';
import '../../domain/models/book.dart';
import '../../domain/models/cabin.dart';
import '../../domain/models/section.dart';
import '../../domain/models/section_type.dart';
import '../../domain/models/story.dart';
import 'frontmatter.dart';

/// Formatversjon for bokens lagringsformat (se `docs/markdown-format.md`).
const int kFormatVersion = 1;

/// Serialiserer [book] til mappestrukturen (posiks-relative stier).
///
/// Nøyaktig det samme formatet `docs/markdown-format.md` beskriver:
/// `book.md`, `cabins/<hytte>/cabin.md`, `start-rutiner.md`,
/// `steng-rutiner.md`, `<seksjon>.md` og `historier/<historie>.md`.
Map<String, String> serializeBookFiles(Book book) {
  final files = <String, String>{'book.md': _bookMd(book)};
  for (final cabin in book.cabins) {
    final dir = 'cabins/${cabin.slug}';
    files['$dir/cabin.md'] = _cabinMd(cabin);
    files['$dir/start-rutiner.md'] = _sectionMd(cabin.startRoutines);
    files['$dir/steng-rutiner.md'] = _sectionMd(cabin.stopRoutines);
    for (final section in cabin.sections) {
      files['$dir/${section.slug}.md'] = _sectionMd(section);
    }
    for (final story in cabin.stories) {
      files['$dir/historier/${story.slug}.md'] = _storyMd(story);
    }
  }
  return files;
}

/// Motsatt av [serializeBookFiles]: leser en bok fra mappestruktur.
///
/// Kaster [CorruptBook] hvis `book.md` mangler eller en hyttedirektør mangler
/// `cabin.md`/rutinefilene.
Book deserializeBookFiles(String slug, Map<String, String> files) {
  final bookMd = files['book.md'];
  if (bookMd == null) throw CorruptBook(slug);

  final fm = parseFrontmatter(bookMd);
  final title = (fm.meta['title'] as String?) ?? slug;
  final coverRaw = fm.meta['cover'] as String?;
  final cover = (coverRaw == null || coverRaw.isEmpty) ? null : coverRaw;
  final updatedAt = _parseDateTime(fm.meta['updated']) ?? DateTime.now();
  final intro = fm.body;

  // Grupper `cabins/<hytte>/…`-filene per hytte.
  final cabinFiles = <String, Map<String, String>>{};
  for (final entry in files.entries) {
    final parts = entry.key.split('/');
    if (parts.length < 3 || parts[0] != 'cabins' || parts[1].isEmpty) continue;
    final cabinSlug = parts[1];
    final rest = entry.key.substring('cabins/$cabinSlug/'.length);
    cabinFiles.putIfAbsent(cabinSlug, () => <String, String>{})[rest] =
        entry.value;
  }

  final cabins =
      cabinFiles.entries
          .map((entry) => _deserializeCabin(entry.key, entry.value))
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));

  return Book(
    slug: slug,
    title: title,
    intro: intro,
    coverImage: cover,
    cabins: cabins,
    updatedAt: updatedAt,
  );
}

// --------------------------------------------------------------------------
// Serialisering (modeller → markdown)
// --------------------------------------------------------------------------

String _bookMd(Book book) {
  final meta = <String, Object?>{
    'type': 'book',
    'title': book.title,
    if (book.coverImage != null) 'cover': book.coverImage,
    'version': kFormatVersion,
    'updated': book.updatedAt.toIso8601String(),
  };
  return withFrontmatter(meta, book.intro);
}

String _cabinMd(Cabin cabin) {
  final meta = <String, Object?>{
    'type': 'cabin',
    'title': cabin.name,
    if (cabin.location != null) 'location': cabin.location,
    'order': cabin.order,
  };
  return withFrontmatter(meta, cabin.description);
}

String _sectionMd(Section section) {
  final meta = <String, Object?>{
    'type': 'section',
    'section': section.type.wireName,
    'title': section.title,
    'order': section.order,
    if (section.images.isNotEmpty) 'images': section.images,
    if (section.hidden) 'hidden': true,
  };
  return withFrontmatter(meta, section.markdown);
}

String _storyMd(Story story) {
  final meta = <String, Object?>{
    'type': 'story',
    'title': story.title,
    if (story.date != null) 'date': _formatDate(story.date),
    if (story.author != null) 'author': story.author,
    if (story.images.isNotEmpty) 'images': story.images,
    'order': story.order,
  };
  return withFrontmatter(meta, story.markdown);
}

// --------------------------------------------------------------------------
// Deserialisering (markdown → modeller)
// --------------------------------------------------------------------------

Cabin _deserializeCabin(String slug, Map<String, String> files) {
  final cabinMd = files['cabin.md'];
  if (cabinMd == null) throw CorruptBook(slug);
  final fm = parseFrontmatter(cabinMd);
  final name = (fm.meta['title'] as String?) ?? slug;
  final location = (fm.meta['location'] as String?);
  final order = (fm.meta['order'] as int?) ?? 0;
  final description = fm.body;

  final startMd = files['start-rutiner.md'];
  final stopMd = files['steng-rutiner.md'];
  if (startMd == null || stopMd == null) throw CorruptBook(slug);

  final startRoutines = _deserializeSection(
    'start-rutiner',
    startMd,
    defaultType: SectionType.startRoutines,
    defaultTitle: 'Åpne-rutiner',
  );
  final stopRoutines = _deserializeSection(
    'steng-rutiner',
    stopMd,
    defaultType: SectionType.stopRoutines,
    defaultTitle: 'Steng-rutiner',
  );

  final sections = <Section>[];
  final stories = <Story>[];
  for (final entry in files.entries) {
    final rel = entry.key;
    if (rel == 'cabin.md' ||
        rel == 'start-rutiner.md' ||
        rel == 'steng-rutiner.md') {
      continue;
    }
    if (rel.startsWith('historier/')) {
      final storySlug = _baseNameWithoutExtension(rel);
      stories.add(_deserializeStory(storySlug, entry.value));
      continue;
    }
    sections.add(
      _deserializeSection(_baseNameWithoutExtension(rel), entry.value),
    );
  }
  sections.sort((a, b) => a.order.compareTo(b.order));
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

Section _deserializeSection(
  String slug,
  String content, {
  SectionType? defaultType,
  String? defaultTitle,
}) {
  final fm = parseFrontmatter(content);
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
    hidden: (fm.meta['hidden'] as bool?) ?? false,
  );
}

Story _deserializeStory(String slug, String content) {
  final fm = parseFrontmatter(content);
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

/// `foo/bar/baz.md` → `baz` (uten å avhenge av `dart:io`/platform-separator).
String _baseNameWithoutExtension(String rel) {
  final base = rel.split('/').last;
  final dot = base.lastIndexOf('.');
  return (dot > 0 ? base.substring(0, dot) : base);
}

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
