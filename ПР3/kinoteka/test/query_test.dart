import 'package:flutter_test/flutter_test.dart';
import 'package:kinoteka/models/director_query.dart';
import 'package:kinoteka/models/list_query.dart';
import 'package:kinoteka/models/movie_query.dart';

void main() {
  test('условия отбора переводятся в адрес и обратно без потерь', () {
    final query = MovieQuery(
      search: 'брат',
      genreId: 6,
      yearFrom: 1990,
      sortField: 'year',
      sortAscending: false,
      page: 2,
      size: 25,
    );
    final location = listLocation('/movies', query);
    expect(location, contains('sort=year%2Cdesc'));

    final parsed = MovieQuery.fromQueryParameters(Uri.parse(location).queryParameters);
    expect(parsed, query);
  });

  test('условия по умолчанию дают чистый адрес', () {
    expect(listLocation('/movies', MovieQuery()), '/movies');
  });

  test('смена фильтра возвращает на первую страницу', () {
    final query = MovieQuery(page: 4).copyWith(genreId: 1);
    expect(query.page, 1);
  });

  test('copyWith умеет сбрасывать фильтр в null', () {
    final query = MovieQuery(genreId: 3).copyWith(genreId: null);
    expect(query.genreId, isNull);
  });

  test('недопустимые значения в адресе заменяются значениями по умолчанию', () {
    final query = DirectorQuery.fromQueryParameters(
      {'sort': 'salary,desc', 'page': '-3', 'size': '7'},
    );
    expect(query.sortField, 'lastName');
    expect(query.sortAscending, isFalse);
    expect(query.page, 1);
    expect(query.size, 10);
  });
}
