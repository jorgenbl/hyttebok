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

Krever [Flutter SDK](https://docs.flutter.dev/get-started/install) (testet mot
Flutter 3.47.2 / Dart 3.13.2). Uavhengig av plattform: avhengigheter, analyse og
tester kjører samme sted.

```bash
# Avhengigheter
flutter pub get

# Statisk analyse + tester
dart analyze
flutter test
```

Velg deretter kommando etter hvor du vil kjøre appen.

### Web

```bash
# Utvikling – hot reload i Chrome
flutter run -d chrome

# Produksjonsbygg → build/web/
flutter build web
```

Webversjonen kjører i nettleseren med to forskjeller fra mobil: bøkene ligger i
minnet under økten (lukker du fanen forsvinner de – eksporter dem for å ta de
med), og innstillingene ligger i `localStorage`. «Ta bilde» byttes ut med
bildegalleriet.

For å forhåndsvise produksjonsbygger lokalt (eller deploye `build/web/` til en
god som helst statisk host):

```bash
cd build/web && python3 -m http.server 8080   # → http://localhost:8080
```

### iOS-simulator

```bash
# List tilgjengelige simulatorer – kopier UUID-en i parentesen
xcrun simctl list devices

# Bygg + installer + start (gi simulator-UUID-en til -d)
flutter run -d <simulator-uuid>
```

Eller bygg, installer og start manuelt:

```bash
flutter build ios --simulator
xcrun simctl install <simulator-uuid> build/ios/iphonesimulator/Runner.app
xcrun simctl launch <simulator-uuid> com.example.hyttebok
```

> **Tips:** gi den eksplicitte simulator-UUID-en til `-d`. I enkelte
> Flutter-build tolkes `-d ios` som et navnefilter og funner ingen enhet.

### Mobil (ekte enhet)

**iOS** – krever Xcode og en Apple Developer-signering (automatisk signing er
nok). Koble telefonen via USB, godkjenn datamaskinen på telefonen, og tillitt
utvikler-profilen ved første start (Innstillinger → Generelt → VPN og
enhetsforvaltning).

```bash
flutter devices                        # list tilkoblede enheter
flutter run -d <enhetens-udid>         # bygg + installer + start
```

**Android** – koble telefonen med USB-debugging slått på:

```bash
flutter run -d <android-enhet-id>
```

`compileSdk = 37` er allerede satt i `android/app/build.gradle.kts` – dette kreves
av plugin-ene `flutter_secure_storage` og `permission_handler_android`. Første
Android-bygg laster automatisk NDK og SDK-plattform (ca. 15 min).

> Uansett plattform: app-ikonet ligger igjen på hjemmeskjermen etter
> installasjonen, så du kan lukke appen og åpne den igjen når som helst.

### Integrasjonstester

```bash
# Krever tilkoblet enhet eller kjørende simulator
flutter test integration_test -d <enhet-eller-simulator>
```

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
