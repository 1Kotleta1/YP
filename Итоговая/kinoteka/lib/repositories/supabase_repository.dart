import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import '../models/entity.dart';
import '../models/list_query.dart';
import '../models/page_result.dart';
import 'entity_repository.dart';

/// Общая реализация репозитория поверх REST API Supabase (PostgREST).
///
/// Список — GET /rest/v1/<таблица или представление> с условиями отбора
/// в параметрах адреса (title=ilike.*брат*, year=gte.1990, order=year.desc,
/// limit/offset). Общее число записей сервер сообщает в заголовке
/// Content-Range, если запрос отправлен с Prefer: count=exact.
///
/// В корзину и обратно — функции базы move_to_trash / restore_from_trash,
/// удаление навсегда — DELETE. Права проверяет база: правила RLS и
/// триггеры отвечают кодами 403, 409 и 422.
///
/// Имена столбцов в базе — snake_case, в моделях клиента — camelCase:
/// ключи переводятся при чтении ([fromRow]) и при записи ([toRow]).
abstract class SupabaseRepository<T extends Entity, Q extends ListQuery> implements EntityRepository<T, Q> {
  SupabaseRepository(this.dio);

  final Dio dio;

  /// Таблица (для записи и удаления), например 'directors'.
  String get table;

  /// Откуда читать список и запись: таблица или представление со связями.
  String get readFrom => table;

  /// Столбцы, по которым ищет строка поиска.
  List<String> get searchColumns;

  /// Поле сортировки клиента → выражение order PostgREST.
  String orderFor(String field, bool ascending) => '${snake(field)}.${ascending ? 'asc' : 'desc'}';

  /// Фильтры из условий отбора списка → параметры PostgREST.
  Map<String, String> filtersFor(Map<String, String> filters) => {
    for (final e in filters.entries) snake(e.key): 'eq.${e.value}',
  };

  T fromJson(Map<String, dynamic> json);

  /// Строка из базы → JSON модели.
  T fromRow(Map<String, dynamic> row) => fromJson(camelKeys(row));

  /// Модель → строка для записи: без id и служебных полей.
  Map<String, dynamic> toRow(T item) => snakeKeys(
    Map.of(item.toJson())
      ..remove('id')
      ..remove('deletedAt'),
  );

  CancelToken? _findToken;

  /// Новый поиск отменяет предыдущий, ещё не завершённый: иначе ответ
  /// на «бр» может прийти после ответа на «брат» и затереть его.
  @override
  Future<PageResult<T>> find(Q q) => guard(() async {
    _findToken?.cancel('устаревший запрос');
    final token = _findToken = CancelToken();
    final response = await dio.get<dynamic>(
      '/rest/v1/$readFrom',
      queryParameters: listParameters(q),
      cancelToken: token,
      options: Options(headers: {'Prefer': 'count=exact'}),
    );
    return PageResult(
      items: response.statusCode == 416 ? <T>[] : parseRows(response.data, fromRow),
      page: q.page,
      size: q.size,
      total: totalFromContentRange(response.headers.value('content-range')),
    );
  });

  /// Параметры запроса страницы списка.
  Map<String, String> listParameters(Q q) {
    final params = q.toQueryParameters()..removeWhere((k, _) => const {'sort', 'page', 'size', 'deleted'}.contains(k));
    final search = params.remove('search')?.trim() ?? '';
    return {
      'select': '*',
      ...filtersFor(params),
      if (search.isNotEmpty) 'or': '(${searchColumns.map((c) => '$c.ilike.${pgrstQuote('*$search*')}').join(',')})',
      if (!q.includeDeleted) 'deleted_at': 'is.null',
      // id в конце — стабильный порядок при равных значениях
      'order': '${orderFor(q.sortField, q.sortAscending)},id.asc',
      'limit': '${q.size}',
      'offset': '${(q.page - 1) * q.size}',
    };
  }

  @override
  Future<T?> findById(int id) => guard(() async {
    final response = await dio.get<dynamic>('/rest/v1/$readFrom', queryParameters: {'select': '*', 'id': 'eq.$id'});
    final rows = parseRows(response.data, fromRow);
    return rows.isEmpty ? null : rows.first;
  });

  @override
  Future<List<T>> findAll({bool includeDeleted = false}) => guard(() async {
    final response = await dio.get<dynamic>(
      '/rest/v1/$readFrom',
      queryParameters: {'select': '*', if (!includeDeleted) 'deleted_at': 'is.null', 'order': 'id.asc'},
    );
    return parseRows(response.data, fromRow);
  });

  @override
  Future<T> create(T item) => guard(() async {
    final response = await dio.post<dynamic>(
      '/rest/v1/$table',
      data: toRow(item),
      options: Options(headers: {'Prefer': 'return=representation'}),
    );
    return _single(response.data, item.id);
  });

  @override
  Future<T> update(T item) => guard(() async {
    final response = await dio.patch<dynamic>(
      '/rest/v1/$table',
      queryParameters: {'id': 'eq.${item.id}'},
      data: toRow(item),
      options: Options(headers: {'Prefer': 'return=representation'}),
    );
    return _single(response.data, item.id);
  });

  T _single(Object? data, int id) {
    final rows = parseRows(data, fromRow);
    if (rows.isEmpty) throw NotFoundException('Запись с номером $id не найдена.');
    return rows.first;
  }

  @override
  Future<void> softDelete(int id) => deleteMany([id]);

  @override
  Future<void> restore(int id) => guard(
    () => rpc(dio, 'restore_from_trash', {
      'p_table': table,
      'p_ids': [id],
    }),
  );

  @override
  Future<int> deleteMany(List<int> ids) =>
      guard(() async => jsonInt(await rpc(dio, 'move_to_trash', {'p_table': table, 'p_ids': ids})));

  @override
  Future<void> hardDelete(int id) => hardDeleteMany([id]);

  @override
  Future<int> hardDeleteMany(List<int> ids) => guard(() async {
    final response = await dio.delete<dynamic>(
      '/rest/v1/$table',
      queryParameters: {'id': 'in.(${ids.join(',')})'},
      options: Options(headers: {'Prefer': 'return=representation'}),
    );
    return response.data is List ? (response.data as List).length : 0;
  });
}

/// Вызов функции базы: POST /rest/v1/rpc/<имя> с параметрами в теле.
Future<dynamic> rpc(Dio dio, String name, [Map<String, dynamic> params = const {}]) async {
  final response = await dio.post<dynamic>('/rest/v1/rpc/$name', data: params);
  return response.data;
}

/// «0-9/42» → 42; «*/0» → 0.
int totalFromContentRange(String? header) {
  if (header == null) return 0;
  final slash = header.lastIndexOf('/');
  return slash == -1 ? 0 : int.tryParse(header.substring(slash + 1)) ?? 0;
}

/// Значение в условии or=(…) берётся в кавычки: запятая или скобка
/// в строке поиска иначе сломали бы разбор условия.
String pgrstQuote(String value) => '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';

/// birthYear → birth_year.
String snake(String key) => key.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');

/// birth_year → birthYear.
String camel(String key) => key.replaceAllMapped(RegExp('_([a-z])'), (m) => m[1]!.toUpperCase());

Map<String, dynamic> camelKeys(Map<String, dynamic> row) => {for (final e in row.entries) camel(e.key): e.value};

Map<String, dynamic> snakeKeys(Map<String, dynamic> json) => {for (final e in json.entries) snake(e.key): e.value};

Map<String, dynamic> asMap(Object? data) =>
    data is Map ? data.cast<String, dynamic>() : throw const ServerException('Сервер вернул ответ неожиданного вида.');

List<T> parseRows<T>(Object? data, T Function(Map<String, dynamic>) fromRow) =>
    data is List ? data.whereType<Map>().map((e) => fromRow(e.cast<String, dynamic>())).toList() : <T>[];
