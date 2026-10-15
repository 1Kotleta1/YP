import '../data/seed_data.dart';
import '../models/director.dart';
import '../models/director_query.dart';
import '../models/page_result.dart';
import '../services/network_simulator.dart';
import 'director_repository.dart';

class InMemoryDirectorRepository implements DirectorRepository {
  InMemoryDirectorRepository(this._network);

  final NetworkSimulator _network;
  final List<Director> _directors = [...seedDirectors];

  @override
  Future<PageResult<Director>> find(DirectorQuery q) async {
    await _network();

    var rows =
        _directors.where((d) => q.includeDeleted || !d.isDeleted).toList();

    if (q.search.trim().isNotEmpty) {
      final needle = q.search.trim().toLowerCase();
      rows = rows
          .where((d) =>
              d.lastName.toLowerCase().contains(needle) ||
              d.country.toLowerCase().contains(needle))
          .toList();
    }
    if (q.country != null) {
      rows = rows.where((d) => d.country == q.country).toList();
    }

    rows.sort((a, b) {
      final result = switch (q.sortField) {
        'firstName' => a.firstName.compareTo(b.firstName),
        'birthYear' => a.birthYear.compareTo(b.birthYear),
        'country' => a.country.compareTo(b.country),
        _ => a.lastName.compareTo(b.lastName),
      };
      return q.sortAscending ? result : -result;
    });

    return PageResult.slice(rows, q.page, q.size);
  }

  @override
  Future<Director?> findById(int id) async {
    await _network();
    for (final d in _directors) {
      if (d.id == id) return d;
    }
    return null;
  }

  @override
  Future<List<Director>> findByIds(List<int> ids) async {
    await _network();
    return _directors.where((d) => ids.contains(d.id)).toList();
  }

  @override
  Future<List<String>> countries() async {
    return _directors.map((d) => d.country).toSet().toList()..sort();
  }

  @override
  Future<void> softDelete(int id) async {
    await _network();
    final i = _indexOf(id);
    _directors[i] = _directors[i].copyWith(deletedAt: DateTime.now());
  }

  @override
  Future<void> hardDelete(int id) async {
    await _network();
    _directors.removeWhere((d) => d.id == id);
  }

  @override
  Future<void> restore(int id) async {
    await _network();
    final i = _indexOf(id);
    _directors[i] = _directors[i].copyWith(clearDeletedAt: true);
  }

  @override
  Future<int> deleteMany(List<int> ids) async {
    await _network();
    var count = 0;
    for (final id in ids) {
      final i = _directors.indexWhere((d) => d.id == id && !d.isDeleted);
      if (i != -1) {
        _directors[i] = _directors[i].copyWith(deletedAt: DateTime.now());
        count++;
      }
    }
    return count;
  }

  @override
  Future<int> hardDeleteMany(List<int> ids) async {
    await _network();
    final before = _directors.length;
    final set = ids.toSet();
    _directors.removeWhere((d) => set.contains(d.id));
    return before - _directors.length;
  }

  int _indexOf(int id) {
    final i = _directors.indexWhere((d) => d.id == id);
    if (i == -1) throw StateError('Режиссёр $id не найден');
    return i;
  }
}
