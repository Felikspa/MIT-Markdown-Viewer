import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:markdown/markdown.dart' as m;
import 'package:markdown_widget/markdown_widget.dart';
import 'package:webview_flutter/webview_flutter.dart';

SpanNodeGeneratorWithTag mermaidGenerator = SpanNodeGeneratorWithTag(
  tag: _mermaidTag,
  generator: (element, config, visitor) =>
      MermaidNode(element.attributes, config),
);

const _mermaidTag = 'mermaid';

class MermaidBlockSyntax extends m.BlockSyntax {
  static final _openingPattern = RegExp(
    r'^\s{0,3}(`{3,}|~{3,})\s*mermaid\s*$',
    caseSensitive: false,
  );

  const MermaidBlockSyntax();

  @override
  RegExp get pattern => _openingPattern;

  @override
  m.Node parse(m.BlockParser parser) {
    final openingMatch = _openingPattern.firstMatch(parser.current.content)!;
    final openingFence = openingMatch.group(1)!;
    final marker = openingFence[0];
    final closingPattern = RegExp(
      '^\\s{0,3}${RegExp.escape(marker)}{${openingFence.length},}\\s*\$',
    );
    final contentLines = <String>[];

    parser.advance();
    while (!parser.isDone) {
      final line = parser.current.content;
      if (closingPattern.hasMatch(line)) {
        parser.advance();
        break;
      }
      contentLines.add(line);
      parser.advance();
    }

    final element = m.Element.text(_mermaidTag, contentLines.join('\n'));
    element.attributes['content'] = contentLines.join('\n');
    return element;
  }
}

class MermaidNode extends SpanNode {
  final Map<String, String> attributes;
  final MarkdownConfig config;

  MermaidNode(this.attributes, this.config);

  @override
  InlineSpan build() {
    final content = attributes['content'] ?? '';
    final style = parentStyle ?? config.p.textStyle;
    if (content.isEmpty) {
      return TextSpan(style: style, text: '');
    }
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: _MermaidView(content: content, textColor: style.color),
    );
  }
}

class _MermaidView extends StatefulWidget {
  final String content;
  final Color? textColor;

  const _MermaidView({required this.content, required this.textColor});

  @override
  State<_MermaidView> createState() => _MermaidViewState();
}

class _MermaidViewState extends State<_MermaidView> {
  late final WebViewController _controller;
  double _height = 220;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    unawaited(_configureController());
  }

  Future<void> _configureController() async {
    try {
      await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await _controller.setBackgroundColor(Colors.transparent);
      await _controller.addJavaScriptChannel(
        'MermaidSize',
        onMessageReceived: (message) {
          final nextHeight = double.tryParse(message.message);
          if (nextHeight == null || !mounted) {
            return;
          }
          setState(() {
            _height = nextHeight.clamp(120, 2400);
          });
        },
      );
      final mermaidScript = await rootBundle.loadString(
        'assets/vendor/mermaid/mermaid.min.js',
      );
      await _controller.loadHtmlString(_buildHtml(mermaidScript));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadError = error;
      });
    }
  }

  @override
  void didUpdateWidget(covariant _MermaidView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content ||
        oldWidget.textColor != widget.textColor) {
      unawaited(_reloadHtml());
    }
  }

  Future<void> _reloadHtml() async {
    try {
      final mermaidScript = await rootBundle.loadString(
        'assets/vendor/mermaid/mermaid.min.js',
      );
      await _controller.loadHtmlString(_buildHtml(mermaidScript));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadError = error;
      });
    }
  }

  String _buildHtml(String mermaidScript) {
    final textColor = widget.textColor ?? Colors.black;
    final isDark = textColor.computeLuminance() > 0.5;
    final theme = isDark ? 'dark' : 'default';
    final diagramSource = jsonEncode(widget.content);
    final foregroundColor = _cssColor(textColor);
    return '''
<!doctype html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    html, body {
      margin: 0;
      padding: 0;
      background: transparent;
      color: $foregroundColor;
      overflow-x: auto;
      overflow-y: hidden;
    }
    #wrap {
      width: max-content;
      min-width: 100vw;
      padding: 8px 0 12px;
      box-sizing: border-box;
    }
    #diagram {
      min-width: 100vw;
      display: flex;
      justify-content: center;
    }
    #diagram svg {
      max-width: none;
      height: auto;
    }
    #error {
      white-space: pre-wrap;
      color: #d32f2f;
      font: 14px sans-serif;
      padding: 12px;
    }
  </style>
  <script>
$mermaidScript
  </script>
</head>
<body>
  <div id="wrap"><div id="diagram"></div></div>
  <script>
    const source = $diagramSource;
    const reportSize = () => {
      const height = Math.ceil(document.documentElement.scrollHeight);
      MermaidSize.postMessage(String(height));
    };
    window.addEventListener('resize', reportSize);
    mermaid.initialize({ startOnLoad: false, theme: '$theme', securityLevel: 'strict' });
    mermaid.render('diagram-svg', source)
      .then(({ svg }) => {
        document.getElementById('diagram').innerHTML = svg;
        requestAnimationFrame(reportSize);
      })
      .catch((error) => {
        document.getElementById('wrap').innerHTML =
          '<pre id="error">Mermaid error: ' + String(error).replace(/[<>&]/g, (c) => ({'<':'&lt;','>':'&gt;','&':'&amp;'}[c])) + '</pre>';
        requestAnimationFrame(reportSize);
      });
  </script>
</body>
</html>
''';
  }

  String _cssColor(Color color) {
    final red = (color.r * 255).round();
    final green = (color.g * 255).round();
    final blue = (color.b * 255).round();
    return 'rgb($red, $green, $blue)';
  }

  @override
  Widget build(BuildContext context) {
    final loadError = _loadError;
    if (loadError != null) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.all(12),
        child: Text(
          'Mermaid error: $loadError',
          style: const TextStyle(color: Colors.red),
        ),
      );
    }
    return Container(
      width: double.infinity,
      height: _height,
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: WebViewWidget(controller: _controller),
    );
  }
}
