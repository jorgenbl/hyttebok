import 'package:flutter/foundation.dart';

import '../../../data/repositories/book_repository.dart';
import '../../../domain/models/book.dart';
import '../../../domain/search/book_search.dart';

/// Tilstand og kommandoer for fulltekstsøk i én bok (Fase 3).
class BookSearchViewModel extends ChangeNotifier {
  BookSearchViewModel(this._repo, this.slug);

  final BookRepository _repo;
  final String slug;

  Book? _book;
  String _query = '';
  bool _loading = false;

  Book? get book => _book;
  String get query => _query;
  bool get loading => _loading;

  /// Nåværende treff, beregnet fra boka og [query].
  List<SearchResult> get results {
    final b = _book;
    if (b == null) return const [];
    return searchBook(b, _query);
  }

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

  void setQuery(String query) {
    if (query == _query) return;
    _query = query;
    notifyListeners();
  }
}
