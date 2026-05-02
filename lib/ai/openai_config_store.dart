import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:markdown_editor/ai/openai_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _OpenAiConfigKey { baseUrl, model }

class OpenAiConfigStore {
  static const _apiKeyKey = 'openai_compatible_api_key';
  static const _secureStorage = FlutterSecureStorage();

  Future<OpenAiConfig?> load() async {
    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    );
    final baseUrl = prefs.getString(_OpenAiConfigKey.baseUrl.name) ?? '';
    final model = prefs.getString(_OpenAiConfigKey.model.name) ?? '';
    final apiKey = await _secureStorage.read(key: _apiKeyKey) ?? '';
    final config = OpenAiConfig(
      baseUrl: baseUrl,
      apiKey: apiKey,
      model: model,
    ).trimmed();
    if (!config.isComplete) {
      return null;
    }
    return config;
  }

  Future<void> save(OpenAiConfig config) async {
    final cleanConfig = config.trimmed();
    if (!cleanConfig.isComplete) {
      throw ArgumentError('OpenAI compatible API configuration is incomplete.');
    }

    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    );
    await prefs.setString(_OpenAiConfigKey.baseUrl.name, cleanConfig.baseUrl);
    await prefs.setString(_OpenAiConfigKey.model.name, cleanConfig.model);
    await _secureStorage.write(key: _apiKeyKey, value: cleanConfig.apiKey);
  }
}
