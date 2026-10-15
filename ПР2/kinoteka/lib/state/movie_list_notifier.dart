import '../models/movie.dart';
import '../models/movie_query.dart';
import '../models/page_result.dart';
import '../repositories/movie_repository.dart';
import 'paged_list_notifier.dart';

class MovieListNotifier extends PagedListNotifier<Movie, MovieQuery> {
  MovieListNotifier(this._repository) : super(MovieQuery());

  final MovieRepository _repository;

  @override
  int idOf(Movie item) => item.id;

  @override
  Future<PageResult<Movie>> fetch(MovieQuery query) => _repository.find(query);

  @override
  Future<int> removeMany(List<int> ids, {required bool permanent}) => permanent
      ? _repository.hardDeleteMany(ids)
      : _repository.deleteMany(ids);

  @override
  Future<void> removeOne(int id, {required bool permanent}) =>
      permanent ? _repository.hardDelete(id) : _repository.softDelete(id);

  @override
  Future<void> restoreOne(int id) => _repository.restore(id);
}
