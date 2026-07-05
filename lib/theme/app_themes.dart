import 'package:flutter/material.dart';

enum AppThemeMode { light, dark, grey, claudeish }

ThemeData getTheme(AppThemeMode mode) {
  switch (mode) {
    case AppThemeMode.light:
      return ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.light),
        useMaterial3: true,
      );
    case AppThemeMode.dark:
      return ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
        useMaterial3: true,
      );
    case AppThemeMode.grey:
      return ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey, brightness: Brightness.dark),
        scaffoldBackgroundColor: const Color(0xFF2B2B2E),
        useMaterial3: true,
      );
    case AppThemeMode.claudeish:
      return ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFCC785C), brightness: Brightness.light),
        scaffoldBackgroundColor: const Color(0xFFF5F0E8),
        useMaterial3: true,
      );
  }
}

String themeName(AppThemeMode mode) {
  switch (mode) {
    case AppThemeMode.light: return 'Light';
    case AppThemeMode.dark: return 'Dark';
    case AppThemeMode.grey: return 'Grey';
    case AppThemeMode.claudeish: return 'Claude-ish';
  }
}