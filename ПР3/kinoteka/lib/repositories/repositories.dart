import '../data/seed_data.dart';
import '../models/director.dart';
import '../models/director_query.dart';
import '../models/genre.dart';
import '../models/movie.dart';
import '../models/movie_query.dart';
import '../models/simple_query.dart';
import '../models/studio.dart';
import '../models/viewer.dart';
import 'entity_repository.dart';
import 'persistent_repository.dart';

class PersistentMovieRepository extends PersistentRepository<Movie, MovieQuery>
    implements MovieRepository {
  PersistentMovieRepository(super.store, super.network);

  @override
  String get collection => 'movies';
  @override
  String get label => 'Фильмы';
  @override
  List<Movie> get seed => seedMovies;
  @override
  Movie fromJson(Map<String, dynamic> json) => Movie.fromJson(json);
  @override
  Movie withId(Movie item, int id) => item.copyWith(id: id);
  @override
  Movie withDeletedAt(Movie item, DateTime? at) =>
      at == null ? item.copyWith(clearDeletedAt: true) : item.copyWith(deletedAt: at);

  @override
  bool matchesSearch(Movie m, String needle) =>
      m.title.toLowerCase().contains(needle) ||
      m.originalTitle.toLowerCase().contains(needle) ||
      m.licenseNumber.contains(needle);

  @override
  bool matchesFilters(Movie m, MovieQuery q) =>
      (q.genreId == null || m.genreIds.contains(q.genreId)) &&
      (q.studioId == null || m.studioId == q.studioId) &&
      (q.yearFrom == null || m.year >= q.yearFrom!) &&
      (q.yearTo == null || m.year <= q.yearTo!);

  @override
  Comparable sortKey(Movie m, String field) => switch (field) {
        'year' => m.year,
        'duration' => m.duration,
        'rating' => m.rating,
        _ => lower(m.title),
      };

  @override
  Future<bool> licenseTaken(String number, {int? exceptId}) async =>
      items.any((m) => m.licenseNumber == number.trim() && m.id != exceptId);

  @override
  Future<List<Movie>> findByDirector(int directorId) async =>
      (await findAll()).where((m) => m.directorIds.contains(directorId)).toList()
        ..sort((a, b) => a.year.compareTo(b.year));
}

class PersistentDirectorRepository extends PersistentRepository<Director, DirectorQuery> {
  PersistentDirectorRepository(super.store, super.network);

  @override
  String get collection => 'directors';
  @override
  String get label => 'Режиссёры';
  @override
  List<Director> get seed => seedDirectors;
  @override
  Director fromJson(Map<String, dynamic> json) => Director.fromJson(json);
  @override
  Director withId(Director item, int id) => item.copyWith(id: id);
  @override
  Director withDeletedAt(Director item, DateTime? at) =>
      at == null ? item.copyWith(clearDeletedAt: true) : item.copyWith(deletedAt: at);

  @override
  bool matchesSearch(Director d, String needle) =>
      d.lastName.toLowerCase().contains(needle) || d.country.toLowerCase().contains(needle);

  @override
  bool matchesFilters(Director d, DirectorQuery q) => q.country == null || d.country == q.country;

  @override
  Comparable sortKey(Director d, String field) => switch (field) {
        'firstName' => lower(d.firstName),
        'birthYear' => d.birthYear,
        'country' => lower(d.country),
        _ => lower(d.lastName),
      };
}

class PersistentGenreRepository extends PersistentRepository<Genre, SimpleQuery>
    implements GenreRepository {
  PersistentGenreRepository(super.store, super.network);

  @override
  String get collection => 'genres';
  @override
  String get label => 'Жанры';
  @override
  List<Genre> get seed => seedGenres;
  @override
  Genre fromJson(Map<String, dynamic> json) => Genre.fromJson(json);
  @override
  Genre withId(Genre item, int id) => item.copyWith(id: id);
  @override
  Genre withDeletedAt(Genre item, DateTime? at) =>
      at == null ? item.copyWith(clearDeletedAt: true) : item.copyWith(deletedAt: at);

  @override
  bool matchesSearch(Genre g, String needle) =>
      g.name.toLowerCase().contains(needle) || g.description.toLowerCase().contains(needle);

  @override
  bool matchesFilters(Genre g, SimpleQuery q) =>
      q.filter('category') == null || g.category == q.filter('category');

  @override
  Comparable sortKey(Genre g, String field) =>
      field == 'category' ? lower('${g.category} ${g.name}') : lower(g.name);

  @override
  Future<bool> nameTaken(String name, {int? exceptId}) async => items
      .any((g) => g.name.toLowerCase() == name.trim().toLowerCase() && g.id != exceptId);
}

class PersistentStudioRepository extends PersistentRepository<Studio, SimpleQuery> {
  PersistentStudioRepository(super.store, super.network);

  @override
  String get collection => 'studios';
  @override
  String get label => 'Киностудии';
  @override
  List<Studio> get seed => seedStudios;
  @override
  Studio fromJson(Map<String, dynamic> json) => Studio.fromJson(json);
  @override
  Studio withId(Studio item, int id) => item.copyWith(id: id);
  @override
  Studio withDeletedAt(Studio item, DateTime? at) =>
      at == null ? item.copyWith(clearDeletedAt: true) : item.copyWith(deletedAt: at);

  @override
  bool matchesSearch(Studio s, String needle) =>
      s.name.toLowerCase().contains(needle) || s.country.toLowerCase().contains(needle);

  @override
  bool matchesFilters(Studio s, SimpleQuery q) =>
      q.filter('country') == null || s.country == q.filter('country');

  @override
  Comparable sortKey(Studio s, String field) => switch (field) {
        'country' => lower('${s.country} ${s.name}'),
        'foundedYear' => s.foundedYear,
        _ => lower(s.name),
      };
}

class PersistentViewerRepository extends PersistentRepository<Viewer, SimpleQuery>
    implements ViewerRepository {
  PersistentViewerRepository(super.store, super.network);

  @override
  String get collection => 'viewers';
  @override
  String get label => 'Зрители';
  @override
  List<Viewer> get seed => seedViewers;
  @override
  Viewer fromJson(Map<String, dynamic> json) => Viewer.fromJson(json);
  @override
  Viewer withId(Viewer item, int id) => item.copyWith(id: id);
  @override
  Viewer withDeletedAt(Viewer item, DateTime? at) =>
      at == null ? item.copyWith(clearDeletedAt: true) : item.copyWith(deletedAt: at);

  @override
  bool matchesSearch(Viewer v, String needle) =>
      v.lastName.toLowerCase().contains(needle) ||
      v.email.toLowerCase().contains(needle) ||
      v.card.number.toLowerCase().contains(needle);

  @override
  bool matchesFilters(Viewer v, SimpleQuery q) =>
      q.filter('tariff') == null || v.card.tariff == q.filter('tariff');

  @override
  Comparable sortKey(Viewer v, String field) => switch (field) {
        'firstName' => lower(v.firstName),
        'email' => lower(v.email),
        'visitsLeft' => v.card.visitsLeft,
        _ => lower(v.lastName),
      };

  @override
  Future<bool> emailTaken(String email, {int? exceptId}) async => items.any(
      (v) => v.email.toLowerCase() == email.trim().toLowerCase() && v.id != exceptId);

  @override
  Future<bool> cardTaken(String number, {int? exceptId}) async => items.any(
      (v) => v.card.number.toUpperCase() == number.trim().toUpperCase() && v.id != exceptId);
}
