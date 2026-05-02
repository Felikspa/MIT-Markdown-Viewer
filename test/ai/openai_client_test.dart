import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:markdown_editor/ai/openai_client.dart';
import 'package:markdown_editor/ai/openai_config.dart';

void main() {
  const config = OpenAiConfig(
    baseUrl: 'https://example.test/v1',
    apiKey: 'api-key',
    model: 'model-a',
  );

  test('explainSelection sends OpenAI compatible chat request', () async {
    final client = OpenAiClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          'https://example.test/v1/chat/completions',
        );
        expect(request.headers['Authorization'], 'Bearer api-key');
        expect(request.headers['Content-Type'], 'application/json');

        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['model'], 'model-a');
        final messages = body['messages']! as List<Object?>;
        expect(messages, hasLength(2));
        final userMessage = messages.last! as Map<String, Object?>;
        expect(userMessage['content'], contains('Selected passage'));
        expect(userMessage['content'], contains('important text'));

        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'Detailed explanation'},
              },
            ],
          }),
          200,
        );
      }),
    );

    final explanation = await client.explainSelection(
      selectedText: 'important text',
      documentTitle: 'chapter.md',
    );

    expect(explanation, 'Detailed explanation');
  });

  test('explainSelection exposes API errors', () async {
    final client = OpenAiClient(
      config: config,
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {'message': 'Invalid key'},
          }),
          401,
        );
      }),
    );

    expect(
      () => client.explainSelection(
        selectedText: 'text',
        documentTitle: 'chapter.md',
      ),
      throwsA(
        isA<OpenAiApiException>().having(
          (error) => error.toString(),
          'message',
          'OpenAI compatible API 401: Invalid key',
        ),
      ),
    );
  });
}
