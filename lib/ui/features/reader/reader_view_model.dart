import 'package:flutter/foundation.dart';

import '../../../data/repositories/book_repository.dart';
import '../../../domain/models/book.dart';
import '../../../domain/models/cabin.dart';

/// Tilstand for lesevisningen: heila boka – eller kun én hytte – som ett
/// lineært dokument, i samme innholdsrekkefølge som MD/PDF-eksporten.
class ReaderViewModel extends ChangeNotifier {
  ReaderViewModel(this._repo, this.bookSlug, {this.cabinSlug});

  final BookRepository _repo;
  final String bookSlug;

  /// Om satt: vis kun denne hytta; ellers heila boka.
  final String? cabinSlug;

  Book? _book;
  bool _loading = true;

  Book? get book => _book;
  bool get loading => _loading;

  /// Boka finnes ikke (ugyldig slug / slettet mens åpen).
  bool get bookNotFound => !_loading && _book == null;

  /// Om [cabinSlug] er satt men ingen hytte har det slug-et.
  bool get cabinNotFound =>
      !_loading && _book != null && cabinSlug != null && cabin == null;

  /// Hytta som skal vises (null ved heil-bok-visning eller manglende slug).
  Cabin? get cabin {
    final slug = cabinSlug;
    final b = _book;
    if (slug == null || b == null) return null;
    for (final c in b.cabins) {
      if (c.slug == slug) return c;
    }
    return null;
  }

  /// Hyttene som skal gjengis, i bokens rekkefølge. Ved valgt hytte som
  /// ikke finnes (stale slug) blir listen tom.
  List<Cabin> get visibleCabins {
    if (cabinSlug != null) {
      final only = cabin;
      return only == null ? const [] : [only];
    }
    return _book?.cabins ?? const [];
  }

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      _book = await _repo.load(bookSlug);
    } catch (_) {
      _book = null;
    }
    _loading = false;
    notifyListeners();
  }
}
