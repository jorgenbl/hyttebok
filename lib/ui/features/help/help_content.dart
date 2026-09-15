/// Innholdet på «Hjelp»-siden – en kort brukerveiledning som følger med
/// appen. Basert på `docs/brukerveiledning.md`, men tilpasset og holdt
/// aktuell med appens funksjoner.
const String helpContent = r'''
Velkommen til Hyttebok! Denne veiledningen går gjennom appen steg for steg:
fra første bok til fullstendig eksportert PDF.

## 1. Kom i gang

1. Biblioteket («Hyttebøker») er startsiden.
2. Trykk **+** nede til høyre → **Ny hyttebok**.
3. Gi boka et navn (f.eks. «Sommehytta») og trykk **Lagre**.
4. Boken åpnes. Trykk **+** igjen → **Ny hytte** (eller **Ny hytte fra mal**
   for en ferdig struktur med ledetekster), gi hytta et navn og lagre.

Du har nå en bok med én hytte. Alt lagres lokalt på enheten – ingen konto,
ingen innlogging, ingen server.

## 2. Biblioteket

Startsiden viser alle hyttebøkene med siste endringsdato.

- **+** – ny bok.
- **Importer bok** – importer en `.md`-fil eller `.zip`-mappe du tidligere
  har eksportert (f.eks. fra en gammel telefon eller en nettbrettversjon).
- **Hjelp** – denne siden.
- **Innstillinger** – tema og AI (se avsnitt 8).
- Trykk en bok for å åpne den. Sveip en bok til venstre for å slette – du
  får «Angre» i et kort øyeblikk. Trykk-hold gir bekreftelsesdialog.

## 3. Bokens side

- **Omslag** – trykk på bildet øverst for å legge til et omslagsbilde (fra
  kamera eller galleri) eller fjerne det. Uten bilde vises et tegnet
  hyttemotiv.
- **Forsiden / intro** – en kort presentasjon av boka. Trykk for å redigere.
- **Les boka** – hele boka som flytende lesevisning.
- **Søk i boka** – finkombinert søk i alle hytter, seksjoner og historier;
  treffene navigerer direkte til riktig sted.
- **Del / eksporter** – se avsnitt 7.
- **+** – ny hytte, eller ny hytte fra mal.

## 4. Hytta

Hver hytte har en side med alt om nettopp den:

| Tile | Hva den gjør |
| --- | --- |
| **Navn** | Endre hyttens navn. |
| **Sted** | Adresse, koordinater, høyde – fritt tekstfelt. |
| **Beskrivelse** | Fritext om hytta (også brukt av AI-strukturforslag). |
| **Åpne-rutiner** | Sjekkliste for åpning: fyring, vann, strøm, vinduer… |
| **Steng-rutiner** | Sjekkliste for stenging og vintersikring. |
| **Seksjoner** | Egne avsnitt: «Ved & peis», «Båt», «Skispor» – se nedenfor. |
| **Historier** | Loggbok over opphold: tittel, dato og forfatter. |

Sveip en hytte til venstre for å slette (med «Angre»), eller trykk-hold for
bekreftelsesdialog.

### Rutiner

Trykk **Åpne-rutiner** (eller **Steng-rutiner**) for å redigere. Bruk
GitHub-style sjekklistepunkter:

```markdown
- [ ] Tenn peisen
- [ ] Sjekk at vannet er rent
- [ ] Åpne vinduene
```

Kryss av i forhåndsvisningen; avkrysningen lagres i boka.

### Seksjoner

- **+ → Ny seksjon** – gi den et navn (f.eks. «Ved & peis»).
- Trykk en seksjon for å redigere innholdet (fritext/Markdown + bilder).
- Meny på seksjonen (tre prikker): **Flytt opp/ned**, **Skjul** (behold
  utenom synlighet) og **Slett**.

### Galleri og bilder

I redigereren kan du legge til bilder:

- **Kameraet** (mobil) – ta et bilde nå.
- **Galleriet** – velg fra telefonens/PC-en sin bildebibliotek.
- **Generer bilde (AI)** – la AI lage et bilde fra en tekstbeskrivelse
  (krever AI-oppsett, se avsnitt 6).

Bildene lagres sammen med boken og følger med ved eksport.

### Historier

**+ → Ny historie**: gi den en tittel (f.eks. «Første jul»), valgfritt en
forfatter, og skriv. Datoen settes automatisk til dagen du lager historien.
Trykk historien senere for å utvide, f.eks. med hvordan oppholdet gikk.

## 5. Redigereren

Alle tekstfelter åpnes i den samme redigereren med to faner:

- **Rediger** – skriv, med AI-hjelp (se avsnitt 6) og bildemuligheter.
- **Forhåndsvis** – så ut boken blir, inkludert avkryssbare rutiner.

Øverst i redigereren ligger tre liste-knapper: **Avkrysningsliste**,
**Punktliste** og **Nummerert liste**. Velg én eller flere linjer og trykk en
knapp for å sette listetegn – trykk igjen for å fjerne dem. Skriv i en liste:
**Enter** fortsetter listen automatisk, og **Enter** på et tomt punkt avslutter
den.

Trykk **Lagre** i øverste høyre hjørne for å lagre og gå tilbake.

## 6. AI-hjelp (valgfritt)

AI-en er helt valgfri – appen fungerer fullt ut uten den.

### Oppsett (Innstillinger → AI)

1. Velg leverandør:
   - **Lokal (Ollama)** – kjører på datamaskin/nettbrett i samme nettverk.
     Dataene forlater ikke hjemmet. Standard: `http://localhost:11434/v1`.
   - **Cloud (f.eks. OpenAI)** – kraftigere modeller; teksten du skriver
     sendes til leverandøren.
2. Angi **Base-URL** og **Modell** (fyller seg ut automatisk).
3. For cloud: lim inn **API-nøkkelen**. Den lagres i enhetens sikre
   lagring (Keychain / keystore), aldri i boken eller i en vanlig fil.
4. Trykk **Test tilkobling** for å sjekke.

### Hva AI-en kan

- **Strukturforslag** (på hyttesiden: + → «Foreslå struktur (AI)») – skriv
  en kort beskrivelse, og AI-en foreslår passende seksjoner. Godkjenn dem
  én og én, eller forkast hele.
- **Skrivehjelp** (i redigereren: ✨-ikonet øverst) – utvid, omskriv eller
  oppsummer markert tekst, eller generer en rutineliste basert på
  beskrivelsen.
- **Bildegenerering** (i redigereren: ✨-ikonet i verktøylinjen,
  «Generer bilde (AI)») – skriv en kort beskrivelse, og AI-en lager et
  bilde. Forhåndsvis det og trykk **Innsett i teksten** for å legge det inn
  i boken. Krever en leverandør som kan generere bilder (f.eks. OpenAI eller
  en lokal SD WebUI-instans).
- **Diktering** (i redigereren: mikrofon-ikonet i verktøylinjen) – trykk på
  mikrofonen og snakk; det du sier settes inn i teksten der cursor står.
  Bruker enhetens egen talegjenkjenning (norsk) og krever mikrofon-rettighet –
  ingen AI-leverandør eller nøkkel trengs.

### Propler per formål

Standardprofilen brukes av alle AI-funksjonene. Vil du bruke forskjellige
leverandører eller modeller for forskjellige formål, kan du gi hvert formål
sin egen profil: **Skrivehjelp**, **Strukturforslag** og **Bildegenerering**.

- I **Innstillinger → AI** finnes kortet **Profiler per formål**. Trykk et
  formål for å åpne sin egen side med leverandør, base-URL, modell og
  API-nøkkel.
- Hvert formål kan ha sin egen API-nøkkel. Er det ikke satt en egen profil
  for et formål, brukes standardprofilen.
- **Fjern egen profil** sletter profilen (og nøkkelen) for formålet og går
  tilbake til standardprofilen.

## 7. Eksport og import

Fra bokens side: **Del / eksporter**.

- **Del som Markdown (.md)** – én fil med alt innhold; bilder inlinet som
  base64. Perfekt for notatapper, Obsidian, skrives ut direkte.
- **Del som mappe (.zip)** – boken som mappe med Markdown-filer og bilder
  hver for seg. Dette er også bokens «ekte» lagringsformat.
- **Eksporter som PDF** – en pen, utskriftsvennlig PDF av hele boka
  (forside, hytter, rutiner, seksjoner, historier).

På web lastes filene ned direkte i nettleseren i stedet for at
delingsarket åpnes.

**Importer:** i biblioteket, **Importer bok** → velg en `.md`-fil eller
`.zip`-mappe. Boken får et nytt navn om en med samme navn allerede finnes.

> **Tips:** lag en PDF eller zip-eksempel av boken før store endringer –
> det er din sikkerhetskopi.

## 8. Innstillinger

Åpnes fra biblioteket (tannhjul-ikonet).

- **AI** – leverandør, base-URL, modell, API-nøkkel, test tilkobling og
  profiler per formål (se avsnitt 6).
- **Tema** – lyst/mørkt/system (også tilgjengelig direkte fra biblioteket).

## 9. Webversjonen

Appen finnes også i nettleseren. Den fungerer som mobilappen, med to
unntak:

- **Lagring:** bøkene ligger i minnet under økten og forsvinner når fanen
  stenges. Eksporter boken (nedlasting) for å ta den med deg, og importer
  den på nytt senere.
- **Kamera:** «Ta bilde» byttes ut med bildegalleriet.

## 10. Vanlige spørsmål

**Hvor lagres bøkene?**
På enheten, i appens dokumentmappe – en mappe med Markdown-filer og bilder
per bok. Ingen kopier sendes til noen server.

**Kan jeg ta boken med til en ny telefon?**
Ja. Eksporter som `.zip` (eller PDF/`.md`), og importer den på den nye
enheten.

**Fungerer appen uten internett?**
Ja. Alt kjører lokalt – bortsett fra cloud-AI, som selvsagt trenger
tilkobling.

**Hva skjer med API-nøkkelen min?**
Den lagres kryptert i enhetens sikre lagring og sendes kun til
AI-leverandøren du har valgt. Slett den i innstillingene når du ikke
bruker den.
''';
