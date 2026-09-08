import 'dart:convert';

/// Hvilken type AI-leverandør som er konfigurert.
///
/// [ollama], [lmstudio] og [custom] snakker alle OpenAI-kompatibel API
/// (`/v1/chat/completions`); kun [anthropic] har eget request/response-format.
enum AiProviderType {
  openai('OpenAI'),
  anthropic('Anthropic (Claude)'),
  ollama('Ollama (lokal)'),
  lmstudio('LM Studio (lokal)'),
  custom('Egen (OpenAI-kompatibel)');

  const AiProviderType(this.label);

  /// Visningsnavn i UI.
  final String label;
}

/// Standard-systemprompt for hyttebok-AI-en.
const String kDefaultAiSystemPrompt =
    'Du er en ekspert på å strukturere og skrive innhold i en hyttebok. '
    'Svar alltid på norsk (Bokmål). Hold deg til det som blir bedt om.';

/// Konfigurasjon for AI-tilkoblingen.
///
/// API-nøkkelen ligger **ikke** i denne modellen: den lagres separat i
/// sikker lagring ([SecureKeyStore]) og injiseres i klienten per kall.
class AiSettings {
  const AiSettings({
    required this.type,
    required this.baseUrl,
    required this.model,
    this.systemPrompt = kDefaultAiSystemPrompt,
    this.maxTokens = 2048,
    this.temperature = 0.7,
  });

  final AiProviderType type;
  final String baseUrl;
  final String model;
  final String systemPrompt;
  final int maxTokens;
  final double temperature;

  /// Standard base-URL for leverandøren (brukes som startverdi i UI).
  static String defaultBaseUrlFor(AiProviderType type) {
    switch (type) {
      case AiProviderType.openai:
        return 'https://api.openai.com/v1';
      case AiProviderType.anthropic:
        return 'https://api.anthropic.com/v1';
      case AiProviderType.ollama:
        return 'http://localhost:11434/v1';
      case AiProviderType.lmstudio:
        return 'http://localhost:1234/v1';
      case AiProviderType.custom:
        return '';
    }
  }

  /// Forslag til modellsnavn (startverdi i UI; brukeren justerer).
  static String defaultModelFor(AiProviderType type) {
    switch (type) {
      case AiProviderType.openai:
        return 'gpt-4o-mini';
      case AiProviderType.anthropic:
        return 'claude-3-5-haiku-latest';
      case AiProviderType.ollama:
        return 'llama3.1';
      case AiProviderType.lmstudio:
        return 'local-model';
      case AiProviderType.custom:
        return '';
    }
  }

  /// Hvorvidt tilkoblingen peker på enheten selv (loopback). Da forlater
  /// aldri data enheten, og UI viser «Lokal» i stedet for «Cloud».
  bool get isLocal {
    final host = Uri.tryParse(baseUrl)?.host ?? '';
    return host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '::1' ||
        host == '[::1]';
  }

  /// Om leverandøren krever API-nøkkel (cloud). Lokale leverandører trenger
  /// ikke nøkkel, men [custom] kan kreve det.
  bool get needsApiKey =>
      type == AiProviderType.openai ||
      type == AiProviderType.anthropic ||
      type == AiProviderType.custom;

  AiSettings copyWith({
    AiProviderType? type,
    String? baseUrl,
    String? model,
    String? systemPrompt,
    int? maxTokens,
    double? temperature,
  }) {
    return AiSettings(
      type: type ?? this.type,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      maxTokens: maxTokens ?? this.maxTokens,
      temperature: temperature ?? this.temperature,
    );
  }

  Map<String, Object?> toJson() => {
    'type': type.name,
    'baseUrl': baseUrl,
    'model': model,
    'systemPrompt': systemPrompt,
    'maxTokens': maxTokens,
    'temperature': temperature,
  };

  /// Tolerant parsing: ukjente leverandørtyper/verdi faller tilbake til
  /// fornuftige standarder i stedet for å kaste.
  factory AiSettings.fromJson(Map<String, Object?> json) {
    final type = AiProviderType.values.firstWhere(
      (t) => t.name == json['type'],
      orElse: () => AiProviderType.ollama,
    );
    final baseUrl = (json['baseUrl'] as String?) ?? '';
    final model = (json['model'] as String?) ?? '';
    final systemPrompt =
        (json['systemPrompt'] as String?) ?? kDefaultAiSystemPrompt;
    final maxTokens = (json['maxTokens'] as num?)?.toInt() ?? 2048;
    final temperature = (json['temperature'] as num?)?.toDouble() ?? 0.7;
    return AiSettings(
      type: type,
      baseUrl: baseUrl.isEmpty ? defaultBaseUrlFor(type) : baseUrl,
      model: model.isEmpty ? defaultModelFor(type) : model,
      systemPrompt: systemPrompt.isEmpty
          ? kDefaultAiSystemPrompt
          : systemPrompt,
      maxTokens: maxTokens,
      temperature: temperature,
    );
  }

  /// String-representasjon for feilmeldinger (uten sensitiv data).
  String get description => '${type.label} ($baseUrl)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AiSettings) return false;
    return other.type == type &&
        other.baseUrl == baseUrl &&
        other.model == model &&
        other.systemPrompt == systemPrompt &&
        other.maxTokens == maxTokens &&
        other.temperature == temperature;
  }

  @override
  int get hashCode =>
      Object.hash(type, baseUrl, model, systemPrompt, maxTokens, temperature);

  @override
  String toString() => jsonEncode(toJson());
}
