class GithubConfig {
  const GithubConfig({
    required this.owner,
    required this.repo,
    required this.branch,
    required this.token,
  });

  factory GithubConfig.fromRepositoryUrl({
    required String repositoryUrl,
    required String branch,
    required String token,
  }) {
    final parsedRepository = GithubRepository.parse(repositoryUrl);
    return GithubConfig(
      owner: parsedRepository.owner,
      repo: parsedRepository.repo,
      branch: branch,
      token: token,
    );
  }

  final String owner;
  final String repo;
  final String branch;
  final String token;

  String get repositoryUrl => 'https://github.com/$owner/$repo.git';

  bool get isComplete =>
      owner.trim().isNotEmpty &&
      repo.trim().isNotEmpty &&
      branch.trim().isNotEmpty &&
      token.trim().isNotEmpty;

  GithubConfig trimmed() {
    return GithubConfig(
      owner: owner.trim(),
      repo: repo.trim(),
      branch: branch.trim(),
      token: token.trim(),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is GithubConfig &&
        other.owner == owner &&
        other.repo == repo &&
        other.branch == branch &&
        other.token == token;
  }

  @override
  int get hashCode => Object.hash(owner, repo, branch, token);
}

class GithubRepository {
  const GithubRepository({required this.owner, required this.repo});

  factory GithubRepository.parse(String input) {
    final value = input.trim();
    if (value.isEmpty) {
      throw const FormatException('GitHub repository URL is required.');
    }

    final sshMatch = RegExp(
      r'^git@github\.com:([^/\s]+)/([^/\s]+?)(?:\.git)?/?$',
      caseSensitive: false,
    ).firstMatch(value);
    if (sshMatch != null) {
      return GithubRepository(
        owner: sshMatch.group(1)!,
        repo: sshMatch.group(2)!,
      );
    }

    final sshUrlMatch = RegExp(
      r'^ssh://git@github\.com/([^/\s]+)/([^/\s]+?)(?:\.git)?/?$',
      caseSensitive: false,
    ).firstMatch(value);
    if (sshUrlMatch != null) {
      return GithubRepository(
        owner: sshUrlMatch.group(1)!,
        repo: sshUrlMatch.group(2)!,
      );
    }

    final uri = Uri.tryParse(value);
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.toLowerCase() != 'github.com') {
      throw const FormatException('Use a github.com repository URL.');
    }

    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty);
    if (segments.length < 2) {
      throw const FormatException('GitHub URL must include owner and repo.');
    }

    final owner = segments.elementAt(0);
    final repo = segments.elementAt(1).replaceFirst(RegExp(r'\.git$'), '');
    if (owner.isEmpty || repo.isEmpty) {
      throw const FormatException('GitHub URL must include owner and repo.');
    }

    return GithubRepository(owner: owner, repo: repo);
  }

  final String owner;
  final String repo;
}
