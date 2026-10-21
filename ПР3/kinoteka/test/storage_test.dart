import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinoteka/models/movie.dart';
import 'package:kinoteka/models/movie_query.dart';
import 'package:kinoteka/models/viewer.dart';
import 'package:kinoteka/repositories/relation_guard.dart';
import 'package:kinoteka/repositories/repositories.dart';
import 'package:kinoteka/services/local_store.dart';
import 'package:kinoteka/services/network_simulator.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _net = NetworkSimulator(delay: Duration.zero);

Future<LocalStore> _store([Map<String, Object> initial = const {}]) async {
  SharedPreferences.setMockInitialValues(initial);
  final store = LocalStore(await SharedPreferences.getInstance());
  await store.migrate();
  return store;
}

void main() {
  test('fromJson не падает на отсутствующих и null-полях', () {
    final m = Movie.fromJson({'id': 7, 'title': null, 'year': '1999', 'genreIds': [1, 'x', 2]});
    expect(m.title, '');
    expect(m.year, 1999);
    expect(m.genreIds, [1, 2]);
    expect(m.deletedAt, isNull);
    final v = Viewer.fromJson({'id': 1, 'card': null});
    expect(v.card.tariff, 'Базовый');
  });

  test('toJson → fromJson сохраняет все поля', () {
    const v = Viewer(
      id: 3, lastName: 'Иванов', firstName: 'Пётр', email: 'p@mail.ru',
      card: ViewerCard(number: 'KT-000001', tariff: 'Премиум', visitsLeft: 5, issuedAt: '01.02.2026'),
    );
    final back = Viewer.fromJson(jsonDecode(jsonEncode(v.toJson())) as Map<String, dynamic>);
    expect(back.card.tariff, 'Премиум');
    expect(back.email, 'p@mail.ru');
  });

  test('созданный фильм переживает «перезагрузку»', () async {
    final store = await _store();
    final repo = PersistentMovieRepository(store, _net);
    final created = await repo.create(const Movie(
      id: 0, title: 'Новый фильм', originalTitle: 'New', year: 2025, duration: 100,
      rating: 7, licenseNumber: '121099999', studioId: 1, directorIds: [1], genreIds: [1],
    ));
    // Новый репозиторий поверх того же хранилища — как после F5
    final reopened = PersistentMovieRepository(store, _net);
    expect((await reopened.findById(created.id))!.title, 'Новый фильм');
    expect(created.id, 43);
  });

  test('уникальность номера удостоверения и почты', () async {
    final store = await _store();
    final movies = PersistentMovieRepository(store, _net);
    final viewers = PersistentViewerRepository(store, _net);
    expect(await movies.licenseTaken('121000001'), isTrue);
    expect(await movies.licenseTaken('121000001', exceptId: 1), isFalse);
    expect(await viewers.emailTaken('IVANOV.A@mail.ru'), isTrue);
  });

  test('миграция данных формата v1', () async {
    final legacy = jsonEncode([
      {'id': 1, 'title': 'Старый фильм', 'year': 2000, 'studioId': 1, 'directorIds': [1], 'genreIds': [1]},
    ]);
    final store = await _store({LocalStore.legacyMoviesKey: legacy});
    final repo = PersistentMovieRepository(store, _net);
    final page = await repo.find(MovieQuery());
    expect(page.items.single.licenseNumber, '121900001');
    expect(store.notices.single, contains('формат v2'));
  });

  test('испорченные данные заменяются начальным набором', () async {
    final store = await _store({'kinoteka_schema': 2, 'movies_v2': '{не json'});
    final repo = PersistentMovieRepository(store, _net);
    expect((await repo.find(MovieQuery())).total, 42);
    expect(store.notices.single, contains('повреждены'));
  });

  test('студию со связанными фильмами удалить нельзя', () async {
    final store = await _store();
    final guard = RelationGuard(PersistentMovieRepository(store, _net));
    final reason = await guard.studios([3], permanent: false);
    expect(reason, contains('9 фильмов'));
    expect(await guard.directors([1], permanent: false), isNull);
    expect(await guard.directors([1], permanent: true), contains('связанных фильмов — 5'));
  });
}
