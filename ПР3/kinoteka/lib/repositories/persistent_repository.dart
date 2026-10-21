import '../models/entity.dart';
import '../models/list_query.dart';
import '../models/page_result.dart';
import '../services/local_store.dart';
import '../services/network_simulator.dart';
import 'entity_repository.dart';

/// Общая реализация репозитория поверх [LocalStore].
///
/// Наследник описывает только особенности сущности: как разобрать запись,
/// по каким полям искать, фильтровать и сортировать.
abstract class PersistentRepository<T extends Entity, Q extends ListQuery>
    implements EntityRepository<T, Q> {
  PersistentRepository(this._store, this._network) {
    _items = _store.load(collection, label, fromJson, seed);
    _nextId = _items.fold(0, (m, e) => e.id > m ? e.id : m) + 1;
  }

  final LocalStore _store;
  final NetworkSimulator _network;
  late List<T> _items;
  late int _nextId;

  String get collection;
  String get label;
  List<T> get seed;
  T fromJson(Map<String, dynamic> json);
  T withId(T item, int id);
  T withDeletedAt(T item, DateTime? at);
  bool matchesSearch(T item, String needle);
  bool matchesFilters(T item, Q query);
  Comparable sortKey(T item, String field);

  /// Синхронный доступ для проверок уникальности в наследниках.
  Iterable<T> get items => _items;

  Future<void> _persist() => _store.save(collection, _items);

  @override
  Future<PageResult<T>> find(Q q) async {
    await _network();
    var rows = _items.where((e) => q.includeDeleted || !e.isDeleted);
    final needle = q.search.trim().toLowerCase();
    if (needle.isNotEmpty) rows = rows.where((e) => matchesSearch(e, needle));
    final list = rows.where((e) => matchesFilters(e, q)).toList()
      ..sort((a, b) {
        final r = sortKey(a, q.sortField).compareTo(sortKey(b, q.sortField));
        return q.sortAscending ? r : -r;
      });
    return PageResult.slice(list, q.page, q.size);
  }

  @override
  Future<T?> findById(int id) async {
    await _network();
    for (final e in _items) {
      if (e.id == id) return e;
    }
    return null;
  }

  @override
  Future<List<T>> findAll({bool includeDeleted = false}) async {
    await _network();
    return _items.where((e) => includeDeleted || !e.isDeleted).toList();
  }

  @override
  Future<T> create(T item) async {
    await _network();
    final created = withId(item, _nextId++);
    _items.add(created);
    await _persist();
    return created;
  }

  @override
  Future<T> update(T item) async {
    await _network();
    _items[_indexOf(item.id)] = item;
    await _persist();
    return item;
  }

  @override
  Future<void> softDelete(int id) async {
    await _network();
    final i = _indexOf(id);
    _items[i] = withDeletedAt(_items[i], DateTime.now());
    await _persist();
  }

  @override
  Future<void> hardDelete(int id) async {
    await _network();
    _items.removeWhere((e) => e.id == id);
    await _persist();
  }

  @override
  Future<void> restore(int id) async {
    await _network();
    final i = _indexOf(id);
    _items[i] = withDeletedAt(_items[i], null);
    await _persist();
  }

  @override
  Future<int> deleteMany(List<int> ids) async {
    await _network();
    var count = 0;
    for (final id in ids.toSet()) {
      final i = _items.indexWhere((e) => e.id == id && !e.isDeleted);
      if (i != -1) {
        _items[i] = withDeletedAt(_items[i], DateTime.now());
        count++;
      }
    }
    await _persist();
    return count;
  }

  @override
  Future<int> hardDeleteMany(List<int> ids) async {
    await _network();
    final before = _items.length;
    final set = ids.toSet();
    _items.removeWhere((e) => set.contains(e.id));
    await _persist();
    return before - _items.length;
  }

  int _indexOf(int id) {
    final i = _items.indexWhere((e) => e.id == id);
    if (i == -1) throw StateError('Запись $id не найдена');
    return i;
  }
}

/// Строки сравниваются без учёта регистра.
Comparable lower(String s) => s.toLowerCase();
