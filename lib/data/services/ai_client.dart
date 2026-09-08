import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/errors.dart';
import 'ai_settings.dart';

/// Abstraksjon over AI-leverandører (tjenest i datalaget).
///
/// [complete] streamer svaret incrementelt (étt tekst-stykke per emit) slik
/// at UI kan vise teksten løpende. Feil kastes som [AiProviderError] med
/// brukervenlig norsk melding.
abstract class AiClient {
  /// Streamer et svar gitt systemprompt + bruker-melding.
  ///
  /// [model] og [maxTokens] overstyrer verdiene i innstillingene om gitt.
  Stream<String> complete({
    required String system,
    required String user,
    String? model,
    int? maxTokens,
  });

  /// Enkel tilkoblingstest: miniforespørring som fullføres uten feil.
  Future<bool> ping({String? model});
}

/// Signatur for oppretting av en [AiClient] fra innstillinger + nøkkel.
///
/// Injiserbar i tester; standard er [AiClientFactory.create].
typedef AiClientBuilder = AiClient Function(
  AiSettings settings,
  String? apiKey,
);

/// Bygger en [AiClient] ut fra [AiSettings].
///
/// [apiKey] injiseres separat (fra sikker lagring). [httpClient] kan
/// injiseres i tester; standard er [http.Client]().
class AiClientFactory {
  static AiClient create(
    AiSettings settings, {
    String? apiKey,
    http.Client? httpClient,
  }) {
    final client = httpClient ?? http.Client();
    final baseUrl = _normalizeBaseUrl(settings.baseUrl);
    if (settings.type == AiProviderType.anthropic) {
      return AnthropicClient(
        baseUrl: baseUrl,
        apiKey: apiKey,
        settings: settings,
        client: client,
      );
    }
    return OpenAiCompatibleClient(
      baseUrl: baseUrl,
      apiKey: apiKey,
      settings: settings,
      client: client,
    );
  }

  static String _normalizeBaseUrl(String baseUrl) {
    var url = baseUrl.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }
}

/// Delte deler for begge klientene: send + status-sjekk + SSE-linjeparsning.
abstract class _BaseAiClient implements AiClient {
  _BaseAiClient(this._client);

  final http.Client _client;

  static const _connectTimeout = Duration(seconds: 30);

  /// POST-er [body] til [uri], sjekker status, og yield-er hver SSE
  /// `data:`-payload som dekodet JSON-objekt. Avslutter ved `data: [DONE]`.
  Stream<Map<String, dynamic>> _streamChat(
    Uri uri,
    Map<String, String> headers,
    Map<String, Object?> body,
  ) async* {
    final request = http.Request('POST', uri)
      ..headers.addAll({'content-type': 'application/json', ...headers})
      ..body = jsonEncode(body);

    final http.StreamedResponse streamed;
    try {
      streamed = await _client.send(request).timeout(_connectTimeout);
    } on TimeoutException {
      throw AiProviderError(
        'Tiden ran ut ved tilkobling til AI-leverandøren. Prøv igjen.',
      );
    } on SocketException {
      throw AiProviderError(
        'Kan ikke nå AI-leverandøren. Kontroller nettverket – '
        'kjører den lokale leverandøren?',
      );
    } on http.ClientException catch (e) {
      throw AiProviderError(
        'Kan ikke nå AI-leverandøren: ${e.message}',
        cause: e,
      );
    }

    if (streamed.statusCode != 200) {
      final errBody = await streamed.stream
          .transform(const Utf8Decoder())
          .join();
      throw _mapStatusError(streamed.statusCode, errBody);
    }

    final lines = _splitLines(const Utf8Decoder().bind(streamed.stream));
    await for (final line in lines) {
      if (!line.startsWith('data:')) continue;
      final data = line.substring(5).trim();
      if (data == '[DONE]') return;
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) yield decoded;
      } on FormatException {
        // Igjenkjør linjer som ikke er JSON (f.eks. keep-alive).
      }
    }
  }

  static AiProviderError _mapStatusError(int status, String body) {
    final snippet = body.length > 300 ? body.substring(0, 300) : body;
    switch (status) {
      case 401 || 403:
        return AiProviderError(
          'Ugyldig eller manglende API-nøkkel. Sjekk AI-innstillingene.',
          statusCode: status,
          cause: snippet,
        );
      case 404:
        return AiProviderError(
          'Modellen eller endepunktet finnes ikke. Sjekk modell- og URL-felt.',
          statusCode: status,
          cause: snippet,
        );
      case 429:
        return AiProviderError(
          'For mange forespørsler til leverandøren. Prøv igjen om litt.',
          statusCode: status,
        );
      default:
        if (status >= 500) {
          return AiProviderError(
            'Leverandøren svarte med feil (kode $status). Prøv igjen.',
            statusCode: status,
            cause: snippet,
          );
        }
        return AiProviderError(
          'Uventet svar fra leverandøren (kode $status).',
          statusCode: status,
          cause: snippet,
        );
    }
  }

  /// Deler en UTF-8-tekststream inn i linjer (håndterer CRLF og delte
  /// flerbytes tegn mellom chunks).
  static Stream<String> _splitLines(Stream<String> chunks) async* {
    var buffer = '';
    await for (final chunk in chunks) {
      buffer += chunk;
      var start = 0;
      var i = 0;
      while (i < buffer.length) {
        if (buffer.codeUnitAt(i) == 0x0A) {
          var end = i;
          if (end > start && buffer.codeUnitAt(end - 1) == 0x0D) end--;
          yield buffer.substring(start, end);
          start = i + 1;
        }
        i++;
      }
      buffer = buffer.substring(start);
    }
    if (buffer.isNotEmpty) yield buffer;
  }
}

/// OpenAI-kompatibel klient: dekker OpenAI, Ollama, LM Studio og andre
/// selvhostede leverandører med `/chat/completions`-endpoint.
class OpenAiCompatibleClient extends _BaseAiClient {
  OpenAiCompatibleClient({
    required this.baseUrl,
    this.apiKey,
    required this.settings,
    required http.Client client,
  }) : super(client);

  /// Base-URL uten avsluttende skråstrek, f.eks. `http://localhost:11434/v1`.
  final String baseUrl;

  /// Bearer-nøkkel; `null`/tom for lokale leverandører som ikke krever nøkkel.
  final String? apiKey;

  final AiSettings settings;

  Uri get _endpoint => Uri.parse('$baseUrl/chat/completions');

  @override
  Stream<String> complete({
    required String system,
    required String user,
    String? model,
    int? maxTokens,
  }) async* {
    final body = {
      'model': model ?? settings.model,
      'stream': true,
      'max_tokens': maxTokens ?? settings.maxTokens,
      'temperature': settings.temperature,
      'messages': [
        {'role': 'system', 'content': system},
        {'role': 'user', 'content': user},
      ],
    };
    final headers = <String, String>{};
    if (apiKey != null && apiKey!.isNotEmpty) {
      headers['authorization'] = 'Bearer $apiKey';
    }

    await for (final event in _streamChat(_endpoint, headers, body)) {
      final choices = event['choices'];
      if (choices is! List || choices.isEmpty) continue;
      final first = choices.first;
      if (first is! Map<String, dynamic>) continue;
      final delta = first['delta'];
      final content = delta is Map<String, dynamic> ? delta['content'] : null;
      if (content is String && content.isNotEmpty) yield content;
    }
  }

  @override
  Future<bool> ping({String? model}) async {
    await for (final _ in complete(
      system: 'Du bekrefter at du er tilkoblet.',
      user: 'Si "ok".',
      model: model,
      maxTokens: 8,
    )) {
      // Fullføring uten feil = tilkoblet.
    }
    return true;
  }
}

/// Klient for Anthropic (Claude) API. Annet request/response-format enn
/// OpenAI-kompatibelt: `system` er eget felt og streaming bruker
/// `content_block_delta`-hendelser.
class AnthropicClient extends _BaseAiClient {
  AnthropicClient({
    required this.baseUrl,
    this.apiKey,
    required this.settings,
    required http.Client client,
  }) : super(client);

  /// Base-URL, f.eks. `https://api.anthropic.com/v1`.
  final String baseUrl;

  /// x-api-key for Anthropic.
  final String? apiKey;

  final AiSettings settings;

  static const _anthropicVersion = '2023-06-01';

  Uri get _endpoint => Uri.parse('$baseUrl/messages');

  @override
  Stream<String> complete({
    required String system,
    required String user,
    String? model,
    int? maxTokens,
  }) async* {
    final body = {
      'model': model ?? settings.model,
      'stream': true,
      'max_tokens': maxTokens ?? settings.maxTokens,
      'temperature': settings.temperature,
      'system': system,
      'messages': [
        {'role': 'user', 'content': user},
      ],
    };
    final headers = <String, String>{
      'x-api-key': apiKey ?? '',
      'anthropic-version': _anthropicVersion,
    };

    await for (final event in _streamChat(_endpoint, headers, body)) {
      if (event['type'] != 'content_block_delta') continue;
      final delta = event['delta'];
      if (delta is! Map<String, dynamic>) continue;
      if (delta['type'] != 'text_delta') continue;
      final text = delta['text'];
      if (text is String && text.isNotEmpty) yield text;
    }
  }

  @override
  Future<bool> ping({String? model}) async {
    await for (final _ in complete(
      system: 'Du bekrefter at du er tilkoblet.',
      user: 'Si "ok".',
      model: model,
      maxTokens: 8,
    )) {
      // Fullføring uten feil = tilkoblet.
    }
    return true;
  }
}
