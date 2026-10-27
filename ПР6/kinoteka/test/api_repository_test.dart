import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinoteka/core/api_client.dart';
import 'package:kinoteka/core/api_debug.dart';
import 'package:kinoteka/core/api_exceptions.dart';
import 'package:kinoteka/models/movie.dart';
import 'package:kinoteka/models/movie_query.dart';
import 'package:kinoteka/models/simple_query.dart';
import 'package:kinoteka/models/viewer.dart';
import 'package:kinoteka/repositories/api_repositories.dart';
import 'package:kinoteka/state/form_notifier.dart';
import 'package:kinoteka/state/lookups.dart';

/// Подменённый транспорт Dio: запросы не уходят в сеть, ответы задаёт тест.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  final FutureOr<ResponseBody> Function(RequestOptions o) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) async {
    requests.add(o);
    return handler(o);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody json(int status, Object? body) => ResponseBody.fromString(
  body == null ? '' : jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json; charset=utf-8'],
  },
);

Never offline(RequestOptions o) => throw DioException.connectionError(requestOptions: o, reason: 'connection refused');

Dio dioWith(FakeAdapter adapter, {ApiDebugFlags? flags}) => buildDio(
  baseUrl: 'http://test/api',
  adapter: adapter,
  logging: false,
  retryDelay: Duration.zero,
  debugFlags: flags,
);

const _movie = {
  'id': 1,
  'title': 'Начало',
  'originalTitle': 'Inception',
  'year': 2010,
  'duration': 148,
  'rating': 8.7,
  'licenseNumber': '121000001',
  'studio': {'id': 1, 'name': 'Warner Bros.'},
  'directors': [
    {'id': 1, 'firstName': 'Кристофер', 'lastName': 'Нолан'},
  ],
  'genres': [
    {'id': 2, 'name': 'Фантастика'},
    {'id': 8, 'name': 'Боевик'},
  ],
};

Movie _newMovie() => const Movie(
  id: 0,
  title: 'Дубль',
  originalTitle: 'Double',
  year: 2020,
  duration: 100,
  rating: 7,
  licenseNumber: '121000001',
  studioId: 1,
  directorIds: [1],
  genreIds: [1],
);

void main() {
  test('поиск, фильтр, сортировка и страница уходят серверу; ответ разбирается', () async {
    final adapter = FakeAdapter(
      (_) => json(200, {
        'items': [_movie],
        'page': 2,
        'size': 10,
        'total': 11,
      }),
    );
    final repo = ApiMovieRepository(dioWith(adapter));

    final page = await repo.find(
      MovieQuery(search: 'нач', genreId: 2, sortField: 'year', sortAscending: false, page: 2),
    );

    final sent = adapter.requests.single;
    expect(sent.path, '/movies');
    expect(sent.queryParameters, {'search': 'нач', 'genreId': '2', 'sort': 'year,desc', 'page': 2, 'size': 10});
    expect(page.total, 11);
    expect(page.hasNext, isFalse);
    // Связи пришли развёрнутыми объектами — в модели остались идентификаторы
    final m = page.items.single;
    expect(m.studioId, 1);
    expect(m.directorIds, [1]);
    expect(m.genreIds, [2, 8]);
  });

  test('422: ошибки валидации доходят по полям', () async {
    final adapter = FakeAdapter(
      (_) => json(422, {
        'message': 'Ошибка валидации',
        'errors': {'licenseNumber': 'Фильм с таким номером удостоверения уже есть в каталоге'},
      }),
    );
    final repo = ApiMovieRepository(dioWith(adapter));

    await expectLater(
      repo.create(_newMovie()),
      throwsA(
        isA<ValidationException>().having((e) => e.errors['licenseNumber'], 'licenseNumber', contains('уже есть')),
      ),
    );
    // На запись ушли идентификаторы, а не объекты
    final body = adapter.requests.single.data as Map;
    expect(body['studioId'], 1);
    expect(body.containsKey('id'), isFalse);
  });

  test('409: конфликт превращается в ConflictException с текстом сервера', () async {
    final adapter = FakeAdapter((_) => json(409, {'message': 'Нельзя удалить киностудию: на неё ссылаются 9 фильмов'}));
    final repo = ApiStudioRepository(dioWith(adapter));

    await expectLater(
      repo.softDelete(3),
      throwsA(isA<ConflictException>().having((e) => e.message, 'message', contains('9 фильмов'))),
    );
  });

  test('сервер недоступен: три попытки чтения, затем NetworkException с подсказкой про CORS', () async {
    final adapter = FakeAdapter(offline);
    final repo = ApiGenreRepository(dioWith(adapter));

    await expectLater(
      repo.find(SimpleQuery(genreQuerySpec)),
      throwsA(isA<NetworkException>().having((e) => e.message, 'message', contains('CORS'))),
    );
    expect(adapter.requests, hasLength(3));
  });

  test('повтор чтения после сбоя сети возвращает данные', () async {
    var calls = 0;
    final adapter = FakeAdapter((o) => ++calls < 2 ? offline(o) : json(200, _movie));
    final repo = ApiMovieRepository(dioWith(adapter));

    final m = await repo.findById(1);
    expect(m?.title, 'Начало');
    expect(adapter.requests, hasLength(2));
  });

  test('создание записи при сбое сети не повторяется', () async {
    final adapter = FakeAdapter(offline);
    final repo = ApiMovieRepository(dioWith(adapter));

    await expectLater(repo.create(_newMovie()), throwsA(isA<NetworkException>()));
    expect(adapter.requests, hasLength(1));
  });

  test('устаревший поиск отменяется, остаётся ответ на последний запрос', () async {
    final adapter = FakeAdapter((o) async {
      final slow = o.queryParameters['search'] == 'бр';
      await Future<void>.delayed(Duration(milliseconds: slow ? 200 : 10));
      return json(200, {'items': [], 'page': 1, 'size': 10, 'total': slow ? 99 : 2});
    });
    final repo = ApiMovieRepository(dioWith(adapter));

    final first = repo.find(MovieQuery(search: 'бр'));
    final second = repo.find(MovieQuery(search: 'брат'));

    await expectLater(first, throwsA(isA<RequestCancelledException>()));
    expect((await second).total, 2);
  });

  test('404 при чтении записи — null, а не исключение', () async {
    final repo = ApiMovieRepository(dioWith(FakeAdapter((_) => json(404, {'message': 'Фильм не найден'}))));
    expect(await repo.findById(999), isNull);
  });

  test('ошибки вложенной карты зрителя раскладываются по полям формы', () async {
    final adapter = FakeAdapter(
      (_) => json(422, {
        'message': 'Ошибка валидации',
        'errors': {
          'email': 'Зритель с такой почтой уже зарегистрирован',
          'card.number': 'Карта с таким номером уже выдана',
        },
      }),
    );
    final form = FormNotifier<Viewer>(
      ApiViewerRepository(dioWith(adapter)),
      null,
      errorKeys: const {'card.number': 'cardNumber'},
    );

    final errors = await form.save(
      const Viewer(
        id: 0,
        lastName: 'Иванов',
        firstName: 'Пётр',
        email: 'p@mail.ru',
        card: ViewerCard(number: 'KT-100001', tariff: 'Базовый', visitsLeft: 1, issuedAt: '01.01.2026'),
      ),
    );
    expect(errors.keys, unorderedEquals(['email', 'cardNumber']));
  });

  test('справочники запрашиваются один раз, после правки — только изменённая часть', () async {
    final adapter = FakeAdapter(
      (o) => o.path == '/studio-directors'
          ? json(200, {
              '1': [1, 2],
            })
          : json(200, []),
    );
    final dio = dioWith(adapter);
    final lookups = Lookups(
      ApiMovieRepository(dio),
      ApiDirectorRepository(dio),
      ApiGenreRepository(dio),
      ApiStudioRepository(dio),
    );

    await Future.wait([lookups.ensureLoaded(), lookups.ensureLoaded()]);
    await lookups.ensureLoaded(); // повторное открытие формы
    expect(adapter.requests, hasLength(4));
    expect(lookups.directorsOfStudio(1), {1, 2});

    await lookups.invalidate(LookupPart.genres);
    expect(adapter.requests, hasLength(5));
    expect(adapter.requests.last.path, '/genres/all');
  });

  test('__fail из меню «Проверка» добавляется только к следующему запросу', () async {
    final flags = ApiDebugFlags()..failNext(500);
    final adapter = FakeAdapter(
      (o) => o.queryParameters['__fail'] == '500'
          ? json(500, {'message': 'Имитация ошибки сервера (__fail=500)'})
          : json(200, {'items': [], 'page': 1, 'size': 10, 'total': 0}),
    );
    final repo = ApiGenreRepository(dioWith(adapter, flags: flags));

    await expectLater(repo.find(SimpleQuery(genreQuerySpec)), throwsA(isA<ServerException>()));
    expect((await repo.find(SimpleQuery(genreQuerySpec))).total, 0);
  });
}
