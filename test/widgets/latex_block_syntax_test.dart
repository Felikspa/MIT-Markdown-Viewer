import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as m;
import 'package:markdown_editor/widgets/MarkdownBody/latex_node.dart';
import 'package:markdown_widget/markdown_widget.dart';

void main() {
  test('multiline display math is parsed as latex block', () {
    const markdown = r'''$$
\sqrt{1+x^2y^2}-1
=
\frac{x^2y^2}{\sqrt{1+x^2y^2}+1}.
$$''';

    final document = m.Document(
      extensionSet: m.ExtensionSet.gitHubFlavored,
      blockSyntaxes: const [LatexBlockSyntax()],
    );
    final nodes = document.parseLines(markdown.split('\n'));

    expect(nodes, hasLength(1));
    final element = nodes.single as m.Element;
    expect(element.tag, 'latex');
    expect(element.attributes['isInline'], 'false');
    expect(element.attributes['content'], contains(r'\sqrt{1+x^2y^2}-1'));
    expect(element.attributes['content'], contains('='));
  });

  test('multiline display math does not appear in toc', () {
    const markdown = r'''$$
\sqrt{1+x^2y^2}-1
=
\frac{x^2y^2}{\sqrt{1+x^2y^2}+1}.
$$

# Real title''';

    var tocList = <Toc>[];
    MarkdownGenerator(
      generators: [latexGenerator],
      blockSyntaxList: const [LatexBlockSyntax()],
      inlineSyntaxList: [LatexSyntax()],
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
