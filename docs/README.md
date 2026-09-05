# Hyttebok – Dokumentasjon

Velkommen til dokumentasjonen for **Hyttebok**, en lokal-first Flutter-app for å
bygge en digital bok om én eller flere hytter: rutiner, beskrivelser, bilder,
historier og mer. Boken kan eksporteres til Markdown for skriving, deling og
gjeninnlasting. Senere tilsettes AI-støtte (både cloud-API og lokale modeller).

Denne mappa inneholder implementasjonsplan, arkitektur og filformat for prosjektet.

## Innhold

| Dokument | Innhold |
| --- | --- |
| [brukerprompt.md](./brukerprompt.md) | Den opprinnelige prompten fra oppdragsgiver (bevart ordrett). |
| [implementasjonsplan.md](./implementasjonsplan.md) | Produktkrav, faser, milepæler, risiko og neste steg. |
| [arkitektur.md](./arkitektur.md) | Lagdelt arkitektur (MVVM), prosjektstruktur, datamodell, pakkevalg. |
| [markdown-format.md](./markdown-format.md) | Spesifikasjon for lagrings-/eksport-/importformatet (filkontrakten). |
| [ai-integrasjon.md](./ai-integrasjon.md) | Design for AI-integrasjon (OpenAI, Claude, Ollama, LM Studio). |

## Status

- **Prosjekt:** Flutter 3.47.2 / Dart 3.13.2 (stable).
- **Plattform:** iOS + Android først, web som et senere mål.
- **Repo:** <https://github.com/jorgenbl/hyttebok>
- **Nåværende fase:** Fase 0 (grunnleggelse) – planlagt, implementasjon starter herfra.

## Raskt oppsett (for utviklere)

```bash
# Hente avhengigheter
flutter pub get

# Støtteme (static analysis + linter)
dart analyze

# Kjøre tester
flutter test

# Kjøpe appen (eksempel: Android)
flutter run
```

## Grunnleggende prinsipper

1. **Lokal-first** – all data ligger på enheten. Ingen server, ingen konto, ingen innlogging.
2. **Markdown som kjernespråk** – boken *er* en mappe med Markdown-filer + bilder.
   Det samme som lagres, kan eksporteres og importeres uten data tap.
3. **Portabelt og git-vennlig** – en bok kan sjekkes inn i Git, synkroniseres mellom
   enheter eller redigeres i en ekstern editor.
4. **Kjente rammeverk fra dart.dev** – vi holder oss til etablerte, velvedligeholdte
   Flutter/Dart-pakker (se [arkitektur.md](./arkitektur.md#teknologi--pakkevalg)).
