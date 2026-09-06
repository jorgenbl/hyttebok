// Typede feil for datalaget. UI kan fange disse og vise vennlige meldinger.

/// En bok med [slug] fantes ikke.
class BookNotFound implements Exception {
  BookNotFound(this.slug);
  final String slug;
  @override
  String toString() => 'Bok fantes ikke: $slug';
}

/// Prøvde å opprette en bok som allerede eksisterte.
class BookExists implements Exception {
  BookExists(this.slug);
  final String slug;
  @override
  String toString() => 'Bok eksisterte allerede: $slug';
}

/// Mappa finnes, men mangler `book.md` (mangelfull/korrupt bok).
class CorruptBook implements Exception {
  CorruptBook(this.slug);
  final String slug;
  @override
  String toString() => 'Boken "$slug" er mangelfull (mangler book.md)';
}

/// Referert bilde fantes ikke på filsystemet.
class ImageNotFound implements Exception {
  ImageNotFound(this.path);
  final String path;
  @override
  String toString() => 'Bilde fantes ikke: $path';
}

/// En fil som skulle importeres var ugyldig (feil type, korrupt, tom).
class InvalidBookFile implements Exception {
  InvalidBookFile(this.message);
  final String message;
  @override
  String toString() => 'Kunne ikke importere boken: $message';
}
