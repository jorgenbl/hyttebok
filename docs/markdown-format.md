# Markdown-formatet – filkontrakten

Dette er **kontrakten** for hvordan en hyttebok lagres, eksporteres og importeres.
Målet: **lagring = eksport = import** – ett og samme format, slik at en bok fritt kan
reiser mellom app, filsystem, Git og andre Markdown-verktøy uten data tap.

---

## 1. Overblikk

En **bok** er en mappe. Mappens trekk definerer strukturen; innholdet er `.md`-filer
med **YAML-frontmatter**. Bilder lagres i `images/` og refereres med **relativ sti**.

```text
sommehytta/                     # en bok (mappe)
├── book.md                     # bokens meta + forside (H1)
├── images/                     # alle bilder
│   ├── fasade.png
│   └── 2023-jul/
│       └── peisen.jpg
└── cabins/
    └── fjellhytta-roros/       # én hytte (mappe)
        ├── cabin.md            # hyttemeta + beskrivelse
        ├── start-rutiner.md
        ├── steng-rutiner.md
        ├── notater.md          # valgfrie ordinære seksjoner
        └── historier/
            ├── 2023-12-23-forste-jul.md
            └── 2024-07-04-fisketur.md
```

### Regler

- **Mappe = objekt:** en mappe `book.md` = bok; `cabins/<x>/cabin.md` = hytte.
- **Fila er inneholdet:** brødtekst (fra 1. linje etter frontmatter) er Markdown.
- **Bilder refereres relativt:** `![](../images/fasade.png)` (fra cabins-mappa) eller
  absolutt-til-boka `![](images/fasade.png)` (fra book.md).
- **Frontmatter bærer metadata:** tittel, dato, forfatter, rekkefølge, bilder (se §3).
- **Slugs er mappe/filnavn:** URL-vennlige, `lowercase`, `hyphen`, unike innenom foreldren.

---

## 2. Heading-konvensjonen (nøkkelen til import)

For at **import** kan rekonstruere modellen fra en **samlet** Markdown-fil, bruker vi en
stabil heading-hierarki:

| Nivå | Betydning | Eksempel |
| --- | --- | --- |
| `#`  | **Bok** (maks 1) | `# Sommehytta` |
| `##` | **Hytte** | `## Fjellhytta, Røros` |
| `###`| **Seksjon** | `### Åpne-rutiner` |
| `####`| **Historie** (under `### Historier`) | `#### Første jul` |

Ved eksport til én fil samles alt til én dokument med dette hierarkiet. Ved import
parses headingene tilbake til `Book → Cabin → Section/Story`.

> Frontmatter i den **samlete** filen (øverst) beskriver boken. Hver `##`/`###`/`####`
> kan bære en liten HTML-kommentar med metadata dersom felter ikke kan uttrykkes i
> headingen (f.eks. dato/forfatter for en historie).

---

## 3. Frontmatter-felt

Felles felt (valgfri der ikke angitt):

```yaml
---
# Bok (book.md)
type: book
title: Sommehytta
intro: "Velkommen til boka vår."
cover: images/fasade.png
version: 1            # formatversjon (for fremtidskompatibilitet)

# Hytte (cabins/<x>/cabin.md)
type: cabin
title: Fjellhytta, Røros
location: Røros, 638 m.o.h.
order: 0

# Seksjon (start-rutiner.md, notater.md, …)
type: section         # section | story
section: start        # start | stop | beskrivelse | notater | medier | egen
title: Åpne-rutiner
order: 1
images: []            # [images/x.png, …] – valgfritt, i tillegg til innfelt ![]()

# Historie (historier/<slug>.md)
type: story
title: Første jul
date: 2023-12-23
author: Jorgen & Ingrid
images: [images/2023-jul/peisen.jpg]
---
```

**Kompatibilitetsregler for import:**
- Ukjente felt **bevares** (skriv tilbake uendrede) – vi mister aldri brukerdata.
- Manglende `order` → rekkefølgen avles fra filnavn/hierarki.
- `version` lavere enn støttet → oppgraderingsveier (bestreves bakoverkompatibelt).

---

## 4. Eksempel: samlet eksport (én fil)

`Sommehytta.md` etter eksport:

```markdown
---
type: book
title: Sommehytta
version: 1
generated: 2026-09-05
app: hyttebok
---

# Sommehytta

Velkommen til boka vår. Her ligger alt vi må huske.

## Fjellhytta, Røros
<!-- location: Røros, 638 m.o.h. -->

Beskrivelse av hytta, hvordan man kommer dit, nøkkler, etc.

### Åpne-rutiner
- [ ] Slå på strømmen (bryter i kjeller)
- [ ] Tappe ut vannet i tak
- [ ] Tenn peis – la den brenne 30 min før du lukker luften
- [ ] Sjek at toalettet har vann

### Steng-rutiner
- [ ] Tøm søpla
- [ ] Slå av vannet og strømmen
- [ ] Lukk vindu
- [ ] Noter gjenværende ved i «Ved»-seksjonen

### Ved
Om lag 4 sekk gjenstår. Kjøp 6 nye neste tur.

### Historier

#### Første jul
<!-- date: 2023-12-23 | author: Jorgen & Ingrid -->

En koselig jul. Peisen sto i fra morgen til kveld.

![](images/2023-jul/peisen.jpg)
```

**Bilder i én-fil-eksport:** to moduser, brukervalgt:
1. **Inlinet (base64)** – `![](data:image/jpeg;base64,/9j/4AAQ…)` – selvstendig fil,
   ideell for utskrift. (Større fil.)
2. **Referanse** – `![](images/peisen.jpg)` – forutsetter at `images/` følger med.

---

## 5. Eksport- og import-moduser

| Modus | Utdata | Bruk |
| --- | --- | --- |
| Én fil (base64) | `Bok.md` | Utskrift, enkel deling, self-contained. |
| Én fil (referanse) | `Bok.md` + `images/` | Mindre fil; krever mappet. |
| Mappe (.zip) | `Bok.zip` (Markdown + `images/`) | Primær for deling/gjenbruk, Git-vennlig. |

**Import** godtar: én `.md` (med eller uten base64-bilder), én mappe, eller én `.zip`.
Flow:
1. Les fil(er) + frontmatter.
2. Bygg `Book`-trekk via heading-konvensjonen.
3. Hvis base64-bilder er inlinet → skriv dem ut til `images/` og erstatte med relativ sti.
4. Skriv boken til appens dokument-mappe (via `BookRepository.writeBook`).
5. Returnér resultat (suksess, eller detaljert feil på første ukjente problem).

---

## 6. Versjonering

- Formatversjon `version: 1` i `book.md`-frontmatter.
- Appen må alltid lese alle versjoner ≤ den nyeste (bestreves bakoverkompatibelt).
- Ved utvidelser (nye felter) legges felt **til**, aldri fjernes.
- Mål: en bok eksportert i dag skal åpnes av fremtidige versjoner, og omvendt.

---

## 7. Standard-maler (Fase 3) – forslag til innhold

Disse er *forslag* appen kan tilby som utgangspunkt (ikke påtvunget):

- **Kontakter & nøkkeler** – verktøyforer, elektrik, brann, naboer.
- **Adresse & koordinater** – GPS, veibeskrivelse, parkering.
- **Åpne-rutiner** (checklist) · **Steng-rutiner** (checklist)
- **Vann, avløp & toalett**
- **Strøm, brytere & generator**
- **Ved & peis**
- **Kjeller / boder / utstyr**
- **Vedlikeholdsplan** (sesongvis oppgaver)
- **Inventar** ( hva som er med, og hvor )
- **Tips for gjester**
- **Gjestebok / historier**
- **Bilder & dokument** (bygsel, uttalelser, forsikring)
