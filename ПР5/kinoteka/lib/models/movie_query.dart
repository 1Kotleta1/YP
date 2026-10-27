import 'list_query.dart';

class MovieQuery extends ListQuery {
  static const sortFields = {'title', 'year', 'duration', 'rating'};
  static const defaultSort = 'title';

  @override
  final String search;
  final int? genreId;
  final int? studioId;
  final int? yearFrom;
  final int? yearTo;
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

  MovieQuery({
    this.search = '',
    this.genreId,
    this.studioId,
    this.yearFrom,
    this.yearTo,
    this.sortField = defaultSort,
    this.sortAscending = true,
    this.page = 1,
    this.size = 10,
    this.includeDeleted = false,
  });

  @override
  bool get hasFilters =>
      search.isNotEmpty ||
      genreId != null ||
      studioId != null ||
      yearFrom != null ||
      yearTo != null;

  MovieQuery copyWith({
    String? search,
    Object? genreId = _unset,
    Object? studioId = _unset,
    Object? yearFrom = _unset,
    Object? yearTo = _unset,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
  }) {
    return MovieQuery(
      search: search ?? this.search,
      genreId: genreId == _unset ? this.genreId : genreId as int?,
      studioId: studioId == _unset ? this.studioId : studioId as int?,
      yearFrom: yearFrom == _unset ? this.yearFrom : yearFrom as int?,
      yearTo: yearTo == _unset ? this.yearTo : yearTo as int?,
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
      // Любое изменение условий отбора возвращает на первую страницу
      page: page ?? 1,
      size: size ?? this.size,
      includeDeleted: includeDeleted ?? this.includeDeleted,
    );
  }

  @override
  MovieQuery withSort(String field, bool ascending) =>
      copyWith(sortField: field, sortAscending: ascending);

  @override
  MovieQuery withPage(int page) => copyWith(page: page);

  @override
  MovieQuery withSize(int size) => copyWith(size: size);

  @override
  MovieQuery withDeleted(bool includeDeleted) =>
      copyWith(includeDeleted: includeDeleted);

  /// Сброс фильтров с сохранением сортировки и размера страницы.
  @override
  MovieQuery cleared() => MovieQuery(
        sortField: sortField,
        sortAscending: sortAscending,
        size: size,
        includeDeleted: includeDeleted,
      );

  factory MovieQuery.fromQueryParameters(Map<String, String> p) {
    final (field, ascending) = parseSort(p['sort'], defaultSort, sortFields);
    return MovieQuery(
      search: p['search']?.trim() ?? '',
      genreId: parseInt(p['genreId']),
      studioId: parseInt(p['studioId']),
      yearFrom: parseInt(p['yearFrom']),
      yearTo: parseInt(p['yearTo']),
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
      if (genreId != null) 'genreId': '$genreId',
      if (studioId != null) 'studioId': '$studioId',
      if (yearFrom != null) 'yearFrom': '$yearFrom',
      if (yearTo != null) 'yearTo': '$yearTo',
      ...tailParameters(defaultSort),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is MovieQuery &&
      other.search == search &&
      other.genreId == genreId &&
      other.studioId == studioId &&
      other.yearFrom == yearFrom &&
      other.yearTo == yearTo &&
      other.sortField == sortField &&
      other.sortAscending == sortAscending &&
      other.page == page &&
      other.size == size &&
      other.includeDeleted == includeDeleted;

  @override
  int get hashCode => Object.hash(search, genreId, studioId, yearFrom, yearTo,
      sortField, sortAscending, page, size, includeDeleted);

  static const _unset = Object();
}
