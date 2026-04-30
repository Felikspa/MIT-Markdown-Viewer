import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_editor/github/github_tree.dart';

void main() {
  test('fromMarkdownEntries builds a sorted markdown directory tree', () {
    final root = GithubDirectoryNode.fromMarkdownEntries([
      const GithubTreeEntry(path: 'zeta.md', type: 'blob'),
      const GithubTreeEntry(path: 'docs/b.md', type: 'blob'),
      const GithubTreeEntry(path: 'docs/a.markdown', type: 'blob'),
      const GithubTreeEntry(path: 'docs/image.png', type: 'blob'),
      const GithubTreeEntry(path: 'docs/nested/c.md', type: 'blob'),
    ]);

    expect(root.files.map((file) => file.path), ['zeta.md']);
    expect(root.directories.keys, ['docs']);

    final docs = root.directories['docs'];
    expect(docs, isNotNull);
    expect(docs!.files.map((file) => file.path), [
      'docs/a.markdown',
      'docs/b.md',
    ]);
    expect(docs.directories.keys, ['nested']);
    expect(docs.directories['nested']!.files.single.path, 'docs/nested/c.md');
  });
}
