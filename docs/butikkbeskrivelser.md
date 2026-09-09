# Butikksomheting – App Store & Google Play

Tekster for lansering av **Hyttebok** i App Store og Google Play. Alle felt
holder seg innenfor butikkens lengderegler (notert ved hvert felt).
Språk: norsk. Tilpass gjerne før innsending – App Store godkjenner tekster
med skrivefeil strengt, og Play krever at appens navn samsvarer med
`CFBundleDisplayName` / `android:label`.

## Feltegenskaper

| Felt | Verd |
| --- | --- |
| App-navn | Hyttebok |
| Kategori (App Store) | Livsstil |
| Kategori (Play) | Livsstil / Reiser |
| Aldersgrense | 3+ / Alle aldre |
| Pris | Gratis (ingen innkjøp, ingen abonnement) |
| Søkbar i | App Store (NO), Google Play (NO) |

## App Store

### Subtittel (maks 30 tegn)

> Rutiner og historier for hytta

### Promotekst (maks 170 tegn)

> Skriv en digital bok om hytta: åpne- og steng-rutiner, bilder, historier og
> notater – alt lokalt på enheten, eksporterbar til PDF, Markdown eller zip.

### Søkbarhetsord / keywords (maks 100 tegn, kommaseparert, uten mellomrom)

> hytte,rutiner,sjekkliste,ferie,hytteferie,loggbok,notater,bilder,pdf,markdown

### Beskrivelse (maks 4000 tegn)

```
Hyttebok er den digitale boken om hytta – alt du trenger å vite før, under
og etter oppholdet, samlet på ett sted.

LAGR ALT DU TRENGER VITE

• Hver hytte får sin egen side med beskrivelse og sted
• Åpne- og steng-rutiner: sjekklister for fyring, vann, strøm og avreising
• Egne seksjoner for hva som passer – ved, båt, skispor, nøkkelhus, noe å
  ha på seg
• Galleri med bilder som følger med boken
• Historier med dato og forfatter – en loggbok over oppholdene

AI-HJELP TIL STRUKTUREN

La en AI foreslå hvilke seksjoner som passer hytta din, ut fra en kort
beskrivelse. Du kan bruke lokale modeller (f.eks. Ollama) der inget forlater
enheten, eller et cloud-API hvis du foretrekker det. Alt er valgfritt –
appen fungerer fullt ut uten AI.

DIN BOK, DINE REGLER

• Alt lagres lokalt på enheten – ingen server, ingen konto, ingen
  innlogging
• Boken er en mappe med Markdown-filer og bilder: lagring = eksport = import
• Eksporter til én Markdown-fil, zip-mappe eller PDF for utskrift
• Del via OS-delingstjenesten, eller last ned på web
•Importer tilbake når du vil – boken følger med deg

Webversjon

Appen finnes også som nettversjon for raske noter og eksport. Merk at
webversjonen lagrer i minnet under økten – eksporter boken for å ta den med
deg, og importer den på nytt senere.

Hyttebok er laget for alle som verdsierer at viktig hyttekunnskap ikke
forsvinner i en skuff – men ligger der den skal, når det gjelder.
```

### Screenshots (App Store, 6,7"/6,9" iPhone)

1. Biblioteket – «Hyttebøker» med 2–3 bøker.
2. Hatteside med åpne-rutiner med avkryssede punkter.
3. Galleri med bilder.
4. Historier med dato og forfatter.
5. AI-strukturforslag (dialog med forslag).
6. PDF-eksport/deling.

### Privatliv / data

Appen samler ingen data. Ingen nettverkstilkobling kreves. Hvis brukeren
aktiverer en cloud-AI-leverandør, sendes kun den teksten brukeren skriver til
den leverandøren; API-nøkkelen lagres i enhetens sikre lagring (Keychain).

## Google Play

### Tittel (maks 30 tegn)

> Hyttebok

### Kort beskrivelse (maks 80 tegn)

> Digital hyttebok: åpne- og steng-rutiner, bilder, historier og PDF-eksport.

### Fullstendig beskrivelse (maks 4000 tegn)

Bruk App Store-beskrivelsen over (den er innenfor 4000 tegn). Play tolererer
samme format med avsnitt og punktlistepunkter.

### Grafiske krav

- Ikon: 512×512 (kan leses fra `android/app/src/main/res/mipmap-xxxhdpi/` +
  `web/icons/Icon-512.png`).
- Feature graphic: 1024×500 – lag en med appens kremgrønn palett
  (bakgrunn `#F7F5EF`, mørkgrønn `#3E4F3A`) og teksten «Hyttebok».
- Screenshots: minst én telefon-skjerm; 9–16 stk anbefales. Rebruk
  App Store-skjermene.
- App-ikon: 512×512 PNG.

### Innholdsrating

3+ / Alle aldre. Ingen betalingsknapp, ingen ekstern lenker til
vold/aldersbestemt innhold.

### Tilknyttede lenker (når tilgjengelig)

- Nettside: `<nettsteds-URL>`
- Privatlivspolitikk: `<URL>` – skriv en kort privatlivspolitikk som bekrefter
  at appen ikke samler inn data, og beskriver AI-leverandørens behandling
  hvis brukeren aktiverer cloud-AI.

## Ekstra tips

- **Oppdateringsnotater** (App Store / Play release notes): hold dem korte
  og konkrete, f.eks. «Ny: PDF-eksport og webversjon. Feilrettinger.»
- **Søkbarhet**: «hytte» + «rutiner» + «sjekkliste» er de viktigste ordene;
  de er med i navn, subtittel og keywords.
- **Språk**: App Store lar deg legge til flere språk (norsk + engelsk +
  svensk/dansk) i Settings → App Information. Oversett subtittel og
  beskrivelse når appen skal ut i flere markeder.
