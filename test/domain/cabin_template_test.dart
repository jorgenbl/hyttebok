import 'package:flutter_test/flutter_test.dart';
import 'package:hyttebok/domain/models/section_type.dart';
import 'package:hyttebok/domain/templates/cabin_template.dart';

void main() {
  group('standardCabinTemplate', () {
    test('inneholder en komplett, ledetekst-fylt struktur', () {
      final t = standardCabinTemplate;
      expect(t.name, isNotEmpty);
      expect(t.sections, isNotEmpty);

      // Alle seksjoner har tittel, unikt slug og ikke-tom ledetekst.
      final slugs = t.sections.map((s) => s.slug).toList();
      expect(
        slugs.toSet().length,
        slugs.length,
        reason: 'alle slug-er i malen må være unike',
      );
      for (final s in t.sections) {
        expect(s.title.trim(), isNotEmpty);
        expect(s.slug.trim(), isNotEmpty);
        expect(s.placeholder.trim(), isNotEmpty, reason: '«${s.title}»');
      }

      // Rutiner og beskrivelse har også ledetekst (rutiner som checklists).
      expect(t.startRoutinePlaceholder, contains('- [ ]'));
      expect(t.stopRoutinePlaceholder, contains('- [ ]'));
      expect(t.descriptionPlaceholder.trim(), isNotEmpty);

      // Ingen seksjon kolliderer med reserverte slug-er.
      final reserved = {'cabin', 'start-rutiner', 'steng-rutiner'};
      expect(slugs.toSet().intersection(reserved), isEmpty);
    });

    test('standardCabinTemplates inneholder standardmalen', () {
      expect(standardCabinTemplates, contains(standardCabinTemplate));
    });
  });

  group('cabinFromTemplate', () {
    test(
      'bygger en gyldig hytte med alle seksjoner fylt i rett rekkefølge',
      () {
        final cabin = cabinFromTemplate(
          standardCabinTemplate,
          name: 'Sommehytta',
          slug: 'sommehytta',
          location: 'Røros',
        );

        expect(cabin.name, 'Sommehytta');
        expect(cabin.slug, 'sommehytta');
        expect(cabin.location, 'Røros');
        expect(cabin.sections.length, standardCabinTemplate.sections.length);

        // Beskrivelse og rutiner fylt med ledetekst.
        expect(cabin.description, isNotEmpty);
        expect(cabin.startRoutines.markdown, contains('- [ ]'));
        expect(cabin.stopRoutines.markdown, contains('- [ ]'));
        expect(cabin.startRoutines.type, SectionType.startRoutines);
        expect(cabin.stopRoutines.type, SectionType.stopRoutines);

        // Hver seksjon matcher sin spec: tittel, slug, type, orden, ledetekst.
        for (var i = 0; i < cabin.sections.length; i++) {
          final spec = standardCabinTemplate.sections[i];
          final s = cabin.sections[i];
          expect(s.title, spec.title);
          expect(s.slug, spec.slug);
          expect(s.type, spec.type);
          expect(s.order, i);
          expect(s.markdown, spec.placeholder);
        }

        // Ingen kollisjon mellom seksjonsslugs og reserverte slug-er.
        final all = {
          'cabin',
          'start-rutiner',
          'steng-rutiner',
          ...cabin.sections.map((s) => s.slug),
        };
        expect(all.length, cabin.sections.length + 3);
      },
    );

    test('tom lokasjon og standard orden er tillatt', () {
      final cabin = cabinFromTemplate(
        standardCabinTemplate,
        name: 'Hytta',
        slug: 'hytta',
        order: 4,
      );
      expect(cabin.location, isNull);
      expect(cabin.order, 4);
    });
  });
}
