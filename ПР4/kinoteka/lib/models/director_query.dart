import 'list_query.dart';

class DirectorQuery extends ListQuery {
  static const sortFields = {'lastName', 'firstName', 'birthYear', 'country'};
  static const defaultSort = 'lastName';

  @override
  final String search;
  final String? country;
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

  DirectorQuery({
    this.search = '',
    this.country,
    this.sortField = defaultSort,
    this.sortAscending = true,
    this.page = 1,
    this.size = 10,
    this.includeDeleted = false,
  });

  @override
  bool get hasFilters => search.isNotEmpty || country != null;

  DirectorQuery copyWith({
    String? search,
    Object? country = _unset,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
  }) {
    return DirectorQuery(
      search: search ?? this.search,
      country: country == _unset ? this.country : country as String?,
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
      page: page ?? 1,
      size: size ?? this.size,
      includeDeleted: includeDeleted ?? this.includeDeleted,
    );
  }

  @override
  DirectorQuery withSort(String field, bool ascending) =>
      copyWith(sortField: field, sortAscending: ascending);

  @override
  DirectorQuery withPage(int page) => copyWith(page: page);

  @override
  DirectorQuery withSize(int size) => copyWith(size: size);

  @override
  DirectorQuery withDeleted(bool includeDeleted) =>
      copyWith(includeDeleted: includeDeleted);

  @override
  DirectorQuery cleared() => DirectorQuery(
        sortField: sortField,
        sortAscending: sortAscending,
        size: size,
        includeDeleted: includeDeleted,
      );

  factory DirectorQuery.fromQueryParameters(Map<String, String> p) {
    final (field, ascending) = parseSort(p['sort'], defaultSort, sortFields);
    final country = p['country']?.trim();
    return DirectorQuery(
      search: p['search']?.trim() ?? '',
      country: country == null || country.isEmpty ? null : country,
      sortField: field,
      sortAscending: ascending,
      page: parsePage(p['page']),
      size: parseSize(p['size']),
      includeDeleted: p['deleted'] == 'true',
    );
  }

  @override
  Map<String, String> toQueryParameters() {
    return {
      if (search.isNotEmpty) 'search': search,
      'country': ?country,
      ...tailParameters(defaultSort),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is DirectorQuery &&
      other.search == search &&
      other.country == country &&
      other.sortField == sortField &&
      other.sortAscending == sortAscending &&
      other.page == page &&
      other.size == size &&
      other.includeDeleted == includeDeleted;

  @override
  int get hashCode => Object.hash(
      search, country, sortField, sortAscending, page, size, includeDeleted);

  static const _unset = Object();
}
