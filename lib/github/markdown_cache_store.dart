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
      jsonEncode({
        'owner': config.owner,
        'repo': config.repo,
        'branch': config.branch,
        'path': path,
        'sha': sha,
        'isDirty': isDirty,
      }),
    );
  }

  Future<List<CachedMarkdownDraft>> listDirtyDrafts({
    required GithubConfig config,
  }) async {
    final directory = await _cacheDirectory();
    if (!await directory.exists()) {
      return const [];
    }

    final drafts = <CachedMarkdownDraft>[];
    await for (final entity in directory.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) {
        continue;
      }
      final metadata = await _readMetadataFile(entity);
      if (metadata == null ||
          !metadata.isDirty ||
          metadata.owner != config.owner ||
          metadata.repo != config.repo ||
          metadata.branch != config.branch) {
        continue;
      }
      final contentPath = entity.path.substring(0, entity.path.length - 5);
      final contentFile = File('$contentPath.md');
      if (!await contentFile.exists()) {
        continue;
      }
      drafts.add(
        CachedMarkdownDraft(
          path: metadata.path,
          content: await contentFile.readAsString(),
          sha: metadata.sha,
        ),
      );
    }
    drafts.sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
    return drafts;
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
    return _readMetadataFile(metadataFile);
  }

  Future<CachedMarkdownMetadata?> _readMetadataFile(File metadataFile) async {
    final decoded = jsonDecode(await metadataFile.readAsString());
    if (decoded is! Map<String, Object?>) {
      return null;
    }
    final sha = decoded['sha'];
    if (sha is! String) {
      return null;
    }
    final isDirty = decoded['isDirty'];
    final owner = decoded['owner'];
    final repo = decoded['repo'];
    final branch = decoded['branch'];
    final path = decoded['path'];
    return CachedMarkdownMetadata(
      owner: owner is String ? owner : '',
      repo: repo is String ? repo : '',
      branch: branch is String ? branch : '',
      path: path is String ? path : '',
      sha: sha,
      isDirty: isDirty is bool && isDirty,
    );
  }

  Future<Directory> _cacheDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    return Directory('${directory.path}/markdown_cache');
  }

  Future<File> _fileFor({
    required GithubConfig config,
    required String path,
  }) async {
    final directory = await _cacheDirectory();
    final key = sha256
        .convert(
          utf8.encode('${config.owner}/${config.repo}/${config.branch}/$path'),
        )
        .toString();
    return File('${directory.path}/$key.md');
  }

  Future<File> _metadataFileFor({
    required GithubConfig config,
    required String path,
  }) async {
    final directory = await _cacheDirectory();
    final key = sha256
        .convert(
          utf8.encode('${config.owner}/${config.repo}/${config.branch}/$path'),
        )
        .toString();
    return File('${directory.path}/$key.json');
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
  const CachedMarkdownMetadata({
    required this.owner,
    required this.repo,
    required this.branch,
    required this.path,
    required this.sha,
    required this.isDirty,
  });

  final String owner;
  final String repo;
  final String branch;
  final String path;
  final String sha;
  final bool isDirty;
}

class CachedMarkdownDraft {
  const CachedMarkdownDraft({
    required this.path,
    required this.content,
    required this.sha,
  });

  final String path;
  final String content;
  final String sha;
}
