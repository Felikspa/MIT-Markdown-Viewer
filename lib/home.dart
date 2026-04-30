import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:markdown_editor/device_preference_notifier.dart';
import 'package:markdown_editor/github/github_client.dart';
import 'package:markdown_editor/github/github_config.dart';
import 'package:markdown_editor/github/github_config_store.dart';
import 'package:markdown_editor/github/github_tree.dart';
import 'package:markdown_editor/github/markdown_cache_store.dart';
import 'package:markdown_editor/widgets/MarkdownBody/custom_image_config.dart';
import 'package:markdown_editor/widgets/MarkdownBody/custom_text_node.dart';
import 'package:markdown_editor/widgets/MarkdownBody/latex_node.dart';
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

  const _SettingsScreen({
    required this.config,
    required this.devicePreferenceNotifier,
    required this.onSaveConfig,
  });

  @override
  State<_SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<_SettingsScreen> {
  late GithubConfig _config;
  late double _readerFontSize;

  @override
  void initState() {
    super.initState();
    _config = widget.config;
    _readerFontSize = widget.devicePreferenceNotifier.value.readerFontSize
        .clamp(12, 28);
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

  Future<void> _setDarkMode(bool enabled) async {
    await widget.devicePreferenceNotifier.setDarkMode(enabled);
  }

  void _setReaderFontSize(double value) {
    setState(() {
      _readerFontSize = value;
    });
    unawaited(widget.devicePreferenceNotifier.setReaderFontSize(value));
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
                SwitchListTile(
                  secondary: Icon(
                    preferences.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                  ),
                  title: const Text('Dark mode'),
                  value: preferences.isDarkMode,
                  onChanged: (value) => unawaited(_setDarkMode(value)),
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
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RepositoryScreen extends StatefulWidget {
  final GithubConfig config;
  final DevicePreferenceNotifier devicePreferenceNotifier;
  final Future<void> Function() onSettingsPressed;

  const _RepositoryScreen({
    required this.config,
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
    if (oldWidget.config != widget.config) {
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
  final ScrollController _scrollController = ScrollController();
  final MarkdownCacheStore _cacheStore = MarkdownCacheStore();
  late Future<_ReaderContent> _contentFuture;
  bool _isTopBarVisible = false;
  String? _cachedContent;
  double? _cachedFontSize;
  bool? _cachedIsDark;
  _ReaderRenderModel? _cachedRenderModel;

  @override
  void initState() {
    super.initState();
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
    _contentFuture = _fetchContent();
  }

  @override
  void dispose() {
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    _scrollController.dispose();
    super.dispose();
  }

  Future<_ReaderContent> _fetchContent() async {
    try {
      final content = await GithubClient(
        config: widget.config,
      ).fetchMarkdownFile(widget.file.path);
      await _cacheStore.write(
        config: widget.config,
        path: widget.file.path,
        content: content,
      );
      return _ReaderContent(content: content, isCached: false);
    } catch (_) {
      final cachedContent = await _cacheStore.read(
        config: widget.config,
        path: widget.file.path,
      );
      if (cachedContent == null) {
        rethrow;
      }
      return _ReaderContent(content: cachedContent, isCached: true);
    }
  }

  void _refresh() {
    setState(() {
      _contentFuture = _fetchContent();
    });
  }

  Future<void> _toggleTheme() async {
    _clearMarkdownCache();
    await widget.devicePreferenceNotifier.toggleTheme();
  }

  void _clearMarkdownCache() {
    _cachedContent = null;
    _cachedFontSize = null;
    _cachedIsDark = null;
    _cachedRenderModel = null;
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

  Widget _markdownView(String content) {
    final theme = Theme.of(context);
    final isDark = widget.devicePreferenceNotifier.value.isDarkMode;
    final fontSize = widget.devicePreferenceNotifier.value.readerFontSize;
    final textColor = isDark
        ? const Color(0xFFEDEFF2)
        : theme.colorScheme.onSurface;
    final markdownConfig =
        (isDark ? MarkdownConfig.darkConfig : MarkdownConfig.defaultConfig)
            .copy(
              configs: [
                PConfig(
                  textStyle: TextStyle(
                    fontSize: fontSize,
                    height: 1.65,
                    color: textColor,
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
            _cachedIsDark == isDark
        ? cachedRenderModel
        : _ReaderRenderModel.fromMarkdown(
            content: content,
            config: markdownConfig,
            generator: MarkdownGenerator(
              generators: [latexGenerator],
              inlineSyntaxList: [LatexSyntax()],
              textGenerator: (node, config, visitor) =>
                  CustomTextNode(node.textContent, config, visitor),
              richTextBuilder: Text.rich,
            ),
          );
    _cachedContent = content;
    _cachedFontSize = fontSize;
    _cachedIsDark = isDark;
    _cachedRenderModel = renderModel;

    return NotificationListener<UserScrollNotification>(
      onNotification: _handleScrollNotification,
      child: Scrollbar(
        controller: _scrollController,
        interactive: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _setTopBarVisible(false),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.devicePreferenceNotifier.value.isDarkMode;
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
        headings: _cachedRenderModel?.headings ?? const [],
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
                  return _markdownView(snapshot.requireData.content);
                },
              ),
            ),
            _ReaderTopBar(
              visible: _isTopBarVisible,
              title: widget.file.name,
              isDark: isDark,
              onToggleTheme: _toggleTheme,
              onRefresh: _refresh,
              onOpenSettings: widget.onSettingsPressed,
            ),
            _ReaderBottomBar(
              visible: _isTopBarVisible,
              previousFile: _previousFile,
              nextFile: _nextFile,
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
  const _ReaderContent({required this.content, required this.isCached});

  final String content;
  final bool isCached;
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
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index].trimRight();
      if (RegExp(r'^\s{0,3}(```|~~~)').hasMatch(line)) {
        isInFence = !isInFence;
        continue;
      }
      if (isInFence) {
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

class _ReaderMarkdownItem extends StatefulWidget {
  final Widget child;

  const _ReaderMarkdownItem({super.key, required this.child});

  @override
  State<_ReaderMarkdownItem> createState() => _ReaderMarkdownItemState();
}

class _ReaderMarkdownItemState extends State<_ReaderMarkdownItem>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RepaintBoundary(child: widget.child);
  }
}

class _ReaderTocDrawer extends StatelessWidget {
  final List<_ReaderHeading> headings;
  final ValueChanged<_ReaderHeading> onHeadingSelected;

  const _ReaderTocDrawer({
    required this.headings,
    required this.onHeadingSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Text(
                'Contents',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: headings.isEmpty
                  ? const Center(child: Text('No headings found.'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: headings.length,
                      itemBuilder: (context, index) {
                        final heading = headings[index];
                        return ListTile(
                          minVerticalPadding: 10,
                          contentPadding: EdgeInsets.only(
                            left: 16 + (heading.level - 1) * 14,
                            right: 16,
                          ),
                          title: Text(
                            heading.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => onHeadingSelected(heading),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReaderTopBar extends StatelessWidget {
  final bool visible;
  final String title;
  final bool isDark;
  final VoidCallback onToggleTheme;
  final VoidCallback onRefresh;
  final Future<void> Function() onOpenSettings;

  const _ReaderTopBar({
    required this.visible,
    required this.title,
    required this.isDark,
    required this.onToggleTheme,
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
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _ReaderBottomBar({
    required this.visible,
    required this.previousFile,
    required this.nextFile,
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
                      width: 1,
                      height: 28,
                      color: theme.colorScheme.outlineVariant,
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
