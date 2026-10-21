import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/entity.dart';

/// Хранилище коллекций между перезагрузками страницы.
///
/// На web shared_preferences пишет в localStorage. Каждая коллекция лежит
/// под своим ключом с суффиксом версии формата: movies_v2, viewers_v2…
class LocalStore {
  LocalStore(this._prefs);

  static const schemaVersion = 2;
  static const versionKey = 'kinoteka_schema';
  static const legacyMoviesKey = 'movies_v1';

  final SharedPreferences _prefs;

  /// Сообщения для пользователя: миграция или сброс испорченных данных.
  final List<String> notices = [];

  /// Приводит данные в хранилище к текущей версии формата.
  ///
  /// Версия 1 (до ПР3) хранила фильмы под ключом movies_v1 без номера
  /// прокатного удостоверения. Такие записи не теряются: им присваивается
  /// номер, и они переносятся под новый ключ.
  Future<void> migrate() async {
    final version = _prefs.getInt(versionKey) ?? 1;
    if (version >= schemaVersion) return;

    final legacy = _prefs.getString(legacyMoviesKey);
    if (legacy != null) {
      try {
        final list = (jsonDecode(legacy) as List).map((e) {
          final map = Map<String, dynamic>.from(e as Map);
          final id = jsonInt(map['id']);
          map['licenseNumber'] ??= '1219${id.toString().padLeft(5, '0')}';
          return map;
        }).toList();
        await _prefs.setString('movies_v$schemaVersion', jsonEncode(list));
        notices.add('Данные из прошлой версии приложения перенесены в формат v$schemaVersion: '
            'фильмов — ${list.length}, им присвоены номера прокатных удостоверений.');
      } catch (_) {
        notices.add('Сохранённые данные прошлой версии не удалось прочитать — '
            'фильмы загружены из начального набора.');
      }
      await _prefs.remove(legacyMoviesKey);
    }
    await _prefs.setInt(versionKey, schemaVersion);
  }

  /// Читает коллекцию. Первый запуск — записывает начальный набор;
  /// испорченные данные заменяются начальным набором без падения приложения.
  List<T> load<T extends Entity>(
    String name,
    String label,
    T Function(Map<String, dynamic>) fromJson,
    List<T> seed,
  ) {
    final key = '${name}_v$schemaVersion';
    final raw = _prefs.getString(key);
    if (raw == null) {
      save(name, seed);
      return [...seed];
    }
    try {
      return (jsonDecode(raw) as List)
          .map((e) => fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      notices.add('Данные раздела «$label» повреждены — восстановлен начальный набор.');
      save(name, seed);
      return [...seed];
    }
  }

  Future<void> save(String name, List<Entity> items) =>
      _prefs.setString('${name}_v$schemaVersion', jsonEncode(items.map((e) => e.toJson()).toList()));
}
