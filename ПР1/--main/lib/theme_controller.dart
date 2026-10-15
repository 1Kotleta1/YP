import 'package:flutter/material.dart';

import 'services/preferences_service.dart';

class ThemeController extends ChangeNotifier {
  ThemeController(this._prefs);

  final PreferencesService _prefs;
  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  Future<void> load() async {
    _mode = await _prefs.loadThemeMode();
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    await _prefs.saveThemeMode(mode);
    notifyListeners();
  }

  Future<void> toggleLightDark() async {
    final next = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setMode(next);
  }
}
