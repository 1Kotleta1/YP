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
///
/// Основные операции не изменились с ПР2/ПР3. Проверки уникальности
/// (licenseTaken, emailTaken…) и запреты удаления ушли на сервер:
/// клиент узнаёт о них из ответов 422 и 409.
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
  /// Фильмы режиссёра, жанра или студии — отбор выполняет сервер.
  Future<List<Movie>> findRelated({int? directorId, int? genreId, int? studioId});

  /// Для каскада в форме фильма: id студии → режиссёры, снимавшие на ней.
  Future<Map<int, Set<int>>> studioDirectors();
}

abstract interface class ViewerRepository implements EntityRepository<Viewer, SimpleQuery> {
  /// Отметить посещение по карте. Посещений не осталось — 409.
  Future<Viewer> registerVisit(int id);
}

typedef DirectorRepository = EntityRepository<Director, DirectorQuery>;
typedef GenreRepository = EntityRepository<Genre, SimpleQuery>;
typedef StudioRepository = EntityRepository<Studio, SimpleQuery>;
