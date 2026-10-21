import 'package:flutter/foundation.dart';

import '../models/director.dart';
import '../models/genre.dart';
import '../models/movie.dart';
import '../models/studio.dart';
import '../repositories/entity_repository.dart';

/// Справочные данные для выпадающих списков и подписей.
///
/// Берутся из репозиториев, а не из констант: новый жанр или студия сразу
/// появляются в фильтрах и формах.
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
  bool _loaded = false;

  bool get loaded => _loaded;

  /// Для форм — только записи не из корзины.
  List<Genre> get genres => _allGenres.where((g) => !g.isDeleted).toList();
  List<Studio> get studios => _allStudios.where((s) => !s.isDeleted).toList();
  List<Director> get directors => _allDirectors.where((d) => !d.isDeleted).toList()
    ..sort((a, b) => a.lastName.compareTo(b.lastName));

  List<String> get directorCountries => _allDirectors.map((d) => d.country).toSet().toList()..sort();
  List<String> get studioCountries => _allStudios.map((s) => s.country).toSet().toList()..sort();

  /// Каскад в форме фильма: режиссёры, уже снимавшие на этой студии.
  Set<int> directorsOfStudio(int studioId) => _directorsByStudio[studioId] ?? const {};

  String genreName(int id) => _name(_allGenres.where((g) => g.id == id).map((g) => g.name));
  String studioName(int id) => _name(_allStudios.where((s) => s.id == id).map((s) => s.name));
  String directorName(int id) =>
      _name(_allDirectors.where((d) => d.id == id).map((d) => d.fullName));

  String _name(Iterable<String> found) => found.isEmpty ? '—' : found.first;

  Future<void> load() async {
    final results = await Future.wait([
      _genres.findAll(includeDeleted: true),
      _studios.findAll(includeDeleted: true),
      _directors.findAll(includeDeleted: true),
      _movies.findAll(),
    ]);
    _allGenres = (results[0] as List<Genre>)..sort((a, b) => a.name.compareTo(b.name));
    _allStudios = (results[1] as List<Studio>)..sort((a, b) => a.name.compareTo(b.name));
    _allDirectors = results[2] as List<Director>;
    final byStudio = <int, Set<int>>{};
    for (final m in results[3] as List<Movie>) {
      byStudio.putIfAbsent(m.studioId, () => {}).addAll(m.directorIds);
    }
    _directorsByStudio = byStudio;
    _loaded = true;
    notifyListeners();
  }
}
