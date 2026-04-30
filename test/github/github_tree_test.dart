import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_editor/github/github_tree.dart';

void main() {
  test('fromMarkdownEntries builds a sorted markdown directory tree', () {
    final root = GithubDirectoryNode.fromMarkdownEntries([
      const GithubTreeEntry(path: 'zeta.md', type: 'blob', sha: 'sha-z'),
      const GithubTreeEntry(path: 'docs/b.md', type: 'blob', sha: 'sha-b'),
      const GithubTreeEntry(
        path: 'docs/a.markdown',
        type: 'blob',
        sha: 'sha-a',
      ),
      const GithubTreeEntry(
        path: 'docs/image.png',
        type: 'blob',
        sha: 'sha-img',
      ),
      const GithubTreeEntry(
        path: 'docs/nested/c.md',
        type: 'blob',
        sha: 'sha-c',
      ),
    ]);

    expect(root.files.map((file) => file.path), ['zeta.md']);
    expect(root.directories.keys, ['docs']);

    final docs = root.directories['docs'];
    expect(docs, isNotNull);
    expect(docs!.files.map((file) => file.path), [
      'docs/a.markdown',
      'docs/b.md',
    ]);
    expect(docs.files.map((file) => file.sha), ['sha-a', 'sha-b']);
    expect(docs.directories.keys, ['nested']);
    expect(docs.directories['nested']!.files.single.path, 'docs/nested/c.md');
  });
}
