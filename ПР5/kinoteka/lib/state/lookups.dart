import 'package:flutter/foundation.dart';

import '../models/director.dart';
import '../models/genre.dart';
import '../models/studio.dart';
import '../repositories/entity_repository.dart';
import 'paged_list_notifier.dart' show LoadStatus;

/// Какую часть справочников нужно перечитать после изменения данных.
enum LookupPart { genres, studios, directors, cascade }

/// Кэш справочников для выпадающих списков, фильтров и подписей.
///
/// Жанры, студии и режиссёры запрашиваются с сервера один раз и не
/// перезагружаются при каждом открытии формы. Перечитывается только та
/// часть, которую изменил пользователь: сохранили жанр — заново
/// загружаются жанры, остальное берётся из кэша.
class Lookups extends ChangeNotifier {
  Lookups(this._movies, this._directors, this._genres, this._studios);

  final MovieRepository _movies;
  final DirectorRepository _directors;
  final GenreRepository _genres;
  final StudioRepository _studios;

  List<Genre> _allGenres = const [];
  List<Studio> _allStudios = const [];
  List<Director> _allDirectors = const [];
  Map<int, Set<int>> _directorsByStudio = const {};
  LoadStatus _status = LoadStatus.idle;
  String? _error;
  Future<void>? _loading;

  /// Сколько раз справочники запрашивались с сервера — для проверки кэша.
  int requests = 0;

  LoadStatus get status => _status;
  String? get error => _error;
  bool get loaded => _status == LoadStatus.success;

  /// Для форм — только записи не из корзины.
  List<Genre> get genres => _allGenres.where((g) => !g.isDeleted).toList();
  List<Studio> get studios => _allStudios.where((s) => !s.isDeleted).toList();
  List<Director> get directors => _allDirectors.where((d) => !d.isDeleted).toList()
    ..sort((a, b) => a.lastName.compareTo(b.lastName));

  List<String> get directorCountries => _allDirectors.map((d) => d.country).toSet().toList()..sort();
  List<String> get studioCountries => _allStudios.map((s) => s.country).toSet().toList()..sort();

  /// Каскад в форме фильма: режиссёры, уже снимавшие на этой студии.
  Set<int> directorsOfStudio(int studioId) => _directorsByStudio[studioId] ?? const {};

  Director? director(int id) {
    for (final d in _allDirectors) {
      if (d.id == id) return d;
    }
    return null;
  }

  String genreName(int id) => _name(_allGenres.where((g) => g.id == id).map((g) => g.name));
  String studioName(int id) => _name(_allStudios.where((s) => s.id == id).map((s) => s.name));
  String directorName(int id) => director(id)?.fullName ?? '—';

  String _name(Iterable<String> found) => found.isEmpty ? '—' : found.first;

  /// Загрузить, если ещё не загружено. Повторный вызов во время загрузки
  /// не создаёт новых запросов, а ждёт уже начатую.
  Future<void> ensureLoaded() {
    if (loaded) return Future.value();
    return _loading ??= load();
  }

  /// Полная загрузка всех справочников (первый запуск, повтор после ошибки).
  Future<void> load() async {
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();
    try {
      await Future.wait(LookupPart.values.map(_fetch));
      _status = LoadStatus.success;
    } catch (e) {
      _error = 'Не удалось загрузить справочники: $e';
      _status = LoadStatus.error;
    } finally {
      _loading = null;
    }
    notifyListeners();
  }

  /// Сброс кэша при смене пользователя: следующий получит справочники заново.
  void reset() {
    _allGenres = const [];
    _allStudios = const [];
    _allDirectors = const [];
    _directorsByStudio = const {};
    _status = LoadStatus.idle;
    _error = null;
    notifyListeners();
  }

  /// Перечитать только изменённую часть кэша.
  Future<void> invalidate(LookupPart part) async {
    if (!loaded) return; // ещё не загружались — загрузятся целиком при первом обращении
    try {
      await _fetch(part);
      notifyListeners();
    } catch (_) {
      // Старые значения остаются в кэше; список при этом уже обновлён
    }
  }

  Future<void> _fetch(LookupPart part) async {
    requests++;
    switch (part) {
      case LookupPart.genres:
        _allGenres = (await _genres.findAll(includeDeleted: true))..sort((a, b) => a.name.compareTo(b.name));
      case LookupPart.studios:
        _allStudios = (await _studios.findAll(includeDeleted: true))..sort((a, b) => a.name.compareTo(b.name));
      case LookupPart.directors:
        _allDirectors = await _directors.findAll(includeDeleted: true);
      case LookupPart.cascade:
        _directorsByStudio = await _movies.studioDirectors();
    }
  }
}
