import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../core/errors.dart';
import 'ai_settings.dart';

/// Et generert bilde: rå bytes + filtype (uten prikk).
class AiGeneratedImage {
  const AiGeneratedImage({required this.bytes, required this.extension});

  /// Bilde-bytes (vanligvis PNG).
  final Uint8List bytes;

  /// Filtype, f.eks. `png` eller `jpg`.
  final String extension;
}

/// Abstraksjon over leverandører av bildegenerering (tjenest i datalaget).
///
/// Feil kastes som [AiProviderError] med brukervenlig norsk melding,
/// slik som for [AiClient].
abstract class AiImageClient {
  /// Genererer ett bilde fra [prompt] og returnerer det som bytes.
  ///
  /// [model] overstyrer den konfigurerte modellen om gitt.
  Future<AiGeneratedImage> generate({required String prompt, String? model});
}

/// Signatur for oppretting av en [AiImageClient] fra innstillinger + nøkkel.
///
/// Injiserbar i tester; standard er [AiImageClientFactory.create].
typedef AiImageClientBuilder = AiImageClient Function(
  AiSettings settings,
  String? apiKey,
);

/// Bygger en [AiImageClient] ut fra [AiSettings].
///
/// Velger klienttype ut fra base-URL: peker den på en SD WebUI-instans
/// (standardport 7860 eller en `/sdapi`-sti), brukes SD WebUIs eget API,
/// ellers det OpenAI-kompatible `/images/generations`-endepunktet.
class AiImageClientFactory {
  static AiImageClient create(
    AiSettings settings, {
    String? apiKey,
    http.Client? httpClient,
  }) {
    final client = httpClient ?? http.Client();
    final baseUrl = _normalizeBaseUrl(settings.baseUrl);
    if (_isSdWebUi(baseUrl)) {
      return SdWebUiImageClient(baseUrl: baseUrl, client: client);
    }
    return OpenAiCompatibleImageClient(
      baseUrl: baseUrl,
      apiKey: apiKey,
      settings: settings,
      client: client,
    );
  }

  /// SD WebUI kjører standard på port 7860; en `/sdapi`-sti i base-URLen
  /// teller også som kjennetegn.
  static bool _isSdWebUi(String baseUrl) {
    if (baseUrl.contains('/sdapi')) return true;
    final uri = Uri.tryParse(baseUrl);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.port == 7860;
  }

  static String _normalizeBaseUrl(String baseUrl) {
    var url = baseUrl.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }
}

/// Felles feilmapping for bildeklientene (samme toning som chat-klienten).
AiProviderError _mapStatusError(int status, String body) {
  final detail = _providerDetail(body);
  switch (status) {
    case 401 || 403:
      return AiProviderError(
        'Ugyldig eller manglende API-nøkkel. Sjekk AI-innstillingene.',
        statusCode: status,
        cause: detail,
      );
    case 404:
      return AiProviderError(
        'Modellen eller endepunktet finnes ikke. Sjekk modell- og URL-felt.',
        statusCode: status,
        cause: detail,
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
          cause: detail,
        );
      }
      return AiProviderError(
        'Uventet svar fra leverandøren (kode $status).',
        statusCode: status,
        cause: detail,
      );
  }
}

/// Leverandørens egen feilmelding (JSON `error.message`), ellers klippet
/// råtekst fra kroppen.
String _providerDetail(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic> && decoded['error'] is Map) {
      final message = (decoded['error'] as Map)['message'];
      if (message is String && message.trim().isNotEmpty) {
        final text = message.trim();
        return text.length > 300 ? text.substring(0, 300) : text;
      }
    }
  } on FormatException {
    // Ikke-JSON-kropp: fall tilbake til råsnippen.
  }
  return body.length > 300 ? body.substring(0, 300) : body;
}

/// OpenAI-kompatibel bildegenerering: `POST /images/generations`.
///
/// Svaret inneholder enten base64 (`data[0].b64_json`) eller en URL
/// (`data[0].url`) som hentes inn. Dekker OpenAI og OpenAI-kompatible
/// tjenester.
class OpenAiCompatibleImageClient implements AiImageClient {
  OpenAiCompatibleImageClient({
    required this.baseUrl,
    this.apiKey,
    required this.settings,
    required this._client,
  });

  /// Base-URL uten avsluttende skråstrek, f.eks. `https://api.openai.com/v1`.
  final String baseUrl;

  /// Bearer-nøkkel; `null`/tom for lokale leverandører.
  final String? apiKey;

  final AiSettings settings;
  final http.Client _client;

  /// Bildegenerering tar lengre tid enn chat – generøs timeout.
  static const _timeout = Duration(minutes: 5);

  @override
  Future<AiGeneratedImage> generate({required String prompt, String? model}) {
    return _generate(prompt, model);
  }

  Future<AiGeneratedImage> _generate(String prompt, String? model) async {
    final uri = Uri.parse('$baseUrl/images/generations');
    final headers = <String, String>{'content-type': 'application/json'};
    if (apiKey != null && apiKey!.isNotEmpty) {
      headers['authorization'] = 'Bearer $apiKey';
    }
    final body = jsonEncode({
      'model': model ?? settings.model,
      'prompt': prompt,
      'n': 1,
    });

    final http.Response response;
    try {
      response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(_timeout);
    } on TimeoutException {
      throw AiProviderError(
        'Tiden ran ut under bildegenereringen. Prøv igjen.',
      );
    } on http.ClientException catch (e) {
      throw AiProviderError('Kan ikke nå leverandøren: ${e.message}', cause: e);
    } on Object catch (e) {
      // Nettverksfeil (SocketException på mobil, XHR/TypeError på web).
      throw AiProviderError(
        'Kan ikke nå leverandøren. Kontroller nettverket – '
        'kjører den lokale leverandøren?',
        cause: e,
      );
    }

    if (response.statusCode != 200) {
      throw _mapStatusError(response.statusCode, response.body);
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw AiProviderError(
        'Uventet svar fra leverandøren (ikke-JSON).',
        statusCode: 200,
      );
    }
    final data = decoded is Map<String, dynamic> ? decoded['data'] : null;
    final first = data is List && data.isNotEmpty ? data.first : null;
    if (first is! Map<String, dynamic>) {
      throw AiProviderError(
        'Leverandøren returnerte ingen bilde. Prøv igjen.',
        statusCode: 200,
      );
    }

    final b64 = first['b64_json'];
    if (b64 is String && b64.isNotEmpty) {
      try {
        return AiGeneratedImage(bytes: base64Decode(b64), extension: 'png');
      } on FormatException {
        throw AiProviderError(
          'Leverandøren returnerte et ugyldig bilde. Prøv igjen.',
          statusCode: 200,
        );
      }
    }

    final url = first['url'];
    if (url is String && url.isNotEmpty) {
      final imageUri = Uri.tryParse(url);
      if (imageUri == null) {
        throw AiProviderError(
          'Leverandøren returnerte en ugyldig bilde-URL.',
          statusCode: 200,
        );
      }
      final http.Response image;
      try {
        image = await _client.get(imageUri).timeout(_timeout);
      } on TimeoutException {
        throw AiProviderError(
          'Tiden ran ut under lasting av bildet. Prøv igjen.',
        );
      } on http.ClientException catch (e) {
        throw AiProviderError('Kan ikke laste bildet: ${e.message}', cause: e);
      } on Object catch (e) {
        throw AiProviderError('Kan ikke laste bildet.', cause: e);
      }
      if (image.statusCode != 200) {
        throw AiProviderError(
          'Kunne ikke laste bildet fra leverandøren (kode '
          '${image.statusCode}).',
          statusCode: image.statusCode,
        );
      }
      return AiGeneratedImage(
        bytes: image.bodyBytes,
        extension: _extensionOf(url),
      );
    }

    throw AiProviderError(
      'Leverandøren returnerte ingen bilde. Prøv igjen.',
      statusCode: 200,
    );
  }

  static String _extensionOf(String url) {
    final path = Uri.tryParse(url)?.path ?? '';
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return 'png';
    final ext = path.substring(dot + 1).toLowerCase();
    return (ext.length <= 4 && RegExp(r'^[a-z0-9]+$').hasMatch(ext))
        ? ext
        : 'png';
  }
}

/// Klient for Stable Diffusion WebUI (AUTOMATIC1111):
/// `POST /sdapi/v1/txt2img`. Bildet leveres som base64-PNG i `images[0]`.
class SdWebUiImageClient implements AiImageClient {
  SdWebUiImageClient({required this.baseUrl, required this._client});

  /// Base-URL uten avsluttende skråstrek, f.eks. `http://localhost:7860`.
  final String baseUrl;
  final http.Client _client;

  /// Lokale SD-modeller kan ta tid – enda mer generøs timeout.
  static const _timeout = Duration(minutes: 10);

  @override
  Future<AiGeneratedImage> generate({required String prompt, String? model}) {
    return _generate(prompt);
  }

  Future<AiGeneratedImage> _generate(String prompt) async {
    final uri = Uri.parse('$baseUrl/sdapi/v1/txt2img');
    final body = jsonEncode({
      'prompt': prompt,
      'negative_prompt': '',
      'width': 512,
      'height': 512,
      'steps': 20,
      'cfg_scale': 7,
      'batch_size': 1,
    });

    final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: const {'content-type': 'application/json'},
            body: body,
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw AiProviderError(
        'Tiden ran ut under bildegenereringen. Prøv igjen.',
      );
    } on http.ClientException catch (e) {
      throw AiProviderError('Kan ikke nå SD WebUI: ${e.message}', cause: e);
    } on Object catch (e) {
      // Er SD WebUI-foren startet?
      throw AiProviderError(
        'Kan ikke nå SD WebUI. Kontroller at foren kjører – '
        'og at nettverkstilgang er slått på i foren.',
        cause: e,
      );
    }

    if (response.statusCode != 200) {
      throw _mapStatusError(response.statusCode, response.body);
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw AiProviderError('Uventet svar fra SD WebUI (ikke-JSON).');
    }
    final images = decoded is Map<String, dynamic> ? decoded['images'] : null;
    if (images is List && images.isNotEmpty && images.first is String) {
      final b64 = images.first as String;
      try {
        return AiGeneratedImage(bytes: base64Decode(b64), extension: 'png');
      } on FormatException {
        throw AiProviderError(
          'SD WebUI returnerte et ugyldig bilde. Prøv igjen.',
        );
      }
    }
    throw AiProviderError('SD WebUI returnerte ingen bilde. Prøv igjen.');
  }
}
