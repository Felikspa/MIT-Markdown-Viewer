import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:markdown_editor/ai/openai_config.dart';

class OpenAiApiException implements Exception {
  const OpenAiApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() {
    if (statusCode == null) {
      return message;
    }
    return 'OpenAI compatible API $statusCode: $message';
  }
}

class OpenAiClient {
  OpenAiClient({required OpenAiConfig config, http.Client? httpClient})
    : _config = config.trimmed(),
      _httpClient = httpClient ?? http.Client();

  final OpenAiConfig _config;
  final http.Client _httpClient;

  Future<String> explainSelection({
    required String selectedText,
    required String documentTitle,
  }) async {
    final response = await _httpClient.post(
      _config.chatCompletionsUri,
      headers: {
        'Authorization': 'Bearer ${_config.apiKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _config.model,
        'messages': [
          {
            'role': 'system',
            'content':
                'You are a patient teacher explaining a selected Markdown passage to a beginner student. Respond in Chinese with a clear teaching tone. Assume the user may not know the background, terminology, or reasoning steps. Explain the context, key concepts, sentence-by-sentence logic when useful, hidden assumptions, and practical examples. Make the explanation detailed enough for a beginner to genuinely understand the passage.',
          },
          {
            'role': 'user',
            'content':
                'Document: $documentTitle\n\nSelected passage:\n$selectedText\n\nPlease provide a detailed explanation of this passage.',
          },
        ],
      }),
    );
    final body = _decodeJsonObject(response);
    _throwForError(response, body);
    final choices = body['choices'];
    if (choices is! List<Object?> || choices.isEmpty) {
      throw const OpenAiApiException('Response is missing choices.');
    }
    final firstChoice = choices.first;
    if (firstChoice is! Map<String, Object?>) {
      throw const OpenAiApiException('Response choice has an invalid shape.');
    }
    final message = firstChoice['message'];
    if (message is! Map<String, Object?>) {
      throw const OpenAiApiException('Response choice is missing message.');
    }
    final content = message['content'];
    if (content is! String || content.trim().isEmpty) {
      throw const OpenAiApiException('Response message content is empty.');
    }
    return content.trim();
  }

  Map<String, Object?> _decodeJsonObject(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, Object?>) {
      throw OpenAiApiException(
        'API returned an unexpected response body.',
        statusCode: response.statusCode,
      );
    }
    return decoded;
  }

  void _throwForError(http.Response response, Map<String, Object?> body) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    final error = body['error'];
    if (error is Map<String, Object?> && error['message'] is String) {
      throw OpenAiApiException(
        error['message']! as String,
        statusCode: response.statusCode,
      );
    }
    throw OpenAiApiException(
      'API request failed.',
      statusCode: response.statusCode,
    );
  }
}
