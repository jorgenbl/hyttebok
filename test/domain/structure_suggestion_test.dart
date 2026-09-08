import 'package:flutter_test/flutter_test.dart';
import 'package:hyttebok/domain/ai/structure_suggestion.dart';
import 'package:hyttebok/domain/models/section_type.dart';

void main() {
  group('AiStructureSuggestion.tryParse', () {
    test('gyldig ren JSON', () {
      const raw = '''
{"sections":[{"title":"Ved & peis","type":"notater","hint":"Vedlager og vedkubb"}]}
''';
      final suggestion = AiStructureSuggestion.tryParse(raw);
      expect(suggestion, isNotNull);
      expect(suggestion!.sections, hasLength(1));
      expect(suggestion.sections.first.title, 'Ved & peis');
      expect(suggestion.sections.first.type, SectionType.notater);
      expect(suggestion.sections.first.hint, 'Vedlager og vedkubb');
    });

    test('JSON i code fence med forklaring rundt', () {
      const raw = '''
Her er et forslag:
```json
{"sections":[
  {"title":"Ved","type":"egen","hint":"Vedlager"},
  {"title":"Rutiner","type":"start","hint":"Åpne-rutiner"}
]}
```
Håper det passer!
''';
      final suggestion = AiStructureSuggestion.tryParse(raw);
      expect(suggestion, isNotNull);
      expect(suggestion!.sections, hasLength(2));
      expect(suggestion.sections[0].type, SectionType.egen);
      expect(suggestion.sections[1].type, SectionType.startRoutines);
    });

    test('type-mapping: alle wire-navn', () {
      for (final (wire, type) in [
        ('start', SectionType.startRoutines),
        ('stop', SectionType.stopRoutines),
        ('beskrivelse', SectionType.beskrivelse),
        ('notater', SectionType.notater),
        ('medier', SectionType.medier),
        ('egen', SectionType.egen),
      ]) {
        final raw = '{"sections":[{"title":"T","type":"$wire","hint":"h"}]}';
        final suggestion = AiStructureSuggestion.tryParse(raw);
        expect(suggestion!.sections.first.type, type, reason: wire);
      }
    });

    test('ukjent type faller tilbake til egen', () {
      const raw = '{"sections":[{"title":"T","type":"galla","hint":"h"}]}';
      final suggestion = AiStructureSuggestion.tryParse(raw);
      expect(suggestion!.sections.first.type, SectionType.egen);
    });

    test('mangler type → egen, mangler hint → tom', () {
      const raw = '{"sections":[{"title":"T"}]}';
      final suggestion = AiStructureSuggestion.tryParse(raw);
      expect(suggestion!.sections.first.type, SectionType.egen);
      expect(suggestion.sections.first.hint, isEmpty);
    });

    test('oppføringer med tom tittel hoppes over', () {
      const raw =
          '{"sections":[{"title":"","type":"egen","hint":"x"},'
          '{"title":"  ","type":"egen","hint":"x"},'
          '{"title":"Beholdt","type":"egen","hint":"h"}]}';
      final suggestion = AiStructureSuggestion.tryParse(raw);
      expect(suggestion!.sections, hasLength(1));
      expect(suggestion.sections.first.title, 'Beholdt');
    });

    test('ingen sections → null', () {
      const raw = '{"sections":[]}';
      expect(AiStructureSuggestion.tryParse(raw), isNull);
    });

    test('mangler «sections»-felt → null', () {
      const raw = '{"foo":"bar"}';
      expect(AiStructureSuggestion.tryParse(raw), isNull);
    });

    test('sections er ikke en liste → null', () {
      const raw = '{"sections":"ikke-en-liste"}';
      expect(AiStructureSuggestion.tryParse(raw), isNull);
    });

    test('ugyldig JSON → null', () {
      const raw = 'Her er noen tips:\n1. Ved\n2. Peis';
      expect(AiStructureSuggestion.tryParse(raw), isNull);
    });

    test('skadd JSON (mangler stengende krave) → null', () {
      const raw = '{"sections":[{"title":"T","type":"egen","hint":"h"}]';
      expect(AiStructureSuggestion.tryParse(raw), isNull);
    });

    test('alt er skrot → null', () {
      expect(AiStructureSuggestion.tryParse(''), isNull);
      const raw = '{"sections":["streng-ikke-objekt"]}';
      expect(AiStructureSuggestion.tryParse(raw), isNull);
    });
  });
}
