# Implementasjonsplan – Hyttebok

Dokumentet beskriver hva vi bygger, i hvilken rekkefølge, med hvilke avgjørelser.
Det er ment å være et levende dokument: faser oppdateres etter hvert som vi jobber.

Les også: [arkitektur.md](./arkitektur.md) (teknisk design) og
[markdown-format.md](./markdown-format.md) (filformatet).

---

## 1. Sammendrag

**Hyttebok** er en lokal-first mobilapp (iOS + Android, web senere) som fungerer som en
digital bok om én eller flere hytter. Brukeren legger inn **start/steng-rutiner,
beskrivelser, bilder og historier**, kan strukturere boken fritt, og kan **eksportere
den som Markdown** for å skrive ut, dele og importere den tilbake. En senere fase legger
til **AI-støtte** (cloud-API som Claude/OpenAI, eller lokale modeller via Ollama/LM Studio)
som hjelper med å bygge opp og strukturere boken.

Det definerende valget: **boken lagres som en mappe med Markdown-filer + bilder på
enheten.** Lagringsformatet er likt eksportformatet. Dette gir lokal lagring uten server,
portabilitet, git-synkronisering og tap-fri import/eksport «for gratis».

---

## 2. Produktkrav

### 2.1 Funksjonskrav (MVP + videre)

| # | Krav | Fase |
| --- | --- | --- |
| F1 | Opprette, åpne og liste én eller flere bøker | 1 |
| F2 | Legge inn én eller flere hytter i en bok | 1 |
| F3 | Redigere fritekst-seksjoner som Markdown (med forhåndsvisning) | 1 |
| F4 | Start-rutiner og steng-rutiner per hytte (støtter avkrysningslister) | 1 |
| F5 | Beskrivelse per hytte (fritekst + bilder) | 1 |
| F6 | Historier (tittel, dato, forfatter, innhold, bilder) | 1 |
| F7 | Ta opp / velge bilder (kamera + galleri) og knytte dem til seksjoner/historier | 1 |
| F8 | Eksportere hele boken til én Markdown-fil (bilder inlinet som base64) | 2 |
| F9 | Eksportere hele boken som mappe (.zip med Markdown + bilder) | 2 |
| F10 | Dele eksportert fil (OS-deling, f.eks. e-post/AirDrop/printer) | 2 |
| F11 | Importere bok fra Markdown-fil / mappe (.zip) | 2 |
| F12 | Strukturbibliotek: forslag om hva en hyttebok bør inneholde + maler | 3 |
| F13 | Omdanne / reorganisere seksjoner (flytte, gjemme, omnavne) | 1–3 |
| F14 | AI: foreslå struktur og innhold for boken/hytta | 4 |
| F15 | AI: hjelpe med å skrive/utvide/omskrive en seksjon | 4 |
| F16 | AI-tilkobling: OpenAI, Anthropic (Claude), Ollama, LM Studio, egen OpenAI-kompatibel endepunkt | 4 |
| F17 | Web-plattform (flutter web) | 5 |
| F18 | Eksport til PDF / direkte utskrift | 5 |

### 2.2 Ikke-funksjonelle krav

- **Lokal lagring:** ingen server, ingen nettverk nødvendig for kjernefunksjonene.
- **Offlinedrift:** hele MVP fungerer uten nett.
- **Privatliv:** data forlater ikke enheten uten at brukeren aktivt bruker AI (cloud).
- **Portabilitet:** en bok kan åpnes/redigeres utenfor appen (ren Markdown + bilder).
- **Plattform:** iOS + Android som mål 1; web som mål 2.
- **Språk:** norsk (Bokmål) som primærspråk i UI, med i18n-klar struktur.

### 2.3 Uttrykkelig utenfor omfang (for nå)

- Flere brukere / kontoer / cloud-synkronisering.
- Sanntidssamarbeid.
- Full WYSIWYG-editor med rik tekst (vi bruker Markdown-kilde + forhåndsvisning).

---

## 3. Arkitektoniske prinsipper

Følgende prinsipper styres av prosjektets offisielle Flutter-skill
(`flutter-apply-architecture-best-practices`):

1. **Lagdelt arkitektur** (UI / Domain / Data) med streng separasjon.
   - **UI** = tunge, gjenbrukbare widgets (Views) + ViewModels (`ChangeNotifier`).
   - **Domain** = rene, umutbare domänmodeller (`freezed`) + valgfri Use-Case-logikk.
   - **Data** = Repositorier (én kildetilhørighet) som kaller Tjenester (fil-io, http, bilder).
2. **Repository-mønsteret** som én sannhetskilde: UI vet aldri om filer/mapper, bare domänmodeller.
3. **Avhengighetssprøytning** via `provider` (DI via constructor injection).
4. **Testbarhet:** Repositorier og ViewModels er enkle å teste isolert (mock Tjenester).
5. **Filformatet er kontrakten:** lagring, eksport og import deler én representasjon
   (se [markdown-format.md](./markdown-format.md)).

Prosjektstruktur og datamodell finnes i [arkitektur.md](./arkitektur.md).

---

## 4. Faser og milepæler

> Hver fase avsluttes med en **milepæl** (verifiserbar leveranse) og grønn
> `dart analyze` + `flutter test`.

### Fase 0 – Grunnleggelse (nå)
Mål: et solid, testbart og CI-klar grunnlag.

- [x] Prosjekt initialisert (Flutter 3.47.2 / Dart 3.13.2).
- [x] Offisielle Flutter/Dart-skills installert i `.agents/skills/`.
- [x] Dokumentasjon (plan, arkitektur, format, AI).
- [x] Git-repo koblet til GitHub (`origin`).
- [ ] Avhengigheter lagt til i `pubspec.yaml` (se [arkitektur.md](./arkitektur.md)).
- [ ] Prosjektstruktur (mapper under `lib/`) opprettet.
- [ ] Tjennelse/tema + språkgrunnlag (Bokmål) satt opp.
- [ ] GitHub Actions-workflow: `dart analyze`, `flutter test`, (valgfritt) `flutter build`.
- [ ] `flutter_secure_storage`, `path_provider` og kamera-/lagringsrettigheter konfigurert per plattform.

**Milepæl 0:** Repo pushet, CI grønn, `flutter run` viser en enkel startskjerm.

### Fase 1 – MVP: kjernen boken
Mål: lage og redigere en bok med én eller flere hytter, helt lokalt.

- [x] **Lagringsmotor:** mappebasert filio (opprette/bok, lese/skrive seksjoner som `.md` med frontmatter, lagre bilder i `images/`).
- [x] **Datamodell + Repositorier:** ett `BookRepository` over fil-tjenesten.
- [x] **UI – Bibliotek:** liste bøker, opprett ny, slett, åpne.
- [x] **UI – Hytte:** liste hytter i en bok, opprett/slett/omnavn, redigere navn/sted.
- [x] **UI – Editor:** Markdown-kilderedigering + forhåndsvisning (skift mellom «Rediger»/«Forhåndsvis»). Støtter avkrysningslister.
- [x] **UI – Bilder:** ta opp (kamera) / velge (galleri), lagre i boken, innsette i seksjon/historie. *(Fase 1b)*
- [ ] **Navigasjon:** `go_router` med `StatefulShellRoute` (bunnnav «Bøker»/«Innstillinger»). — *Kjerne-routing med `go_router` er på plass; bunnnav-skal (`StatefulShellRoute`) er utsatt.*
- [x] **Tester:** enhetstester for lagringsmotor + Repositorier; widget-tester for editor og bibliotek.

**Milepæl 1: ✅ nådd** – Bruker kan opprette «Sommehytta», legge til en hytte, skrive
start-/steng-rutiner, beskrivelse og 2–3 historier med bilder – alt lagret lokalt og
bevarer seg ved app-oppstart.

#### Fase 1b – Bilder (fullført)
- `image_picker` + `permission_handler` lagt til i `pubspec.yaml`.
- `ImagePickerService` (datalag): `takePhoto()` ber om kamera-rettighet først;
  `pickFromGallery()` er rettighetsfritt. Testbar via underklassing (fake).
- `BookRepository.importImage(bookSlug, XFile)`: leser byteene, gir filen et unikt
  navn (tidsstempel) og lagrer den i `<bok>/images/`; returnerer relativ sti.
- Editoren får knappene «Ta bilde»/«Fra galleri» som setter inn
  `![navn](images/…)` på cursorposisjonen (kun når `bookSlug` er satt).
- Plattform: Android `CAMERA`-rettighet + ikke-obligatorisk kamera-feature;
  iOS `NSCameraUsageDescription` / `NSPhotoLibraryUsageDescription` /
  `NSPhotoLibraryAddUsageDescription`.
- Tester: `importImage` round-trip + unikt filnavn (enhet); editor setter inn
  bilde via fake-piker (widget).

### Fase 2 – Eksport / Import / Deling
Mål: boken kan ut og inn.

- [x] **Eksport → én fil:** samlet Markdown med bilder inlinet som base64 (valgfritt: referanse i stedet).
- [x] **Eksport → mappe:** `.zip` med Markdown-filer + `images/` (tro mot lagringsformatet).
- [x] **Deling:** `share_plus` for å dele eksportert fil (printer/e-post/deling).
- [x] **Import:** velg `.md`/`.zip` (`file_picker`), pars frontmatter + heading-konvensjonen, rekonstruér modellen.
- [x] **Round-trip-test:** eksport → import gir en likeverdig bok (integritet).
- [x] **Konflikt-/validering:** håndter korrupte/ukjente filer med vennlige feilmeldinger.

**Milepæl 2: ✅ nådd** – Bruker kan eksportere «Sommehytta» til én `.md` (åpenes pent i
f.eks. Obsidian/Typora, printes), dele den, og importere den tilbake uten data tap.

#### Fase 2 – Eksport/Import/Deling (fullført)
- `share_plus`, `file_picker` og `archive` lagt til i `pubspec.yaml`.
- `book_markdown.dart` (datalag): `bookToSingleFile` / `singleFileToBook` – én samlet
  Markdown med struktur koden i HTML-kommentar-markører
  (`<!-- cabin:… -->`, `<!-- start:images=… -->`, `<!-- section:… -->`,
  `<!-- story:… -->`) + heading-konvensjonen. Bilder inlines som base64-data-uri ved
  eksport og trekkes ut til filer igjen ved import (byte-preservasjon).
- `BookRepository`: `exportSingleFile(slug)` (én `.md`), `exportZip(slug)` (`.zip` med
  Markdown + `images/` + `cabins/`), `importFromPath(path)` (`.md`/`.zip` → ny bok med
  unikt slug). Eksport legges i en eksportmappe (injectbar for tester).
- `ShareService` (`share_plus`-innpakning: `shareFile(path, {subject})`) og
  `FilePickerService` (`file_picker`-innpakning: `pickBookFile()` → `PickedBookFile`),
  begge injiserbare via `HyttebokApp` for tester.
- `InvalidBookFile`-feiltype for vennlige meldinger ved tom/korrupt/ukjent inndata.
- UI: delingsmeny på bok-siden («Del som Markdown» / «Del som mappe») og «Importer
  bok»-knapp i biblioteket (plukk → import → naviger til den nye boken).
- Tester: serializer round-trip (ren tekst eksakt like, base64-bilder trekkes ut med
  byte-preservasjon), repo eksport/import for `.md` og `.zip`, korrupt/ukjent inndata →
  `InvalidBookFile`; widget-tester for delingsmenyen og import-flyten.

### Fase 3 – Struktur, maler og oppbygging (uten AI)
Mål: hjelpe brukeren til å lage en komplett, velstrukturert bok.

- [x] **Standardstrukturbibliotek:** innebygd mal for hva en hyttebok bør inneholde
      (f.eks. «Kontakter», «Adresser & koordinater», «Åpne-rutiner», «Steng-rutiner»,
      «Kjeller / ved», «Vann & avløp», «Elverk / strømforsyning», «Vedlikeholdsplan»,
      «Inventar», «Gjestebok / historier», «Tips for gjester»).
- [x] **Mal-basert opprettelse:** «Ny hytte fra mal» som fyller ut seksjoner med ledetekst.
- [x] **Reorganisering:** flytt/legge til/skjul seksjoner, endre rekkefølge (opp/ned-kontroller; drag & drop er et oppfølgingspunkt).
- [x] **Søk:** fulltekstssøk i hele boken.
- [x] **Polering:** tomme tilstander, skelettladning, tilgangsløs design (dark mode + tema-veksler).

**Milepæl 3: ✅ nådd** – En ny bruker kan med ett trykk få en komplett, ledetekst-fylt
mal og strukturere boken til å bli komplett – helt uten AI.

#### Fase 3 – Struktur/maler/søk/polering (fullført)
- **Standardstrukturbibliotek** (`lib/domain/templates/cabin_template.dart`): rene
  datamodeller `CabinTemplate`/`SectionSpec` + konstant `standardCabinTemplate`
  (Kontakter & nøkkeler, Adresse & koordinater, Vann/avløp/toalett,
  Strøm/brytere/generator, Ved & peis, Kjeller/boder/utstyr, Vedlikeholdsplan,
  Inventar, Tips for gjester) + ledetekst til beskrivelse og åpne-/steng-rutiner.
  `cabinFromTemplate(...)` materialiserer malen til en `Cabin`. Injiserbart via
  `HyttebokApp(cabinTemplates: …)`.
- **Mal-basert opprettelse:** FAB i boken åpner bottom sheet «Ny hytte» /
  «Ny hytte fra mal» (navn + valgfritt sted → full struktur med ledetekst).
  `BookViewModel.createCabinFromTemplate`.
- **Reorganisering:** `Section.hidden` (persistert i lagrings-frontmatter og i
  serializer-markøren `hidden=true`, tap-fri round-trip). `CabinViewModel.moveSection`
  (opp/ned blant synlige) og `toggleHideSection`. UI: kontekstmeny per seksjon
  (flytt opp/ned, skjul/vis igjen, slett) + separat «Skjulte seksjoner»-gruppe.
  Drag & drop (i stedet for opp/ned) er et oppfølgingspunkt.
- **Søk** (`lib/domain/search/book_search.dart`): ren funksjon `searchBook(book, query)`
  (case-uavhengig, hele boken inkl. skjulte seksjoner) → `SearchResult`. Søkeskjerm
  via rute `/book/:slug/search` + søkeknappp i boken; treff navigerer til hytta.
- **Polering:** `SkeletonList` (pulsrende skelett) i ladingstilstand; tema-veksler
  (system/lys/mørk) via `ThemePreference` + meny i biblioteket (mørk modus følger
  system og kan velges manuelt); bedre tomme tilstander. Temavalget holdes i minne
  for sesjonen; persistering mellom oppstart krever et innstillingslager og er et
  oppfølgingspunkt.
- **Feilrettelse underveis:** `showTextInputDialog` byttet til egen `StatefulWidget`
  som eier `TextEditingController` (disposert i `State.dispose`) – fikser latent
  «used after disposed» ved påfølgende dialoger.
- Tester: enhetstester for mal, søk og `hidden`-round-trip (lagring + serializer);
  widget-tester for «Ny hytte fra mal», flytt/skjul-seksjoner, søk og tema-veksler.

### Fase 4 – AI-integrasjon
Mål: AI hjelper med oppbygging, struktur og innhold.

- [x] **`AiClient`-abstraksjon** (tjenst i datalaget): `OpenAiCompatibleClient`
      (dekker OpenAI, Ollama, LM Studio og egen OpenAI-kompatibel) + egen
      `AnthropicClient` (Claude sitt request/response-format). Felles SSE-parsing
      (CRLF-sikker, chunk-sikker), status-feilmapping og timeout.
- [x] **Innstillinger:** leverandør, base-URL, modell, systemprompt (+ avansert:
      maks token, temperatur); API-nøkkel KUN i `flutter_secure_storage`
      (Keychain/Keystore), aldri i innstillingsfilen. «Test tilkobling»-knapp.
- [x] **Funksjoner:**
      - «Foreslå struktur» → strengt JSON `{"sections":[…]}` som parseres tolerant
        (code fences, forklaringstekst) → godkjenn/forkast; godkjente seksjoner
        blir vanlige seksjoner i boka.
      - «Skrivehjelp i editor» → utvid/omskriv/oppsummer et utvalg (ellers hele
        teksten); resultatet settes inn i editoren (erstatt utvalg/tekst).
      - «Generer rutineliste» → `- [ ]`-liste fra teksten i åpnings-/steng-rutiner
        (tilgjengelig i AI-menyen i editor for disse seksjonene).
- [x] **Streaming-svar** i UI, avbrytbar; «Lokal» vs «Cloud»-indikator i
      innstillingene (basert på base-URL) + privatslivstekst.
- [x] **Feilbehandling:** offline/ukjent feil, tidsfrist (30 s), feil nøkkel (401/403),
      modell finnes ikke (404), rate-limit (429), 5xx, og uformatert AI-svar
      (faller tilbake til rå tekst + «Prøv igjen») – alle med norske meldinger.

**Milepæl 4: ✅ nådd** – Med en lokal Ollama-instans (eller et API-nøkkel) kan
brukeren få AI-forslag på struktur og utkast til innhold, som kan godkjennes/
redigeres som vanlig.

#### Fase 4 – AI-integrasjon (fullført)
- **Datapotet** (`lib/data/services/ai_client.dart`, `ai_settings.dart`,
  `secure_key_store.dart`, `lib/data/repositories/settings_repository.dart`):
  `AiClient`-abstraksjon (`complete` som streamer + `ping` for tilkoblingstest),
  `AiClientFactory` (leverandør → klient, injiserbar `httpClient` i tester) og
  `AiClientBuilder`-typedef for test-injeksjon. `AiSettings` (type, base-URL,
  modell, systemprompt, maks token, temperatur) med `isLocal` (loopback-deteksjon)
  og `needsApiKey`; tolerant `fromJson`. Innstillinger lagres som `settings.json`
  i app-mappen; API-nøkkel i `SecureKeyStore` (iOS Keychain / Android Keystore).
  `AiProviderError` i `lib/core/errors.dart` bærer norske, brukervenlige meldinger.
- **Domene** (`lib/domain/ai/`): `AiStructureSuggestion.tryParse` (tolerant mot
  code fences/forklaring, type-mapping wire-navn → `SectionType`, `null` ved
  skrott) + `AiPrompts` (strengt JSON-schema for struktur, `- [ ]`-liste for
  rutiner, utvid/omskriv/oppsummer; alle bygger på brukeren sin systemprompt).
- **Innstillings-UI** (`lib/ui/features/settings/`): nådd via innstillingsikon
  i biblioteket (rute `/settings`). Første gang: privatslivsforklaring + valg
  «lokal» eller «cloud». Deretter form (leverandør-dropper med standard-URL/
  modell per type, base-URL, modell, API-nøkkel med skjule/vis, systemprompt,
  avansert-uttrekk, «Test tilkobling»). Alt lagres automatisk (seriert);
  Lokal/Cloud-indikator følger base-URLen.
- **Funksjons-UI** (`lib/ui/features/ai/`): felles `AiAssistantViewModel`
  (streaming, avbrudd, feil, «ikke konfigurert»/«mangler nøkkel»-sjekk) brukt av
  «Foreslå struktur»-dialogen i hytta (beskrivelse → streaming → parsede
  seksjoner → «Opprett seksjoner»/«Forkast»; `CabinViewModel.addSections` lager
  unike slugs og bruker hint som start-Markdown) og skrivehjelp-dialogen i
  editoren (utvid/omskriv/oppsummer på utvalg eller hele tekst; «Generer
  rutineliste» for start/steng-rutiner; «Innsett» erstatter utvalget/teksten).
- **Plattform:** iOS `NSAllowsLocalNetworking` (Info.plist) + Android
  `network_security_config` (klartekst kun til localhost/127.0.0.1) slik at
  lokale leverandører (Ollama/LM Studio) fungerer.
- Tester: enhetstester for SSE-parsing (OpenAI + Anthropic, CRLF/delte chunks/
  flerbytes tegn, `[DONE]`, keep-alive), status-feilmapping (401/403/404/429/500/
  418, Socket/Client-exception), factory, `AiSettings` (standarder, round-trip,
  `isLocal`/`needsApiKey`), `SettingsRepository` (round-trip, tolerant mot
  ødelagte filer), `AiStructureSuggestion.tryParse` og `AiPrompts`; widget-tester
  for innstillingsfløten (intro → lokal → cloud → nøkkel i sikker lagring →
  test tilkobling vellykket/feil, persistens uten nøkkel i filen), strukturforslag
  (streaming → parse → godkjenn → seksjonene vises; forkast; leverandørfeil;
  uformatert svar; ikke konfigurert) og editor-AI (rutineliste innsett, utvid
  tekst, forkast endrer ingenting).

### Fase 5 – Web og ferdigpolering
- [ ] **Web-mål:** `flutter build web`, fikse plattformspesifikke deler (kamera/filer via web-API).
- [ ] **PDF-utskrift** av boken (direkte utskrift / lagre PDF).
- [ ] **Automatiserte integrasjonstester** (`flutter drive` / `integration_test`).
- [ ] **Butikksomheting:** ikoner, skjærmyr, beskrivelser, bygg for iOS/Android.
- [ ] **Dokumentasjon:** oppdater README, skrive en «Brukerveiledning».

**Milepæl 5:** Appen bygges for iOS, Android og web; kan eksporteres til PDF.

---

## 5. Teknologi & pakkevalg (oppsamling)

Detaljert grunngivning ligger i [arkitektur.md](./arkitektur.md). Oppsummering:

| Område | Pakke |
| --- | --- |
| Navigasjon | `go_router` |
| Tilstand / DI | `provider` (+ `ChangeNotifier` ViewModels) |
| Domänmodeller | `freezed` (+ `json_serializable` der det trengs) |
| Fil-io / dokument-mappe | `path_provider`, `file` |
| Markdown-rendering | `flutter_markdown` |
| Markdown-redigering (senere) | `flutter_code_editor` (MVP: kilde + forhåndsvisning) |
| Kamera / bilder | `image_picker` |
| Deling | `share_plus` |
| Velge fil (import) | `file_picker` |
| Zip (mappe-eksport/import) | `archive` |
| Rettigheter | `permission_handler` |
| HTTP (AI) | `http` |
| Sikker lagring (nøkkler) | `flutter_secure_storage` |
| i18n (senere) | `flutter_localizations` / `intl` |
| Testing | `flutter_test`, `mockito` eller `mocktail` |

Alt er velkjente, velvedligeholdte pakker fra den offisielle Flutter/Dart-økosfæren.

---

## 6. Risiko & avveininger

| Risiko | Vurdering / mottiltak |
| --- | --- |
| Filbasert lagring vs. database | Valgt filbasert for portabilitet. Ved store bøker kan vi legge et lokalt indeks/DB-lag (Drift) **over** filene for hastighet, uten å endre formatet. |
| Markdown-import fra eksterne kilder | Vi styrer formatet selv → round-trip er pålitelig. Vi håndterer ukjente frontmatter-felt tolerant (bevarer dem). |
| WYSIWYG-editor-mognad i Flutter | Ingen perfekt Markdown-WYSIWYG ennå. Vi bruker kilde + forhåndsvisning (robust), og vurderer `flutter_code_editor` for syntak. |
| AI-privatliv | Tydelig valg mellom lokal og cloud; nøkkler i sikker lagring; data sendes kun til valgt leverandør. |
| Web-plattform (kamera/filer) | Web har begrensede file/camera-API-er; isoleres bak Tjenestegrensesnittet så plattformene kan avvike. |
| Base64-bilder i én-fil-eksport | Gjør filen stor. Vi tilbyr mappe-eksport (`.zip`) som primær for deling, én-fil for utskrift. |

---

## 7. Verifisering (kvalitetsport)

For hver fase skal følgende kjøre grønt lokalt og i CI:

```bash
dart analyze        # ingen feil/advarsler
flutter test        # enhets- + widget-tester
flutter test --coverage   # dekning (målestokk: kritisk logikk > 80 %)
```

- Enhets-tester: datamodell, lagringsmotor (round-trip), Repositorier, AI-parsning.
- Widget-tester: editor (rediger/forhåndsvis), bibliotek, hytte-liste, eksport-dialog.
- Integrasjonstester (Fase 5): opprett → skriv → eksport → import → sammenlign.

---

## 8. Næste steg (konkret, umiddelbart)

1. `flutter pub add` for pakker i Fase 0/1 (se [arkitektur.md](./arkitektur.md)).
2. Oprette `lib/`-struktur (data/domain/ui) og en enkel ruter.
3. Implementere **lagringsmotoren** (mappe + frontmatter) med round-trip-enhetstester – dette er fundamentet.
4. Mape `go_router` + `provider` inn i `main.dart`.
5. Bygge bibliotek- og hytte-ui, deretter editoren med forhåndsvisning.
6. Sette opp GitHub Actions-workflow.
