import 'dart:convert';

import '../models/section_type.dart';

/// Étt foreslått seksjon fra AI-strukturforslaget.
class SuggestedSection {
  const SuggestedSection({
    required this.title,
    required this.type,
    this.hint = '',
  });

  final String title;
  final SectionType type;

  /// Ledetekst AI-en foreslår som utgangspunkt for innholdet.
  final String hint;
}

/// Et strukturforslag fra AI-en: en liste over seksjoner en hyttebok bør
/// inneholde. Renderes i UI som gjenbruksbart forslag; ingenting skrives til
/// boken før brukeren godkjenner.
class AiStructureSuggestion {
  const AiStructureSuggestion(this.sections);

  final List<SuggestedSection> sections;

  /// Parser rå AI-tekst til et [AiStructureSuggestion].
  ///
  /// Tolerant mot at modellen rammer JSON-en inn i code fences eller legger
  /// til forklaringstekst rundt. Returnerer `null` om ingen gyldig
  /// `{"sections":[…]}`-struktur kan trekkes ut.
  static AiStructureSuggestion? tryParse(String raw) {
    final jsonText = _extractJsonObject(raw);
    if (jsonText == null) return null;

    final dynamic decoded;
    try {
      decoded = jsonDecode(jsonText);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;

    final rawSections = decoded['sections'];
    if (rawSections is! List) return null;

    final sections = <SuggestedSection>[];
    for (final entry in rawSections) {
      if (entry is! Map<String, dynamic>) continue;
      final title = (entry['title'] as String?)?.trim() ?? '';
      if (title.isEmpty) continue;
      final hint = (entry['hint'] as String?)?.trim() ?? '';
      sections.add(
        SuggestedSection(
          title: title,
          type: _typeFromRaw(entry['type']),
          hint: hint,
        ),
      );
    }
    if (sections.isEmpty) return null;
    return AiStructureSuggestion(sections);
  }

  /// Tolerant type-mapping: aksepterer både wire-navn (`start`, `notater`, …)
  /// og enum-navn; ukjent → [SectionType.egen].
  static SectionType _typeFromRaw(Object? raw) {
    if (raw is! String) return SectionType.egen;
    final value = raw.trim().toLowerCase();
    for (final type in SectionType.values) {
      if (type.wireName == value || type.name == value) return type;
    }
    return SectionType.egen;
  }

  /// Finner den ytre JSON-objektet i [text], selv om det er innrammet i
  /// code fences eller omgitt av forklaringstekst.
  static String? _extractJsonObject(String text) {
    // Fjern eventuelle code fences (```json … ``` eller ``` … ```).
    var cleaned = text;
    final fence = RegExp(r'```(?:json)?\s*(.*?)```', dotAll: true);
    final fenceMatch = fence.firstMatch(cleaned);
    if (fenceMatch != null) {
      cleaned = fenceMatch.group(1) ?? cleaned;
    }

    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    return cleaned.substring(start, end + 1);
  }
}
