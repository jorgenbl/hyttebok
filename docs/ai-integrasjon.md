# AI-integrasjon – design

AI-en er en **valgfri hjelpefunksjon** (Fase 4). Den skal hjelpe brukeren med å
**oppbygge, strukturere og skrive** innhold i hytteboken – ikke erstatte redigeringen.
Alt kan kjøre **lokalt** (Ollama/LM Studio) eller mot et **cloud-API** (OpenAI/Claude).

**Prinsipp:** AI er en *tjeneste i datalaget*. ViewModels kaller en abstrakt
`AiClient`; UI vet aldri om hvilken leverandør som er koblet til.

---

## 1. Mål og funksjoner

| Funksjon | Beskrivelse | Inndata → Utdata |
| --- | --- | --- |
| Foreslå struktur | Forslå hvilke seksjoner en hyttebok bør inneholde | (hyttype, omgivelser) → liste av seksjoner |
| Skriv mal/utkast | Generere innholdsutkast for en seksjon | (seksjonstype, kontekst) → Markdown |
| Skrivehjelp i editor | Utvid / omskriv / forkort / oppsummer et utvalg | (tekst, instruks) → tekst |
| Generer rutineliste | Lage en avkrysningsliste fra en beskrivelse | (fri tekst) → `- [ ] …` |
| (Senere) Bildetekst/vedlikehold | Lese et bilde av notis/utstyr og strukturere | (bilde) → tekst |

Alle utdata er **forslag** som renderes i UI og kan godkjennes, redigeres eller forkastes.
Ingenting skrives til boken uten at brukeren bekrefter.

---

## 2. `AiClient`-abstraksjon (tjenest i datalaget)

```dart
abstract class AiClient {
  /// Streamer et svar gitt en systemprompt + bruker-melding (med valgfri kontekst).
  Stream<String> complete({
    required String system,
    required String user,
    String? model,
    Map<String, String>? context,   // f.eks. eksisterende bokinnhold som kontekst
    void Function()? onDone,
  });

  /// Enkelt sanity-check for innstillingsskjermen.
  Future<bool> ping({String? model});
}
```

Implementasjoner:

| Leverandør | Type | Endpoint | Merknad |
| --- | --- | --- | --- |
| **OpenAI** | Cloud | `https://api.openai.com/v1` | Bearer-nøkkel; `gpt-*` modeller. |
| **Anthropic (Claude)** | Cloud | `https://api.anthropic.com/v1` | `x-api-key` + `anthropic-version`; `claude-*`. |
| **Ollama** | Lokal | `http://localhost:11434/v1` | **OpenAI-kompatibel** – ingen nøkkel nødvendig. |
| **LM Studio** | Lokal | `http://localhost:1234/v1` | **OpenAI-kompatibel** – ingen nøkkel nødvendig. |
| **Egen (OpenAI-kompat.)** | Lokal/Cloud | brukervalgt `baseUrl` | Dekker andre selvhostede (vLLM, llama.cpp, text-generation-inference, …). |

> **Nøkkelsyn:** Ollama, LM Studio og de fleste selvhostede leverandører snakker
> **OpenAI-kompatibel API** (`/v1/chat/completions`). Én klient med konfigurerbar
> `baseUrl` + `apiKey` + `model` dekker de fleste tilfeller. Kun **Anthropic** krever
> egen klient (annen request/response-form) – likevel enkel.

### Konfigurasjonsmodell

```dart
class AiSettings {
  final AiProviderType type;   // openai | anthropic | ollama | lmstudio | custom
  final String baseUrl;        // for custom/ollama/lmstudio
  final String? apiKey;        // kun cloud (lagres i secure storage)
  final String model;
  final String systemPrompt;   // standard: "Du er en hytteboken-ekspert…"
  final int maxTokens;
  final double temperature;
}
```

`AiClientFactory.create(AiSettings)` returnerer den rette implementasjonen.

---

## 3. Konfig, sikker lagring & privatliv

- **Innstillinger** (leverandør, base-URL, modell) lagres lokalt
  (`SettingsRepository` → `shared_preferences`-aktig fil / JSON).
- **API-nøkler** lagres **kun** i `flutter_secure_storage` (Keychain på iOS, Keystore på
  Android) – aldri i klartekst-fil eller i boken.
- **Privatliv:**
  - Tydelig indikator i UI: **Lokal** vs **Cloud**.
  - Når **Lokal** velges: data forlater aldri enheten.
  - Når **Cloud** velges: kun det brukeren velger å sende (systemprompt + valgt
    kontekst) sendes til den valgte leverandør. Appen viser hva som sendes.
  - **Test-tilkobling**-knapp i innstillinger (sender et minimalt ping).
- **Ikke send** mer kontekst enn nødvendig; la brukeren kontrollere hva som inkluderes.

---

## 4. Arkitektur i koden

```
ui/features/ai (view + view_model)
        │  (kommandoer: suggestStructure(), rewriteSelection())
        ▼
domain/use_cases/ai_*  (valgfri: formaterer forspørring + tolker svar)
        │
        ▼
data/services/ai_client.dart  (AiClient + implementasjoner + factory)
        │
        ▼
http (GET/POST, streaming)  ·  flutter_secure_storage (nøkkel)
```

- `AiSettingsViewModel` (innstillinger) + `AiAssistantViewModel` (redigering/strukturforslag).
- Svaret **streames** til UI (tekst dukker opp løpende), er **avbrytbar**
  (`StreamSubscription.cancel()`).
- Parsing av strukturforslag: AI returnerer **JSON** (strengt schema) →
  `AiStructureSuggestion.fromJson` → renderes som en gjenbruksbar mal. Brukes
  `compute()` for parsing (jfr. http-skill-et) for å unngå UI-jank.

### Eksempel: «Foreslå struktur» (strengt JSON-schema)

System:
```
Du er en ekspert på å strukturere en hyttebok. Returner KUN gyldig JSON med form:
{"sections":[{"title":"…","type":"start|stop|beskrivelse|notater|medier|egen","hint":"…"}]}
```
Bruker: «Hytta er en fjellhytte i Røros med peis, uthus, båt og elbil-lader.»

---

## 5. Feilbehandling

| Situasjon | Håndtering |
| --- | --- |
| Ingen tilkobling (offline) | Vis «AI er ikke koblet til / offline», funksjon grå. |
| Ugyldig / manglende API-nøkkel | Tydelig melding + lenke til innstillinger. |
| Tidsfrist / nettverksfeil | Melding + «Prøv igjen». |
| Leverandør-4xx/5xx | Vis status + kort feilkode; logg (valgfritt) lokalt. |
| Modell finnes ikke | Fallback-melding + foreslå tilgjengelige modeller (hvis leverandøren støtter `GET /models`). |
| Ugyldig JSON i strukturforslag | Fallback: vis råtekst + be brukere prøve igjen. |

---

## 6. Privacy-first default

- **Default = ingen AI tilkoblet** (ingen nøkkel, ingen nettverk).
- Første gang AI-området åpnes, vis en kort forklaring + valg av **Lokal** eller **Cloud**.
- Lokale leverandører (Ollama/LM Studio) anbefales som «trygg» vei for privat innhold.
