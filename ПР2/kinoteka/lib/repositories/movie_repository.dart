import '../models/movie.dart';
import '../models/movie_query.dart';
import '../models/page_result.dart';

abstract interface class MovieRepository {
  Future<PageResult<Movie>> find(MovieQuery query);
  Future<Movie?> findById(int id);
  Future<List<Movie>> findByDirector(int directorId);
  Future<Movie> create(Movie movie);
  Future<Movie> update(Movie movie);
  Future<void> softDelete(int id);
  Future<void> hardDelete(int id);
  Future<void> restore(int id);
  Future<int> deleteMany(List<int> ids);
  Future<int> hardDeleteMany(List<int> ids);
}
