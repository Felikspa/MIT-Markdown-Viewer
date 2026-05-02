class OpenAiConfig {
  const OpenAiConfig({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
  });

  final String baseUrl;
  final String apiKey;
  final String model;

  bool get isComplete =>
      baseUrl.trim().isNotEmpty &&
      apiKey.trim().isNotEmpty &&
      model.trim().isNotEmpty;

  Uri get chatCompletionsUri {
    final normalizedBaseUrl = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$normalizedBaseUrl/chat/completions');
  }

  OpenAiConfig trimmed() {
    return OpenAiConfig(
      baseUrl: baseUrl.trim(),
      apiKey: apiKey.trim(),
      model: model.trim(),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is OpenAiConfig &&
        other.baseUrl == baseUrl &&
        other.apiKey == apiKey &&
        other.model == model;
  }

  @override
  int get hashCode => Object.hash(baseUrl, apiKey, model);
}
