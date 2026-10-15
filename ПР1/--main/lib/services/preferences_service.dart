import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const _themeKey = 'theme_mode';
  static const _fromKey = 'converter_from';
  static const _toKey = 'converter_to';

  Future<ThemeMode> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_themeKey);
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await prefs.setString(_themeKey, value);
  }

  Future<(String from, String to)?> loadConverterPair() async {
    final prefs = await SharedPreferences.getInstance();
    final from = prefs.getString(_fromKey);
    final to = prefs.getString(_toKey);
    if (from == null || to == null) return null;
    return (from, to);
  }

  Future<void> saveConverterPair(String from, String to) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fromKey, from);
    await prefs.setString(_toKey, to);
  }
}
