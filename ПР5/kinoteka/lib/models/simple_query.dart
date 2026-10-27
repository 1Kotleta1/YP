import 'package:flutter/foundation.dart';

import 'list_query.dart';

/// Какие поля сортировки и какие фильтры допустимы у сущности.
class QuerySpec {
  const QuerySpec({
    required this.defaultSort,
    required this.sortFields,
    this.filterKeys = const {},
  });

  final String defaultSort;
  final Set<String> sortFields;
  final Set<String> filterKeys;
}

const genreQuerySpec = QuerySpec(
  defaultSort: 'name',
  sortFields: {'name', 'category'},
  filterKeys: {'category'},
);

const studioQuerySpec = QuerySpec(
  defaultSort: 'name',
  sortFields: {'name', 'country', 'foundedYear'},
  filterKeys: {'country'},
);

const viewerQuerySpec = QuerySpec(
  defaultSort: 'lastName',
  sortFields: {'lastName', 'firstName', 'email', 'visitsLeft'},
  filterKeys: {'tariff'},
);

/// Условия отбора для справочных сущностей. Фильтры хранятся словарём,
/// поэтому новой сущности не нужен свой класс запроса — только [QuerySpec].
class SimpleQuery extends ListQuery {
  SimpleQuery(
    this.spec, {
    this.search = '',
    this.filters = const {},
    String? sortField,
    this.sortAscending = true,
    this.page = 1,
    this.size = 10,
    this.includeDeleted = false,
  }) : sortField = sortField ?? spec.defaultSort;

  final QuerySpec spec;
  @override
  final String search;
  final Map<String, String> filters;
  @override
  final String sortField;
  @override
  final bool sortAscending;
  @override
  final int page;
  @override
  final int size;
  @override
  final bool includeDeleted;

  String? filter(String key) => filters[key];

  @override
  bool get hasFilters => search.isNotEmpty || filters.isNotEmpty;

  /// [filters]: значение null снимает фильтр, строка — устанавливает.
  SimpleQuery copyWith({
    String? search,
    Map<String, String?>? filters,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
  }) {
    final next = {...this.filters};
    filters?.forEach((k, v) => v == null || v.isEmpty ? next.remove(k) : next[k] = v);
    return SimpleQuery(
      spec,
      search: search ?? this.search,
      filters: next,
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
      page: page ?? 1,
      size: size ?? this.size,
      includeDeleted: includeDeleted ?? this.includeDeleted,
    );
  }

  @override
  SimpleQuery withSort(String field, bool ascending) =>
      copyWith(sortField: field, sortAscending: ascending);

  @override
  SimpleQuery withPage(int page) => copyWith(page: page);

  @override
  SimpleQuery withSize(int size) => copyWith(size: size);

  @override
  SimpleQuery withDeleted(bool includeDeleted) => copyWith(includeDeleted: includeDeleted);

  @override
  SimpleQuery cleared() => SimpleQuery(
        spec,
        sortField: sortField,
        sortAscending: sortAscending,
        size: size,
        includeDeleted: includeDeleted,
      );

  factory SimpleQuery.fromQueryParameters(QuerySpec spec, Map<String, String> p) {
    final (field, ascending) = parseSort(p['sort'], spec.defaultSort, spec.sortFields);
    return SimpleQuery(
      spec,
      search: p['search']?.trim() ?? '',
      filters: {
        for (final k in spec.filterKeys)
          if ((p[k] ?? '').trim().isNotEmpty) k: p[k]!.trim(),
      },
      sortField: field,
      sortAscending: ascending,
      page: parsePage(p['page']),
      size: parseSize(p['size']),
      includeDeleted: p['deleted'] == 'true',
    );
  }

  @override
  Map<String, String> toQueryParameters() => {
        if (search.isNotEmpty) 'search': search,
        ...filters,
        ...tailParameters(spec.defaultSort),
      };

  @override
  bool operator ==(Object other) =>
      other is SimpleQuery &&
      identical(other.spec, spec) &&
      other.search == search &&
      mapEquals(other.filters, filters) &&
      other.sortField == sortField &&
      other.sortAscending == sortAscending &&
      other.page == page &&
      other.size == size &&
      other.includeDeleted == includeDeleted;

  @override
  int get hashCode => Object.hash(spec, search, Object.hashAllUnordered(filters.entries.map((e) => '${e.key}=${e.value}')),
      sortField, sortAscending, page, size, includeDeleted);
}
