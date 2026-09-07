import '../models/book.dart';

/// Én treff i en fulltekstsøk i en [Book].
class SearchResult {
  const SearchResult({
    required this.title,
    required this.snippet,
    required this.location,
    this.cabinSlug,
  });

  /// Tittel / hovedtekst for treffet (seksjonstittel, hyttenavn, «Forsiden» …).
  final String title;

  /// Kort utdrag rundt matchen, eller tomt dersom tittelen alene matchet.
  final String snippet;

  /// Menneskelesbar plassering (f.eks. «Hytta» eller «Hytta · Historier»).
  final String location;

  /// Slug til hytta treffet tilhører (null = treff i bokens forside).
  final String? cabinSlug;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SearchResult) return false;
    return other.title == title &&
        other.snippet == snippet &&
        other.location == location &&
        other.cabinSlug == cabinSlug;
  }

  @override
  int get hashCode => Object.hash(title, snippet, location, cabinSlug);

  @override
  String toString() => 'SearchResult(title: $title, location: $location)';
}

/// Søk etter [query] i hele [book]: forside, hytter (navn/sted/beskrivelse),
/// åpne-/steng-rutiner, alle seksjoner og alle historier.
///
/// Matching er case-uavhengig og delstrengsbasert. Returnerer treff i
/// dokument-rekkefølge. Skjulte seksjoner er likevel med (søk gjelder hele
/// boken).
List<SearchResult> searchBook(Book book, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  final results = <SearchResult>[];

  if (book.intro.toLowerCase().contains(q)) {
    results.add(
      SearchResult(
        title: 'Forsiden',
        snippet: _snippet(book.intro, q),
        location: book.title,
        cabinSlug: null,
      ),
    );
  }

  for (final cabin in book.cabins) {
    final label = cabin.name;
    if (cabin.name.toLowerCase().contains(q) ||
        (cabin.location?.toLowerCase().contains(q) ?? false)) {
      results.add(
        SearchResult(
          title: label,
          snippet: cabin.location ?? '',
          location: 'Hytte',
          cabinSlug: cabin.slug,
        ),
      );
    }
    if (cabin.description.toLowerCase().contains(q)) {
      results.add(
        SearchResult(
          title: 'Beskrivelse',
          snippet: _snippet(cabin.description, q),
          location: label,
          cabinSlug: cabin.slug,
        ),
      );
    }
    if (cabin.startRoutines.markdown.toLowerCase().contains(q)) {
      results.add(
        SearchResult(
          title: cabin.startRoutines.title,
          snippet: _snippet(cabin.startRoutines.markdown, q),
          location: label,
          cabinSlug: cabin.slug,
        ),
      );
    }
    if (cabin.stopRoutines.markdown.toLowerCase().contains(q)) {
      results.add(
        SearchResult(
          title: cabin.stopRoutines.title,
          snippet: _snippet(cabin.stopRoutines.markdown, q),
          location: label,
          cabinSlug: cabin.slug,
        ),
      );
    }
    for (final section in cabin.sections) {
      if (section.title.toLowerCase().contains(q) ||
          section.markdown.toLowerCase().contains(q)) {
        results.add(
          SearchResult(
            title: section.title,
            snippet: _snippet(section.markdown, q),
            location: label,
            cabinSlug: cabin.slug,
          ),
        );
      }
    }
    for (final story in cabin.stories) {
      if (story.title.toLowerCase().contains(q) ||
          story.markdown.toLowerCase().contains(q)) {
        results.add(
          SearchResult(
            title: story.title,
            snippet: _snippet(story.markdown, q),
            location: '$label · Historier',
            cabinSlug: cabin.slug,
          ),
        );
      }
    }
  }
  return results;
}

/// Et kort utdrag (maks ~60 tegn) rundt første forekomst av [q] i [text].
String _snippet(String text, String q) {
  final idx = text.toLowerCase().indexOf(q);
  if (idx < 0) return '';
  final before = idx > 24 ? idx - 24 : 0;
  final after = idx + q.length + 24 > text.length
      ? text.length
      : idx + q.length + 24;
  final s = text
      .substring(before, after)
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
  return (before > 0 ? '…' : '') + s + (after < text.length ? '…' : '');
}
