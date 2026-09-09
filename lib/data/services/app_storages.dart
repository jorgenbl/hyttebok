import 'book_storage.dart';
import 'text_key_value_store.dart';

/// Plattformvalgt lagringssett for appen (returverdi fra [createStorages]).
class AppStorages {
  const AppStorages({required this.books, required this.settings});

  /// Boklagring (mappe på disk natively, minne på web).
  final BookStorage books;

  /// Innstillingslagring (fil natively, `localStorage` på web).
  final TextKeyValueStore settings;
}
