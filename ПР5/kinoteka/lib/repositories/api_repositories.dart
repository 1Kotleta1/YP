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
import 'api_repository.dart';
import 'entity_repository.dart';

class ApiMovieRepository extends ApiRepository<Movie, MovieQuery> implements MovieRepository {
  ApiMovieRepository(super.dio);

  @override
  String get path => '/movies';
  @override
  Movie fromJson(Map<String, dynamic> json) => Movie.fromJson(json);

  @override
  Future<List<Movie>> findRelated({int? directorId, int? genreId, int? studioId}) => guard(() async {
        final response = await dio.get<dynamic>(path, queryParameters: {
          'directorId': ?directorId,
          'genreId': ?genreId,
          'studioId': ?studioId,
          'sort': 'year,asc',
          'size': 100,
        });
        return parsePage(response.data, Movie.fromJson, 100).items;
      });

  @override
  Future<Map<int, Set<int>>> studioDirectors() => guard(() async {
        final response = await dio.get<dynamic>('/studio-directors');
        return {
          for (final e in asMap(response.data).entries)
            jsonInt(e.key): jsonIntList(e.value).toSet(),
        };
      });
}

class ApiDirectorRepository extends ApiRepository<Director, DirectorQuery> {
  ApiDirectorRepository(super.dio);

  @override
  String get path => '/directors';
  @override
  Director fromJson(Map<String, dynamic> json) => Director.fromJson(json);
}

class ApiGenreRepository extends ApiRepository<Genre, SimpleQuery> {
  ApiGenreRepository(super.dio);

  @override
  String get path => '/genres';
  @override
  Genre fromJson(Map<String, dynamic> json) => Genre.fromJson(json);
}

class ApiStudioRepository extends ApiRepository<Studio, SimpleQuery> {
  ApiStudioRepository(super.dio);

  @override
  String get path => '/studios';
  @override
  Studio fromJson(Map<String, dynamic> json) => Studio.fromJson(json);
}

class ApiViewerRepository extends ApiRepository<Viewer, SimpleQuery> implements ViewerRepository {
  ApiViewerRepository(super.dio);

  @override
  String get path => '/viewers';
  @override
  Viewer fromJson(Map<String, dynamic> json) => Viewer.fromJson(json);

  @override
  Future<Viewer> registerVisit(int id) => guard(() async {
        final response = await dio.post<dynamic>('$path/$id/visit');
        return Viewer.fromJson(asMap(response.data));
      });
}
