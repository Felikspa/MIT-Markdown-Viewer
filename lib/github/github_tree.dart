class GithubTreeEntry {
  const GithubTreeEntry({
    required this.path,
    required this.type,
    required this.sha,
  });

  factory GithubTreeEntry.fromJson(Map<String, Object?> json) {
    final path = json['path'];
    final type = json['type'];
    final sha = json['sha'];
    if (path is! String || type is! String || sha is! String) {
      throw const FormatException(
        'GitHub tree entry is missing path, type, or sha.',
      );
    }
    return GithubTreeEntry(path: path, type: type, sha: sha);
  }

  final String path;
  final String type;
  final String sha;

  bool get isMarkdownFile {
    final lowerPath = path.toLowerCase();
    return type == 'blob' &&
        (lowerPath.endsWith('.md') || lowerPath.endsWith('.markdown'));
  }
}

class GithubDirectoryNode {
  GithubDirectoryNode({required this.name, required this.path});

  final String name;
  final String path;
  final Map<String, GithubDirectoryNode> directories = {};
  final List<GithubMarkdownFile> files = [];

  static GithubDirectoryNode fromMarkdownEntries(
    Iterable<GithubTreeEntry> entries,
  ) {
    final root = GithubDirectoryNode(name: '', path: '');
    final markdownEntries = entries.where((entry) => entry.isMarkdownFile);

    for (final entry in markdownEntries) {
      final parts = entry.path.split('/');
      var current = root;
      for (var index = 0; index < parts.length; index++) {
        final part = parts[index];
        final isFile = index == parts.length - 1;
        if (isFile) {
          current.files.add(
            GithubMarkdownFile(name: part, path: entry.path, sha: entry.sha),
          );
        } else {
          final directoryPath = parts.take(index + 1).join('/');
          current = current.directories.putIfAbsent(
            part,
            () => GithubDirectoryNode(name: part, path: directoryPath),
          );
        }
      }
    }

    root.sortChildren();
    return root;
  }

  void sortChildren() {
    final sortedDirectories = directories.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
    directories
      ..clear()
      ..addEntries(sortedDirectories);
    files.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    for (final directory in directories.values) {
      directory.sortChildren();
    }
  }

  List<GithubMarkdownFile> flattenFiles() {
    return [
      for (final directory in directories.values) ...directory.flattenFiles(),
      ...files,
    ];
  }
}

class GithubMarkdownFile {
  const GithubMarkdownFile({
    required this.name,
    required this.path,
    required this.sha,
  });

  final String name;
  final String path;
  final String sha;
}
