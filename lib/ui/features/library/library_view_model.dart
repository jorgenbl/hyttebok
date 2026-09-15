import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/utils/swipe_delete.dart';
import '../../../data/repositories/book_repository.dart';
import '../../../domain/models/book_meta.dart';

/// Tilstand og kommandoer for biblioteket (listen med bøker).
class LibraryViewModel extends ChangeNotifier {
  LibraryViewModel(this._repo);

  final BookRepository _repo;

  List<BookMeta> _books = const [];
  bool _loading = false;

  /// Bøker som er sveipet bort, men ikke fysisk slettet ennå. Dataene er
  /// intakte inntil tidsvinduet går ut uten at brukeren angret.
  final Map<String, Timer> _pendingDeletes = {};

  List<BookMeta> get books =>
      _books.where((b) => !_pendingDeletes.containsKey(b.slug)).toList();
  bool get loading => _loading;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _books = await _repo.listBooks();
    _loading = false;
    notifyListeners();
  }

  /// Sveip-sletting: boka forsvinner fra listen med det samme, men
  /// slettes ikke fysisk før tidsvinduet er passert uten at
  /// [cancelSwipeDelete] kalles.
  void swipeDelete(String slug) {
    _pendingDeletes[slug]?.cancel();
    _pendingDeletes[slug] = Timer(swipeDeleteCommitDelay, () {
      _pendingDeletes.remove(slug);
      notifyListeners();
      unawaited(deleteBook(slug));
    });
    notifyListeners();
  }

  /// Angrer en pågående sveip-sletting: boka dukker tilbake opp, og
  /// ingenting er slettet.
  void cancelSwipeDelete(String slug) {
    _pendingDeletes.remove(slug)?.cancel();
    notifyListeners();
  }

  /// Oppretter en ny bok og returnerer slug.
  Future<String> createBook(String title) async {
    final slug = await _repo.create(title);
    await load();
    return slug;
  }

  /// Importerer en bok fra plukkede [bytes] (fil fra `file_picker`) og
  /// returnerer slug til den nye boken. Kan kaste [InvalidBookFile] fra
  /// datalaget.
  Future<String> importBook(String name, Uint8List bytes) async {
    final slug = await _repo.importFromBytes(name, bytes);
    await load();
    return slug;
  }

  Future<void> deleteBook(String slug) async {
    await _repo.delete(slug);
    await load();
  }
}
