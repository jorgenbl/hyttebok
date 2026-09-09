# Hyttebok 🏔️📖

**Hyttebok** er en lokal-first app (Flutter) for iOS, Android og web, laget for å
bygge en digital bok om én eller flere hytter: start-/steng-rutiner, beskrivelser,
bilder, historier og mer. Boken kan eksporteres til **Markdown**, **zip** eller
**PDF** for utskrift, deles og importeres tilbake. **AI-støtte** (cloud-API eller
lokale modeller via Ollama/LM Studio) er valgfri og hjelper med oppbygging,
struktur og skriving.

## Kjennetegn

- 📱 **iOS, Android og web** – én kodebase, tre plattformer.
- 🏠 **Lokal lagring** – alt ligger på enheten. Ingen server, ingen konto, ingen innlogging.
- 📝 **Markdown-native** – boken *er* en mappe med Markdown-filer + bilder. Lagring = eksport = import.
- 📤 **Eksport/import** – én Markdown-fil (bilder inlinet), `.zip`-mappe eller PDF; del via OS-deling.
- 🤖 **AI (valgfritt)** – cloud-API eller lokale modeller; privatlivsfokus med lokal som trygt valg.

## Dokumentasjon

Detaljert plan, arkitektur, filformat og AI-design ligger i [`docs/`](./docs):

- [`docs/brukerveiledning.md`](./docs/brukerveiledning.md) – brukerveiledning til appen.
- [`docs/implementasjonsplan.md`](./docs/implementasjonsplan.md) – produktkrav, faser, milepæler.
- [`docs/arkitektur.md`](./docs/arkitektur.md) – lagdelt arkitektur (MVVM), datamodell, pakkevalg.
- [`docs/markdown-format.md`](./docs/markdown-format.md) – lagrings-/eksport-/importformatet.
- [`docs/ai-integrasjon.md`](./docs/ai-integrasjon.md) – AI-design.
- [`docs/butikkbeskrivelser.md`](./docs/butikkbeskrivelser.md) – App Store / Play Store-tekster.
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

# Kjør appen (velg enhet med -d)
flutter run

# Bygg for plattformene
flutter build ios --simulator   # eller: flutter build ipa
flutter build apk --release     # eller: flutter build appbundle
flutter build web

# Integrasjonstester (krever tilkoblet enhet/simulator)
flutter test integration_test -d <enhet>
```

Krever [Flutter SDK](https://docs.flutter.dev/get-started/install) (testet mot
Flutter 3.47.2 / Dart 3.13.2).

## Brukerveiledning

Se [`docs/brukerveiledning.md`](./docs/brukerveiledning.md) for en gjennomgang
av appen: bibliotek, bøker, hytter, rutiner, seksjoner, galleri, historier,
AI-hjelp, eksport/import og innstillinger.

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
