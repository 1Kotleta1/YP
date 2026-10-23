/// Общие параметры любого списка: поиск, сортировка, страница.
///
/// Наследники добавляют свои фильтры и умеют превращаться
/// в параметры адреса и обратно.
abstract class ListQuery {
  static const pageSizes = [10, 25, 50];

  String get search;
  String get sortField;
  bool get sortAscending;
  int get page;
  int get size;
  bool get includeDeleted;

  bool get hasFilters;

  Map<String, String> toQueryParameters();

  // Операции, общие для всех списков, — их вызывает обобщённый экран.
  ListQuery withSort(String field, bool ascending);
  ListQuery withPage(int page);
  ListQuery withSize(int size);
  ListQuery withDeleted(bool includeDeleted);
  ListQuery cleared();

  /// Общий хвост параметров адреса: сортировка, страница, размер, удалённые.
  Map<String, String> tailParameters(String defaultSort) {
    return {
      if (sortField != defaultSort || !sortAscending)
        'sort': '$sortField,${sortAscending ? 'asc' : 'desc'}',
      if (page != 1) 'page': '$page',
      if (size != pageSizes.first) 'size': '$size',
      if (includeDeleted) 'deleted': 'true',
    };
  }
}

/// Разбор «sort=year,desc» на поле и направление.
(String, bool) parseSort(String? raw, String fallback, Set<String> allowed) {
  if (raw == null || raw.isEmpty) return (fallback, true);
  final parts = raw.split(',');
  final field = allowed.contains(parts.first) ? parts.first : fallback;
  final ascending = parts.length < 2 || parts[1] != 'desc';
  return (field, ascending);
}

int? parseInt(String? raw) => raw == null ? null : int.tryParse(raw);

int parsePage(String? raw) {
  final value = parseInt(raw);
  return value == null || value < 1 ? 1 : value;
}

int parseSize(String? raw) {
  final value = parseInt(raw);
  return ListQuery.pageSizes.contains(value) ? value! : ListQuery.pageSizes.first;
}

/// Адрес списка с условиями отбора: /movies?search=брат&sort=year,desc&page=2.
String listLocation(String path, ListQuery query) {
  final params = query.toQueryParameters();
  return Uri(path: path, queryParameters: params.isEmpty ? null : params).toString();
}
