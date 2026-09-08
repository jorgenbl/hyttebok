import 'package:flutter_test/flutter_test.dart';
import 'package:hyttebok/domain/ai/prompts.dart';

void main() {
  group('AiPrompts', () {
    test('structureSystem bygger på brukerprompt og krever streng JSON', () {
      final prompt = AiPrompts.structureSystem('Mitt base-prompt');
      expect(prompt, contains('Mitt base-prompt'));
      expect(prompt, contains('"sections"'));
      expect(prompt, contains('"title"'));
      expect(prompt, contains('"type"'));
      expect(prompt, contains('"hint"'));
      expect(prompt, contains('KUN gyldig JSON'));
    });

    test('routineSystem krever ren avkrysningsliste', () {
      final prompt = AiPrompts.routineSystem('base');
      expect(prompt, contains('- [ ]'));
      expect(prompt, contains('base'));
    });

    test('writingSystem inkluderer den konkrete instruksjonen', () {
      expect(
        AiPrompts.writingSystem('base', AiWritingInstruction.extend),
        contains('Utvid og utdyp'),
      );
      expect(
        AiPrompts.writingSystem('base', AiWritingInstruction.rewrite),
        contains('Omskriv'),
      );
      expect(
        AiPrompts.writingSystem('base', AiWritingInstruction.summarize),
        contains('Oppsummer'),
      );
    });

    test('structureUser inneholder hyttebeskrivelsen', () {
      expect(
        AiPrompts.structureUser('trestue på fjellet'),
        contains('trestue på fjellet'),
      );
    });

    test('routineUser skiller mellom åpne og steng-rutiner', () {
      expect(
        AiPrompts.routineUser('peis og lys', isStart: true),
        contains('åpne-rutine'),
      );
      expect(
        AiPrompts.routineUser('peis og lys', isStart: false),
        contains('steng-rutine'),
      );
    });

    test('writingUser inkluderer teksten', () {
      expect(AiPrompts.writingUser('Min tekst'), contains('Min tekst'));
    });
  });
}
