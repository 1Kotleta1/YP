import '../data/seed_data.dart';
import '../models/movie.dart';
import '../models/movie_query.dart';
import '../models/page_result.dart';
import '../services/network_simulator.dart';
import 'movie_repository.dart';

class InMemoryMovieRepository implements MovieRepository {
  InMemoryMovieRepository(this._network);

  final NetworkSimulator _network;
  final List<Movie> _movies = [...seedMovies];
  int _nextId = seedMovies.length + 1;

  @override
  Future<PageResult<Movie>> find(MovieQuery q) async {
    await _network();

    var rows = _movies.where((m) => q.includeDeleted || !m.isDeleted).toList();

    if (q.search.trim().isNotEmpty) {
      final needle = q.search.trim().toLowerCase();
      rows = rows
          .where((m) =>
              m.title.toLowerCase().contains(needle) ||
              m.originalTitle.toLowerCase().contains(needle))
          .toList();
    }

    if (q.genreId != null) {
      rows = rows.where((m) => m.genreIds.contains(q.genreId)).toList();
    }
    if (q.studioId != null) {
      rows = rows.where((m) => m.studioId == q.studioId).toList();
    }
    if (q.yearFrom != null) rows = rows.where((m) => m.year >= q.yearFrom!).toList();
    if (q.yearTo != null) rows = rows.where((m) => m.year <= q.yearTo!).toList();

    rows.sort((a, b) {
      final result = switch (q.sortField) {
        'year' => a.year.compareTo(b.year),
        'duration' => a.duration.compareTo(b.duration),
        'rating' => a.rating.compareTo(b.rating),
        _ => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      };
      return q.sortAscending ? result : -result;
    });

    return PageResult.slice(rows, q.page, q.size);
  }

  @override
  Future<Movie?> findById(int id) async {
    await _network();
    for (final m in _movies) {
      if (m.id == id) return m;
    }
    return null;
  }

  @override
  Future<List<Movie>> findByDirector(int directorId) async {
    await _network();
    return _movies
        .where((m) => !m.isDeleted && m.directorIds.contains(directorId))
        .toList()
      ..sort((a, b) => a.year.compareTo(b.year));
  }

  @override
  Future<Movie> create(Movie movie) async {
    await _network();
    final created = Movie(
      id: _nextId++,
      title: movie.title,
      originalTitle: movie.originalTitle,
      year: movie.year,
      duration: movie.duration,
      rating: movie.rating,
      studioId: movie.studioId,
      directorIds: movie.directorIds,
      genreIds: movie.genreIds,
    );
    _movies.add(created);
    return created;
  }

  @override
  Future<Movie> update(Movie movie) async {
    await _network();
    final i = _indexOf(movie.id);
    _movies[i] = movie;
    return movie;
  }

  @override
  Future<void> softDelete(int id) async {
    await _network();
    final i = _indexOf(id);
    _movies[i] = _movies[i].copyWith(deletedAt: DateTime.now());
  }

  @override
  Future<void> hardDelete(int id) async {
    await _network();
    _movies.removeWhere((m) => m.id == id);
  }

  @override
  Future<void> restore(int id) async {
    await _network();
    final i = _indexOf(id);
    _movies[i] = _movies[i].copyWith(clearDeletedAt: true);
  }

  @override
  Future<int> deleteMany(List<int> ids) async {
    await _network();
    var count = 0;
    for (final id in ids) {
      // Исправлено: в исходном варианте условие обращалось к b[i] —
      // к переменной i до её объявления и к фильму как к списку.
      final i = _movies.indexWhere((m) => m.id == id && !m.isDeleted);
      if (i != -1) {
        _movies[i] = _movies[i].copyWith(deletedAt: DateTime.now());
        count++;
      }
    }
    return count;
  }

  @override
  Future<int> hardDeleteMany(List<int> ids) async {
    await _network();
    final before = _movies.length;
    final set = ids.toSet();
    _movies.removeWhere((m) => set.contains(m.id));
    return before - _movies.length;
  }

  int _indexOf(int id) {
    final i = _movies.indexWhere((m) => m.id == id);
    if (i == -1) throw StateError('Фильм $id не найден');
    return i;
  }
}
