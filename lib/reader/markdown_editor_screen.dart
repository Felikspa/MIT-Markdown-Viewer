import 'dart:async';

import 'package:flutter/material.dart';
import 'package:markdown_editor/github/github_client.dart';
import 'package:markdown_editor/github/github_config.dart';

class MarkdownEditResult {
  const MarkdownEditResult({
    required this.content,
    required this.sha,
    required this.uploaded,
  });

  final String content;
  final String sha;
  final bool uploaded;
}

class MarkdownEditorScreen extends StatefulWidget {
  const MarkdownEditorScreen({
    super.key,
    required this.config,
    required this.path,
    required this.initialContent,
    required this.initialSha,
  });

  final GithubConfig config;
  final String path;
  final String initialContent;
  final String initialSha;

  @override
  State<MarkdownEditorScreen> createState() => _MarkdownEditorScreenState();
}

class _MarkdownEditorScreenState extends State<MarkdownEditorScreen> {
  late final TextEditingController _contentController;
  bool _isUploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.initialContent);
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  void _saveDraft() {
    Navigator.of(context).pop(
      MarkdownEditResult(
        content: _contentController.text,
        sha: widget.initialSha,
        uploaded: false,
      ),
    );
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
      Navigator.of(context).pop(
        MarkdownEditResult(
          content: _contentController.text,
          sha: updatedFile.sha,
          uploaded: true,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.path),
        actions: [
          IconButton(
            onPressed: _isUploading ? null : _saveDraft,
            tooltip: 'Save draft',
            icon: const Icon(Icons.save_outlined),
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
    );
  }
}
