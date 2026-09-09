import 'package:flutter/foundation.dart';

import '../../../data/repositories/book_repository.dart';
import '../../../domain/models/book_meta.dart';

/// Tilstand og kommandoer for biblioteket (listen med bøker).
class LibraryViewModel extends ChangeNotifier {
  LibraryViewModel(this._repo);

  final BookRepository _repo;

  List<BookMeta> _books = const [];
  bool _loading = false;

  List<BookMeta> get books => _books;
  bool get loading => _loading;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _books = await _repo.listBooks();
    _loading = false;
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
