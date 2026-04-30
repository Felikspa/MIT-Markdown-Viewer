import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:markdown_editor/device_preference_notifier.dart';
import 'package:markdown_editor/home.dart';
import 'package:markdown_editor/l10n/generated/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      statusBarColor: Colors.transparent,
    ),
  );
  final DevicePreferenceNotifier devicePreferenceNotifier =
      DevicePreferenceNotifier();
  await devicePreferenceNotifier.loadDevicePreferences();

  runApp(MarkdownEditorApp(devicePreferenceNotifier: devicePreferenceNotifier));
}

class MarkdownEditorApp extends StatelessWidget {
  final DevicePreferenceNotifier devicePreferenceNotifier;
  const MarkdownEditorApp({super.key, required this.devicePreferenceNotifier});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DevicePreferences>(
      valueListenable: devicePreferenceNotifier,
      builder: (context, devicePreference, _) {
        return DynamicColorBuilder(
          builder: (lightDynamic, darkDynamic) {
            final lightScheme =
                lightDynamic ??
                ColorScheme.fromSeed(seedColor: const Color(0xFF2864A6));
            const darkScheme = ColorScheme(
              brightness: Brightness.dark,
              primary: Color(0xFF8AB4F8),
              onPrimary: Color(0xFF062A5A),
              secondary: Color(0xFF9BD8C0),
              onSecondary: Color(0xFF00382A),
              tertiary: Color(0xFFE0C27A),
              onTertiary: Color(0xFF3B2F00),
              error: Color(0xFFFFB4AB),
              onError: Color(0xFF690005),
              surface: Color(0xFF101214),
              onSurface: Color(0xFFE6E8EA),
              surfaceContainerLowest: Color(0xFF050506),
              surfaceContainerLow: Color(0xFF121417),
              surfaceContainer: Color(0xFF171A1D),
              surfaceContainerHigh: Color(0xFF202428),
              surfaceContainerHighest: Color(0xFF2A2F34),
              outline: Color(0xFF8A929B),
              outlineVariant: Color(0xFF3F464D),
              shadow: Color(0xFF000000),
              scrim: Color(0xFF000000),
              inverseSurface: Color(0xFFE6E8EA),
              onInverseSurface: Color(0xFF202428),
              inversePrimary: Color(0xFF1E5AA0),
            );
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'Markdown Reader',
              themeMode: devicePreference.isDarkMode
                  ? ThemeMode.dark
                  : ThemeMode.light,
              theme: ThemeData(
                useMaterial3: true,
                textTheme: GoogleFonts.notoSansTextTheme(),
                colorScheme: lightScheme,
                appBarTheme: AppBarTheme(
                  centerTitle: false,
                  backgroundColor: lightScheme.surface,
                  foregroundColor: lightScheme.onSurface,
                ),
              ),
              darkTheme: ThemeData(
                useMaterial3: true,
                textTheme: GoogleFonts.notoSansTextTheme(
                  ThemeData(brightness: Brightness.dark).textTheme,
                ),
                brightness: Brightness.dark,
                colorScheme: darkScheme,
                scaffoldBackgroundColor: darkScheme.surface,
                appBarTheme: const AppBarTheme(
                  centerTitle: false,
                  backgroundColor: Color(0xFF101214),
                  foregroundColor: Color(0xFFE6E8EA),
                  surfaceTintColor: Colors.transparent,
                ),
              ),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Home(devicePreferenceNotifier: devicePreferenceNotifier),
            );
          },
        );
      },
    );
  }
}
