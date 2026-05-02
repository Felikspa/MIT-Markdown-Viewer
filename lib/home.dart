import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:markdown_editor/ai/openai_client.dart';
import 'package:markdown_editor/ai/openai_config_screen.dart';
import 'package:markdown_editor/ai/openai_config_store.dart';
import 'package:markdown_editor/device_preference_notifier.dart';
import 'package:markdown_editor/github/github_client.dart';
import 'package:markdown_editor/github/github_config.dart';
import 'package:markdown_editor/github/github_config_store.dart';
import 'package:markdown_editor/github/github_tree.dart';
import 'package:markdown_editor/github/markdown_cache_store.dart';
import 'package:markdown_editor/reader/markdown_editor_screen.dart';
import 'package:markdown_editor/widgets/MarkdownBody/custom_image_config.dart';
import 'package:markdown_editor/widgets/MarkdownBody/custom_text_node.dart';
import 'package:markdown_editor/widgets/MarkdownBody/latex_node.dart';
import 'package:markdown_editor/widgets/MarkdownBody/mermaid_node.dart';
import 'package:markdown_widget/markdown_widget.dart';

class Home extends StatefulWidget {
  final DevicePreferenceNotifier devicePreferenceNotifier;

  const Home({super.key, required this.devicePreferenceNotifier});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final GithubConfigStore _configStore = GithubConfigStore();
  GithubConfig? _config;
  GithubConfig? _editingConfig;
  Object? _loadError;
  bool _isLoading = true;
  int _repositoryRevision = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadConfig());
  }

  Future<void> _loadConfig() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final config = await _configStore.load();
      if (!mounted) {
        return;
      }
      setState(() {
        _config = config;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadError = error;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveConfig(GithubConfig config) async {
    await _configStore.save(config);
    setState(() {
      _config = config.trimmed();
      _editingConfig = null;
      _repositoryRevision++;
    });
  }

  Future<void> _repositoryUpdated() async {
    await _loadConfig();
    if (!mounted) {
      return;
    }
    setState(() {
      _repositoryRevision++;
    });
  }

  Future<void> _openSettings() async {
    final config = _config;
    if (config == null) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _SettingsScreen(
          config: config,
          devicePreferenceNotifier: widget.devicePreferenceNotifier,
          onSaveConfig: _saveConfig,
          onRepositoryUpdated: _repositoryUpdated,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    if (_loadError != null) {
      return _ErrorScaffold(
        title: 'Markdown Reader',
        message: _loadError.toString(),
        onRetry: _loadConfig,
      );
    }

    final config = _config;
    if (config == null) {
      return _GithubConfigScreen(
        initialConfig: _editingConfig,
        onSave: _saveConfig,
      );
    }

    return _RepositoryScreen(
      config: config,
      revision: _repositoryRevision,
      devicePreferenceNotifier: widget.devicePreferenceNotifier,
      onSettingsPressed: _openSettings,
    );
  }
}

class _GithubConfigScreen extends StatefulWidget {
  final GithubConfig? initialConfig;
  final Future<void> Function(GithubConfig config) onSave;

  const _GithubConfigScreen({
    required this.initialConfig,
    required this.onSave,
  });

  @override
  State<_GithubConfigScreen> createState() => _GithubConfigScreenState();
}

class _GithubConfigScreenState extends State<_GithubConfigScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _repositoryUrlController;
  late final TextEditingController _branchController;
  late final TextEditingController _tokenController;
  bool _isSaving = false;
  bool _obscureToken = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final config = widget.initialConfig;
    _repositoryUrlController = TextEditingController(
      text: config?.repositoryUrl ?? '',
    );
    _branchController = TextEditingController(text: config?.branch ?? 'main');
    _tokenController = TextEditingController(text: config?.token ?? '');
  }

  @override
  void dispose() {
    _repositoryUrlController.dispose();
    _branchController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await widget.onSave(
        GithubConfig.fromRepositoryUrl(
          repositoryUrl: _repositoryUrlController.text,
          branch: _branchController.text,
          token: _tokenController.text,
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
          _isSaving = false;
        });
      }
    }
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    return null;
  }

  String? _repositoryUrlValidator(String? value) {
    final requiredError = _requiredValidator(value);
    if (requiredError != null) {
      return requiredError;
    }
    try {
      GithubRepository.parse(value!);
      return null;
    } on FormatException catch (error) {
      return error.message;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GitHub Repository')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _repositoryUrlController,
                    decoration: const InputDecoration(
                      labelText: 'GitHub URL',
                      prefixIcon: Icon(Icons.link),
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.url,
                    validator: _repositoryUrlValidator,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _branchController,
                    decoration: const InputDecoration(
                      labelText: 'Branch',
                      prefixIcon: Icon(Icons.alt_route),
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.next,
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _tokenController,
                    decoration: InputDecoration(
                      labelText: 'GitHub Token',
                      prefixIcon: const Icon(Icons.key),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _obscureToken = !_obscureToken;
                          });
                        },
                        tooltip: _obscureToken ? 'Show token' : 'Hide token',
                        icon: Icon(
                          _obscureToken
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    obscureText: _obscureToken,
                    textInputAction: TextInputAction.done,
                    validator: _requiredValidator,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _submit,
                    icon: _isSaving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: const Text('Save'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsScreen extends StatefulWidget {
  final GithubConfig config;
  final DevicePreferenceNotifier devicePreferenceNotifier;
  final Future<void> Function(GithubConfig config) onSaveConfig;
  final Future<void> Function() onRepositoryUpdated;

  const _SettingsScreen({
    required this.config,
    required this.devicePreferenceNotifier,
    required this.onSaveConfig,
    required this.onRepositoryUpdated,
  });

  @override
  State<_SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<_SettingsScreen> {
  static const MethodChannel _platformChannel = MethodChannel(
    'com.adeeteya.markdown_editor/channel',
  );

  late GithubConfig _config;
  late double _readerFontSize;
  late final Future<List<String>> _fontFamiliesFuture;
  bool _isSyncing = false;
  String? _syncStatus;

  @override
  void initState() {
    super.initState();
    _config = widget.config;
    _readerFontSize = widget.devicePreferenceNotifier.value.readerFontSize
        .clamp(12, 28);
    _fontFamiliesFuture = _loadSystemFontFamilies();
  }

  Future<List<String>> _loadSystemFontFamilies() async {
    final fontFamilies = await _platformChannel.invokeListMethod<String>(
      'getSystemFontFamilies',
    );
    if (fontFamilies == null) {
      throw StateError('System font list is empty.');
    }
    return fontFamilies
        .map((fontFamily) => fontFamily.trim())
        .where((fontFamily) => fontFamily.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  Future<void> _editRepository() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _GithubConfigScreen(
          initialConfig: _config,
          onSave: (config) async {
            await widget.onSaveConfig(config);
            if (!mounted) {
              return;
            }
            setState(() {
              _config = config.trimmed();
            });
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
    );
  }

  Future<void> _editAiApi() async {
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(builder: (context) => const OpenAiConfigScreen()),
    );
  }

  Future<void> _syncAllMarkdown() async {
    setState(() {
      _isSyncing = true;
      _syncStatus = 'Loading repository tree...';
    });
    try {
      final client = GithubClient(config: _config);
      final cacheStore = MarkdownCacheStore();
      final entries = await client.fetchMarkdownTree();
      var updated = 0;
      var skipped = 0;
      var completed = 0;
      const concurrency = 6;
      var cursor = 0;
      final counters = _SyncCounters();

      Future<void> worker() async {
        while (true) {
          final currentIndex = cursor;
          if (currentIndex >= entries.length) {
            return;
          }
          cursor++;
          final entry = entries[currentIndex];
          final isFresh = await cacheStore.isFresh(
            config: _config,
            path: entry.path,
            sha: entry.sha,
          );
          if (isFresh) {
            counters.skipped++;
          } else {
            final content = await client.fetchMarkdownFile(entry.path);
            await cacheStore.write(
              config: _config,
              path: entry.path,
              content: content,
              sha: entry.sha,
            );
            counters.updated++;
          }
          completed++;
          if (!mounted) {
            return;
          }
          setState(() {
            _syncStatus = 'Syncing $completed/${entries.length}';
          });
        }
      }

      await Future.wait([
        for (var index = 0; index < concurrency; index++) worker(),
      ]);
      updated = counters.updated;
      skipped = counters.skipped;
      await widget.onRepositoryUpdated();
      if (!mounted) {
        return;
      }
      setState(() {
        _syncStatus = 'Synced $updated files, skipped $skipped unchanged.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _syncStatus = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  void _setReaderFontSize(double value) {
    setState(() {
      _readerFontSize = value;
    });
    unawaited(widget.devicePreferenceNotifier.setReaderFontSize(value));
  }

  void _setReaderEnglishFontFamily(String value) {
    unawaited(
      widget.devicePreferenceNotifier.setReaderEnglishFontFamily(value),
    );
  }

  void _setReaderChineseFontFamily(String value) {
    unawaited(
      widget.devicePreferenceNotifier.setReaderChineseFontFamily(value),
    );
  }

  Widget _fontFamilyDropdown({
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return FutureBuilder<List<String>>(
      future: _fontFamiliesFuture,
      builder: (context, snapshot) {
        final fontFamilies = snapshot.data ?? const <String>[];
        final options = ['', ...fontFamilies];
        final selectedValue = options.contains(value) ? value : '';
        return DropdownButtonFormField<String>(
          initialValue: selectedValue,
          isExpanded: true,
          decoration: InputDecoration(
            helperText: snapshot.connectionState == ConnectionState.done
                ? 'Current device fonts'
                : 'Loading fonts...',
            errorText: snapshot.hasError ? snapshot.error.toString() : null,
          ),
          items: [
            const DropdownMenuItem<String>(
              value: '',
              child: Text('Follow system'),
            ),
            for (final fontFamily in fontFamilies)
              DropdownMenuItem<String>(
                value: fontFamily,
                child: Text(
                  fontFamily,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: fontFamily),
                ),
              ),
          ],
          onChanged: (nextValue) {
            if (nextValue == null) {
              return;
            }
            onChanged(nextValue);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<DevicePreferences>(
      valueListenable: widget.devicePreferenceNotifier,
      builder: (context, preferences, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(
                    'Repository',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.link),
                  title: Text('${_config.owner}/${_config.repo}'),
                  subtitle: Text('${_config.repositoryUrl}\n${_config.branch}'),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _editRepository,
                ),
                ListTile(
                  leading: _isSyncing
                      ? const SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_sync),
                  title: const Text('Sync all Markdown'),
                  subtitle: Text(
                    _syncStatus ??
                        'Download every Markdown file and refresh local cache.',
                  ),
                  enabled: !_isSyncing,
                  onTap: _isSyncing ? null : _syncAllMarkdown,
                ),
                const Divider(height: 28),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Text(
                    'AI',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.smart_toy_outlined),
                  title: const Text('OpenAI compatible API'),
                  subtitle: const Text(
                    'Configure base URL, API key, and model for selected text queries.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _editAiApi,
                ),
                const Divider(height: 28),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Text(
                    'Reading',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.contrast),
                  title: const Text('Theme'),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: SegmentedButton<AppThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: AppThemeMode.system,
                          icon: Icon(Icons.settings_suggest),
                          label: Text('System'),
                        ),
                        ButtonSegment(
                          value: AppThemeMode.light,
                          icon: Icon(Icons.light_mode),
                          label: Text('Light'),
                        ),
                        ButtonSegment(
                          value: AppThemeMode.dark,
                          icon: Icon(Icons.dark_mode),
                          label: Text('Dark'),
                        ),
                      ],
                      selected: {preferences.themeMode},
                      onSelectionChanged: (selection) {
                        unawaited(
                          widget.devicePreferenceNotifier.setThemeMode(
                            selection.single,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.format_size),
                  title: const Text('Text size'),
                  subtitle: Slider(
                    value: _readerFontSize,
                    min: 12,
                    max: 28,
                    divisions: 16,
                    label: _readerFontSize.round().toString(),
                    onChanged: _setReaderFontSize,
                  ),
                  trailing: SizedBox(
                    width: 44,
                    child: Text(
                      _readerFontSize.round().toString(),
                      textAlign: TextAlign.end,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.text_fields),
                  title: const Text('English font'),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _fontFamilyDropdown(
                      value: preferences.readerEnglishFontFamily,
                      onChanged: _setReaderEnglishFontFamily,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.translate),
                  title: const Text('Chinese font'),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _fontFamilyDropdown(
                      value: preferences.readerChineseFontFamily,
                      onChanged: _setReaderChineseFontFamily,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SyncCounters {
  int updated = 0;
  int skipped = 0;
}

class _RepositoryScreen extends StatefulWidget {
  final GithubConfig config;
  final int revision;
  final DevicePreferenceNotifier devicePreferenceNotifier;
  final Future<void> Function() onSettingsPressed;

  const _RepositoryScreen({
    required this.config,
    required this.revision,
    required this.devicePreferenceNotifier,
    required this.onSettingsPressed,
  });

  @override
  State<_RepositoryScreen> createState() => _RepositoryScreenState();
}

class _RepositoryScreenState extends State<_RepositoryScreen> {
  late Future<GithubDirectoryNode> _treeFuture;

  @override
  void initState() {
    super.initState();
    _treeFuture = _fetchTree();
  }

  @override
  void didUpdateWidget(covariant _RepositoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config ||
        oldWidget.revision != widget.revision) {
      _treeFuture = _fetchTree();
    }
  }

  Future<GithubDirectoryNode> _fetchTree() async {
    final client = GithubClient(config: widget.config);
    final entries = await client.fetchMarkdownTree();
    return GithubDirectoryNode.fromMarkdownEntries(entries);
  }

  void _refresh() {
    setState(() {
      _treeFuture = _fetchTree();
    });
  }

  Future<void> _openFile(
    GithubMarkdownFile file,
    List<GithubMarkdownFile> files,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _ReaderScreen(
          config: widget.config,
          file: file,
          files: files,
          devicePreferenceNotifier: widget.devicePreferenceNotifier,
          onSettingsPressed: widget.onSettingsPressed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.config.owner}/${widget.config.repo}'),
        actions: [
          IconButton(
            onPressed: _refresh,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: widget.onSettingsPressed,
            tooltip: 'Settings',
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<GithubDirectoryNode>(
          future: _treeFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator.adaptive());
            }
            if (snapshot.hasError) {
              return _ErrorView(
                message: snapshot.error.toString(),
                onRetry: _refresh,
              );
            }
            final root = snapshot.requireData;
            if (root.directories.isEmpty && root.files.isEmpty) {
              return const Center(child: Text('No Markdown files found.'));
            }
            final files = root.flattenFiles();
            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final directory in root.directories.values)
                  _DirectoryTile(
                    directory: directory,
                    onOpenFile: (file) => _openFile(file, files),
                  ),
                for (final file in root.files)
                  _FileTile(
                    file: file,
                    onOpenFile: (file) => _openFile(file, files),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DirectoryTile extends StatelessWidget {
  final GithubDirectoryNode directory;
  final Future<void> Function(GithubMarkdownFile file) onOpenFile;

  const _DirectoryTile({required this.directory, required this.onOpenFile});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: const Icon(Icons.folder_outlined),
      title: Text(directory.name),
      childrenPadding: const EdgeInsets.only(left: 16),
      children: [
        for (final child in directory.directories.values)
          _DirectoryTile(directory: child, onOpenFile: onOpenFile),
        for (final file in directory.files)
          _FileTile(file: file, onOpenFile: onOpenFile),
      ],
    );
  }
}

class _FileTile extends StatelessWidget {
  final GithubMarkdownFile file;
  final Future<void> Function(GithubMarkdownFile file) onOpenFile;

  const _FileTile({required this.file, required this.onOpenFile});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minVerticalPadding: 12,
      leading: const Icon(Icons.article_outlined),
      title: Text(file.name),
      subtitle: Text(file.path),
      onTap: () => onOpenFile(file),
    );
  }
}

class _ReaderScreen extends StatefulWidget {
  final GithubConfig config;
  final GithubMarkdownFile file;
  final List<GithubMarkdownFile> files;
  final DevicePreferenceNotifier devicePreferenceNotifier;
  final Future<void> Function() onSettingsPressed;

  const _ReaderScreen({
    required this.config,
    required this.file,
    required this.files,
    required this.devicePreferenceNotifier,
    required this.onSettingsPressed,
  });

  @override
  State<_ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<_ReaderScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<SelectionAreaState> _selectionAreaKey =
      GlobalKey<SelectionAreaState>();
  final ScrollController _scrollController = ScrollController();
  final MarkdownCacheStore _cacheStore = MarkdownCacheStore();
  late Future<_ReaderContent> _contentFuture;
  bool _isTopBarVisible = false;
  bool _isSourceView = false;
  int _activeHeadingIndex = 0;
  _ReaderTextStats _currentStats = const _ReaderTextStats(
    characters: 0,
    words: 0,
  );
  Offset? _pointerDownPosition;
  DateTime? _pointerDownTime;
  String? _cachedContent;
  double? _cachedFontSize;
  String? _cachedEnglishFontFamily;
  String? _cachedChineseFontFamily;
  bool? _cachedIsDark;
  _ReaderRenderModel? _cachedRenderModel;
  _ReaderContentStatus? _lastShownContentStatus;
  OverlayEntry? _statusOverlay;
  Timer? _headingUpdateTimer;
  late String _currentSha;
  String? _currentContent;
  String? _selectedText;

  @override
  void initState() {
    super.initState();
    _currentSha = widget.file.sha;
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
    _scrollController.addListener(_scheduleActiveHeadingUpdate);
    _contentFuture = _fetchContent();
  }

  @override
  void dispose() {
    _statusOverlay?.remove();
    _headingUpdateTimer?.cancel();
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    _scrollController.removeListener(_scheduleActiveHeadingUpdate);
    _scrollController.dispose();
    super.dispose();
  }

  Future<_ReaderContent> _fetchContent() async {
    final cachedContent = await _cacheStore.read(
      config: widget.config,
      path: widget.file.path,
    );
    if (cachedContent != null && cachedContent.isDirty) {
      return _ReaderContent.fromContent(
        content: cachedContent.content,
        status: _ReaderContentStatus.localDraft,
      );
    }

    final hasConnection = await InternetConnection().hasInternetAccess;
    if (!hasConnection) {
      if (cachedContent == null) {
        throw const GithubApiException('Offline and no cached copy exists.');
      }
      return _ReaderContent.fromContent(
        content: cachedContent.content,
        status: _ReaderContentStatus.offlineCached,
      );
    }

    if (cachedContent != null && cachedContent.sha == widget.file.sha) {
      return _ReaderContent.fromContent(
        content: cachedContent.content,
        status: _ReaderContentStatus.upToDate,
      );
    }

    try {
      final content = await GithubClient(
        config: widget.config,
      ).fetchMarkdownFile(widget.file.path);
      await _cacheStore.write(
        config: widget.config,
        path: widget.file.path,
        content: content,
        sha: widget.file.sha,
      );
      return _ReaderContent.fromContent(
        content: content,
        status: cachedContent == null
            ? _ReaderContentStatus.downloaded
            : _ReaderContentStatus.updated,
      );
    } catch (_) {
      if (cachedContent == null) {
        rethrow;
      }
      return _ReaderContent.fromContent(
        content: cachedContent.content,
        status: _ReaderContentStatus.networkFailedCached,
      );
    }
  }

  void _showContentStatus(_ReaderContentStatus status) {
    if (_lastShownContentStatus == status) {
      return;
    }
    _lastShownContentStatus = status;
    final message = switch (status) {
      _ReaderContentStatus.upToDate => 'Already up to date.',
      _ReaderContentStatus.updated => 'Updated to the latest version.',
      _ReaderContentStatus.downloaded => 'Downloaded and cached.',
      _ReaderContentStatus.localDraft => 'Opened local draft.',
      _ReaderContentStatus.offlineCached => 'Offline. Opened cached copy.',
      _ReaderContentStatus.networkFailedCached =>
        'Network failed. Opened cached copy.',
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _statusOverlay?.remove();
      final overlay = Overlay.of(context);
      final entry = OverlayEntry(
        builder: (context) => _ReaderStatusToast(message: message),
      );
      _statusOverlay = entry;
      overlay.insert(entry);
      Future<void>.delayed(const Duration(milliseconds: 1800), () {
        if (_statusOverlay == entry) {
          entry.remove();
          _statusOverlay = null;
        }
      });
    });
  }

  void _refresh() {
    _lastShownContentStatus = null;
    setState(() {
      _contentFuture = _fetchContent();
    });
  }

  Future<void> _toggleTheme() async {
    await widget.devicePreferenceNotifier.toggleTheme();
    if (!mounted) {
      return;
    }
    setState(_clearMarkdownCache);
  }

  void _clearMarkdownCache() {
    _cachedContent = null;
    _cachedFontSize = null;
    _cachedEnglishFontFamily = null;
    _cachedChineseFontFamily = null;
    _cachedIsDark = null;
    _cachedRenderModel = null;
  }

  void _toggleSourceView() {
    setState(() {
      _isSourceView = !_isSourceView;
    });
  }

  void _handleReaderPointerDown(PointerDownEvent event) {
    _pointerDownPosition = event.position;
    _pointerDownTime = DateTime.now();
  }

  void _handleReaderPointerUp(PointerUpEvent event) {
    final downPosition = _pointerDownPosition;
    final downTime = _pointerDownTime;
    _pointerDownPosition = null;
    _pointerDownTime = null;
    if (downPosition == null || downTime == null) {
      return;
    }
    final distance = (event.position - downPosition).distance;
    final duration = DateTime.now().difference(downTime);
    if (distance > 12 || duration > const Duration(milliseconds: 260)) {
      return;
    }
    _selectionAreaKey.currentState?.selectableRegion.clearSelection();
    _setTopBarVisible(false);
  }

  void _rememberStats(_ReaderTextStats stats) {
    if (_currentStats == stats) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _currentStats == stats) {
        return;
      }
      setState(() {
        _currentStats = stats;
      });
    });
  }

  void _scheduleActiveHeadingUpdate() {
    if (_headingUpdateTimer?.isActive ?? false) {
      return;
    }
    _headingUpdateTimer = Timer(const Duration(milliseconds: 90), () {
      if (mounted) {
        _updateActiveHeadingFromScroll();
      }
    });
  }

  void _updateActiveHeadingFromScroll() {
    final renderModel = _cachedRenderModel;
    if (renderModel == null || renderModel.headings.isEmpty || !mounted) {
      return;
    }

    final threshold = MediaQuery.paddingOf(context).top + 88;
    int? activeIndex;
    int? firstBelowIndex;
    for (var index = 0; index < renderModel.headings.length; index++) {
      final heading = renderModel.headings[index];
      final keyContext =
          renderModel.itemKeys[heading.widgetIndex].currentContext;
      if (keyContext == null) {
        continue;
      }
      final box = keyContext.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) {
        continue;
      }
      final top = box.localToGlobal(Offset.zero).dy;
      if (top <= threshold) {
        activeIndex = index;
      } else {
        firstBelowIndex ??= index;
      }
    }

    final nextIndex =
        activeIndex ??
        (firstBelowIndex == null
            ? renderModel.headings.length - 1
            : (firstBelowIndex - 1).clamp(0, renderModel.headings.length - 1));
    if (nextIndex == _activeHeadingIndex) {
      return;
    }
    setState(() {
      _activeHeadingIndex = nextIndex;
    });
  }

  void _setTopBarVisible(bool visible) {
    if (_isTopBarVisible == visible) {
      return;
    }
    setState(() {
      _isTopBarVisible = visible;
    });
    unawaited(
      SystemChrome.setEnabledSystemUIMode(
        visible ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
      ),
    );
  }

  bool _handleScrollNotification(UserScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }
    switch (notification.direction) {
      case ScrollDirection.reverse:
        _setTopBarVisible(false);
        break;
      case ScrollDirection.forward:
        _setTopBarVisible(true);
        break;
      case ScrollDirection.idle:
        break;
    }
    return false;
  }

  String _resolveImageUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri != null && uri.hasScheme) {
      return url;
    }
    if (url.startsWith('#')) {
      return url;
    }

    final baseParts = widget.file.path.split('/')..removeLast();
    final imageParts = url.startsWith('/')
        ? url.substring(1).split('/')
        : [...baseParts, ...url.split('/')];
    final normalizedParts = <String>[];
    for (final part in imageParts) {
      if (part.isEmpty || part == '.') {
        continue;
      }
      if (part == '..') {
        if (normalizedParts.isEmpty) {
          throw ArgumentError('Image path leaves the repository root: $url');
        }
        normalizedParts.removeLast();
      } else {
        normalizedParts.add(part);
      }
    }
    final imagePath = normalizedParts.join('/');
    return Uri.https(
      'raw.githubusercontent.com',
      '/${widget.config.owner}/${widget.config.repo}/${widget.config.branch}/$imagePath',
    ).toString();
  }

  int get _currentFileIndex {
    return widget.files.indexWhere((file) => file.path == widget.file.path);
  }

  GithubMarkdownFile? get _previousFile {
    final index = _currentFileIndex;
    if (index <= 0) {
      return null;
    }
    return widget.files[index - 1];
  }

  GithubMarkdownFile? get _nextFile {
    final index = _currentFileIndex;
    if (index == -1 || index >= widget.files.length - 1) {
      return null;
    }
    return widget.files[index + 1];
  }

  int get _safeActiveHeadingIndex {
    final headings = _cachedRenderModel?.headings;
    if (headings == null || headings.isEmpty) {
      return 0;
    }
    return _activeHeadingIndex.clamp(0, headings.length - 1);
  }

  Future<void> _openSibling(
    GithubMarkdownFile file, {
    required bool isPrevious,
  }) async {
    await Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) => _ReaderScreen(
          config: widget.config,
          file: file,
          files: widget.files,
          devicePreferenceNotifier: widget.devicePreferenceNotifier,
          onSettingsPressed: widget.onSettingsPressed,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final begin = isPrevious ? const Offset(-1, 0) : const Offset(1, 0);
          final tween = Tween<Offset>(
            begin: begin,
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 320),
      ),
    );
  }

  void _jumpToHeading(_ReaderHeading heading) {
    _setTopBarVisible(false);
    unawaited(Navigator.of(context).maybePop());
    final key = _cachedRenderModel?.itemKeys[heading.widgetIndex];
    final keyContext = key?.currentContext;
    if (keyContext != null) {
      unawaited(
        Scrollable.ensureVisible(
          keyContext,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  void _handleSelectionChanged(SelectedContent? content) {
    final plainText = content?.plainText.trim();
    if (plainText == null || plainText.isEmpty) {
      if (_selectedText != null) {
        setState(() {
          _selectedText = null;
        });
      }
      return;
    }
    if (_selectedText == plainText) {
      return;
    }
    setState(() {
      _selectedText = plainText;
    });
  }

  Widget _selectionContextMenu(
    BuildContext context,
    SelectableRegionState selectableRegionState,
  ) {
    final selectedText = _selectedText?.trim();
    final buttonItems = [
      if (selectedText != null && selectedText.isNotEmpty)
        ContextMenuButtonItem(
          label: '查询',
          onPressed: () {
            ContextMenuController.removeAny();
            unawaited(_querySelection(selectedText));
          },
        ),
      ...selectableRegionState.contextMenuButtonItems,
    ];
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: selectableRegionState.contextMenuAnchors,
      buttonItems: buttonItems,
    );
  }

  Future<void> _openEditor() async {
    final content = _currentContent;
    if (content == null) {
      return;
    }
    final result = await Navigator.of(context).push<MarkdownEditResult>(
      MaterialPageRoute<MarkdownEditResult>(
        builder: (context) => MarkdownEditorScreen(
          config: widget.config,
          path: widget.file.path,
          initialContent: content,
          initialSha: _currentSha,
        ),
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    _currentSha = result.sha;
    await _cacheStore.write(
      config: widget.config,
      path: widget.file.path,
      content: result.content,
      sha: result.sha,
      isDirty: !result.uploaded,
    );
    if (!mounted) {
      return;
    }
    _lastShownContentStatus = null;
    setState(() {
      _clearMarkdownCache();
      _contentFuture = Future.value(
        _ReaderContent.fromContent(
          content: result.content,
          status: result.uploaded
              ? _ReaderContentStatus.updated
              : _ReaderContentStatus.localDraft,
        ),
      );
    });
  }

  Future<void> _querySelection(String? text) async {
    final selectedText = text?.trim();
    if (selectedText == null || selectedText.isEmpty) {
      _showSnackBar('Select text first.');
      return;
    }

    final store = OpenAiConfigStore();
    final config = await store.load();
    if (!mounted) {
      return;
    }
    if (config == null) {
      _showSnackBar('Configure AI API in Settings first.');
      return;
    }

    final future = OpenAiClient(config: config).explainSelection(
      selectedText: selectedText,
      documentTitle: widget.file.name,
    );
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _AiExplanationSheet(
        selectedText: selectedText,
        explanationFuture: future,
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _markdownView(String content) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final preferences = widget.devicePreferenceNotifier.value;
    final fontSize = preferences.readerFontSize;
    final englishFontFamily = preferences.readerEnglishFontFamily.trim();
    final chineseFontFamily = preferences.readerChineseFontFamily.trim();
    final textColor = isDark ? Colors.white : Colors.black;
    TextStyle readerTextStyle({
      required double fontSize,
      required double height,
      FontWeight? fontWeight,
    }) {
      return TextStyle(
        fontSize: fontSize,
        height: height,
        fontWeight: fontWeight,
        color: textColor,
        fontFamily: englishFontFamily.isEmpty ? null : englishFontFamily,
        fontFamilyFallback: chineseFontFamily.isEmpty
            ? null
            : [chineseFontFamily],
      );
    }

    final markdownConfig =
        (isDark ? MarkdownConfig.darkConfig : MarkdownConfig.defaultConfig)
            .copy(
              configs: [
                PConfig(
                  textStyle: readerTextStyle(fontSize: fontSize, height: 1.65),
                ),
                _ReaderHeadingConfig(
                  tag: MarkdownTag.h1.name,
                  style: readerTextStyle(
                    fontSize: 32,
                    height: 40 / 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _ReaderHeadingConfig(
                  tag: MarkdownTag.h2.name,
                  style: readerTextStyle(
                    fontSize: 24,
                    height: 30 / 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _ReaderHeadingConfig(
                  tag: MarkdownTag.h3.name,
                  style: readerTextStyle(
                    fontSize: 20,
                    height: 25 / 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _ReaderHeadingConfig(
                  tag: MarkdownTag.h4.name,
                  style: readerTextStyle(
                    fontSize: 16,
                    height: 20 / 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _ReaderHeadingConfig(
                  tag: MarkdownTag.h5.name,
                  style: readerTextStyle(
                    fontSize: 16,
                    height: 20 / 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _ReaderHeadingConfig(
                  tag: MarkdownTag.h6.name,
                  style: readerTextStyle(
                    fontSize: 16,
                    height: 20 / 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                CustomImgConfig(
                  headers: {'Authorization': 'Bearer ${widget.config.token}'},
                  transformUrl: _resolveImageUrl,
                ),
                TableConfig(
                  wrapper: (tableWidget) => SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: tableWidget,
                  ),
                ),
              ],
            );
    final cachedRenderModel = _cachedRenderModel;
    final renderModel =
        cachedRenderModel != null &&
            _cachedContent == content &&
            _cachedFontSize == fontSize &&
            _cachedEnglishFontFamily == englishFontFamily &&
            _cachedChineseFontFamily == chineseFontFamily &&
            _cachedIsDark == isDark
        ? cachedRenderModel
        : _ReaderRenderModel.fromMarkdown(
            content: content,
            config: markdownConfig,
            generator: MarkdownGenerator(
              generators: [latexGenerator, mermaidGenerator],
              blockSyntaxList: const [MermaidBlockSyntax(), LatexBlockSyntax()],
              inlineSyntaxList: [LatexSyntax()],
              textGenerator: (node, config, visitor) =>
                  CustomTextNode(node.textContent, config, visitor),
              richTextBuilder: Text.rich,
            ),
          );
    _cachedContent = content;
    _cachedFontSize = fontSize;
    _cachedEnglishFontFamily = englishFontFamily;
    _cachedChineseFontFamily = chineseFontFamily;
    _cachedIsDark = isDark;
    _cachedRenderModel = renderModel;
    if (cachedRenderModel == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _updateActiveHeadingFromScroll();
          setState(() {});
        }
      });
    }

    return NotificationListener<UserScrollNotification>(
      onNotification: _handleScrollNotification,
      child: Scrollbar(
        controller: _scrollController,
        interactive: true,
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _handleReaderPointerDown,
          onPointerUp: _handleReaderPointerUp,
          child: SelectionArea(
            key: _selectionAreaKey,
            onSelectionChanged: _handleSelectionChanged,
            contextMenuBuilder: _selectionContextMenu,
            child: ListView.builder(
              controller: _scrollController,
              cacheExtent: 2400,
              padding: EdgeInsets.fromLTRB(
                18,
                12,
                18,
                MediaQuery.paddingOf(context).bottom + kToolbarHeight + 28,
              ),
              itemCount: renderModel.widgets.length,
              itemBuilder: (context, index) => _ReaderMarkdownItem(
                key: renderModel.itemKeys[index],
                child: renderModel.widgets[index],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sourceView(String content) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final preferences = widget.devicePreferenceNotifier.value;
    final englishFontFamily = preferences.readerEnglishFontFamily.trim();
    final textColor = isDark ? Colors.white : Colors.black;
    return NotificationListener<UserScrollNotification>(
      onNotification: _handleScrollNotification,
      child: Scrollbar(
        controller: _scrollController,
        interactive: true,
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _handleReaderPointerDown,
          onPointerUp: _handleReaderPointerUp,
          child: SelectionArea(
            key: _selectionAreaKey,
            onSelectionChanged: _handleSelectionChanged,
            contextMenuBuilder: _selectionContextMenu,
            child: ListView(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(
                18,
                12,
                18,
                MediaQuery.paddingOf(context).bottom + kToolbarHeight + 28,
              ),
              children: [
                Text(
                  content,
                  style: TextStyle(
                    color: textColor,
                    fontFamily: englishFontFamily.isEmpty
                        ? 'monospace'
                        : englishFontFamily,
                    fontSize: (preferences.readerFontSize - 1).clamp(12, 27),
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? Colors.black
        : Theme.of(context).colorScheme.surface;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: backgroundColor,
      drawerEdgeDragWidth: 108,
      onDrawerChanged: (isOpened) {
        if (isOpened) {
          _setTopBarVisible(false);
        }
      },
      drawer: _ReaderTocDrawer(
        key: ValueKey(_safeActiveHeadingIndex),
        headings: _cachedRenderModel?.headings ?? const [],
        activeHeadingIndex: _safeActiveHeadingIndex,
        onHeadingSelected: _jumpToHeading,
      ),
      body: ColoredBox(
        color: backgroundColor,
        child: Stack(
          children: [
            SafeArea(
              top: false,
              child: FutureBuilder<_ReaderContent>(
                future: _contentFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                      child: CircularProgressIndicator.adaptive(),
                    );
                  }
                  if (snapshot.hasError) {
                    return _ErrorView(
                      message: snapshot.error.toString(),
                      onRetry: _refresh,
                    );
                  }
                  final content = snapshot.requireData;
                  _currentContent = content.content;
                  _rememberStats(content.stats);
                  _showContentStatus(content.status);
                  return _isSourceView
                      ? _sourceView(content.content)
                      : _markdownView(content.content);
                },
              ),
            ),
            _ReaderTopBar(
              visible: _isTopBarVisible,
              title: widget.file.name,
              isDark: isDark,
              isSourceView: _isSourceView,
              onToggleTheme: _toggleTheme,
              onToggleSourceView: _toggleSourceView,
              onEdit: _openEditor,
              onRefresh: _refresh,
              onOpenSettings: widget.onSettingsPressed,
            ),
            _ReaderBottomBar(
              visible: _isTopBarVisible,
              previousFile: _previousFile,
              nextFile: _nextFile,
              stats: _currentStats,
              onPrevious: _previousFile == null
                  ? null
                  : () => unawaited(
                      _openSibling(_previousFile!, isPrevious: true),
                    ),
              onNext: _nextFile == null
                  ? null
                  : () =>
                        unawaited(_openSibling(_nextFile!, isPrevious: false)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReaderContent {
  const _ReaderContent({
    required this.content,
    required this.status,
    required this.stats,
  });

  factory _ReaderContent.fromContent({
    required String content,
    required _ReaderContentStatus status,
  }) {
    return _ReaderContent(
      content: content,
      status: status,
      stats: _ReaderTextStats.fromContent(content),
    );
  }

  final String content;
  final _ReaderContentStatus status;
  final _ReaderTextStats stats;
}

class _ReaderTextStats {
  const _ReaderTextStats({required this.characters, required this.words});

  factory _ReaderTextStats.fromContent(String content) {
    final characters = content.replaceAll(RegExp(r'\s'), '').length;
    final words = RegExp(
      r"[A-Za-z0-9]+(?:['-][A-Za-z0-9]+)*",
    ).allMatches(content).length;
    return _ReaderTextStats(characters: characters, words: words);
  }

  final int characters;
  final int words;

  @override
  bool operator ==(Object other) {
    return other is _ReaderTextStats &&
        other.characters == characters &&
        other.words == words;
  }

  @override
  int get hashCode => Object.hash(characters, words);
}

enum _ReaderContentStatus {
  upToDate,
  updated,
  downloaded,
  localDraft,
  offlineCached,
  networkFailedCached,
}

class _ReaderHeadingConfig extends HeadingConfig {
  @override
  final String tag;

  @override
  final TextStyle style;

  const _ReaderHeadingConfig({required this.tag, required this.style});
}

class _ReaderStatusToast extends StatefulWidget {
  final String message;

  const _ReaderStatusToast({required this.message});

  @override
  State<_ReaderStatusToast> createState() => _ReaderStatusToastState();
}

class _ReaderStatusToastState extends State<_ReaderStatusToast> {
  var _visible = true;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _visible = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned(
      left: 16,
      right: 16,
      bottom: MediaQuery.paddingOf(context).bottom + 16,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: _visible ? 1 : 0,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          child: Material(
            color: Colors.transparent,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.inverseSurface,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Text(
                    widget.message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onInverseSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AiExplanationSheet extends StatelessWidget {
  final String selectedText;
  final Future<String> explanationFuture;

  const _AiExplanationSheet({
    required this.selectedText,
    required this.explanationFuture,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      minChildSize: 0.42,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return Material(
          color: theme.colorScheme.surface,
          child: FutureBuilder<String>(
            future: explanationFuture,
            builder: (context, snapshot) {
              final hasResult =
                  snapshot.connectionState == ConnectionState.done;
              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Query',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Close',
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Selected text',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.colorScheme.outline),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        selectedText,
                        maxLines: 8,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (!hasResult)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator.adaptive(),
                      ),
                    )
                  else if (snapshot.hasError)
                    Text(
                      snapshot.error.toString(),
                      style: TextStyle(color: theme.colorScheme.error),
                    )
                  else
                    SelectableText(
                      snapshot.requireData,
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _ReaderRenderModel {
  const _ReaderRenderModel({
    required this.widgets,
    required this.itemKeys,
    required this.headings,
  });

  factory _ReaderRenderModel.fromMarkdown({
    required String content,
    required MarkdownConfig config,
    required MarkdownGenerator generator,
  }) {
    var tocList = <Toc>[];
    final widgets = generator.buildWidgets(
      content,
      config: config,
      onTocList: (list) {
        tocList = list;
      },
    );
    final itemKeys = List<GlobalKey>.generate(
      widgets.length,
      (index) => GlobalKey(),
    );
    final markdownHeadings = _extractMarkdownHeadings(content);
    final headings = [
      for (var index = 0; index < tocList.length; index++)
        _ReaderHeading.fromToc(
          tocList[index],
          markdownHeading: index < markdownHeadings.length
              ? markdownHeadings[index]
              : null,
        ),
    ];
    return _ReaderRenderModel(
      widgets: widgets,
      itemKeys: itemKeys,
      headings: headings,
    );
  }

  static List<_MarkdownHeading> _extractMarkdownHeadings(String content) {
    final headings = <_MarkdownHeading>[];
    final lines = content.split('\n');
    var isInFence = false;
    String? latexClosingMarker;
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index].trimRight();
      if (RegExp(r'^\s{0,3}(```|~~~)').hasMatch(line)) {
        isInFence = !isInFence;
        continue;
      }
      if (latexClosingMarker != null) {
        if (line.trim() == latexClosingMarker) {
          latexClosingMarker = null;
        }
        continue;
      }
      if (isInFence) {
        continue;
      }
      final trimmedLine = line.trim();
      if (trimmedLine == r'$$' || trimmedLine == r'\[') {
        latexClosingMarker = trimmedLine == r'$$' ? r'$$' : r'\]';
        continue;
      }
      final atxMatch = RegExp(
        r'^\s{0,3}(#{1,6})\s+(.+?)\s*#*\s*$',
      ).firstMatch(line);
      if (atxMatch != null) {
        headings.add(
          _MarkdownHeading(
            title: _cleanHeadingText(atxMatch.group(2)!),
            level: atxMatch.group(1)!.length,
          ),
        );
        continue;
      }

      if (index + 1 >= lines.length) {
        continue;
      }
      final marker = lines[index + 1].trim();
      if (line.trim().isEmpty || !RegExp(r'^(=+|-+)$').hasMatch(marker)) {
        continue;
      }
      headings.add(
        _MarkdownHeading(
          title: _cleanHeadingText(line.trim()),
          level: marker.startsWith('=') ? 1 : 2,
        ),
      );
    }
    return headings;
  }

  static String _cleanHeadingText(String value) {
    return value
        .replaceAllMapped(
          RegExp(r'!\[([^\]]*)\]\([^)]+\)'),
          (match) => match.group(1) ?? '',
        )
        .replaceAllMapped(
          RegExp(r'\[([^\]]+)\]\([^)]+\)'),
          (match) => match.group(1) ?? '',
        )
        .replaceAll(RegExp(r'[`*_~]'), '')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .trim();
  }

  final List<Widget> widgets;
  final List<GlobalKey> itemKeys;
  final List<_ReaderHeading> headings;
}

class _MarkdownHeading {
  const _MarkdownHeading({required this.title, required this.level});

  final String title;
  final int level;
}

class _ReaderHeading {
  const _ReaderHeading({
    required this.title,
    required this.level,
    required this.widgetIndex,
  });

  factory _ReaderHeading.fromToc(
    Toc toc, {
    required _MarkdownHeading? markdownHeading,
  }) {
    final tag = toc.node.headingConfig.tag;
    final level = int.tryParse(tag.replaceFirst('h', '')) ?? 1;
    return _ReaderHeading(
      title: markdownHeading?.title ?? toc.node.build().toPlainText(),
      level: (markdownHeading?.level ?? level).clamp(1, 6),
      widgetIndex: toc.widgetIndex,
    );
  }

  final String title;
  final int level;
  final int widgetIndex;
}

class _ReaderMarkdownItem extends StatelessWidget {
  final Widget child;

  const _ReaderMarkdownItem({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(child: child);
  }
}

class _ReaderTocDrawer extends StatefulWidget {
  final List<_ReaderHeading> headings;
  final int activeHeadingIndex;
  final ValueChanged<_ReaderHeading> onHeadingSelected;

  const _ReaderTocDrawer({
    super.key,
    required this.headings,
    required this.activeHeadingIndex,
    required this.onHeadingSelected,
  });

  @override
  State<_ReaderTocDrawer> createState() => _ReaderTocDrawerState();
}

class _ReaderTocDrawerState extends State<_ReaderTocDrawer> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController(
      initialScrollOffset: (widget.activeHeadingIndex * 52 - 96)
          .clamp(0, double.infinity)
          .toDouble(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? Colors.black : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.08);
    final textColor = isDark ? Colors.white : Colors.black;
    final mutedTextColor = isDark
        ? Colors.white.withValues(alpha: 0.62)
        : Colors.black.withValues(alpha: 0.55);
    final activeBackgroundColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : theme.colorScheme.primary.withValues(alpha: 0.11);
    final activeTextColor = isDark ? Colors.white : theme.colorScheme.primary;
    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: surfaceColor,
              border: Border(right: BorderSide(color: borderColor)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.42 : 0.12),
                  blurRadius: 28,
                  offset: const Offset(8, 0),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 18, 18, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Contents',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: textColor,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.headings.length} headings',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: mutedTextColor,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: borderColor),
                  Expanded(
                    child: widget.headings.isEmpty
                        ? Center(
                            child: Text(
                              'No headings found.',
                              style: TextStyle(
                                color: mutedTextColor,
                                fontSize: 16,
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _controller,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            itemCount: widget.headings.length,
                            itemBuilder: (context, index) {
                              final heading = widget.headings[index];
                              final isMajor = heading.level <= 2;
                              final isActive =
                                  index == widget.activeHeadingIndex;
                              return Padding(
                                padding: EdgeInsets.only(
                                  left: 10 + (heading.level - 1) * 12,
                                  right: 10,
                                  top: 2,
                                  bottom: 2,
                                ),
                                child: Material(
                                  color: isActive
                                      ? activeBackgroundColor
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () =>
                                        widget.onHeadingSelected(heading),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 10,
                                      ),
                                      child: Text(
                                        heading.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: isActive
                                                  ? activeTextColor
                                                  : textColor,
                                              fontSize: isMajor ? 17 : 16,
                                              fontWeight: isActive
                                                  ? FontWeight.w800
                                                  : isMajor
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              height: 1.25,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReaderTopBar extends StatelessWidget {
  final bool visible;
  final String title;
  final bool isDark;
  final bool isSourceView;
  final VoidCallback onToggleTheme;
  final VoidCallback onToggleSourceView;
  final Future<void> Function() onEdit;
  final VoidCallback onRefresh;
  final Future<void> Function() onOpenSettings;

  const _ReaderTopBar({
    required this.visible,
    required this.title,
    required this.isDark,
    required this.isSourceView,
    required this.onToggleTheme,
    required this.onToggleSourceView,
    required this.onEdit,
    required this.onRefresh,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topPadding = MediaQuery.paddingOf(context).top;
    final backgroundColor = isDark
        ? const Color(0xF2050506)
        : theme.colorScheme.surface.withValues(alpha: 0.96);
    final foregroundColor = isDark
        ? const Color(0xFFEDEFF2)
        : theme.colorScheme.onSurface;

    return AnimatedSlide(
      offset: visible ? Offset.zero : const Offset(0, -1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOut,
        child: Material(
          color: backgroundColor,
          elevation: visible ? 3 : 0,
          child: Padding(
            padding: EdgeInsets.only(top: topPadding),
            child: SizedBox(
              height: kToolbarHeight,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    tooltip: 'Back',
                    color: foregroundColor,
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: foregroundColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onToggleTheme,
                    tooltip: 'Theme',
                    color: foregroundColor,
                    icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                  ),
                  IconButton(
                    onPressed: onToggleSourceView,
                    tooltip: isSourceView ? 'Render view' : 'Source view',
                    color: foregroundColor,
                    icon: Icon(isSourceView ? Icons.article : Icons.code),
                  ),
                  IconButton(
                    onPressed: () => unawaited(onEdit()),
                    tooltip: 'Edit',
                    color: foregroundColor,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    onPressed: onRefresh,
                    tooltip: 'Refresh',
                    color: foregroundColor,
                    icon: const Icon(Icons.refresh),
                  ),
                  IconButton(
                    onPressed: () => unawaited(onOpenSettings()),
                    tooltip: 'Settings',
                    color: foregroundColor,
                    icon: const Icon(Icons.tune),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReaderBottomBar extends StatelessWidget {
  final bool visible;
  final GithubMarkdownFile? previousFile;
  final GithubMarkdownFile? nextFile;
  final _ReaderTextStats stats;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _ReaderBottomBar({
    required this.visible,
    required this.previousFile,
    required this.nextFile,
    required this.stats,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xF2050506)
        : theme.colorScheme.surface.withValues(alpha: 0.96);
    final foregroundColor = isDark
        ? const Color(0xFFEDEFF2)
        : theme.colorScheme.onSurface;

    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 1),
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOut,
          child: Material(
            color: backgroundColor,
            elevation: visible ? 3 : 0,
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomPadding),
              child: SizedBox(
                height: kToolbarHeight,
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: onPrevious,
                        icon: const Icon(Icons.chevron_left),
                        label: Text(
                          previousFile?.name ?? 'Previous',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: foregroundColor,
                        ),
                      ),
                    ),
                    Container(
                      constraints: const BoxConstraints(minWidth: 92),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '${stats.characters} chars\n${stats.words} words',
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: foregroundColor.withValues(alpha: 0.72),
                          height: 1.12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: onNext,
                        iconAlignment: IconAlignment.end,
                        icon: const Icon(Icons.chevron_right),
                        label: Text(
                          nextFile?.name ?? 'Next',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: foregroundColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorScaffold extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;

  const _ErrorScaffold({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: _ErrorView(message: message, onRetry: onRetry),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
              size: 36,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
