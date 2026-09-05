import 'package:flutter/foundation.dart';

import '../../../core/utils/slug.dart';
import '../../../data/repositories/book_repository.dart';
import '../../../domain/models/book.dart';
import '../../../domain/models/cabin.dart';
import '../../../domain/models/section.dart';
import '../../../domain/models/section_type.dart';

/// Tilstand og kommandoer for én bok (forside + listen med hytter).
class BookViewModel extends ChangeNotifier {
  BookViewModel(this._repo, this.slug);

  final BookRepository _repo;
  final String slug;

  Book? _book;
  bool _loading = false;

  Book? get book => _book;
  bool get loading => _loading;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      _book = await _repo.load(slug);
    } catch (_) {
      _book = null;
    }
    _loading = false;
    notifyListeners();
  }

  /// Oppretter en ny hytte i boka og returnerer slug.
  Future<String> createCabin(String name) async {
    final b = _book!;
    var base = slugify(name);
    if (base.isEmpty) base = 'hytte';
    var candidate = base;
    var i = 2;
    final existing = b.cabins.map((c) => c.slug).toSet();
    while (existing.contains(candidate)) {
      candidate = '$base-$i';
      i++;
    }
    final cabin = Cabin(
      slug: candidate,
      name: name,
      order: b.cabins.length,
      startRoutines: Section(
        slug: 'start-rutiner',
        title: 'Åpne-rutiner',
        type: SectionType.startRoutines,
        order: 1,
      ),
      stopRoutines: Section(
        slug: 'steng-rutiner',
        title: 'Steng-rutiner',
        type: SectionType.stopRoutines,
        order: 2,
      ),
    );
    await _save(b.copyWith(cabins: [...b.cabins, cabin]));
    return candidate;
  }

  Future<void> deleteCabin(String cabinSlug) async {
    final b = _book!;
    await _save(
      b.copyWith(cabins: b.cabins.where((c) => c.slug != cabinSlug).toList()),
    );
  }

  Future<void> updateIntro(String markdown) async {
    final b = _book!;
    await _save(b.copyWith(intro: markdown));
  }

  Future<void> _save(Book updated) async {
    await _repo.save(updated.copyWith(updatedAt: DateTime.now()));
    await load();
  }
}
