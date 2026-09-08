/// Hvilken skriveoperasjon AI-en skal utføre i editoren.
enum AiWritingInstruction {
  extend('Utvid og utdyp teksten – hold deg til samme emne og tone.'),
  rewrite('Omskriv teksten slik at den blir klarere og bedre formulert.'),
  summarize('Oppsummer teksten konsist i noen setninger.');

  const AiWritingInstruction(this.instruction);

  /// Den konkrete oppgaven som sendes til modellen.
  final String instruction;
}

/// Bygger systemprompts for AI-funksjonene.
///
/// [base] er brukeren sin (eventuelt tilpassede) standard-systemprompt fra
/// innstillingene. Alle prompts krever at modellen returnerer KUN selve
/// resultatet, slik at svaret kan brukes direkte.
abstract final class AiPrompts {
  /// «Foreslå struktur»: strengt JSON-schema for en liste med seksjoner.
  static String structureSystem(String base) => '''$base

Returner KUN gyldig JSON (ingen forklaring, ingen markdown-kodeblokk) med form:
{"sections":[{"title":"tittel","type":"start|stop|beskrivelse|notater|medier|egen","hint":"kort ledetekst for innholdet"}]}

Foreslå 4–10 seksjoner som passer til hytta brukeren beskriver. Bruk «notater» eller «egen» for de fleste seksjoner; bruk «start»/«stop» kun dersom de trengs som vanlige notatseksjoner (ikke rutiner).''';

  /// «Generer rutineliste»: ren avkrysningsliste i Markdown.
  static String routineSystem(String base) => '''$base

Returner KUN en Markdown-avkrysningsliste der hver oppgave starter med «- [ ]». Ingen overskrifter, forklaring eller annet. 5–12 konkrete, korte oppgaver.''';

  /// Skrivehjelp i editor: utvid/omskriv/oppsummer.
  static String writingSystem(String base, AiWritingInstruction instruction) =>
      '''$base

Oppgave: ${instruction.instruction}

Returner KUN den ferdige teksten i Markdown. Ingen forklaring eller innledninger.''';

  /// Brukermelding for strukturforslag: kort beskrivelse av hytta.
  static String structureUser(String description) => 'Hytta: $description';

  /// Brukermelding for rutineliste: beskrivelse av hva rutinen skal dekke.
  static String routineUser(String description, {required bool isStart}) =>
      'Lag en ${isStart ? 'åpne-rutine' : 'steng-rutine'} basert på dette: '
      '$description';

  /// Brukermelding for skrivehjelp: selve teksten som skal behandles.
  static String writingUser(String text) => 'Tekst:\n\n$text';
}
