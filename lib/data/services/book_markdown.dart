import 'dart:convert';
import 'dart:typed_data';

import '../../core/utils/slug.dart';
import '../../domain/models/book.dart';
import '../../domain/models/cabin.dart';
import '../../domain/models/section.dart';
import '../../domain/models/section_type.dart';
import '../../domain/models/story.dart';
import 'frontmatter.dart';

/// Konverterer en [Book] til én samlet Markdown-streng (og tilbake).
///
/// Formatet er designet for å være både **lesbart/skrivebart ut** (Obsidian,
/// Typora, printer) og **round-trippbart** til en [Book]. Struktur kodes med
/// HTML-kommentar-markører (f.eks. `<!-- cabin:slug=… -->`) + heading-konvensjon:
///
/// ```
/// # <hytte>
/// ## Beskrivelse
/// ## Åpne-rutiner
/// ## Steng-rutiner
/// ## <egen seksjon>
/// ## Historier
/// ### <historie>
/// ```
///
/// Bilder referert i Markdown (`images/foo.jpg`) inlinas som base64-data-uri ved
/// eksport og trekkes ut til filer igjen ved import, slik at bildene fungerer i
/// appen etter import.

/// Eksporterer [book] til én Markdown-streng.
///
/// [imageBytes] henter byteene for et relativt bilde (f.eks. `images/foo.jpg`);
/// returner `null` hvis bildet ikke finnes. [inlineImages] false beholder
/// referansene istedenfor å inlinet dem.
Future<String> bookToSingleFile(
  Book book, {
  required Future<Uint8List?> Function(String relativePath) imageBytes,
  bool inlineImages = true,
}) async {
  final body = StringBuffer();

  void writeSection(String heading, {String? marker, String content = ''}) {
    if (marker != null) {
      body.writeln(marker);
    }
    body.writeln(heading);
    body.writeln(content.trim());
    body.writeln();
  }

  body.write(book.intro.trim());
  if (book.intro.trim().isNotEmpty) {
    body.writeln();
    body.writeln();
  }

  for (final cabin in book.cabins) {
    final cabinMarker =
        '<!-- cabin:slug=${_enc(cabin.slug)}'
        ' order=${cabin.order}'
        '${cabin.location != null && cabin.location!.trim().isNotEmpty ? ' location=${_enc(cabin.location!)}' : ''} -->';
    body.writeln(cabinMarker);
    body.writeln('# ${cabin.name}');
    body.writeln();

    writeSection('## Beskrivelse', content: cabin.description);
    writeSection(
      '## Åpne-rutiner',
      marker: '<!-- start:images=${_encImages(cabin.startRoutines.images)} -->',
      content: cabin.startRoutines.markdown,
    );
    writeSection(
      '## Steng-rutiner',
      marker: '<!-- stop:images=${_encImages(cabin.stopRoutines.images)} -->',
      content: cabin.stopRoutines.markdown,
    );

    for (final section in cabin.sections) {
      writeSection(
        '## ${section.title}',
        marker:
            '<!-- section:slug=${_enc(section.slug)}'
            ' images=${_encImages(section.images)}'
            '${section.hidden ? ' hidden=true' : ''} -->',
        content: section.markdown,
      );
    }

    if (cabin.stories.isNotEmpty) {
      body.writeln('## Historier');
      body.writeln();
      for (final story in cabin.stories) {
        final storyMarker =
            '<!-- story:slug=${_enc(story.slug)}'
            '${story.date != null ? ' date=${_enc(story.date!.toIso8601String())}' : ''}'
            '${story.author != null && story.author!.isNotEmpty ? ' author=${_enc(story.author!)}' : ''}'
            ' images=${_encImages(story.images)} -->';
        body.writeln(storyMarker);
        body.writeln('### ${story.title}');
        body.writeln(story.markdown.trim());
        body.writeln();
      }
    }
  }

  final meta = <String, Object?>{
    'type': 'book',
    'title': book.title,
    'version': 1,
    'updated': book.updatedAt.toIso8601String(),
    if (book.coverImage != null) 'cover': book.coverImage,
  };

  final fullBody = body.toString();
  final withImages = inlineImages
      ? await _inlineImages(fullBody, imageBytes)
      : fullBody;

  return withFrontmatter(meta, withImages);
}

/// Parser en samlet Markdown-streng (fra [bookToSingleFile]) tilbake til en
/// [Book]. [slug] er mappenavnet for den importerte boken.
///
/// [saveImage] lagrer et inlinet base64-bilde og returnerer den relative stien
/// (f.eks. `images/imported-0.jpg`) som settes inn i Markdown.
Future<Book> singleFileToBook(
  String content, {
  required String slug,
  required Future<String> Function(String filename, Uint8List bytes) saveImage,
}) async {
  final fm = parseFrontmatter(content);
  final title = (fm.meta['title'] as String?)?.trim() ?? slug;
  final updatedAt = _parseDateTime(fm.meta['updated']) ?? DateTime.now();
  final cover = fm.meta['cover'] as String?;

  final body = await _extractInlineImages(fm.body, saveImage);

  final cabinMarkers = RegExp(r'<!--\s*cabin:(\w+=\S+(?:\s+\w+=\S+)*)\s*-->')
      .allMatches(body)
      .toList();
  final intro = cabinMarkers.isEmpty
      ? body.trim()
      : body.substring(0, cabinMarkers.first.start).trim();

  final cabins = <Cabin>[];
  for (var i = 0; i < cabinMarkers.length; i++) {
    final fields = _parseFields(cabinMarkers[i].group(1)!);
    final blockStart = cabinMarkers[i].end;
    final blockEnd = i + 1 < cabinMarkers.length
        ? cabinMarkers[i + 1].start
        : body.length;
    cabins.add(_parseCabin(body.substring(blockStart, blockEnd), fields));
  }

  return Book(
    slug: slug,
    title: title,
    intro: intro,
    coverImage: (cover == null || cover.isEmpty) ? null : cover,
    cabins: cabins,
    updatedAt: updatedAt,
  );
}

// ---------------------------------------------------------------------------
// Intern – eksport
// ---------------------------------------------------------------------------

String _enc(String s) => Uri.encodeComponent(s);

String _encImages(List<String> images) =>
    images.isEmpty ? '' : Uri.encodeComponent(images.join('|'));

Future<String> _inlineImages(
  String md,
  Future<Uint8List?> Function(String relativePath) imageBytes,
) async {
  final regex = RegExp(r'!\[([^\]]*)\]\(([^)\s]+)\)');
  var out = md;
  final matches = regex.allMatches(md).toList();
  for (final m in matches.reversed) {
    final alt = m.group(1)!;
    final src = m.group(2)!;
    if (!_isLocalRef(src)) continue;
    final bytes = await imageBytes(src);
    if (bytes == null) continue;
    final dataUri = 'data:${_mimeForPath(src)};base64,${base64Encode(bytes)}';
    out = out.replaceRange(m.start, m.end, '![$alt]($dataUri)');
  }
  return out;
}

// ---------------------------------------------------------------------------
// Intern – import
// ---------------------------------------------------------------------------

Future<String> _extractInlineImages(
  String md,
  Future<String> Function(String filename, Uint8List bytes) saveImage,
) async {
  final regex = RegExp(
    r'!\[[^\]]*\]\(data:([a-z0-9.+/_-]+);base64,([A-Za-z0-9+/=]+)\)',
  );
  final matches = regex.allMatches(md).toList();
  final replacements = <MapEntry<Match, String>>[];
  for (var i = 0; i < matches.length; i++) {
    final m = matches[i];
    final mime = m.group(1)!;
    final b64 = m.group(2)!;
    final bytes = base64Decode(b64);
    final filename = 'imported-$i${_extForMime(mime)}';
    final rel = await saveImage(filename, bytes);
    replacements.add(MapEntry(m, '![]($rel)'));
  }
  var out = md;
  for (final e in replacements.reversed) {
    out = out.replaceRange(e.key.start, e.key.end, e.value);
  }
  return out;
}

Cabin _parseCabin(String block, Map<String, String> cabinFields) {
  final slug = cabinFields['slug'] ?? 'hytte';
  final order = int.tryParse(cabinFields['order'] ?? '0') ?? 0;
  final location = cabinFields['location'];

  final nameMatch = RegExp(r'^# (.+?)\s*$', multiLine: true).firstMatch(block);
  final name = nameMatch?.group(1)?.trim() ?? slug;

  final h2 = RegExp(
    r'^## (.+?)\s*$',
    multiLine: true,
  ).allMatches(block).toList();

  String titleAt(int i) => h2[i].group(1)!.trim();
  String contentAt(int i) {
    final start = h2[i].end;
    final end = i + 1 < h2.length ? h2[i + 1].start : block.length;
    return block.substring(start, end).trim();
  }

  var description = '';
  var startMd = '';
  var stopMd = '';
  List<String> startImages = const [];
  List<String> stopImages = const [];
  final sections = <Section>[];
  final stories = <Story>[];

  for (var i = 0; i < h2.length; i++) {
    final t = titleAt(i);
    final content = contentAt(i);
    final body = _stripMarkers(content);
    final before = block.substring(0, h2[i].start);
    switch (t) {
      case 'Beskrivelse':
        description = body;
      case 'Åpne-rutiner':
        startMd = body;
        startImages = _resolveImages(
          startMd,
          _markerBefore(before, 'start')?['images'],
        );
      case 'Steng-rutiner':
        stopMd = body;
        stopImages = _resolveImages(
          stopMd,
          _markerBefore(before, 'stop')?['images'],
        );
      case 'Historier':
        // Rå innhold: historiene har sine egne `<!-- story:… -->`-markører som
        // [ _parseStories ] leser. Markerne skal derfor ikke strykes her.
        stories.addAll(_parseStories(content));
      default:
        final fields = _markerBefore(before, 'section');
        final sslug = fields?['slug'] ?? slugify(t);
        sections.add(
          Section(
            slug: sslug,
            title: t,
            markdown: body,
            images: _resolveImages(body, fields?['images']),
            type: SectionType.egen,
            order: sections.length,
            hidden: fields?['hidden'] == 'true',
          ),
        );
    }
  }

  return Cabin(
    slug: slug,
    name: name,
    location: (location == null || location.isEmpty) ? null : location,
    description: description,
    startRoutines: Section(
      slug: 'start-rutiner',
      title: 'Åpne-rutiner',
      markdown: startMd,
      images: startImages,
      type: SectionType.startRoutines,
      order: 1,
    ),
    stopRoutines: Section(
      slug: 'steng-rutiner',
      title: 'Steng-rutiner',
      markdown: stopMd,
      images: stopImages,
      type: SectionType.stopRoutines,
      order: 2,
    ),
    sections: sections,
    stories: stories,
    order: order,
  );
}

List<Story> _parseStories(String content) {
  final h3 = RegExp(
    r'^### (.+?)\s*$',
    multiLine: true,
  ).allMatches(content).toList();
  final stories = <Story>[];
  for (var i = 0; i < h3.length; i++) {
    final title = h3[i].group(1)!.trim();
    final start = h3[i].end;
    final end = i + 1 < h3.length ? h3[i + 1].start : content.length;
    final body = _stripMarkers(content.substring(start, end));
    final before = content.substring(0, h3[i].start);
    final fields = _markerBefore(before, 'story') ?? const {};
    stories.add(
      Story(
        slug: fields['slug'] ?? slugify(title),
        title: title,
        date: fields['date'] != null && fields['date']!.isNotEmpty
            ? DateTime.tryParse(fields['date']!)
            : null,
        author: (fields['author'] == null || fields['author']!.isEmpty)
            ? null
            : fields['author'],
        markdown: body,
        images: _resolveImages(body, fields['images']),
        order: i,
      ),
    );
  }
  return stories;
}

/// Henter felt fra den nærmeste forgående `<type:…>`-markøren i [before].
Map<String, String>? _markerBefore(String before, String type) {
  final re = RegExp('<!--\\s*$type:([\\w\\s=/@:._%+-]*?)\\s*-->');
  final all = re.allMatches(before).toList();
  if (all.isEmpty) return null;
  return _parseFields(all.last.group(1)!);
}

Map<String, String> _parseFields(String inner) {
  final map = <String, String>{};
  for (final token in inner.trim().split(RegExp(r'\s+'))) {
    if (token.isEmpty) continue;
    final eq = token.indexOf('=');
    final key = eq <= 0 ? token : token.substring(0, eq);
    final value = eq < 0 ? '' : Uri.decodeComponent(token.substring(eq + 1));
    map[key] = value;
  }
  return map;
}

List<String> _imagesFrom(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  return raw.split('|').where((e) => e.isNotEmpty).toList();
}

/// Bilder som refereres i Markdown (`![](images/…)`), i forekomstsrekkefølge.
///
/// Ettersom bilder ved eksport inlines som data-uri og ved import trekkes ut til
/// nye filer, er Markdown-kilden det som bestiller den virkelige bildeoppløsningen
/// i boken. Markør-listen brukes kun som fallback om Markdown mangler referanser.
List<String> _imagesFromMarkdown(String md) {
  final re = RegExp(r'!\[[^\]]*\]\((images/[^)\s]+)\)');
  final seen = <String>{};
  final out = <String>[];
  for (final m in re.allMatches(md)) {
    final ref = m.group(1)!;
    if (seen.add(ref)) out.add(ref);
  }
  return out;
}

List<String> _resolveImages(String md, String? markerRaw) {
  final fromMd = _imagesFromMarkdown(md);
  if (fromMd.isNotEmpty) return fromMd;
  return _imagesFrom(markerRaw);
}

/// Fjerner strukturelle markører (HTML-kommentarer) fra en seksjonsbrødtekst og
/// trimmer resultatet. Markører tilhører alltid oppfølgende overskrift, så de
/// skal aldri inngå i selve innholdet.
String _stripMarkers(String s) =>
    s.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '').trim();

// ---------------------------------------------------------------------------
// Hjelpere
// ---------------------------------------------------------------------------

bool _isLocalRef(String src) {
  final uri = Uri.tryParse(src);
  if (uri == null) return true;
  if (uri.hasScheme) {
    return !(uri.isScheme('http') ||
        uri.isScheme('https') ||
        uri.isScheme('data'));
  }
  return true;
}

String _mimeForPath(String path) {
  final ext = path.split('.').last.toLowerCase();
  switch (ext) {
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'gif':
      return 'image/gif';
    case 'avif':
      return 'image/avif';
    default:
      return 'image/jpeg';
  }
}

String _extForMime(String mime) {
  switch (mime) {
    case 'image/png':
      return '.png';
    case 'image/webp':
      return '.webp';
    case 'image/gif':
      return '.gif';
    case 'image/avif':
      return '.avif';
    default:
      return '.jpg';
  }
}

DateTime? _parseDateTime(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) {
    final s = value.trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }
  return null;
}
