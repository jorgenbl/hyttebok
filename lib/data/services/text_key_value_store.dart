/// Enkel lagring for én tekstverdi (appens `settings.json`-dokument).
///
/// Plattformene avviker: mobil lagrer i fil ([FileTextKeyValueStore]),
/// web i `localStorage` ([WebLocalStorageTextStore]).
abstract interface class TextKeyValueStore {
  /// Returnerer lagret tekst, eller `null` hvis ingenting er lagret.
  String? load();

  /// Lagrer [value] (overskriver eksisterende verdi).
  Future<void> save(String value);
}
