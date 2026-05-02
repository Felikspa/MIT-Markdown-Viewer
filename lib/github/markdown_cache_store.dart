import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:markdown_editor/github/github_config.dart';
import 'package:path_provider/path_provider.dart';

class MarkdownCacheStore {
  Future<CachedMarkdownFile?> read({
    required GithubConfig config,
    required String path,
  }) async {
    final file = await _fileFor(config: config, path: path);
    if (!await file.exists()) {
      return null;
    }
    final content = await file.readAsString();
    final metadata = await _readMetadata(config: config, path: path);
    return CachedMarkdownFile(
      content: content,
      sha: metadata?.sha,
      isDirty: metadata?.isDirty ?? false,
    );
  }

  Future<void> write({
    required GithubConfig config,
    required String path,
    required String content,
    required String sha,
    bool isDirty = false,
  }) async {
    final file = await _fileFor(config: config, path: path);
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
    final metadataFile = await _metadataFileFor(config: config, path: path);
    await metadataFile.writeAsString(
      jsonEncode({'sha': sha, 'isDirty': isDirty}),
    );
  }

  Future<bool> isFresh({
    required GithubConfig config,
    required String path,
    required String sha,
  }) async {
    final file = await _fileFor(config: config, path: path);
    if (!await file.exists()) {
      return false;
    }
    final metadata = await _readMetadata(config: config, path: path);
    return metadata?.sha == sha && metadata?.isDirty == false;
  }

  Future<CachedMarkdownMetadata?> _readMetadata({
    required GithubConfig config,
    required String path,
  }) async {
    final metadataFile = await _metadataFileFor(config: config, path: path);
    if (!await metadataFile.exists()) {
      return null;
    }
    final decoded = jsonDecode(await metadataFile.readAsString());
    if (decoded is! Map<String, Object?>) {
      return null;
    }
    final sha = decoded['sha'];
    if (sha is! String) {
      return null;
    }
    final isDirty = decoded['isDirty'];
    return CachedMarkdownMetadata(
      sha: sha,
      isDirty: isDirty is bool && isDirty,
    );
  }

  Future<File> _fileFor({
    required GithubConfig config,
    required String path,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final key = sha256
        .convert(
          utf8.encode('${config.owner}/${config.repo}/${config.branch}/$path'),
        )
        .toString();
    return File('${directory.path}/markdown_cache/$key.md');
  }

  Future<File> _metadataFileFor({
    required GithubConfig config,
    required String path,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final key = sha256
        .convert(
          utf8.encode('${config.owner}/${config.repo}/${config.branch}/$path'),
        )
        .toString();
    return File('${directory.path}/markdown_cache/$key.json');
  }
}

class CachedMarkdownFile {
  const CachedMarkdownFile({
    required this.content,
    required this.sha,
    required this.isDirty,
  });

  final String content;
  final String? sha;
  final bool isDirty;
}

class CachedMarkdownMetadata {
  const CachedMarkdownMetadata({required this.sha, required this.isDirty});

  final String sha;
  final bool isDirty;
}
