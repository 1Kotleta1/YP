import '../models/director.dart';
import '../models/director_query.dart';
import '../models/page_result.dart';

abstract interface class DirectorRepository {
  Future<PageResult<Director>> find(DirectorQuery query);
  Future<Director?> findById(int id);
  Future<List<Director>> findByIds(List<int> ids);
  Future<List<String>> countries();
  Future<void> softDelete(int id);
  Future<void> hardDelete(int id);
  Future<void> restore(int id);
  Future<int> deleteMany(List<int> ids);
  Future<int> hardDeleteMany(List<int> ids);
}
