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

/// Feil fra en AI-leverandør. [message] er på norsk og kan vises rett til
/// brukeren; [statusCode] og [cause] er tekniske detaljer for feillogging.
class AiProviderError implements Exception {
  AiProviderError(this.message, {this.statusCode, this.cause});

  /// Brukervenlig melding (Bokmål).
  final String message;

  /// HTTP-statuskode fra leverandøren, om tilgjengelig.
  final int? statusCode;

  /// Rå feiltekst / unntak fra leverandøren (klippet), om noen.
  final Object? cause;

  @override
  String toString() => 'AiProviderError: $message';
}
