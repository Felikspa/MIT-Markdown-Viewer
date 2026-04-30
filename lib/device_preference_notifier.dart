import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { system, light, dark }

enum _SharedPreferencesKeys {
  isDarkMode,
  themeMode,
  isSplitLayout,
  defaultFolderPath,
  readerFontSize,
}

class DevicePreferences {
  final AppThemeMode themeMode;
  final bool isSplitLayout;
  final String? defaultFolderPath;
  final double readerFontSize;

  DevicePreferences({
    this.themeMode = AppThemeMode.system,
    this.isSplitLayout = false,
    this.defaultFolderPath,
    this.readerFontSize = 17,
  });

  bool get isDarkMode {
    return switch (themeMode) {
      AppThemeMode.system =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark,
      AppThemeMode.light => false,
      AppThemeMode.dark => true,
    };
  }

  DevicePreferences copyWith({
    AppThemeMode? themeMode,
    bool? isSplitLayout,
    String? defaultFolderPath,
    double? readerFontSize,
  }) {
    return DevicePreferences(
      themeMode: themeMode ?? this.themeMode,
      isSplitLayout: isSplitLayout ?? this.isSplitLayout,
      defaultFolderPath: defaultFolderPath ?? this.defaultFolderPath,
      readerFontSize: readerFontSize ?? this.readerFontSize,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DevicePreferences &&
        other.themeMode == themeMode &&
        other.isSplitLayout == isSplitLayout &&
        other.defaultFolderPath == defaultFolderPath &&
        other.readerFontSize == readerFontSize;
  }

  @override
  int get hashCode =>
      Object.hash(themeMode, isSplitLayout, defaultFolderPath, readerFontSize);

  @override
  String toString() {
    return 'DevicePreferences(themeMode: $themeMode, isSplitLayout: $isSplitLayout, defaultFolderPath: $defaultFolderPath, readerFontSize: $readerFontSize)';
  }
}

class DevicePreferenceNotifier extends ValueNotifier<DevicePreferences> {
  static late final SharedPreferencesWithCache _prefs;
  DevicePreferenceNotifier() : super(DevicePreferences());

  Future<void> loadDevicePreferences() async {
    _prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    );
    final themeMode = _loadThemeMode();
    final isSplitLayout =
        _prefs.getBool(_SharedPreferencesKeys.isSplitLayout.name) ?? true;
    final defaultFolderPath = _prefs.getString(
      _SharedPreferencesKeys.defaultFolderPath.name,
    );
    final readerFontSize =
        _prefs.getDouble(_SharedPreferencesKeys.readerFontSize.name) ?? 17;
    value = DevicePreferences(
      themeMode: themeMode,
      isSplitLayout: isSplitLayout,
      defaultFolderPath: defaultFolderPath,
      readerFontSize: readerFontSize,
    );
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    final nextMode = value.isDarkMode ? AppThemeMode.light : AppThemeMode.dark;
    await setThemeMode(nextMode);
  }

  Future<void> setThemeMode(AppThemeMode themeMode) async {
    value = value.copyWith(themeMode: themeMode);
    await _prefs.setString(
      _SharedPreferencesKeys.themeMode.name,
      themeMode.name,
    );
    notifyListeners();
  }

  Future<void> setDarkMode(bool isDarkMode) async {
    await setThemeMode(isDarkMode ? AppThemeMode.dark : AppThemeMode.light);
  }

  Future<void> toggleLayout() async {
    value = value.copyWith(isSplitLayout: !value.isSplitLayout);
    await _prefs.setBool(
      _SharedPreferencesKeys.isSplitLayout.name,
      value.isSplitLayout,
    );
    notifyListeners();
  }

  Future<void> setDefaultFolderPath(String path) async {
    value = value.copyWith(defaultFolderPath: path);
    await _prefs.setString(_SharedPreferencesKeys.defaultFolderPath.name, path);
    notifyListeners();
  }

  Future<void> setReaderFontSize(double fontSize) async {
    value = value.copyWith(readerFontSize: fontSize);
    await _prefs.setDouble(
      _SharedPreferencesKeys.readerFontSize.name,
      fontSize,
    );
    notifyListeners();
  }

  AppThemeMode _loadThemeMode() {
    final themeModeName = _prefs.getString(
      _SharedPreferencesKeys.themeMode.name,
    );
    if (themeModeName != null) {
      for (final mode in AppThemeMode.values) {
        if (mode.name == themeModeName) {
          return mode;
        }
      }
    }
    final legacyDarkMode = _prefs.getBool(
      _SharedPreferencesKeys.isDarkMode.name,
    );
    if (legacyDarkMode != null) {
      return legacyDarkMode ? AppThemeMode.dark : AppThemeMode.light;
    }
    return AppThemeMode.system;
  }
}
