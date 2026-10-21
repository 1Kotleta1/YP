import 'package:flutter/material.dart';

import '../services/preferences_service.dart';

class ThemeController extends ChangeNotifier {
  ThemeController(this._prefs);

  final PreferencesService _prefs;
  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  Future<void> load() async {
    _mode = await _prefs.loadThemeMode();
    notifyListeners();
  }

  Future<void> toggleLightDark() async {
    _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await _prefs.saveThemeMode(_mode);
    notifyListeners();
  }
}
