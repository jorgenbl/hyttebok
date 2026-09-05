# Arkitektur – Hyttebok

Teknisk design for Hyttebok. Styrt av det offisielle Flutter-skill
`flutter-apply-architecture-best-practices`: **lagdelt arkitektur (UI / Domain / Data)**
med MVVM i UI-laget og Repository-mønster i datalaget.

---

## 1. Lagdelt modell

```
┌─────────────────────────────────────────────┐
│  UI (Presentation)                          │
│  Views (widgets)  +  ViewModels             │
│  (ChangeNotifier, exponerer immutable tilstand)│
├─────────────────────────────────────────────┤
│  Domain (Logikk)                            │
│  Renumulbare modeller (freezed)            │
│  + Use Cases (valgfri, for kompleks logikk) │
├─────────────────────────────────────────────┤
│  Data                                       │
│  Repositorier (én sannhetskilde)           │
│  → Tjenester: FilIO, ImageIO, AiClient      │
└─────────────────────────────────────────────┘
```

- **Views** = tunge widgets. Ingen forretningslogikk – kun layout/animasjon/routing.
  Mottar data fra ViewModel og kaller kommandoer (`load()`, `save()`, …).
- **ViewModels** arver `ChangeNotifier`. Injecter et Repository via constructor.
  Eksponerer immutable snapshots + `async`-kommandoer.
- **Repositorier** er én sannhetskilde. De transformerer persisterte DTO-er til rene
  domänmodeller og skjuler fil-/nettverksdetaljer.
- **Tjenester** er tilstandslose klasser som pakkter eksterne API-er: filsystemet
  (`FileStorageService`), bilder (`ImageService`), AI (`AiClient`). Returnerer rå data.
- **Use Cases** (valgfri): kun dersom logikken blir kompleks eller skal deles mellom
  flere ViewModels (f.eks. «EksportBok», «ImportBok»).

---

## 2. Prosjektstruktur

Hybrid: UI grupperes per **funksjon**, data/domain grupperes per **type**.

```text
lib/
├── main.dart                  # bootstrap, DI-oppsett (provider), MaterialApp.router
├── app/
│   ├── app.dart               # rot-widget, tema
│   ├── router.dart            # GoRouter + StatefulShellRoute
│   └── di.dart                # tjenesteregistrering (MultiProvider / get_it)
├── core/
│   ├── errors/                # Feil-typer / Result
│   ├── utils/                 # slugs, datoformat, md-hjelpere
│   └── widgets/               # gjenbrukbare UI (MdEditor, MdPreview, ImageGrid)
├── domain/
│   ├── models/
│   │   ├── book.dart          # Book
│   │   ├── cabin.dart         # Cabin
│   │   ├── section.dart       # Section (type + markdown + bilder)
│   │   └── story.dart         # Story
│   └── use_cases/             # EksportBok, ImportBok, (senere) Ai*
├── data/
│   ├── models/                # persisterte DTO-er (frontmatter-mapping)
│   ├── services/
│   │   ├── file_storage_service.dart   # mappe/.md/bilder IO
│   │   ├── image_service.dart          # image_picker → lagre i boken
│   │   └── ai_client.dart              # OpenAI/Anthropic/Ollama/LM Studio
│   └── repositories/
│       ├── book_repository.dart        # lese/skrive en hel bok
│       └── settings_repository.dart    # app- + AI-innstillinger
└── ui/
    ├── core/                  # tema, typography, farger, felles stil
    └── features/
        ├── library/           # (views + view_models) liste/oppsett bøker
        ├── book/              # bokoversikt, hytte-liste
        ├── cabin/             # hyttedetalj, seksjonsliste
        ├── editor/            # Markdown-editor + forhåndsvisning (gjenbrukes)
        ├── media/             # bildevalg/galleri
        ├── export_import/     # eksport-/import-dialoger
        ├── ai/                # AI-assistent, tilkobling
        └── settings/          # app- + AI-innstillinger
```

---

## 3. Datamodell (Domain)

Reenumulbare modeller (implementeres med `freezed` for `copyWith`/`==`/`hashCode`).

```dart
/// En bok om én eller flere hytter.
class Book {
  final String slug;          // mappe-navn, f.eks. "sommehytta"
  final String title;
  final String intro;         // Markdown (valgfritt forsiden)
  final String? coverImage;   // relativ sti til images/
  final List<Cabin> cabins;
  final DateTime updatedAt;
}

/// Én hytte.
class Cabin {
  final String slug;
  final String name;
  final String? location;
  final Section startRoutines;   // typisk avkrysningslister
  final Section stopRoutines;
  final List<Section> sections;  // ordinære, ordnede seksjoner (beskrivelse, tips…)
  final List<Story> stories;
}

/// En fritekst-seksjon med Markdown + bilder.
class Section {
  final String slug;
  final String title;
  final String markdown;         // brødtekst
  final List<String> images;     // relative stier til images/
  final SectionType type;        // start, stop, beskrivelse, notater, medier, …
  final int order;
}

enum SectionType { startRoutines, stopRoutines, beskrivelse, notater, medier, historien, egen }

/// En historie / gjestebok-innlegg.
class Story {
  final String slug;
  final String title;
  final DateTime? date;
  final String? author;
  final String markdown;
  final List<String> images;
  final int order;
}
```

**Merking:** `SectionType` er et hjelp for UI (ikoner, rekkefølge, standard-maler),
men modellen er bevisst åpen – en `egen`-type gir fri struktur. Dette understøtter
AI-forslag om «hva boken bør inneholde» uten å låse innholdet.

---

## 4. Lagring: filbasert, Markdown-native

**Prinsipp:** en bok er en mappe. Inholdet er `.md`-filer med YAML-frontmatter; bilder
ligger i `images/` og refereres med relativ sti. Lagringsformatet = eksportformatet.

Detaljer og filkontrakten: [markdown-format.md](./markdown-format.md).

`FileStorageService` (tjenest i datalaget) abstraherer alt fil-io:

```dart
abstract class FileStorageService {
  Future<String> createBook(String title, {String? intro});   // returover mappe
  Future<List<BookMeta>> listBooks();
  Future<Book> readBook(String slug);
  Future<void> writeBook(Book book);
  Future<void> deleteBook(String slug);
  Future<String> saveImage(String bookSlug, XFile picked);    // returover relativ sti
  Future<Uint8List> readImageBytes(String bookSlug, String relativePath);
}
```

`BookRepository` bruker `FileStorageService` og returnerer domänmodeller. UI kaller
aldrig `FileStorageService` direkte.

> **Vekstmulighet:** ved svært store bøker kan vi legge et lokalt indeks-lag
> (f.eks. Drift/SQLite) **over** filene for søk/hastighet, uten å endre formatet.
> Det er ikke nødvendig for MVP.

---

## 5. Navigasjon (`go_router`)

- `MaterialApp.router` med en `GoRouter`.
- `StatefulShellRoute.indexedStack` for et vedvarende skal med bunnnav:
  `Bøker` / `Innstillinger` (senere kanskje `Assistent`).
- Ruter (eksempel):
  - `/library` → bibliotek
  - `/book/:slug` → bokoversikt
  - `/book/:slug/cabin/:cabinSlug` → hyttedetalj
  - `/book/:slug/cabin/:cabinSlug/section/:sectionSlug` → editor
  - `/settings`, `/settings/ai`
- Deep linking og Web-url-strategi (`usePathUrlStrategy`) til Web-fasen.

---

## 6. Tilstandsstyring & DI

- **ViewModels** = `ChangeNotifier`, lytt med `ListenableBuilder`/`AnimatedBuilder`.
- **DI** via `provider`:
  - Registrer Tjenester (`FileStorageService`, `ImageService`, `AiClient`) som
    singleton/`ChangeNotifierProvider.value` i rot.
  - Registrer Repositorier som avhenger av Tjenestene.
  - Skap ViewModels med `ChangeNotifierProvider` per funksjon (inject Repository).
- Alternativer vurdert: `Riverpod` (meget populært) og `get_it`. Vi holder oss til
  `provider` + `ChangeNotifier` for å være i tråd med det offisielle skill-et og holde
  det enkelt; bytte til Riverpod er en lokal omstrukturerings-operasjon dersom ønskes.

---

## 7. Teknologi- & pakkevalg

Alle er velkjente pakker i det offisielle Flutter/Dart-økosystemet.

| Område | Pakke | Grunngivning |
| --- | --- | --- |
| Navigasjon | `go_router` | Offisielt anbefalt; declarative routing, deep linking, Web-vennlig. |
| Tilstand/DI | `provider` | Lettvint, innebygd i Flutter; parer bra med `ChangeNotifier`-ViewModels. |
| Modeller | `freezed` (+`json_serializable`) | Iumutbare modeller, `copyWith`, `==`; mindre feilkilde. |
| Fil-io | `path_provider`, `file` | Hente dokument-mappe, robuste fil-operasjoner. |
| Markdown (vis) | `flutter_markdown` | Velkjent rendering av Markdown inkl. bilder/avkrysningslister. |
| Markdown (edit) | MVP: kilde + forhåndsvisning; senere `flutter_code_editor` | Robust fra dag 1; syntaksefarging ved oppgradering. |
| Kamera/bilder | `image_picker` | Standardpakken for kamera + galleri, tvers til plattformer. |
| Deling | `share_plus` | Del fil/tekst via OS-deling (printer, e-post, AirDrop). |
| Import (filvalg) | `file_picker` | Velge `.md`/`.zip` til import, Web-vennlig. |
| Zip | `archive` | Pakk/opp med mappe + bilder for eksport/import. |
| Rettigheter | `permission_handler` | Kamera/filstyre på Android/iOS. |
| HTTP (AI) | `http` | Offisielt anbefalt; enkle GET/POST. |
| Sikker lagring | `flutter_secure_storage` | API-nøkler i Keychain/Keystore (ikke klartekst). |
| i18n | `flutter_localizations` / `intl` | Bokmål som primær, klar for flere språk. |
| Testing | `flutter_test`, `mocktail` | Enhet- + widget-tester; enkle mocks. |

---

## 8. Teststrategi

- **Enhetstester:** domänmodeller, `FileStorageService` (round-trip: skriv → les →
  likhet), Repositorier (med mock Tjeneste), AI-svar-parsning.
- **Widget-tester:** editor (rediger ↔ forhåndsvis), bibliotek-liste, hytte-liste,
  eksport-dialog (valg av format).
- **Integrasjonstester (Fase 5):** full flow opprett → rediger → eksport → import →
  sammenlign.
- **Kvalitetsport:** `dart analyze` (ingen advarsler) + `flutter test` + `--coverage`
  i CI (GitHub Actions).

---

## 9. Feilhåndtering & `Result`

- Data-laget returnerer `Result<T>` eller kaster typede feil (`BookNotFoundError`,
  `ImportParseError`, `AiProviderError`).
- UI mottar feil og viser vennlige, norsk-språklige meldinger.
- Null returneres aldri for å unngå uendelige ladetildstander (jfr. http-skill-et).
