import 'package:flutter_test/flutter_test.dart';
import 'package:kinoteka/models/movie_query.dart';
import 'package:kinoteka/repositories/in_memory_movie_repository.dart';
import 'package:kinoteka/services/network_simulator.dart';

void main() {
  late InMemoryMovieRepository repo;

  setUp(() {
    repo = InMemoryMovieRepository(NetworkSimulator(delay: Duration.zero));
  });

  test('первая страница содержит 10 записей из 42', () async {
    final page = await repo.find(MovieQuery());
    expect(page.items, hasLength(10));
    expect(page.total, 42);
    expect(page.totalPages, 5);
  });

  test('последняя страница неполная', () async {
    final page = await repo.find(MovieQuery(page: 5));
    expect(page.items, hasLength(2));
    expect(page.hasNext, isFalse);
  });

  test('поиск по оригинальному названию', () async {
    final page = await repo.find(MovieQuery(search: 'inception'));
    expect(page.items.single.title, 'Начало');
  });

  test('фильтры комбинируются между собой', () async {
    final page = await repo.find(
      MovieQuery(genreId: 2, studioId: 1, yearFrom: 2010, yearTo: 2020),
    );
    expect(page.items.map((m) => m.title), ['Бегущий по лезвию 2049', 'Начало']);
  });

  test('сортировка по году по убыванию', () async {
    final page = await repo.find(MovieQuery(sortField: 'year', sortAscending: false));
    expect(page.items.first.title, 'Оппенгеймер');
  });

  test('deleteMany помечает записи и убирает их из выборки', () async {
    final count = await repo.deleteMany([1, 2, 1]);
    expect(count, 2);
    final page = await repo.find(MovieQuery(search: 'Начало'));
    expect(page.items, isEmpty);
    final withDeleted = await repo.find(MovieQuery(search: 'Начало', includeDeleted: true));
    expect(withDeleted.items.single.isDeleted, isTrue);
  });

  test('восстановление и физическое удаление', () async {
    await repo.softDelete(3);
    await repo.restore(3);
    expect((await repo.findById(3))!.isDeleted, isFalse);
    await repo.hardDelete(3);
    expect(await repo.findById(3), isNull);
  });

  test('сбой сети приводит к исключению', () async {
    final network = NetworkSimulator(delay: Duration.zero)..failNext();
    final failing = InMemoryMovieRepository(network);
    expect(failing.find(MovieQuery()), throwsA(isA<NetworkException>()));
  });
}
