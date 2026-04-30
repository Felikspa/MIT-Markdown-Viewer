import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _SharedPreferencesKeys {
  isDarkMode,
  isSplitLayout,
  defaultFolderPath,
  readerFontSize,
}

class DevicePreferences {
  final bool isDarkMode;
  final bool isSplitLayout;
  final String? defaultFolderPath;
  final double readerFontSize;

  DevicePreferences({
    this.isDarkMode = false,
    this.isSplitLayout = false,
    this.defaultFolderPath,
    this.readerFontSize = 17,
  });

  DevicePreferences copyWith({
    bool? isDarkMode,
    bool? isSplitLayout,
    String? defaultFolderPath,
    double? readerFontSize,
  }) {
    return DevicePreferences(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      isSplitLayout: isSplitLayout ?? this.isSplitLayout,
      defaultFolderPath: defaultFolderPath ?? this.defaultFolderPath,
      readerFontSize: readerFontSize ?? this.readerFontSize,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DevicePreferences &&
        other.isDarkMode == isDarkMode &&
        other.isSplitLayout == isSplitLayout &&
        other.defaultFolderPath == defaultFolderPath &&
        other.readerFontSize == readerFontSize;
  }

  @override
  int get hashCode =>
      Object.hash(isDarkMode, isSplitLayout, defaultFolderPath, readerFontSize);

  @override
  String toString() {
    return 'DevicePreferences(isDarkMode: $isDarkMode, isSplitLayout: $isSplitLayout, defaultFolderPath: $defaultFolderPath, readerFontSize: $readerFontSize)';
  }
}

class DevicePreferenceNotifier extends ValueNotifier<DevicePreferences> {
  static late final SharedPreferencesWithCache _prefs;
  DevicePreferenceNotifier() : super(DevicePreferences());

  Future<void> loadDevicePreferences() async {
    _prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    );
    final isDarkMode =
        _prefs.getBool(_SharedPreferencesKeys.isDarkMode.name) ??
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
    final isSplitLayout =
        _prefs.getBool(_SharedPreferencesKeys.isSplitLayout.name) ?? true;
    final defaultFolderPath = _prefs.getString(
      _SharedPreferencesKeys.defaultFolderPath.name,
    );
    final readerFontSize =
        _prefs.getDouble(_SharedPreferencesKeys.readerFontSize.name) ?? 17;
    value = DevicePreferences(
      isDarkMode: isDarkMode,
      isSplitLayout: isSplitLayout,
      defaultFolderPath: defaultFolderPath,
      readerFontSize: readerFontSize,
    );
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    value = value.copyWith(isDarkMode: !value.isDarkMode);
    await _prefs.setBool(
      _SharedPreferencesKeys.isDarkMode.name,
      value.isDarkMode,
    );
    notifyListeners();
  }

  Future<void> setDarkMode(bool isDarkMode) async {
    value = value.copyWith(isDarkMode: isDarkMode);
    await _prefs.setBool(_SharedPreferencesKeys.isDarkMode.name, isDarkMode);
    notifyListeners();
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
}
