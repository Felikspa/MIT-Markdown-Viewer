import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_editor/github/github_config.dart';

void main() {
  test('GithubRepository parses HTTPS clone URLs', () {
    final repository = GithubRepository.parse(
      'https://github.com/octo/notes.git',
    );

    expect(repository.owner, 'octo');
    expect(repository.repo, 'notes');
  });

  test('GithubRepository parses SSH clone URLs', () {
    final repository = GithubRepository.parse('git@github.com:octo/notes.git');

    expect(repository.owner, 'octo');
    expect(repository.repo, 'notes');
  });

  test('GithubRepository parses browser URLs', () {
    final repository = GithubRepository.parse(
      'https://github.com/octo/notes/tree/main/docs',
    );

    expect(repository.owner, 'octo');
    expect(repository.repo, 'notes');
  });

  test('GithubConfig.fromRepositoryUrl builds API config', () {
    final config = GithubConfig.fromRepositoryUrl(
      repositoryUrl: 'https://github.com/octo/notes.git',
      branch: 'main',
      token: 'secret-token',
    );

    expect(config.owner, 'octo');
    expect(config.repo, 'notes');
    expect(config.repositoryUrl, 'https://github.com/octo/notes.git');
  });

  test('GithubRepository rejects non-GitHub URLs', () {
    expect(
      () => GithubRepository.parse('https://example.com/octo/notes.git'),
      throwsFormatException,
    );
  });
}
