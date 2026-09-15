import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:hyttebok/core/errors.dart';
import 'package:hyttebok/data/services/ai_image_client.dart';
import 'package:hyttebok/data/services/ai_settings.dart';

/// Fake http-klient: returnerer forutbestemte svar (per kall) eller kaster,
/// og logger requestene for inspeksjon.
class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient({
    this.status = 200,
    this.bodies = const [''],
    this.exception,
  });

  final int status;

  /// Én eller flere responskropper (første kall, andre kall, …).
  final List<String> bodies;
  final Object? exception;

  final List<http.Request> requests = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final req = request as http.Request;
    requests.add(req);
    if (exception != null) throw exception!;
    final index = requests.length - 1;
    final body = index < bodies.length ? bodies[index] : bodies.last;
    return http.StreamedResponse(Stream.value(utf8.encode(body)), status);
  }

  http.Request? get lastRequest => requests.isEmpty ? null : requests.last;

  Map<String, dynamic> get lastBody =>
      jsonDecode(lastRequest!.body) as Map<String, dynamic>;
}

/// 1×1-piksel PNG (gyldig, slik at [Image.memory] i widget-tester krasjer
/// ikke). Brukes også som «bilde-bytes» i fake-svarene.
final Uint8List kTinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
  'AAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

const openAiSettings = AiSettings(
  type: AiProviderType.openai,
  baseUrl: 'https://api.openai.com/v1',
  model: 'gpt-image-1',
);

const sdSettings = AiSettings(
  type: AiProviderType.custom,
  baseUrl: 'http://localhost:7860',
  model: 'sd-xl',
);

void main() {
  group('OpenAiCompatibleImageClient', () {
    test(
      'b64_json-svar blir til bytes; request har model/prompt/n + Bearer',
      () async {
        final client = _FakeHttpClient(
          bodies: [
            jsonEncode({
              'data': [
                {'b64_json': base64.encode(kTinyPng)},
              ],
            }),
          ],
        );
        final image = await OpenAiCompatibleImageClient(
          baseUrl: 'https://api.openai.com/v1',
          apiKey: 'sk-test',
          settings: openAiSettings,
          client: client,
        ).generate(prompt: 'en hytte');

        expect(image.bytes, kTinyPng);
        expect(image.extension, 'png');

        final request = client.lastRequest!;
        expect(request.url.path, '/v1/images/generations');
        expect(request.headers['authorization'], 'Bearer sk-test');
        expect(client.lastBody['model'], 'gpt-image-1');
        expect(client.lastBody['prompt'], 'en hytte');
        expect(client.lastBody['n'], 1);
      },
    );

    test('url-svar hentes inn; ekstensjon fra URL', () async {
      final client = _FakeHttpClient(
        bodies: [
          jsonEncode({
            'data': [
              {'url': 'https://images.example.com/result.jpg'},
            ],
          }),
          'RAWE-BILDE-BYTES',
        ],
      );
      final image = await OpenAiCompatibleImageClient(
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'sk-test',
        settings: openAiSettings,
        client: client,
      ).generate(prompt: 'en hytte');

      expect(image.bytes, utf8.encode('RAWE-BILDE-BYTES'));
      expect(image.extension, 'jpg');
      expect(client.requests.length, 2);
      expect(client.requests[1].method, 'GET');
    });

    test('url uten kjent ekstensjon blir png', () async {
      final client = _FakeHttpClient(
        bodies: [
          jsonEncode({
            'data': [
              {'url': 'https://images.example.com/result'},
            ],
          }),
          'BYTES',
        ],
      );
      final image = await OpenAiCompatibleImageClient(
        baseUrl: 'https://api.openai.com/v1',
        settings: openAiSettings,
        client: client,
      ).generate(prompt: 'en hytte');
      expect(image.extension, 'png');
    });

    test('401 gir vennlig nøkkel-feil', () async {
      final client = _FakeHttpClient(
        status: 401,
        bodies: [
          jsonEncode({
            'error': {'message': 'invalid api key'},
          }),
        ],
      );
      final imageClient = OpenAiCompatibleImageClient(
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'sk-feil',
        settings: openAiSettings,
        client: client,
      );
      expect(
        () => imageClient.generate(prompt: 'x'),
        throwsA(
          isA<AiProviderError>().having(
            (e) => e.message,
            'message',
            'Ugyldig eller manglende API-nøkkel. Sjekk AI-innstillingene.',
          ),
        ),
      );
    });

    test('404 gir modell/endepunkt-feil', () async {
      final client = _FakeHttpClient(
        status: 404,
        bodies: [
          jsonEncode({
            'error': {'message': 'not found'},
          }),
        ],
      );
      final imageClient = OpenAiCompatibleImageClient(
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'sk-test',
        settings: openAiSettings,
        client: client,
      );
      expect(
        () => imageClient.generate(prompt: 'x'),
        throwsA(
          isA<AiProviderError>().having(
            (e) => e.message,
            'message',
            'Modellen eller endepunktet finnes ikke. Sjekk modell- og URL-felt.',
          ),
        ),
      );
    });

    test('tomt datafelt gir «ingen bilde»-feil', () async {
      final client = _FakeHttpClient(
        bodies: [
          jsonEncode({'data': []}),
        ],
      );
      final imageClient = OpenAiCompatibleImageClient(
        baseUrl: 'https://api.openai.com/v1',
        settings: openAiSettings,
        client: client,
      );
      expect(
        () => imageClient.generate(prompt: 'x'),
        throwsA(
          isA<AiProviderError>().having(
            (e) => e.message,
            'message',
            'Leverandøren returnerte ingen bilde. Prøv igjen.',
          ),
        ),
      );
    });

    test('ugyldig b64 gir «ugyldig bilde»-feil', () async {
      final client = _FakeHttpClient(
        bodies: [
          jsonEncode({
            'data': [
              {'b64_json': '!!ikke-base64!!'},
            ],
          }),
        ],
      );
      final imageClient = OpenAiCompatibleImageClient(
        baseUrl: 'https://api.openai.com/v1',
        settings: openAiSettings,
        client: client,
      );
      expect(
        () => imageClient.generate(prompt: 'x'),
        throwsA(
          isA<AiProviderError>().having(
            (e) => e.message,
            'message',
            'Leverandøren returnerte et ugyldig bilde. Prøv igjen.',
          ),
        ),
      );
    });

    test('unåelig leverandør gir nettverksfeil', () async {
      final client = _FakeHttpClient(
        exception: const SocketException('no route to host'),
      );
      final imageClient = OpenAiCompatibleImageClient(
        baseUrl: 'http://localhost:11434/v1',
        settings: openAiSettings,
        client: client,
      );
      expect(
        () => imageClient.generate(prompt: 'x'),
        throwsA(
          isA<AiProviderError>().having(
            (e) => e.message,
            'message',
            contains('Kan ikke nå leverandøren'),
          ),
        ),
      );
    });
  });

  group('SdWebUiImageClient', () {
    test('txt2img-svar med images[] blir til bytes', () async {
      final client = _FakeHttpClient(
        bodies: [
          jsonEncode({
            'images': [base64.encode(kTinyPng)],
          }),
        ],
      );
      final image = await SdWebUiImageClient(
        baseUrl: 'http://localhost:7860',
        client: client,
      ).generate(prompt: 'en hytte');

      expect(image.bytes, kTinyPng);
      expect(image.extension, 'png');

      final request = client.lastRequest!;
      expect(request.url.path, '/sdapi/v1/txt2img');
      expect(client.lastBody['prompt'], 'en hytte');
      expect(client.lastBody['width'], 512);
      expect(client.lastBody['height'], 512);
    });

    test('manglende images gir feil', () async {
      final client = _FakeHttpClient(
        bodies: [
          jsonEncode({'foo': 'bar'}),
        ],
      );
      final imageClient = SdWebUiImageClient(
        baseUrl: 'http://localhost:7860',
        client: client,
      );
      expect(
        () => imageClient.generate(prompt: 'x'),
        throwsA(
          isA<AiProviderError>().having(
            (e) => e.message,
            'message',
            'SD WebUI returnerte ingen bilde. Prøv igjen.',
          ),
        ),
      );
    });

    test('500 gir leverandør-feil med kode', () async {
      final client = _FakeHttpClient(status: 500, bodies: ['internal error']);
      final imageClient = SdWebUiImageClient(
        baseUrl: 'http://localhost:7860',
        client: client,
      );
      expect(
        () => imageClient.generate(prompt: 'x'),
        throwsA(
          isA<AiProviderError>().having(
            (e) => e.message,
            'message',
            'Leverandøren svarte med feil (kode 500). Prøv igjen.',
          ),
        ),
      );
    });
  });

  group('AiImageClientFactory', () {
    test('port 7860 gir SD WebUI-klient', () {
      final client = AiImageClientFactory.create(
        sdSettings,
        httpClient: _FakeHttpClient(),
      );
      expect(client, isA<SdWebUiImageClient>());
    });

    test('/sdapi i base-URL gir SD WebUI-klient', () {
      final settings = const AiSettings(
        type: AiProviderType.custom,
        baseUrl: 'http://192.168.1.10:9000/sdapi',
        model: 'sd',
      );
      final client = AiImageClientFactory.create(
        settings,
        httpClient: _FakeHttpClient(),
      );
      expect(client, isA<SdWebUiImageClient>());
    });

    test('øvrige base-URL-er gir OpenAI-kompatibel klient', () {
      final client = AiImageClientFactory.create(
        openAiSettings,
        httpClient: _FakeHttpClient(),
      );
      expect(client, isA<OpenAiCompatibleImageClient>());
    });

    test('avsluttende skråstrek i base-URL normaliseres bort', () async {
      final client = _FakeHttpClient(
        bodies: [
          jsonEncode({
            'data': [
              {'b64_json': base64.encode(kTinyPng)},
            ],
          }),
        ],
      );
      const settings = AiSettings(
        type: AiProviderType.openai,
        baseUrl: 'https://api.openai.com/v1/',
        model: 'gpt-image-1',
      );
      await AiImageClientFactory.create(
        settings,
        httpClient: client,
      ).generate(prompt: 'x');
      expect(
        client.lastRequest!.url,
        Uri.parse('https://api.openai.com/v1/images/generations'),
      );
    });
  });
}
