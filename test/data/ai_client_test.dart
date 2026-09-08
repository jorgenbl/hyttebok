import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:hyttebok/core/errors.dart';
import 'package:hyttebok/data/services/ai_client.dart';
import 'package:hyttebok/data/services/ai_settings.dart';

/// Fake http-klient som returnerer en ferdig [http.StreamedResponse] (SSE)
/// eller kaster en feil, og logger requesten for inspeksjon.
class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient(this.chunks, {this.status = 200, this.exception});

  final List<List<int>> chunks;
  final int status;
  final Object? exception;

  http.Request? lastRequest;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final req = request as http.Request;
    lastRequest = req;
    if (exception != null) throw exception!;
    return http.StreamedResponse(
      Stream<List<int>>.fromIterable(chunks),
      status,
    );
  }

  Map<String, String> get lastHeaders =>
      Map<String, String>.from(lastRequest!.headers);

  Map<String, dynamic> get lastBody =>
      jsonDecode(lastRequest!.body) as Map<String, dynamic>;
}

List<List<int>> utf8Chunks(List<String> parts) => [
  for (final part in parts) utf8.encode(part),
];

/// Én eller flere OpenAI-kompatible SSE-`data:`-linjer.
List<List<int>> openAiChunks(List<String> contents) {
  final lines = [
    for (final c in contents)
      'data: ${jsonEncode({
        'choices': [
          {
            'delta': {'content': c},
          },
        ],
      })}',
    'data: [DONE]',
    '',
  ];
  return utf8Chunks([lines.join('\n')]);
}

/// Anthropic-SSE-hendelser.
List<List<int>> anthropicChunks(List<String> texts) {
  final events = [
    'data: ${jsonEncode({'type': 'message_start'})}',
    '',
    for (final t in texts) ...[
      'data: ${jsonEncode({
        'type': 'content_block_delta',
        'delta': {'type': 'text_delta', 'text': t},
      })}',
      '',
    ],
    'data: ${jsonEncode({'type': 'message_stop'})}',
    '',
  ];
  return utf8Chunks([events.join('\n')]);
}

AiSettings ollamaSettings() => AiSettings(
  type: AiProviderType.ollama,
  baseUrl: 'http://localhost:11434/v1',
  model: 'llama3.1',
);

/// Returnerer den første feilen fra en AI-stream (eller `null` ved
/// fullføring uten feil).
Future<Object?> firstStreamError(AiClient client) async {
  try {
    await client.complete(system: 's', user: 'u').first;
  } catch (e) {
    return e;
  }
  return null;
}

void main() {
  group('OpenAiCompatibleClient', () {
    test('streamer SSE-delt og slår dem sammen', () async {
      final fake = _FakeHttpClient(openAiChunks(['Hei', ' fra', ' hytta!']));
      final client = OpenAiCompatibleClient(
        baseUrl: 'http://localhost:11434/v1',
        settings: ollamaSettings(),
        client: fake,
      );
      await expectLater(
        client.complete(system: 'sys', user: 'usr'),
        emitsInOrder(['Hei', ' fra', ' hytta!']),
      );
    });

    test('sender POST til /chat/completions med Bearer-nøkkel', () async {
      final fake = _FakeHttpClient(openAiChunks(['ok']));
      final client = OpenAiCompatibleClient(
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'sk-test',
        settings: AiSettings(
          type: AiProviderType.openai,
          baseUrl: 'https://api.openai.com/v1',
          model: 'gpt-4o-mini',
        ),
        client: fake,
      );
      await client.complete(system: 'sys', user: 'usr', maxTokens: 42).drain();
      expect(
        fake.lastRequest!.url,
        Uri.parse('https://api.openai.com/v1/chat/completions'),
      );
      expect(fake.lastHeaders['authorization'], 'Bearer sk-test');
      expect(fake.lastHeaders['content-type'], 'application/json');
      final body = fake.lastBody;
      expect(body['model'], 'gpt-4o-mini');
      expect(body['stream'], isTrue);
      expect(body['max_tokens'], 42);
      expect(body['messages'], [
        {'role': 'system', 'content': 'sys'},
        {'role': 'user', 'content': 'usr'},
      ]);
    });

    test('sender ingen authorization-header uten nøkkel', () async {
      final fake = _FakeHttpClient(openAiChunks(['ok']));
      final client = OpenAiCompatibleClient(
        baseUrl: 'http://localhost:1234/v1',
        settings: AiSettings(
          type: AiProviderType.lmstudio,
          baseUrl: 'http://localhost:1234/v1',
          model: 'local',
        ),
        client: fake,
      );
      await client.complete(system: 's', user: 'u').drain();
      expect(fake.lastHeaders.containsKey('authorization'), isFalse);
    });

    test(
      'håndterer CRLF og chunks som deler linjer og flerbytes tegn',
      () async {
        // «Hei café» utf8-kodet, delt midt i é-tegnet (0xC3 0xA9).
        final full = utf8.encode(
          'data: ${jsonEncode({
            'choices': [
              {
                'delta': {'content': 'Hei café'},
              },
            ],
          })}\r\n',
        );
        final split = full.indexOf(0xA9);
        final chunks = utf8Chunks([]);
        chunks.add(full.sublist(0, split));
        chunks.add(full.sublist(split));
        final fake = _FakeHttpClient(chunks);
        final client = OpenAiCompatibleClient(
          baseUrl: 'http://localhost:11434/v1',
          settings: ollamaSettings(),
          client: fake,
        );
        await expectLater(
          client.complete(system: 's', user: 'u'),
          emits('Hei café'),
        );
      },
    );

    test('hopper over ikke-JSON-linjer (keep-alive)', () async {
      final lines = [
        ': keep-alive',
        '',
        'data: ${jsonEncode({
          'choices': [
            {
              'delta': {'content': 'ok'},
            },
          ],
        })}',
        '',
        'data: ikkje-json',
        '',
        'data: [DONE]',
        '',
      ];
      final fake = _FakeHttpClient(utf8Chunks([lines.join('\n')]));
      final client = OpenAiCompatibleClient(
        baseUrl: 'http://localhost:11434/v1',
        settings: ollamaSettings(),
        client: fake,
      );
      await expectLater(
        client.complete(system: 's', user: 'u'),
        emitsThrough('ok'),
      );
    });

    test('avslutter streamen ved data: [DONE]', () async {
      final lines = [
        'data: ${jsonEncode({
          'choices': [
            {
              'delta': {'content': 'først'},
            },
          ],
        })}',
        'data: [DONE]',
        'data: ${jsonEncode({
          'choices': [
            {
              'delta': {'content': 'etter'},
            },
          ],
        })}',
      ];
      final fake = _FakeHttpClient(utf8Chunks([lines.join('\n')]));
      final client = OpenAiCompatibleClient(
        baseUrl: 'http://localhost:11434/v1',
        settings: ollamaSettings(),
        client: fake,
      );
      await expectLater(
        client.complete(system: 's', user: 'u'),
        emitsInOrder(['først']),
      );
    });

    group('status-koder → AiProviderError', () {
      Future<Object?> firstError(http.Client fake) async {
        final client = OpenAiCompatibleClient(
          baseUrl: 'https://api.openai.com/v1',
          apiKey: 'sk-test',
          settings: AiSettings(
            type: AiProviderType.openai,
            baseUrl: 'https://api.openai.com/v1',
            model: 'gpt-4o-mini',
          ),
          client: fake,
        );
        return firstStreamError(client);
      }

      test('401 → ugyldig API-nøkkel', () async {
        final fake = _FakeHttpClient(
          utf8Chunks(['{"error":"bad key"}']),
          status: 401,
        );
        final error = await firstError(fake) as AiProviderError;
        expect(
          error.message,
          'Ugyldig eller manglende API-nøkkel. Sjekk AI-innstillingene.',
        );
        expect(error.statusCode, 401);
      });

      test('403 → ugyldig API-nøkkel', () async {
        final fake = _FakeHttpClient(utf8Chunks(['no']), status: 403);
        final error = await firstError(fake) as AiProviderError;
        expect(error.statusCode, 403);
      });

      test('404 → modellen finnes ikke', () async {
        final fake = _FakeHttpClient(utf8Chunks(['nope']), status: 404);
        final error = await firstError(fake) as AiProviderError;
        expect(
          error.message,
          'Modellen eller endepunktet finnes ikke. Sjekk modell- og URL-felt.',
        );
      });

      test('429 → for mange forespørsler', () async {
        final fake = _FakeHttpClient(utf8Chunks(['slow down']), status: 429);
        final error = await firstError(fake) as AiProviderError;
        expect(
          error.message,
          'For mange forespørsler til leverandøren. Prøv igjen om litt.',
        );
      });

      test('500 → leverandørfeil med kode', () async {
        final fake = _FakeHttpClient(utf8Chunks(['boom']), status: 500);
        final error = await firstError(fake) as AiProviderError;
        expect(
          error.message,
          'Leverandøren svarte med feil (kode 500). Prøv igjen.',
        );
      });

      test('418 → uventet svar', () async {
        final fake = _FakeHttpClient(utf8Chunks(['teapot']), status: 418);
        final error = await firstError(fake) as AiProviderError;
        expect(error.message, 'Uventet svar fra leverandøren (kode 418).');
      });
    });

    test('SocketException → kan ikke nå leverandøren', () async {
      final fake = _FakeHttpClient([], exception: SocketException('refused'));
      final client = OpenAiCompatibleClient(
        baseUrl: 'http://localhost:11434/v1',
        settings: ollamaSettings(),
        client: fake,
      );
      final error = await firstStreamError(client) as AiProviderError;
      expect(error.message, contains('Kan ikke nå AI-leverandøren'));
    });

    test('ClientException → kan ikke nå leverandøren med detalj', () async {
      final fake = _FakeHttpClient(
        [],
        exception: http.ClientException('DNS feil'),
      );
      final client = OpenAiCompatibleClient(
        baseUrl: 'http://localhost:11434/v1',
        settings: ollamaSettings(),
        client: fake,
      );
      final error = await firstStreamError(client) as AiProviderError;
      expect(error.message, contains('Kan ikke nå AI-leverandøren: DNS feil'));
    });

    test('ping returnerer true ved 200', () async {
      final fake = _FakeHttpClient(openAiChunks(['ok']));
      final client = OpenAiCompatibleClient(
        baseUrl: 'http://localhost:11434/v1',
        settings: ollamaSettings(),
        client: fake,
      );
      expect(await client.ping(), isTrue);
    });

    test('ping kaster AiProviderError ved 401', () async {
      final fake = _FakeHttpClient(utf8Chunks(['no']), status: 401);
      final client = OpenAiCompatibleClient(
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'sk-dårlig',
        settings: AiSettings(
          type: AiProviderType.openai,
          baseUrl: 'https://api.openai.com/v1',
          model: 'gpt-4o-mini',
        ),
        client: fake,
      );
      await expectLater(client.ping(), throwsA(isA<AiProviderError>()));
    });
  });

  group('AnthropicClient', () {
    test('streamer text_delta-hendelser og ignorerer andre typer', () async {
      final fake = _FakeHttpClient(anthropicChunks(['Hei', ' ', 'Claude']));
      final client = AnthropicClient(
        baseUrl: 'https://api.anthropic.com/v1',
        apiKey: 'sk-ant',
        settings: AiSettings(
          type: AiProviderType.anthropic,
          baseUrl: 'https://api.anthropic.com/v1',
          model: 'claude-3-5-haiku-latest',
        ),
        client: fake,
      );
      await expectLater(
        client.complete(system: 'sys', user: 'usr'),
        emitsInOrder(['Hei', ' ', 'Claude']),
      );
    });

    test('sender x-api-key + anthropic-version til /messages', () async {
      final fake = _FakeHttpClient(anthropicChunks(['ok']));
      final client = AnthropicClient(
        baseUrl: 'https://api.anthropic.com/v1',
        apiKey: 'sk-ant',
        settings: AiSettings(
          type: AiProviderType.anthropic,
          baseUrl: 'https://api.anthropic.com/v1',
          model: 'claude-3-5-haiku-latest',
        ),
        client: fake,
      );
      await client.complete(system: 'sys', user: 'usr').drain();
      expect(
        fake.lastRequest!.url,
        Uri.parse('https://api.anthropic.com/v1/messages'),
      );
      expect(fake.lastHeaders['x-api-key'], 'sk-ant');
      expect(fake.lastHeaders['anthropic-version'], '2023-06-01');
      final body = fake.lastBody;
      expect(body['system'], 'sys');
      expect(body['messages'], [
        {'role': 'user', 'content': 'usr'},
      ]);
    });
  });

  group('AiClientFactory', () {
    http.Client empty() => _FakeHttpClient(utf8Chunks(['']));

    test('anthropic → AnthropicClient', () {
      final client = AiClientFactory.create(
        AiSettings(
          type: AiProviderType.anthropic,
          baseUrl: 'https://api.anthropic.com/v1/',
          model: 'claude-3-5-haiku-latest',
        ),
        httpClient: empty(),
      );
      expect(client, isA<AnthropicClient>());
      expect(
        (client as AnthropicClient).baseUrl,
        'https://api.anthropic.com/v1',
      );
    });

    test('openai/ollama/lmstudio/custom → OpenAiCompatibleClient', () {
      for (final type in [
        AiProviderType.openai,
        AiProviderType.ollama,
        AiProviderType.lmstudio,
        AiProviderType.custom,
      ]) {
        final client = AiClientFactory.create(
          AiSettings(
            type: type,
            baseUrl: 'http://localhost:11434/v1/',
            model: 'm',
          ),
          httpClient: empty(),
        );
        expect(client, isA<OpenAiCompatibleClient>(), reason: type.name);
        expect(
          (client as OpenAiCompatibleClient).baseUrl,
          'http://localhost:11434/v1',
          reason: type.name,
        );
      }
    });

    test('apiKey settes på klienten', () {
      final client = AiClientFactory.create(
        ollamaSettings(),
        apiKey: 'nøkkelen',
        httpClient: empty(),
      ) as OpenAiCompatibleClient;
      expect(client.apiKey, 'nøkkelen');
    });
  });
}
