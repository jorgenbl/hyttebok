import 'package:yaml/yaml.dart';

/// Et Markdown-dokument splittet i YAML-frontmatter ([meta]) og brødtekst ([body]).
class Frontmatter {
  const Frontmatter(this.meta, this.body);

  /// Metadata fra frontmatter-blokken (tom mappe hvis ingen blokk).
  final Map<String, Object?> meta;

  /// Brødtekst etter frontmatter, trimmet.
  final String body;
}

/// Løser opp rå tekst (med eller uten frontmatter) i en [Frontmatter].
///
/// Frontmatter må starte med `---` på første linje og avsluttes med en egen `---`.
/// Alt etter avslutningen er brødtekst.
Frontmatter parseFrontmatter(String raw) {
  final lines = raw.split('\n');
  if (lines.isEmpty || lines.first.trim() != '---') {
    return Frontmatter(const {}, raw.trim());
  }
  for (var i = 1; i < lines.length; i++) {
    if (lines[i].trim() == '---') {
      final yamlBlock = lines.sublist(1, i).join('\n');
      final body = lines.sublist(i + 1).join('\n').trim();
      final meta = <String, Object?>{};
      if (yamlBlock.trim().isNotEmpty) {
        final parsed = loadYaml(yamlBlock);
        if (parsed is Map) {
          parsed.forEach((key, value) => meta['$key'] = value);
        }
      }
      return Frontmatter(meta, body);
    }
  }
  // Ingen avsluttende `---`: behandel hele teksten som brødtekst.
  return Frontmatter(const {}, raw.trim());
}

/// Skriver ut [meta] som YAML-frontmatter + [body].
///
/// Nøkkelen i [meta] lages i den rekkefølgen de er satt (lesbar, deterministisk).
/// Null-verdier utelates.
String withFrontmatter(Map<String, Object?> meta, String body) {
  final buffer = StringBuffer('---\n');
  meta.forEach((key, value) {
    final rendered = _renderValue(value);
    if (rendered == null) return;
    buffer.writeln('$key: $rendered');
  });
  buffer.writeln('---');
  buffer.writeln();
  buffer.writeln(body);
  return buffer.toString();
}

String? _renderValue(Object? value) {
  if (value == null) return null;
  if (value is bool) return value ? 'true' : 'false';
  if (value is num) return value.toString();
  if (value is List) {
    final items = value.map(_renderScalar).toList();
    return '[${items.join(', ')}]';
  }
  return _renderScalar(value);
}

String _renderScalar(Object? value) {
  final escaped = value
      .toString()
      .replaceAll(r'\', r'\\')
      .replaceAll('"', r'\"');
  return '"$escaped"';
}
