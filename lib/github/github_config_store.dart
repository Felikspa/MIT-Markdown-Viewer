import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:markdown_editor/github/github_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _RepoConfigKey { owner, repo, branch }

class GithubConfigStore {
  static const _tokenKey = 'github_token';
  static const _secureStorage = FlutterSecureStorage();

  Future<GithubConfig?> load() async {
    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    );
    final owner = prefs.getString(_RepoConfigKey.owner.name) ?? '';
    final repo = prefs.getString(_RepoConfigKey.repo.name) ?? '';
    final branch = prefs.getString(_RepoConfigKey.branch.name) ?? '';
    final token = await _secureStorage.read(key: _tokenKey) ?? '';
    final config = GithubConfig(
      owner: owner,
      repo: repo,
      branch: branch,
      token: token,
    ).trimmed();

    if (!config.isComplete) {
      return null;
    }
    return config;
  }

  Future<void> save(GithubConfig config) async {
    final cleanConfig = config.trimmed();
    if (!cleanConfig.isComplete) {
      throw ArgumentError('GitHub configuration is incomplete.');
    }

    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    );
    await prefs.setString(_RepoConfigKey.owner.name, cleanConfig.owner);
    await prefs.setString(_RepoConfigKey.repo.name, cleanConfig.repo);
    await prefs.setString(_RepoConfigKey.branch.name, cleanConfig.branch);
    await _secureStorage.write(key: _tokenKey, value: cleanConfig.token);
  }
}
