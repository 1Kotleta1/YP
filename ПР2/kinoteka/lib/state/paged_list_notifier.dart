import 'package:flutter/foundation.dart';

import '../models/list_query.dart';
import '../models/page_result.dart';

enum LoadStatus { idle, loading, success, error }

/// Общее состояние экрана списка: условия отбора, текущая страница,
/// статус загрузки и набор выделенных записей.
///
/// Наследник лишь говорит, как достать страницу и как удалять записи —
/// вся остальная логика одинакова для фильмов и режиссёров.
abstract class PagedListNotifier<T, Q extends ListQuery> extends ChangeNotifier {
  PagedListNotifier(this._query);

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

  int idOf(T item);

  @protected
  Future<PageResult<T>> fetch(Q query);

  @protected
  Future<int> removeMany(List<int> ids, {required bool permanent});

  @protected
  Future<void> removeOne(int id, {required bool permanent});

  @protected
  Future<void> restoreOne(int id);

  Future<void> load() async {
    final request = ++_requestId;
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();

    try {
      final page = await fetch(_query);
      // Пока шёл запрос, условия могли смениться — старый ответ отбрасываем
      if (request != _requestId) return;
      _result = page;
      _status = LoadStatus.success;
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
    final count = await removeMany(_selected.toList(), permanent: permanent);
    _selected.clear();
    await load();
    return count;
  }

  Future<void> delete(int id, {bool permanent = false}) async {
    await removeOne(id, permanent: permanent);
    _selected.remove(id);
    await load();
  }

  Future<void> restore(int id) async {
    await restoreOne(id);
    await load();
  }
}
