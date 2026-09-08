import 'package:flutter/foundation.dart';

import '../../../core/utils/format.dart';
import '../../../core/utils/slug.dart';
import '../../../data/repositories/book_repository.dart';
import '../../../domain/ai/structure_suggestion.dart';
import '../../../domain/models/cabin.dart';
import '../../../domain/models/section.dart';
import '../../../domain/models/story.dart';

/// Tilstand og kommandoer for én hytte (navn/sted, rutiner, seksjoner, historier).
class CabinViewModel extends ChangeNotifier {
  CabinViewModel(this._repo, this.bookSlug, this.cabinSlug);

  final BookRepository _repo;
  final String bookSlug;
  final String cabinSlug;

  Cabin? _cabin;
  bool _loading = false;

  Cabin? get cabin => _cabin;
  bool get loading => _loading;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    Cabin? found;
    try {
      final book = await _repo.load(bookSlug);
      for (final c in book.cabins) {
        if (c.slug == cabinSlug) found = c;
      }
    } catch (_) {
      found = null;
    }
    _cabin = found;
    _loading = false;
    notifyListeners();
  }

  Future<void> _save(Cabin updated) async {
    final book = await _repo.load(bookSlug);
    final cabins = book.cabins
        .map((c) => c.slug == cabinSlug ? updated : c)
        .toList();
    await _repo.save(book.copyWith(cabins: cabins, updatedAt: DateTime.now()));
    await load();
  }

  // Navn / sted
  Future<void> rename(String name) => _save(_cabin!.copyWith(name: name));
  Future<void> setLocation(String location) =>
      _save(_cabin!.copyWith(location: location));

  // Innhold
  Future<void> updateDescription(String markdown) =>
      _save(_cabin!.copyWith(description: markdown));
  Future<void> updateStart(String markdown) => _save(
    _cabin!.copyWith(
      startRoutines: _cabin!.startRoutines.copyWith(markdown: markdown),
    ),
  );
  Future<void> updateStop(String markdown) => _save(
    _cabin!.copyWith(
      stopRoutines: _cabin!.stopRoutines.copyWith(markdown: markdown),
    ),
  );

  // Seksjoner
  Future<String> addSection(String title) async {
    final c = _cabin!;
    var base = slugify(title);
    if (base.isEmpty) base = 'seksjon';
    var candidate = base;
    var i = 2;
    final existing = {
      ...c.sections.map((s) => s.slug),
      'cabin',
      'start-rutiner',
      'steng-rutiner',
    };
    while (existing.contains(candidate)) {
      candidate = '$base-$i';
      i++;
    }
    final section = Section(
      slug: candidate,
      title: title,
      order: c.sections.length,
    );
    await _save(c.copyWith(sections: [...c.sections, section]));
    return candidate;
  }

  /// Oppretter seksjoner fra et godkjent AI-strukturforslag.
  ///
  /// Hver foreslåtte seksjon blir en vanlig seksjon i boka (også for type
  /// start/stop — faste åpne/steng-rutiner ligger separat på hytten), og
  /// ledeteksten blir start-Markdown. Slugene gjøres unike på samme måte som
  /// i [addSection].
  Future<void> addSections(List<SuggestedSection> suggested) async {
    final c = _cabin!;
    final existing = {
      ...c.sections.map((s) => s.slug),
      'cabin',
      'start-rutiner',
      'steng-rutiner',
    };
    final added = <Section>[];
    var order = c.sections.length;
    for (final s in suggested) {
      var base = slugify(s.title);
      if (base.isEmpty) base = 'seksjon';
      var candidate = base;
      var i = 2;
      while (existing.contains(candidate)) {
        candidate = '$base-$i';
        i++;
      }
      existing.add(candidate);
      added.add(
        Section(
          slug: candidate,
          title: s.title,
          markdown: s.hint,
          type: s.type,
          order: order,
        ),
      );
      order++;
    }
    if (added.isEmpty) return;
    await _save(c.copyWith(sections: [...c.sections, ...added]));
  }

  Future<void> updateSectionMarkdown(String sectionSlug, String markdown) =>
      _save(
        _cabin!.copyWith(
          sections: _cabin!.sections
              .map(
                (s) =>
                    s.slug == sectionSlug ? s.copyWith(markdown: markdown) : s,
              )
              .toList(),
        ),
      );

  Future<void> deleteSection(String sectionSlug) => _save(
    _cabin!.copyWith(
      sections: _cabin!.sections.where((s) => s.slug != sectionSlug).toList(),
    ),
  );

  /// Flytter seksjonen [slug] [delta] steg (negativt = opp) blant de synlige
  /// seksjonene, og tildeler orden på nytt. Skjulte seksjoner holder plassen sin.
  Future<void> moveSection(String sectionSlug, int delta) async {
    final c = _cabin!;
    final visible = c.sections.where((s) => !s.hidden).toList();
    final hidden = c.sections.where((s) => s.hidden).toList();
    final idx = visible.indexWhere((s) => s.slug == sectionSlug);
    if (idx < 0) return;
    final target = idx + delta;
    if (target < 0 || target >= visible.length) return;
    final reordered = [...visible];
    final moved = reordered.removeAt(idx);
    reordered.insert(target, moved);
    final merged = [...reordered, ...hidden];
    final renumbered = [
      for (var i = 0; i < merged.length; i++) merged[i].copyWith(order: i),
    ];
    await _save(c.copyWith(sections: renumbered));
  }

  /// Veksler synlighet (skjul/vis) for seksjonen [sectionSlug].
  Future<void> toggleHideSection(String sectionSlug) => _save(
    _cabin!.copyWith(
      sections: _cabin!.sections
          .map((s) => s.slug == sectionSlug ? s.copyWith(hidden: !s.hidden) : s)
          .toList(),
    ),
  );

  // Historier
  Future<String> addStory(
    String title, {
    DateTime? date,
    String? author,
  }) async {
    final c = _cabin!;
    final d = date ?? DateTime.now();
    final titleSlug = slugify(title).isEmpty ? 'historie' : slugify(title);
    var base = '${formatDate(d)}-$titleSlug';
    var candidate = base;
    var i = 2;
    final existing = c.stories.map((s) => s.slug).toSet();
    while (existing.contains(candidate)) {
      candidate = '$base-$i';
      i++;
    }
    final story = Story(
      slug: candidate,
      title: title,
      date: date,
      author: author,
      order: c.stories.length,
    );
    await _save(c.copyWith(stories: [...c.stories, story]));
    return candidate;
  }

  Future<void> updateStoryMarkdown(String storySlug, String markdown) => _save(
    _cabin!.copyWith(
      stories: _cabin!.stories
          .map((s) => s.slug == storySlug ? s.copyWith(markdown: markdown) : s)
          .toList(),
    ),
  );

  Future<void> deleteStory(String storySlug) => _save(
    _cabin!.copyWith(
      stories: _cabin!.stories.where((s) => s.slug != storySlug).toList(),
    ),
  );
}
