import 'dart:async';

import 'package:flutter/material.dart';
import 'package:markdown_editor/github/github_client.dart';
import 'package:markdown_editor/github/github_config.dart';

class MarkdownEditResult {
  const MarkdownEditResult({
    required this.content,
    required this.sha,
    required this.uploaded,
    required this.scrollProgress,
  });

  final String content;
  final String sha;
  final bool uploaded;
  final double scrollProgress;
}

class MarkdownEditorScreen extends StatefulWidget {
  const MarkdownEditorScreen({
    super.key,
    required this.config,
    required this.path,
    required this.initialContent,
    required this.initialSha,
    required this.initialScrollProgress,
  });

  final GithubConfig config;
  final String path;
  final String initialContent;
  final String initialSha;
  final double initialScrollProgress;

  @override
  State<MarkdownEditorScreen> createState() => _MarkdownEditorScreenState();
}

class _MarkdownEditorScreenState extends State<MarkdownEditorScreen> {
  late final TextEditingController _contentController;
  late final ScrollController _scrollController;
  late final UndoHistoryController _undoController;
  bool _isUploading = false;
  bool _isClosing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.initialContent);
    _scrollController = ScrollController();
    _undoController = UndoHistoryController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      final maxScrollExtent = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(
        maxScrollExtent * widget.initialScrollProgress.clamp(0, 1),
      );
    });
  }

  @override
  void dispose() {
    _contentController.dispose();
    _scrollController.dispose();
    _undoController.dispose();
    super.dispose();
  }

  double get _scrollProgress {
    if (!_scrollController.hasClients) {
      return widget.initialScrollProgress.clamp(0, 1);
    }
    final maxScrollExtent = _scrollController.position.maxScrollExtent;
    if (maxScrollExtent <= 0) {
      return 0;
    }
    return (_scrollController.offset / maxScrollExtent).clamp(0, 1);
  }

  void _closeWithDraft() {
    _finish(
      MarkdownEditResult(
        content: _contentController.text,
        sha: widget.initialSha,
        uploaded: false,
        scrollProgress: _scrollProgress,
      ),
    );
  }

  void _finish(MarkdownEditResult result) {
    if (_isClosing) {
      return;
    }
    setState(() {
      _isClosing = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(result);
    });
  }

  Future<void> _upload() async {
    final message = await _requestCommitMessage();
    if (message == null) {
      return;
    }
    setState(() {
      _isUploading = true;
      _error = null;
    });
    try {
      final updatedFile = await GithubClient(config: widget.config)
          .updateMarkdownFile(
            path: widget.path,
            content: _contentController.text,
            sha: widget.initialSha,
            message: message,
          );
      if (!mounted) {
        return;
      }
      _finish(
        MarkdownEditResult(
          content: _contentController.text,
          sha: updatedFile.sha,
          uploaded: true,
          scrollProgress: _scrollProgress,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error is GithubApiException && error.statusCode == 409
            ? 'Remote file changed on GitHub. Refresh before uploading to avoid overwriting another edit.'
            : error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<String?> _requestCommitMessage() async {
    final controller = TextEditingController(text: 'Update ${widget.path}');
    final message = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Commit message'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Message',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (value) {
              if (value.trim().isEmpty) {
                return;
              }
              Navigator.of(context).pop(value.trim());
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty) {
                  return;
                }
                Navigator.of(context).pop(value);
              },
              child: const Text('Upload'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return message;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope<MarkdownEditResult>(
      canPop: _isClosing,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _isClosing) {
          return;
        }
        _closeWithDraft();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.path),
          actions: [
            ValueListenableBuilder<UndoHistoryValue>(
              valueListenable: _undoController,
              builder: (context, value, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: value.canUndo ? _undoController.undo : null,
                      tooltip: 'Undo',
                      icon: const Icon(Icons.undo),
                    ),
                    IconButton(
                      onPressed: value.canRedo ? _undoController.redo : null,
                      tooltip: 'Redo',
                      icon: const Icon(Icons.redo),
                    ),
                  ],
                );
              },
            ),
            IconButton(
              onPressed: _isUploading ? null : () => unawaited(_upload()),
              tooltip: 'Upload to GitHub',
              icon: _isUploading
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (_error != null)
                MaterialBanner(
                  content: Text(_error!),
                  leading: Icon(
                    Icons.error_outline,
                    color: theme.colorScheme.error,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _error = null;
                        });
                      },
                      child: const Text('Dismiss'),
                    ),
                  ],
                ),
              Expanded(
                child: TextField(
                  controller: _contentController,
                  undoController: _undoController,
                  scrollController: _scrollController,
                  expands: true,
                  maxLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  keyboardType: TextInputType.multiline,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 15,
                    height: 1.55,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
