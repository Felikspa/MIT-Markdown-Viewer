import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:html/dom.dart' as h;
import 'package:html/dom_parsing.dart';
import 'package:html/parser.dart';
import 'package:markdown/markdown.dart' as m;
import 'package:markdown_widget/markdown_widget.dart';

void htmlToMarkdown(h.Node? node, int deep, List<m.Node> mNodes) {
  if (node == null) return;
  if (node is h.Text) {
    mNodes.add(m.Text(node.text));
  } else if (node is h.Element) {
    final tag = node.localName;
    final List<m.Node> children = [];
    for (final e in node.children) {
      htmlToMarkdown(e, deep + 1, children);
    }
    m.Element element;
    if (tag == MarkdownTag.img.name || tag == 'video') {
      element = HtmlElement(tag!, children, node.text);
      element.attributes.addAll(node.attributes.cast());
    } else {
      element = HtmlElement(tag!, children, node.text);
      element.attributes.addAll(node.attributes.cast());
    }
    mNodes.add(element);
  }
}

final RegExp tableRep = RegExp(r'<table[^>]*>', multiLine: true);

final RegExp htmlRep = RegExp(r'<[^>]*>', multiLine: true);

///parse [m.Node] to [h.Node]
List<SpanNode> parseHtml(
  m.Text node, {
  ValueCallback<dynamic>? onError,
  WidgetVisitor? visitor,
  TextStyle? parentStyle,
}) {
  try {
    final text = node.textContent.replaceAll(
      visitor?.splitRegExp ?? WidgetVisitor.defaultSplitRegExp,
      '',
    );
    if (!text.contains(htmlRep)) return [TextNode(text: node.text)];
    final h.DocumentFragment document = parseFragment(text);
    return HtmlToSpanVisitor(
      visitor: visitor,
      parentStyle: parentStyle,
    ).toVisit(document.nodes.toList());
  } catch (e) {
    onError?.call(e);
    return [TextNode(text: node.text)];
  }
}

class HtmlElement extends m.Element {
  @override
  final String textContent;

  HtmlElement(super.tag, super.children, this.textContent);
}

class HtmlToSpanVisitor extends TreeVisitor {
  final List<SpanNode> _spans = [];
  final List<SpanNode> _spansStack = [];
  final WidgetVisitor visitor;
  final TextStyle parentStyle;

  HtmlToSpanVisitor({WidgetVisitor? visitor, TextStyle? parentStyle})
    : visitor = visitor ?? WidgetVisitor(),
      parentStyle = parentStyle ?? const TextStyle();

  List<SpanNode> toVisit(List<h.Node> nodes) {
    _spans.clear();
    for (final node in nodes) {
      final emptyNode = ConcreteElementNode(style: parentStyle);
      _spans.add(emptyNode);
      _spansStack.add(emptyNode);
      visit(node);
      _spansStack.removeLast();
    }
    final result = List.of(_spans);
    _spans.clear();
    _spansStack.clear();
    return result;
  }

  @override
  void visitText(h.Text node) {
    final last = _spansStack.last;
    if (last is ElementNode) {
      final textNode = TextNode(text: node.text);
      last.accept(textNode);
    }
  }

  @override
  void visitElement(h.Element node) {
    final localName = node.localName ?? '';
    final mdElement = m.Element(localName, []);
    mdElement.attributes.addAll(node.attributes.cast());
    SpanNode spanNode = visitor.getNodeByElement(mdElement, visitor.config);
    if (spanNode is! ElementNode) {
      final n = ConcreteElementNode(tag: localName, style: parentStyle);
      n.accept(spanNode);
      spanNode = n;
    }
    final last = _spansStack.last;
    if (last is ElementNode) {
      last.accept(spanNode);
    }
    _spansStack.add(spanNode);
    for (final child in node.nodes.toList(growable: false)) {
      visit(child);
    }
    _spansStack.removeLast();
  }
}

class CustomTextNode extends ElementNode {
  final String text;
  final MarkdownConfig config;
  final WidgetVisitor visitor;
  bool isTable = false;

  CustomTextNode(this.text, this.config, this.visitor);

  @override
  InlineSpan build() {
    if (isTable) {
      //deal complex table tag with html core widget
      return WidgetSpan(child: HtmlWidget(text));
    } else {
      return super.build();
    }
  }

  @override
  void onAccepted(SpanNode parent) {
    final textStyle = config.p.textStyle.merge(parentStyle);
    children.clear();
    if (!text.contains(htmlRep)) {
      _acceptTextByScript(textStyle);
      return;
    }
    //Intercept as table tag
    if (text.contains(tableRep)) {
      isTable = true;
      accept(parent);
      return;
    }

    //The remaining ones are processed by the regular HTML processing.
    final spans = parseHtml(
      m.Text(text),
      visitor: WidgetVisitor(
        config: visitor.config,
        generators: visitor.generators,
        richTextBuilder: visitor.richTextBuilder,
      ),
      parentStyle: parentStyle,
    );
    for (final element in spans) {
      isTable = false;
      accept(element);
    }
  }

  void _acceptTextByScript(TextStyle textStyle) {
    final fontFamilyFallback = textStyle.fontFamilyFallback;
    final chineseFontFamily =
        fontFamilyFallback == null || fontFamilyFallback.isEmpty
        ? null
        : fontFamilyFallback.first;
    if (chineseFontFamily == null || chineseFontFamily.isEmpty) {
      accept(TextNode(text: text, style: textStyle));
      return;
    }

    final buffer = StringBuffer();
    bool? currentIsChinese;
    for (final rune in text.runes) {
      final isChinese = _isChineseRune(rune);
      if (currentIsChinese != null && currentIsChinese != isChinese) {
        _acceptTextSegment(
          buffer.toString(),
          textStyle,
          currentIsChinese,
          chineseFontFamily,
        );
        buffer.clear();
      }
      buffer.writeCharCode(rune);
      currentIsChinese = isChinese;
    }
    if (buffer.isNotEmpty) {
      _acceptTextSegment(
        buffer.toString(),
        textStyle,
        currentIsChinese ?? false,
        chineseFontFamily,
      );
    }
  }

  void _acceptTextSegment(
    String value,
    TextStyle textStyle,
    bool isChinese,
    String chineseFontFamily,
  ) {
    accept(
      TextNode(
        text: value,
        style: isChinese
            ? textStyle.copyWith(fontFamily: chineseFontFamily)
            : textStyle,
      ),
    );
  }
}

bool _isChineseRune(int rune) {
  return (rune >= 0x3400 && rune <= 0x4DBF) ||
      (rune >= 0x4E00 && rune <= 0x9FFF) ||
      (rune >= 0xF900 && rune <= 0xFAFF) ||
      (rune >= 0x20000 && rune <= 0x2A6DF) ||
      (rune >= 0x2A700 && rune <= 0x2B73F) ||
      (rune >= 0x2B740 && rune <= 0x2B81F) ||
      (rune >= 0x2B820 && rune <= 0x2CEAF) ||
      (rune >= 0x2CEB0 && rune <= 0x2EBEF) ||
      (rune >= 0x3000 && rune <= 0x303F) ||
      (rune >= 0xFF00 && rune <= 0xFFEF);
}
