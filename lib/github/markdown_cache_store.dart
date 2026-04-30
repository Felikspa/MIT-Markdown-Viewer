import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:markdown_editor/github/github_config.dart';
import 'package:path_provider/path_provider.dart';

class MarkdownCacheStore {
  Future<String?> read({
    required GithubConfig config,
    required String path,
  }) async {
    final file = await _fileFor(config: config, path: path);
    if (!await file.exists()) {
      return null;
    }
    return file.readAsString();
  }

  Future<void> write({
    required GithubConfig config,
    required String path,
    required String content,
  }) async {
    final file = await _fileFor(config: config, path: path);
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
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
}
