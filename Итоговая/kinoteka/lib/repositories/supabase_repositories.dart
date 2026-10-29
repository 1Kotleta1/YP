import '../core/api_exceptions.dart';
import '../models/director.dart';
import '../models/director_query.dart';
import '../models/entity.dart';
import '../models/genre.dart';
import '../models/movie.dart';
import '../models/movie_query.dart';
import '../models/simple_query.dart';
import '../models/studio.dart';
import '../models/viewer.dart';
import 'entity_repository.dart';
import 'supabase_repository.dart';

/// Фильмы читаются из представления movies_view: там к строке фильма
/// добавлены списки director_ids и genre_ids. Записываются функцией
/// save_movie — фильм и связи многие ко многим одной транзакцией.
class SupabaseMovieRepository extends SupabaseRepository<Movie, MovieQuery> implements MovieRepository {
  SupabaseMovieRepository(super.dio);

  @override
  String get table => 'movies';
  @override
  String get readFrom => 'movies_view';
  @override
  List<String> get searchColumns => const ['title', 'original_title', 'license_number'];

  @override
  Map<String, String> filtersFor(Map<String, String> filters) => movieFilters(
    genreId: filters['genreId'],
    studioId: filters['studioId'],
    directorId: filters['directorId'],
    yearFrom: filters['yearFrom'],
    yearTo: filters['yearTo'],
  );

  @override
  Movie fromJson(Map<String, dynamic> json) => Movie.fromJson(json);

  @override
  Future<Movie> create(Movie item) => _save(item, null);

  @override
  Future<Movie> update(Movie item) => _save(item, item.id);

  Future<Movie> _save(Movie item, int? id) => guard(() async {
    final row = await rpc(dio, 'save_movie', {
      'p': Map.of(item.toJson())
        ..remove('id')
        ..remove('deletedAt'),
      'p_id': id,
    });
    return fromRow(asMap(row));
  });

  @override
  Future<List<Movie>> findRelated({int? directorId, int? genreId, int? studioId}) => guard(() async {
    final response = await dio.get<dynamic>(
      '/rest/v1/$readFrom',
      queryParameters: {
        'select': '*',
        ...movieFilters(directorId: directorId, genreId: genreId, studioId: studioId),
        'deleted_at': 'is.null',
        'order': 'year.asc,id.asc',
        'limit': '100',
      },
    );
    return parseRows(response.data, fromRow);
  });

  @override
  Future<Map<int, Set<int>>> studioDirectors() => guard(() async {
    final data = await rpc(dio, 'studio_directors');
    return {for (final e in asMap(data).entries) jsonInt(e.key): jsonIntList(e.value).toSet()};
  });
}

/// Условия отбора фильмов. Связи многие ко многим — массивы в
/// представлении: cs.{3} означает «массив содержит 3».
Map<String, String> movieFilters({
  Object? genreId,
  Object? studioId,
  Object? directorId,
  Object? yearFrom,
  Object? yearTo,
}) {
  return {
    if (genreId != null) 'genre_ids': 'cs.{$genreId}',
    if (directorId != null) 'director_ids': 'cs.{$directorId}',
    if (studioId != null) 'studio_id': 'eq.$studioId',
    if (yearFrom != null || yearTo != null)
      'and': '(${[if (yearFrom != null) 'year.gte.$yearFrom', if (yearTo != null) 'year.lte.$yearTo'].join(',')})',
  };
}

class SupabaseDirectorRepository extends SupabaseRepository<Director, DirectorQuery> {
  SupabaseDirectorRepository(super.dio);

  @override
  String get table => 'directors';
  @override
  List<String> get searchColumns => const ['last_name', 'first_name', 'country'];
  @override
  Director fromJson(Map<String, dynamic> json) => Director.fromJson(json);
}

class SupabaseGenreRepository extends SupabaseRepository<Genre, SimpleQuery> {
  SupabaseGenreRepository(super.dio);

  @override
  String get table => 'genres';
  @override
  List<String> get searchColumns => const ['name', 'description'];
  @override
  String orderFor(String field, bool ascending) {
    final dir = ascending ? 'asc' : 'desc';
    // Категория, а внутри неё — по названию
    return field == 'category' ? 'category.$dir,name.$dir' : super.orderFor(field, ascending);
  }

  @override
  Genre fromJson(Map<String, dynamic> json) => Genre.fromJson(json);
}

class SupabaseStudioRepository extends SupabaseRepository<Studio, SimpleQuery> {
  SupabaseStudioRepository(super.dio);

  @override
  String get table => 'studios';
  @override
  List<String> get searchColumns => const ['name', 'country'];
  @override
  String orderFor(String field, bool ascending) {
    final dir = ascending ? 'asc' : 'desc';
    return field == 'country' ? 'country.$dir,name.$dir' : super.orderFor(field, ascending);
  }

  @override
  Studio fromJson(Map<String, dynamic> json) => Studio.fromJson(json);
}

/// Зрители читаются из представления viewers_view (зритель + карта),
/// записываются функцией save_viewer: зритель и карта — две таблицы,
/// связанные один к одному.
class SupabaseViewerRepository extends SupabaseRepository<Viewer, SimpleQuery> implements ViewerRepository {
  SupabaseViewerRepository(super.dio);

  @override
  String get table => 'viewers';
  @override
  String get readFrom => 'viewers_view';
  @override
  List<String> get searchColumns => const ['last_name', 'email', 'card_number'];

  @override
  String orderFor(String field, bool ascending) =>
      field == 'visitsLeft' ? 'card_visits_left.${ascending ? 'asc' : 'desc'}' : super.orderFor(field, ascending);

  @override
  Map<String, String> filtersFor(Map<String, String> filters) => {
    if (filters['tariff'] != null) 'card_tariff': 'eq.${filters['tariff']}',
  };

  @override
  Viewer fromJson(Map<String, dynamic> json) => Viewer.fromJson(json);

  @override
  Viewer fromRow(Map<String, dynamic> row) => Viewer.fromJson(viewerJson(row));

  @override
  Future<Viewer> create(Viewer item) => _save(item, null);

  @override
  Future<Viewer> update(Viewer item) => _save(item, item.id);

  Future<Viewer> _save(Viewer item, int? id) => guard(() async {
    final row = await rpc(dio, 'save_viewer', {
      'p': Map.of(item.toJson())
        ..remove('id')
        ..remove('deletedAt'),
      'p_id': id,
    });
    return fromRow(asMap(row));
  });

  @override
  Future<Viewer> registerVisit(int id) => guard(() async {
    return fromRow(asMap(await rpc(dio, 'register_visit', {'p_viewer_id': id})));
  });
}

/// Строка viewers_view (поля карты с префиксом card_) → JSON модели с
/// вложенной картой.
Map<String, dynamic> viewerJson(Map<String, dynamic> row) {
  final json = camelKeys(row);
  return {
    ...json,
    'card': {
      'number': json['cardNumber'],
      'tariff': json['cardTariff'],
      'visitsLeft': json['cardVisitsLeft'],
      'issuedAt': json['cardIssuedAt'],
    },
  };
}
