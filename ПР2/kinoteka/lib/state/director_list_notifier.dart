import '../models/director.dart';
import '../models/director_query.dart';
import '../models/page_result.dart';
import '../repositories/director_repository.dart';
import 'paged_list_notifier.dart';

class DirectorListNotifier extends PagedListNotifier<Director, DirectorQuery> {
  DirectorListNotifier(this._repository) : super(DirectorQuery());

  final DirectorRepository _repository;
  List<String> _countries = const [];

  /// Страны для фильтра — берутся из самих данных.
  List<String> get countries => _countries;

  @override
  int idOf(Director item) => item.id;

  @override
  Future<PageResult<Director>> fetch(DirectorQuery query) async {
    _countries = await _repository.countries();
    return _repository.find(query);
  }

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
