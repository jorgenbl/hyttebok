# Hyttebok 🏔️📖

**Hyttebok** er en lokal-first mobilapp (Flutter) for å bygge en digital bok om én eller
flere hytter: start-/steng-rutiner, beskrivelser, bilder, historier og mer. Boken kan
eksporteres til **Markdown** for å skrives ut, deles og importeres tilbake. Senere
tilsettes **AI-støtte** (OpenAI, Claude, eller lokale modeller via Ollama/LM Studio) som
hjelper med oppbygging og struktur.

## Kjennetegn

- 📱 **iOS + Android** (web som et senere mål).
- 🏠 **Lokal lagring** – alt ligger på enheten. Ingen server, ingen konto, ingen innlogging.
- 📝 **Markdown-native** – boken *er* en mappe med Markdown-filer + bilder. Lagring = eksport = import.
- 📤 **Eksport/import** – én Markdown-fil (bilder inlinet) eller en `.zip`-mappe; del via OS-deling.
- 🤖 **AI (senere)** – cloud-API eller lokale modeller; privatlivsfokus med lokal som trygt valg.

## Dokumentasjon

Detaljert plan, arkitektur, filformat og AI-design ligger i [`docs/`](./docs):

- [`docs/implementasjonsplan.md`](./docs/implementasjonsplan.md) – produktkrav, faser, milepæler.
- [`docs/arkitektur.md`](./docs/arkitektur.md) – lagdelt arkitektur (MVVM), datamodell, pakkevalg.
- [`docs/markdown-format.md`](./docs/markdown-format.md) – lagrings-/eksport-/importformatet.
- [`docs/ai-integrasjon.md`](./docs/ai-integrasjon.md) – AI-design.
- [`docs/brukerprompt.md`](./docs/brukerprompt.md) – den opprinnelige prompten.

## Teknologi

Flutter / Dart med velkjente pakker: `go_router`, `provider`, `freezed`,
`flutter_markdown`, `image_picker`, `share_plus`, `file_picker`, `archive`, `http`,
`path_provider`, `flutter_secure_storage`. Detaljer i
[`docs/arkitektur.md`](./docs/arkitektur.md#7-teknologi--pakkevalg).

## Kom i gang

```bash
# Avhengigheter
flutter pub get

# Statisk analyse + tester
dart analyze
flutter test

# Kjør appen
flutter run
```

Krever [Flutter SDK](https://docs.flutter.dev/get-started/install) (testet mot
Flutter 3.47.2 / Dart 3.13.2).

## Utviklerverktøy (agent-skills)

Prosjektet bruker offisielle Flutter/Dart agent-skills (installert i `.agents/skills/`).
De kan gjenskapes med:

```bash
npx skills add flutter/agent-plugins@flutter-apply-architecture-best-practices
npx skills add dart-lang/skills@dart-run-static-analysis
# …se docs/README.md for full liste
```

## Lisens

Private / all rights reserved (foreløpig).
