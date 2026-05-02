import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:markdown_editor/github/github_client.dart';
import 'package:markdown_editor/github/github_config.dart';

void main() {
  const config = GithubConfig(
    owner: 'octo',
    repo: 'notes',
    branch: 'main',
    token: 'secret-token',
  );

  test(
    'fetchMarkdownTree sends GitHub headers and filters markdown files',
    () async {
      final client = GithubClient(
        config: config,
        httpClient: MockClient((request) async {
          expect(request.url.host, 'api.github.com');
          expect(request.url.path, '/repos/octo/notes/git/trees/main');
          expect(request.url.queryParameters['recursive'], '1');
          expect(request.headers['Authorization'], 'Bearer secret-token');
          expect(request.headers['Accept'], 'application/vnd.github+json');
          expect(request.headers['X-GitHub-Api-Version'], '2022-11-28');

          return http.Response(
            jsonEncode({
              'tree': [
                {'path': 'README.md', 'type': 'blob', 'sha': 'sha-1'},
                {
                  'path': 'docs/chapter.markdown',
                  'type': 'blob',
                  'sha': 'sha-2',
                },
                {'path': 'assets/cover.png', 'type': 'blob', 'sha': 'sha-3'},
                {'path': 'docs', 'type': 'tree', 'sha': 'sha-4'},
              ],
            }),
            200,
          );
        }),
      );

      final entries = await client.fetchMarkdownTree();

      expect(entries.map((entry) => entry.path), [
        'README.md',
        'docs/chapter.markdown',
      ]);
      expect(entries.map((entry) => entry.sha), ['sha-1', 'sha-2']);
    },
  );

  test('fetchMarkdownFile decodes repository contents response', () async {
    final client = GithubClient(
      config: config,
      httpClient: MockClient((request) async {
        expect(request.url.path, '/repos/octo/notes/contents/docs/a.md');
        expect(request.url.queryParameters['ref'], 'main');

        return http.Response(
          jsonEncode({
            'encoding': 'base64',
            'content': base64.encode(utf8.encode('# Title\n\nBody')),
          }),
          200,
        );
      }),
    );

    final content = await client.fetchMarkdownFile('docs/a.md');

    expect(content, '# Title\n\nBody');
  });

  test(
    'updateMarkdownFile uploads encoded content and returns new sha',
    () async {
      final client = GithubClient(
        config: config,
        httpClient: MockClient((request) async {
          expect(request.method, 'PUT');
          expect(request.url.path, '/repos/octo/notes/contents/docs/a.md');
          expect(request.headers['Authorization'], 'Bearer secret-token');
          expect(request.headers['Content-Type'], 'application/json');

          final body = jsonDecode(request.body) as Map<String, Object?>;
          expect(body['message'], 'Update docs/a.md');
          expect(body['sha'], 'old-sha');
          expect(body['branch'], 'main');
          expect(
            utf8.decode(base64.decode(body['content']! as String)),
            '# Updated',
          );

          return http.Response(
            jsonEncode({
              'content': {'sha': 'new-sha'},
            }),
            200,
          );
        }),
      );

      final updatedFile = await client.updateMarkdownFile(
        path: 'docs/a.md',
        content: '# Updated',
        sha: 'old-sha',
        message: 'Update docs/a.md',
      );

      expect(updatedFile.sha, 'new-sha');
    },
  );

  test('fetchMarkdownTree exposes GitHub API errors', () async {
    final client = GithubClient(
      config: config,
      httpClient: MockClient((request) async {
        return http.Response(jsonEncode({'message': 'Bad credentials'}), 401);
      }),
    );

    expect(
      client.fetchMarkdownTree,
      throwsA(
        isA<GithubApiException>().having(
          (error) => error.toString(),
          'message',
          'GitHub API 401: Bad credentials',
        ),
      ),
    );
  });
}
