import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import '../models/entity.dart';
import '../models/list_query.dart';
import '../models/page_result.dart';
import 'entity_repository.dart';

/// Общая реализация репозитория поверх REST API.
///
/// Наследник задаёт только адрес коллекции и разбор записи. Поиск,
/// фильтры, сортировка и страницы передаются серверу параметрами запроса:
/// клиент хранит только текущую страницу.
abstract class ApiRepository<T extends Entity, Q extends ListQuery>
    implements EntityRepository<T, Q> {
  ApiRepository(this.dio);

  final Dio dio;

  /// Адрес коллекции относительно baseUrl, например '/movies'.
  String get path;
  T fromJson(Map<String, dynamic> json);

  /// Тело запроса на запись: без id и служебных полей.
  Map<String, dynamic> toWriteJson(T item) =>
      Map.of(item.toJson())..remove('id')..remove('deletedAt');

  CancelToken? _findToken;

  /// Новый поиск отменяет предыдущий, ещё не завершённый: иначе ответ
  /// на «бр» может прийти после ответа на «брат» и затереть его.
  @override
  Future<PageResult<T>> find(Q q) => guard(() async {
        _findToken?.cancel('устаревший запрос');
        final token = _findToken = CancelToken();
        final response = await dio.get<dynamic>(path, queryParameters: apiParameters(q), cancelToken: token);
        return parsePage(response.data, fromJson, q.size);
      });

  @override
  Future<T?> findById(int id) async {
    try {
      return await guard(() async {
        final response = await dio.get<dynamic>('$path/$id');
        return fromJson(asMap(response.data));
      });
    } on NotFoundException {
      return null;
    }
  }

  @override
  Future<List<T>> findAll({bool includeDeleted = false}) => guard(() async {
        final response = await dio.get<dynamic>('$path/all',
            queryParameters: {if (includeDeleted) 'includeDeleted': true});
        return parseList(response.data, fromJson);
      });

  @override
  Future<T> create(T item) => guard(() async {
        final response = await dio.post<dynamic>(path, data: toWriteJson(item));
        return fromJson(asMap(response.data));
      });

  @override
  Future<T> update(T item) => guard(() async {
        final response = await dio.put<dynamic>('$path/${item.id}', data: toWriteJson(item));
        return fromJson(asMap(response.data));
      });

  @override
  Future<void> softDelete(int id) => guard(() => dio.delete<dynamic>('$path/$id'));

  @override
  Future<void> hardDelete(int id) =>
      guard(() => dio.delete<dynamic>('$path/$id', queryParameters: {'hard': true}));

  @override
  Future<void> restore(int id) => guard(() => dio.post<dynamic>('$path/$id/restore'));

  @override
  Future<int> deleteMany(List<int> ids) => _bulkDelete(ids, hard: false);

  @override
  Future<int> hardDeleteMany(List<int> ids) => _bulkDelete(ids, hard: true);

  Future<int> _bulkDelete(List<int> ids, {required bool hard}) => guard(() async {
        final response = await dio.post<dynamic>('$path/bulk-delete', data: {'ids': ids, 'hard': hard});
        return jsonInt(asMap(response.data)['deleted']);
      });
}

/// Параметры запроса списка: условия отбора из адреса страницы
/// плюс сортировка и страница, которые сервер получает всегда.
Map<String, dynamic> apiParameters(ListQuery q) {
  final p = q.toQueryParameters()..removeWhere((k, _) => const {'sort', 'page', 'size', 'deleted'}.contains(k));
  return {
    ...p,
    'sort': '${q.sortField},${q.sortAscending ? 'asc' : 'desc'}',
    'page': q.page,
    'size': q.size,
    if (q.includeDeleted) 'includeDeleted': true,
  };
}

Map<String, dynamic> asMap(Object? data) =>
    data is Map ? data.cast<String, dynamic>() : throw const ServerException('Сервер вернул ответ неожиданного вида.');

List<T> parseList<T>(Object? data, T Function(Map<String, dynamic>) fromJson) =>
    data is List ? data.whereType<Map>().map((e) => fromJson(e.cast<String, dynamic>())).toList() : <T>[];

PageResult<T> parsePage<T>(Object? data, T Function(Map<String, dynamic>) fromJson, int size) {
  final map = asMap(data);
  return PageResult(
    items: parseList(map['items'], fromJson),
    page: jsonInt(map['page'], 1),
    size: jsonInt(map['size'], size),
    total: jsonInt(map['total']),
  );
}
