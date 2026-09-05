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

- [ ] **Eksport → én fil:** samlet Markdown med bilder inlinet som base64 (valgfritt: referanse i stedet).
- [ ] **Eksport → mappe:** `.zip` med Markdown-filer + `images/` (tro mot lagringsformatet).
- [ ] **Deling:** `share_plus` for å dele eksportert fil (printer/e-post/deling).
- [ ] **Import:** velg `.md`/`.zip` (`file_picker`), pars frontmatter + heading-konvensjonen, rekonstruér modellen.
- [ ] **Round-trip-test:** eksport → import gir en likeverdig bok (integritet).
- [ ] **Konflikt-/validering:** håndter korrupte/ukjente filer med vennlige feilmeldinger.

**Milepæl 2:** Bruker kan eksportere «Sommehytta» til én `.md` (åpenes pent i f.eks.
Obsidian/Typora, printes), dele den, og importere den tilbake uten data tap.

### Fase 3 – Struktur, maler og oppbygging (uten AI)
Mål: hjelpe brukeren til å lage en komplett, velstrukturert bok.

- [ ] **Standardstrukturbibliotek:** innebygd mal for hva en hyttebok bør inneholde
      (f.eks. «Kontakter», «Adresser & koordinater», «Åpne-rutiner», «Steng-rutiner»,
      «Kjeller / ved», «Vann & avløp», «Elverk / strømforsyning», «Vedlikeholdsplan»,
      «Inventar», «Gjestebok / historier», «Tips for gjester»).
- [ ] **Mal-basert opprettelse:** «Ny hytte fra mal» som fyller ut seksjoner med ledetekst.
- [ ] **Reorganisering:** flytt/legge til/skjul seksjoner, endre rekkefølge (drag & drop).
- [ ] **Søk:** fulltekstssøk i hele boken.
- [ ] **Polering:** tomme tilstander, skelettladning, tilgangsløs design (dark mode).

**Milepæl 3:** En ny bruker kan med ett trykk få en komplett, ledetekst-fylt mal og
strukturere boken til å bli komplett – helt uten AI.

### Fase 4 – AI-integrasjon
Mål: AI hjelper med oppbygging, struktur og innhold.

- [ ] **`AiProvider`-abstraksjon** (tjenst i datalaget) med implementasjoner:
      `OpenAiProvider`, `AnthropicProvider`, `OllamaProvider`, `LmStudioProvider`,
      `CustomOpenAiCompatibleProvider`. (Ollama og LM Studio snakker OpenAI-kompatibel API –
      en klientdekning dekker de fleste tilfeller.)
- [ ] **Innstillinger:** velg leverandør, base-URL, modell, system-oppsett; lagre API-nøkkel
      i `flutter_secure_storage` (Keychain/Keystore). «Test tilkobling»-knapp.
- [ ] **Funksjoner:**
      - «Foreslå struktur» → returnerer et forslag til seksjoner (renderes som en gjenbruksbar mal).
      - «Skrivehjelp i editor» → utvid/omskriv/oppsummer et utvalg eller en seksjon.
      - «Generer rutineliste» → fra en beskrivelse eller (senere) et bilde av en notis.
- [ ] **Streaming-svar** i UI, avbrytbar; tydelig skille mellom «lokal» og «cloud» (privatliv).
- [ ] **Feilbehandling:** offline, tidsfrist, feil nøkkel, modell finnes ikke – med klare meldinger.

**Milepæl 4:** Med en lokal Ollama-instans (eller et API-nøkkel) kan brukeren få
AI-forslag på struktur og utkast til innhold, som kan godkjennes/redigeres som vanlig.

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
