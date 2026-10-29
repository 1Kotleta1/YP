import 'package:flutter/foundation.dart';

import '../models/director.dart';
import '../models/director_query.dart';
import '../models/entity.dart';
import '../models/genre.dart';
import '../models/list_query.dart';
import '../models/movie.dart';
import '../models/movie_query.dart';
import '../models/page_result.dart';
import '../models/simple_query.dart';
import '../models/studio.dart';
import '../models/viewer.dart';
import '../repositories/entity_repository.dart';

enum LoadStatus { idle, loading, success, error }

/// Состояние экрана списка любой сущности: условия отбора, текущая
/// страница, статус загрузки и набор выделенных записей.
///
/// В ПР4 класс не изменился по сути: поиск, фильтры и страницы теперь
/// выполняет сервер, но для состояния экрана это незаметно. Запреты
/// удаления приходят с сервера ответом 409 (ConflictException) и
/// доходят до виджета без перехвата здесь.
class PagedListNotifier<T extends Entity, Q extends ListQuery> extends ChangeNotifier {
  PagedListNotifier(this._repository, this._query, {this.onMutated, this.onLoaded});

  final EntityRepository<T, Q> _repository;

  /// Вызывается после любого изменения данных — например, чтобы обновить
  /// выпадающие списки в формах.
  final VoidCallback? onMutated;

  /// Вызывается после успешной загрузки — например, чтобы догрузить
  /// справочники, если при запуске сервер был недоступен.
  final VoidCallback? onLoaded;

  Q _query;
  PageResult<T> _result = PageResult.empty();
  LoadStatus _status = LoadStatus.idle;
  String? _error;
  final Set<int> _selected = {};
  int _requestId = 0;

  Q get query => _query;
  PageResult<T> get result => _result;
  LoadStatus get status => _status;
  String? get error => _error;
  Set<int> get selected => Set.unmodifiable(_selected);
  bool get hasSelection => _selected.isNotEmpty;

  /// Успешная загрузка, но записей нет — отдельное от «загружается» состояние.
  bool get isEmpty => _status == LoadStatus.success && _result.items.isEmpty;

  int idOf(T item) => item.id;

  Future<void> load() async {
    final request = ++_requestId;
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();

    try {
      final page = await _repository.find(_query);
      // Пока шёл запрос, условия могли смениться — старый ответ отбрасываем
      if (request != _requestId) return;
      _result = page;
      _status = LoadStatus.success;
      onLoaded?.call();
    } catch (e) {
      if (request != _requestId) return;
      _error = 'Не удалось загрузить список: $e';
      _status = LoadStatus.error;
    }
    notifyListeners();
  }

  /// Применяет условия из адреса. Повторный вызов с теми же условиями
  /// не перезапрашивает данные.
  Future<void> applyQuery(Q next) async {
    if (next == _query && _status != LoadStatus.idle && _status != LoadStatus.error) {
      return;
    }
    _query = next;
    _selected.clear(); // выделение теряет смысл при смене условий отбора
    await load();
  }

  /// Сброс при выходе из системы: данные одного пользователя
  /// не должны мелькнуть на экране у следующего.
  void reset(Q initial) {
    ++_requestId;
    _query = initial;
    _result = PageResult.empty();
    _status = LoadStatus.idle;
    _error = null;
    _selected.clear();
    notifyListeners();
  }

  /// Перечитать список, если он уже открывался (после правки в форме).
  Future<void> refresh() async {
    if (_status != LoadStatus.idle) await load();
  }

  void toggleSelection(int id) {
    _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
    notifyListeners();
  }

  /// Флажок в заголовке таблицы: выделить или снять всю текущую страницу.
  void setPageSelection(bool value) {
    final ids = _result.items.map(idOf);
    value ? _selected.addAll(ids) : _selected.removeAll(ids);
    notifyListeners();
  }

  void clearSelection() {
    _selected.clear();
    notifyListeners();
  }

  Future<int> deleteSelected({bool permanent = false}) async {
    final ids = _selected.toList();
    final count = permanent ? await _repository.hardDeleteMany(ids) : await _repository.deleteMany(ids);
    _selected.clear();
    await load();
    onMutated?.call();
    return count;
  }

  Future<void> delete(int id, {bool permanent = false}) async {
    permanent ? await _repository.hardDelete(id) : await _repository.softDelete(id);
    _selected.remove(id);
    await load();
    onMutated?.call();
  }

  Future<void> restore(int id) async {
    await _repository.restore(id);
    await load();
    onMutated?.call();
  }
}

typedef MovieListNotifier = PagedListNotifier<Movie, MovieQuery>;
typedef DirectorListNotifier = PagedListNotifier<Director, DirectorQuery>;
typedef GenreListNotifier = PagedListNotifier<Genre, SimpleQuery>;
typedef StudioListNotifier = PagedListNotifier<Studio, SimpleQuery>;
typedef ViewerListNotifier = PagedListNotifier<Viewer, SimpleQuery>;
