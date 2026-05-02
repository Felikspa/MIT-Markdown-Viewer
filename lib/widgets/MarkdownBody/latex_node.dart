import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as m;
import 'package:markdown_widget/markdown_widget.dart';

SpanNodeGeneratorWithTag latexGenerator = SpanNodeGeneratorWithTag(
  tag: _latexTag,
  generator: (e, config, visitor) =>
      LatexNode(e.attributes, e.textContent, config),
);

const _latexTag = 'latex';

class LatexBlockSyntax extends m.BlockSyntax {
  static final _openingPattern = RegExp(r'^\s*(\$\$|\\\[)\s*$');

  const LatexBlockSyntax();

  @override
  RegExp get pattern => _openingPattern;

  @override
  m.Node parse(m.BlockParser parser) {
    final openingMatch = _openingPattern.firstMatch(parser.current.content)!;
    final openingDelimiter = openingMatch.group(1)!;
    final closingPattern = openingDelimiter == r'$$'
        ? RegExp(r'^\s*\$\$\s*$')
        : RegExp(r'^\s*\\\]\s*$');
    final contentLines = <String>[];
    final rawLines = <String>[parser.current.content];

    parser.advance();
    while (!parser.isDone) {
      final line = parser.current.content;
      rawLines.add(line);
      if (closingPattern.hasMatch(line)) {
        parser.advance();
        break;
      }
      contentLines.add(line);
      parser.advance();
    }

    final element = m.Element.text(_latexTag, rawLines.join('\n'));
    element.attributes['content'] = contentLines.join('\n');
    element.attributes['isInline'] = 'false';
    return element;
  }
}

class LatexSyntax extends m.InlineSyntax {
  LatexSyntax()
    : super(r'(\$\$[\s\S]+?\$\$)|(\\\[[\s\S]+?\\\])|(\\\(.+?\\\))|(\$.+?\$)');

  @override
  bool onMatch(m.InlineParser parser, Match match) {
    final input = match.input;
    final matchValue = input.substring(match.start, match.end);
    String content = '';
    bool isInline = true;
    const blockSyntax = '\$\$';
    const inlineSyntax = '\$';
    if (matchValue.startsWith(blockSyntax) &&
        matchValue.endsWith(blockSyntax) &&
        matchValue != blockSyntax) {
      content = matchValue.substring(2, matchValue.length - 2);
      isInline = false;
    } else if (matchValue.startsWith(r'\[') && matchValue.endsWith(r'\]')) {
      content = matchValue.substring(2, matchValue.length - 2);
      isInline = false;
    } else if (matchValue.startsWith(r'\(') && matchValue.endsWith(r'\)')) {
      content = matchValue.substring(2, matchValue.length - 2);
    } else if (matchValue.startsWith(inlineSyntax) &&
        matchValue.endsWith(inlineSyntax) &&
        matchValue != inlineSyntax) {
      content = matchValue.substring(1, matchValue.length - 1);
    }
    final m.Element el = m.Element.text(_latexTag, matchValue);
    el.attributes['content'] = content;
    el.attributes['isInline'] = '$isInline';
    parser.addNode(el);
    return true;
  }
}

class LatexNode extends SpanNode {
  final Map<String, String> attributes;
  final String textContent;
  final MarkdownConfig config;

  LatexNode(this.attributes, this.textContent, this.config);

  @override
  InlineSpan build() {
    final content = attributes['content'] ?? '';
    final isInline = attributes['isInline'] == 'true';
    final style = parentStyle ?? config.p.textStyle;
    if (content.isEmpty) return TextSpan(style: style, text: textContent);

    final latex = Math.tex(
      content,
      mathStyle: MathStyle.text,
      textStyle: style,
      textScaleFactor: 1,
      onErrorFallback: (error) {
        return Text(
          'LaTeX error: ${error.message}',
          style: style.copyWith(color: Colors.red),
        );
      },
    );
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: !isInline
          ? Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 16),
              child: _ScrollableLatex(latex: latex, isInline: false),
            )
          : _ScrollableLatex(latex: latex, isInline: true),
    );
  }
}

class _ScrollableLatex extends StatelessWidget {
  final Widget latex;
  final bool isInline;

  const _ScrollableLatex({required this.latex, required this.isInline});

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width - 48;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: isInline
            ? latex
            : ConstrainedBox(
                constraints: BoxConstraints(minWidth: maxWidth),
                child: Center(child: latex),
              ),
      ),
    );
  }
}
