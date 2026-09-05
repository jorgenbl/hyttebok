/// Typen til en seksjon i en hytte.
///
/// [wireName] er verdien som lagres i frontmatter-feltet `section`,
/// og er kontrakten mot filformatet (se `docs/markdown-format.md`).
enum SectionType {
  startRoutines('start'),
  stopRoutines('stop'),
  beskrivelse('beskrivelse'),
  notater('notater'),
  medier('medier'),
  egen('egen');

  const SectionType(this.wireName);

  final String wireName;

  /// Tolk en wire-verdi til en [SectionType]. Ukjente verdier blir [egen].
  static SectionType fromWireName(String? value) {
    for (final type in values) {
      if (type.wireName == value) return type;
    }
    return SectionType.egen;
  }
}
