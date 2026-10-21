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

/// Что приложение умеет делать с записями любой сущности —
/// безотносительно того, где они лежат.
abstract interface class EntityRepository<T extends Entity, Q extends ListQuery> {
  Future<PageResult<T>> find(Q query);
  Future<T?> findById(int id);
  Future<List<T>> findAll({bool includeDeleted = false});
  Future<T> create(T item);
  Future<T> update(T item);
  Future<void> softDelete(int id);
  Future<void> hardDelete(int id);
  Future<void> restore(int id);
  Future<int> deleteMany(List<int> ids);
  Future<int> hardDeleteMany(List<int> ids);
}

abstract interface class MovieRepository implements EntityRepository<Movie, MovieQuery> {
  /// Номер прокатного удостоверения уже занят другим фильмом.
  Future<bool> licenseTaken(String number, {int? exceptId});
  Future<List<Movie>> findByDirector(int directorId);
}

abstract interface class ViewerRepository implements EntityRepository<Viewer, SimpleQuery> {
  Future<bool> emailTaken(String email, {int? exceptId});
  Future<bool> cardTaken(String number, {int? exceptId});
}

abstract interface class GenreRepository implements EntityRepository<Genre, SimpleQuery> {
  Future<bool> nameTaken(String name, {int? exceptId});
}

typedef DirectorRepository = EntityRepository<Director, DirectorQuery>;
typedef StudioRepository = EntityRepository<Studio, SimpleQuery>;
