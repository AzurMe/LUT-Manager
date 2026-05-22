import 'package:flutter/material.dart';

import 'theme/codex_theme.dart';
import 'ui/lut_manager_home.dart';

void main() {
  runApp(const LutManagerApp());
}

class LutManagerApp extends StatefulWidget {
  const LutManagerApp({super.key});

  @override
  State<LutManagerApp> createState() => _LutManagerAppState();
}

class _LutManagerAppState extends State<LutManagerApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LUT Manager',
      theme: buildCodexTheme(Brightness.light),
      darkTheme: buildCodexTheme(Brightness.dark),
      themeMode: _themeMode,
      home: LutManagerHome(
        themeMode: _themeMode,
        onThemeModeChanged: (mode) => setState(() => _themeMode = mode),
      ),
    );
  }
}
