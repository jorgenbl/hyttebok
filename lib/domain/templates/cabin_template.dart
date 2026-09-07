import '../models/cabin.dart';
import '../models/section.dart';
import '../models/section_type.dart';

/// Definisjon av én seksjon i en mal: tittel, stabilt slug, type og
/// ledetekst som settes inn som utgangspunkt.
class SectionSpec {
  const SectionSpec({
    required this.title,
    required this.slug,
    this.type = SectionType.egen,
    this.placeholder = '',
  });

  final String title;

  /// Stabilt slug (mappe/filnavn) for seksjonen. Må være unikt innenom malen.
  final String slug;
  final SectionType type;

  /// Ledetekst som fylles inn som brødtekst i seksjonen ved opprettelse.
  final String placeholder;
}

/// En mal for hvordan en hytte bør struktureres (Fase 3).
///
/// En mal er **ren data**: den sier hvilke seksjoner en hytte bør inneholde,
/// med ledetekst, og ledetekst til beskrivelse/rutiner. [cabinFromTemplate]
/// materialiserer malen til en konkret [Cabin].
class CabinTemplate {
  const CabinTemplate({
    required this.name,
    required this.sections,
    this.descriptionPlaceholder = '',
    this.startRoutinePlaceholder = '',
    this.stopRoutinePlaceholder = '',
  });

  /// Synlig navn på malen (f.eks. «Standard hyttebok»).
  final String name;

  /// Seksjonene malen fyller hytta med, i ønsket rekkefølge.
  final List<SectionSpec> sections;

  /// Ledetekst til hyttens beskrivelse (valgfritt).
  final String descriptionPlaceholder;

  /// Ledetekst til åpne-/steng-rutinene (valgfritt).
  final String startRoutinePlaceholder;
  final String stopRoutinePlaceholder;
}

/// Bygger en [Cabin] ut fra en [CabinTemplate]: beskrivelse, rutiner og alle
/// seksjoner fylles med malens ledetekst, slik at brukeren får en komplett
/// start å bygge videre på.
Cabin cabinFromTemplate(
  CabinTemplate template, {
  required String name,
  required String slug,
  String? location,
  int order = 0,
}) {
  return Cabin(
    slug: slug,
    name: name,
    location: location,
    order: order,
    description: template.descriptionPlaceholder,
    startRoutines: Section(
      slug: 'start-rutiner',
      title: 'Åpne-rutiner',
      type: SectionType.startRoutines,
      order: 1,
      markdown: template.startRoutinePlaceholder,
    ),
    stopRoutines: Section(
      slug: 'steng-rutiner',
      title: 'Steng-rutiner',
      type: SectionType.stopRoutines,
      order: 2,
      markdown: template.stopRoutinePlaceholder,
    ),
    sections: [
      for (var i = 0; i < template.sections.length; i++)
        Section(
          slug: template.sections[i].slug,
          title: template.sections[i].title,
          type: template.sections[i].type,
          order: i,
          markdown: template.sections[i].placeholder,
        ),
    ],
    stories: const [],
  );
}

/// Standardmalen for en hyttebok – forslag til hva som bør være med.
const CabinTemplate standardCabinTemplate = CabinTemplate(
  name: 'Standard hyttebok',
  descriptionPlaceholder:
      'Beskriv hytta: hva den er, hvor den ligger, kapasitet, nøkkeler '
      'og alt det viktigste gjestene bør vite.',
  startRoutinePlaceholder:
      'Lag en liste over ting du gjør når du åpner hytta. Bruk avkryssingslister.\n\n'
      '- [ ] Slå på strømmen\n'
      '- [ ] Slå på vannet\n'
      '- [ ] Tenn peisen\n'
      '- [ ] Sjekk at toalettet har vann',
  stopRoutinePlaceholder:
      'Lag en liste over ting du gjør når du stenger hytta. Bruk avkryssingslister.\n\n'
      '- [ ] Tøm søpla\n'
      '- [ ] Slå av vannet og strømmen\n'
      '- [ ] Lukk vinduer\n'
      '- [ ] Noter gjenværende ved',
  sections: [
    SectionSpec(
      title: 'Kontakter & nøkkeler',
      slug: 'kontakter-nokkeler',
      type: SectionType.notater,
      placeholder:
          'Verktøyforer, elektrik, brann, nøkkeler og naboer.\n\n'
          '- Navn: \n'
          '- Telefon: \n'
          '- Adresse: ',
    ),
    SectionSpec(
      title: 'Adresse & koordinater',
      slug: 'adresse-koordinater',
      type: SectionType.notater,
      placeholder:
          'GPS-koordinater, veibeskrivelse og parkering.\n\n'
          '- Koordinater: \n'
          '- Veibeskrivelse: \n'
          '- Parkering: ',
    ),
    SectionSpec(
      title: 'Vann, avløp & toalett',
      slug: 'vann-avlop-toalett',
      placeholder:
          'Hvordan vannet kobles på og av, avløp og toalett.\n\n'
          '- Slå på vannet: \n'
          '- Avløp: \n'
          '- Toalett: ',
    ),
    SectionSpec(
      title: 'Strøm, brytere & generator',
      slug: 'strom-brytere-generator',
      placeholder:
          'Hovedbryter, sikringer, generator og solcelle.\n\n'
          '- Hovedbryter: \n'
          '- Sikringer: \n'
          '- Generator: ',
    ),
    SectionSpec(
      title: 'Ved & peis',
      slug: 'ved-peis',
      placeholder:
          'Vedforsyning, peisrenser og røyk.\n\n'
          '- Hvor lang til ved: \n'
          '- Peisrenser: \n'
          '- Røyk: ',
    ),
    SectionSpec(
      title: 'Kjeller, boder & utstyr',
      slug: 'kjeller-boder-utstyr',
      placeholder:
          'Kjeller, boder, utstyr og båt/brygge.\n\n'
          '- Kjeller: \n'
          '- Boder: \n'
          '- Utstyr: ',
    ),
    SectionSpec(
      title: 'Vedlikeholdsplan',
      slug: 'vedlikeholdsplan',
      placeholder:
          'Sesongvise vedlikeholdsoppgaver. Bruk avkryssingslister.\n\n'
          '- [ ] Vår: \n'
          '- [ ] Sommer: \n'
          '- [ ] Høst: \n'
          '- [ ] Vinter: ',
    ),
    SectionSpec(
      title: 'Inventar',
      slug: 'inventar',
      placeholder:
          'Hva som er med i hytta, og hvor det står.\n\n'
          '| Gjenstand | Hvor |\n'
          '| --- | --- |\n'
          '|  |  |',
    ),
    SectionSpec(
      title: 'Tips for gjester',
      slug: 'tips-for-gjester',
      placeholder:
          'Gode råd og ting å huske for alle som bor i hytta.\n\n'
          '- Husk å: ',
    ),
  ],
);

/// Alle malene appen tilbyr. Start med én (standard); utvides senere.
const List<CabinTemplate> standardCabinTemplates = [standardCabinTemplate];
