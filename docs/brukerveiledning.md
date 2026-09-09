# Brukerveiledning – Hyttebok

Velkommen! Denne veiledningen går gjennom appen steg for steg: fra første
bok til fullstendig eksportert PDF.

## 1. Kom i gang

1. Åpne appen. Biblioteket («Hyttebøker») er startside.
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
- **Innstillinger** – tema og AI (se avsnitt 8).
- **Tema** – «Følg system», «Lyst tema» eller «Mørkt tema».
- Trykk en bok for å åpne den; to-finger-svipe/trykk-hold for å slette
  (bekreftelsesdialog inkludert).

## 3. Bokens side

- **Forsiden / intro** – en kort presentasjon av boka. Trykk for å redigere.
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

Bildene lagres sammen med boken og følger med ved eksport.

### Historier

**+ → Ny historie**: gi den en tittel (f.eks. «Første jul»), valgfritt en
forfatter, og skriv. Datoen settes automatisk til dagen du lager historien.
Trykk historien senere for å utvide, f.eks. med hvordan oppholdet gikk.

## 5. Redigereren

Alle tekstfelter åpnes i den samme redigereren med to faner:

- **Rediger** – skriv, med AI-hjelp (se avsnitt 6) og bildemuligheter.
- **Forhåndsvis** – så ut boken blir, inkludert avkryssbare rutiner.

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
- **Skrivehjelp** (i redigereren: ✨-ikonet) – utvid, omskriv eller
  oppsummer markert tekst, eller generer en rutineliste basert på
  beskrivelsen.

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

- **AI** – leverandør, base-URL, modell, API-nøkkel, test tilkobling
  (se avsnitt 6).
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
