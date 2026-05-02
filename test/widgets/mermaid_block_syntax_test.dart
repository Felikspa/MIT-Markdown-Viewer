import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as m;
import 'package:markdown_editor/widgets/MarkdownBody/mermaid_node.dart';
import 'package:markdown_widget/markdown_widget.dart';

void main() {
  test('mermaid fence is parsed as mermaid block', () {
    const markdown = '''```mermaid
graph TD
  A-->B
```''';

    final document = m.Document(
      extensionSet: m.ExtensionSet.gitHubFlavored,
      blockSyntaxes: const [MermaidBlockSyntax()],
    );
    final nodes = document.parseLines(markdown.split('\n'));

    expect(nodes, hasLength(1));
    final element = nodes.single as m.Element;
    expect(element.tag, 'mermaid');
    expect(element.attributes['content'], contains('graph TD'));
    expect(element.attributes['content'], contains('A-->B'));
  });

  test('mermaid fence does not appear in toc', () {
    const markdown = '''```mermaid
graph TD
  A-->B
```

# Real title''';

    var tocList = <Toc>[];
    MarkdownGenerator(
      generators: [mermaidGenerator],
      blockSyntaxList: const [MermaidBlockSyntax()],
    ).buildWidgets(
      markdown,
      onTocList: (list) {
        tocList = list;
      },
    );

    expect(tocList, hasLength(1));
    expect(tocList.single.node.headingConfig.tag, MarkdownTag.h1.name);
  });
}
