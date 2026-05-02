import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:markdown_editor/github/github_config.dart';
import 'package:markdown_editor/github/github_tree.dart';

class GithubApiException implements Exception {
  const GithubApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() {
    if (statusCode == null) {
      return message;
    }
    return 'GitHub API $statusCode: $message';
  }
}

class GithubClient {
  GithubClient({required GithubConfig config, http.Client? httpClient})
    : _config = config.trimmed(),
      _httpClient = httpClient ?? http.Client();

  final GithubConfig _config;
  final http.Client _httpClient;

  Map<String, String> get _headers => {
    'Authorization': 'Bearer ${_config.token}',
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
  };

  Future<List<GithubTreeEntry>> fetchMarkdownTree() async {
    final uri = Uri.https(
      'api.github.com',
      '/repos/${_config.owner}/${_config.repo}/git/trees/${_config.branch}',
      {'recursive': '1'},
    );
    final response = await _httpClient.get(uri, headers: _headers);
    final body = _decodeJsonObject(response);
    _throwForError(response, body);
    final tree = body['tree'];
    if (tree is! List<Object?>) {
      throw const GithubApiException('GitHub tree response is missing tree.');
    }
    return tree
        .whereType<Map<String, Object?>>()
        .map(GithubTreeEntry.fromJson)
        .where((entry) => entry.isMarkdownFile)
        .toList(growable: false);
  }

  Future<String> fetchMarkdownFile(String path) async {
    final uri = Uri.https(
      'api.github.com',
      '/repos/${_config.owner}/${_config.repo}/contents/$path',
      {'ref': _config.branch},
    );
    final response = await _httpClient.get(uri, headers: _headers);
    final body = _decodeJsonObject(response);
    _throwForError(response, body);

    final encoding = body['encoding'];
    final content = body['content'];
    if (encoding != 'base64' || content is! String) {
      throw const GithubApiException(
        'GitHub file response does not contain base64 content.',
      );
    }

    return utf8.decode(base64.decode(content.replaceAll('\n', '')));
  }

  Future<GithubUpdatedFile> updateMarkdownFile({
    required String path,
    required String content,
    required String sha,
    required String message,
  }) async {
    final uri = Uri.https(
      'api.github.com',
      '/repos/${_config.owner}/${_config.repo}/contents/$path',
    );
    final response = await _httpClient.put(
      uri,
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode({
        'message': message,
        'content': base64.encode(utf8.encode(content)),
        'sha': sha,
        'branch': _config.branch,
      }),
    );
    final body = _decodeJsonObject(response);
    _throwForError(response, body);
    final responseContent = body['content'];
    if (responseContent is! Map<String, Object?>) {
      throw const GithubApiException(
        'GitHub update response is missing content.',
      );
    }
    final updatedSha = responseContent['sha'];
    if (updatedSha is! String || updatedSha.isEmpty) {
      throw const GithubApiException(
        'GitHub update response is missing file sha.',
      );
    }
    return GithubUpdatedFile(sha: updatedSha);
  }

  Map<String, Object?> _decodeJsonObject(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, Object?>) {
      throw GithubApiException(
        'GitHub returned an unexpected response body.',
        statusCode: response.statusCode,
      );
    }
    return decoded;
  }

  void _throwForError(http.Response response, Map<String, Object?> body) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    final message = body['message'];
    throw GithubApiException(
      message is String ? message : 'GitHub request failed.',
      statusCode: response.statusCode,
    );
  }
}

class GithubUpdatedFile {
  const GithubUpdatedFile({required this.sha});

  final String sha;
}
