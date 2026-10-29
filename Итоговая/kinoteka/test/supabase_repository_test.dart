import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinoteka/core/api_client.dart';
import 'package:kinoteka/core/api_debug.dart';
import 'package:kinoteka/core/api_exceptions.dart';
import 'package:kinoteka/models/director.dart';
import 'package:kinoteka/models/movie.dart';
import 'package:kinoteka/models/movie_query.dart';
import 'package:kinoteka/models/simple_query.dart';
import 'package:kinoteka/models/viewer.dart';
import 'package:kinoteka/repositories/supabase_repositories.dart';
import 'package:kinoteka/repositories/supabase_repository.dart';
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

ResponseBody json(int status, Object? body, {String? contentRange}) => ResponseBody.fromString(
  body == null ? '' : jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json; charset=utf-8'],
    'content-range': ?(contentRange == null ? null : [contentRange]),
  },
);

/// Ошибка PostgREST, поднятая функцией или триггером базы с кодом PTxxx.
ResponseBody pgError(int status, String message, {Object? details}) => json(status, {
  'code': 'PT$status',
  'message': message,
  'details': details == null ? null : jsonEncode(details),
  'hint': null,
});

Never offline(RequestOptions o) => throw DioException.connectionError(requestOptions: o, reason: 'connection refused');

Dio dioWith(FakeAdapter adapter, {ApiDebugFlags? flags}) => buildDio(
  baseUrl: 'https://test.supabase.co',
  apiKey: 'sb_publishable_test',
  adapter: adapter,
  logging: false,
  retryDelay: Duration.zero,
  debugFlags: flags,
);

/// Строка представления movies_view, как её отдаёт PostgREST.
const _movieRow = {
  'id': 1,
  'title': 'Начало',
  'original_title': 'Inception',
  'year': 2010,
  'duration': 148,
  'rating': 8.7,
  'license_number': '121000001',
  'studio_id': 1,
  'deleted_at': null,
  'director_ids': [1],
  'genre_ids': [2, 8],
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
  test('поиск, фильтры, сортировка и страница — параметры PostgREST; ответ разбирается', () async {
    final adapter = FakeAdapter((_) => json(200, [_movieRow], contentRange: '10-10/11'));
    final repo = SupabaseMovieRepository(dioWith(adapter));

    final page = await repo.find(
      MovieQuery(search: 'нач', genreId: 2, yearFrom: 2000, sortField: 'year', sortAscending: false, page: 2),
    );

    final sent = adapter.requests.single;
    expect(sent.path, '/rest/v1/movies_view');
    expect(sent.headers['apikey'], 'sb_publishable_test');
    expect(sent.headers['Prefer'], 'count=exact');
    expect(sent.queryParameters, {
      'select': '*',
      'genre_ids': 'cs.{2}',
      'and': '(year.gte.2000)',
      'or': '(title.ilike."*нач*",original_title.ilike."*нач*",license_number.ilike."*нач*")',
      'deleted_at': 'is.null',
      'order': 'year.desc,id.asc',
      'limit': '10',
      'offset': '10',
    });
    // Общее число записей — из заголовка Content-Range
    expect(page.total, 11);
    expect(page.hasNext, isFalse);
    final m = page.items.single;
    expect(m.originalTitle, 'Inception');
    expect(m.studioId, 1);
    expect(m.genreIds, [2, 8]);
  });

  test('страница за пределами списка (416) — пустая страница, а не ошибка', () async {
    final repo = SupabaseGenreRepository(
      dioWith(FakeAdapter((_) => json(416, {'code': 'PGRST103'}, contentRange: '*/12'))),
    );
    final page = await repo.find(SimpleQuery(genreQuerySpec, page: 5));
    expect(page.items, isEmpty);
    expect(page.total, 12);
  });

  test('запятая и кавычка в строке поиска не ломают условие or', () {
    expect(pgrstQuote('*a,b"c*'), r'"*a,b\"c*"');
  });

  test('422 из функции save_movie: ошибки по полям из details', () async {
    final adapter = FakeAdapter(
      (_) => pgError(
        422,
        'Ошибка валидации',
        details: {'licenseNumber': 'Фильм с таким номером удостоверения уже есть в каталоге'},
      ),
    );
    final repo = SupabaseMovieRepository(dioWith(adapter));

    await expectLater(
      repo.create(_newMovie()),
      throwsA(
        isA<ValidationException>().having((e) => e.errors['licenseNumber'], 'licenseNumber', contains('уже есть')),
      ),
    );
    // Фильм уходит в функцию базы целиком, со связями, без id
    final sent = adapter.requests.single;
    expect(sent.path, '/rest/v1/rpc/save_movie');
    final p = (sent.data as Map)['p'] as Map;
    expect(p['directorIds'], [1]);
    expect(p.containsKey('id'), isFalse);
    expect((sent.data as Map)['p_id'], isNull);
  });

  test('запись режиссёра — столбцы в snake_case, ответ — модель', () async {
    final adapter = FakeAdapter(
      (o) => json(201, [
        {...snakeKeys(Map.of(o.data as Map<String, dynamic>)), 'id': 15, 'deleted_at': null},
      ]),
    );
    final repo = SupabaseDirectorRepository(dioWith(adapter));
    final saved = await repo.create(
      const Director(id: 0, lastName: 'Тестов', firstName: 'Тест', country: 'Россия', birthYear: 1980),
    );
    final sent = adapter.requests.single;
    expect(sent.path, '/rest/v1/directors');
    expect(sent.headers['Prefer'], 'return=representation');
    expect(sent.data, {'last_name': 'Тестов', 'first_name': 'Тест', 'country': 'Россия', 'birth_year': 1980});
    expect(saved.id, 15);
    expect(saved.birthYear, 1980);
  });

  test('409 из триггера: ConflictException с текстом базы', () async {
    final adapter = FakeAdapter((_) => pgError(409, 'Нельзя удалить киностудию: на неё ссылаются 9 фильмов'));
    final repo = SupabaseStudioRepository(dioWith(adapter));

    await expectLater(
      repo.softDelete(3),
      throwsA(isA<ConflictException>().having((e) => e.message, 'message', contains('9 фильмов'))),
    );
    expect(adapter.requests.single.path, '/rest/v1/rpc/move_to_trash');
    expect(adapter.requests.single.data, {
      'p_table': 'studios',
      'p_ids': [3],
    });
  });

  test('403 из базы: текст о недостающем праве роли', () async {
    final adapter = FakeAdapter(
      (_) => pgError(403, 'Недостаточно прав: «удаление навсегда» не разрешено роли «менеджер».'),
    );
    final repo = SupabaseGenreRepository(dioWith(adapter));
    await expectLater(
      repo.hardDeleteMany([1, 2]),
      throwsA(isA<ForbiddenException>().having((e) => e.message, 'message', contains('удаление навсегда'))),
    );
    expect(adapter.requests.single.method, 'DELETE');
    expect(adapter.requests.single.queryParameters, {'id': 'in.(1,2)'});
  });

  test('сервер недоступен: три попытки чтения, затем NetworkException с подсказкой про CORS', () async {
    final adapter = FakeAdapter(offline);
    final repo = SupabaseGenreRepository(dioWith(adapter));

    await expectLater(
      repo.find(SimpleQuery(genreQuerySpec)),
      throwsA(isA<NetworkException>().having((e) => e.message, 'message', contains('CORS'))),
    );
    expect(adapter.requests, hasLength(3));
  });

  test('повтор чтения после сбоя сети возвращает данные', () async {
    var calls = 0;
    final adapter = FakeAdapter((o) => ++calls < 2 ? offline(o) : json(200, [_movieRow]));
    final repo = SupabaseMovieRepository(dioWith(adapter));

    final m = await repo.findById(1);
    expect(m?.title, 'Начало');
    expect(adapter.requests, hasLength(2));
    expect(adapter.requests.last.queryParameters['id'], 'eq.1');
  });

  test('создание записи при сбое сети не повторяется', () async {
    final adapter = FakeAdapter(offline);
    final repo = SupabaseMovieRepository(dioWith(adapter));

    await expectLater(repo.create(_newMovie()), throwsA(isA<NetworkException>()));
    expect(adapter.requests, hasLength(1));
  });

  test('устаревший поиск отменяется, остаётся ответ на последний запрос', () async {
    final adapter = FakeAdapter((o) async {
      final slow = '${o.queryParameters['or']}'.contains('"*бр*"');
      await Future<void>.delayed(Duration(milliseconds: slow ? 200 : 10));
      return json(200, [], contentRange: slow ? '*/99' : '*/2');
    });
    final repo = SupabaseMovieRepository(dioWith(adapter));

    final first = repo.find(MovieQuery(search: 'бр'));
    final second = repo.find(MovieQuery(search: 'брат'));

    await expectLater(first, throwsA(isA<RequestCancelledException>()));
    expect((await second).total, 2);
  });

  test('нет записи — null, а не исключение', () async {
    final repo = SupabaseMovieRepository(dioWith(FakeAdapter((_) => json(200, []))));
    expect(await repo.findById(999), isNull);
  });

  test('зритель из viewers_view собирается с вложенной картой; ошибки карты — по полям формы', () async {
    final row = {
      'id': 1,
      'last_name': 'Иванов',
      'first_name': 'Алексей',
      'email': 'ivanov.a@mail.ru',
      'phone': '',
      'deleted_at': null,
      'card_number': 'KT-100037',
      'card_tariff': 'Премиум',
      'card_visits_left': 24,
      'card_issued_at': '12.01.2026',
    };
    final viewer = Viewer.fromJson(viewerJson(row));
    expect(viewer.card.number, 'KT-100037');
    expect(viewer.card.visitsLeft, 24);

    final adapter = FakeAdapter(
      (_) => pgError(
        422,
        'Ошибка валидации',
        details: {
          'email': 'Зритель с такой почтой уже зарегистрирован',
          'card.number': 'Карта с таким номером уже выдана',
        },
      ),
    );
    final form = FormNotifier<Viewer>(
      SupabaseViewerRepository(dioWith(adapter)),
      null,
      errorKeys: const {'card.number': 'cardNumber'},
    );
    final errors = await form.save(viewer.copyWith(id: 0));
    expect(errors.keys, unorderedEquals(['email', 'cardNumber']));
    expect(adapter.requests.single.path, '/rest/v1/rpc/save_viewer');
  });

  test('справочники запрашиваются один раз, после правки — только изменённая часть', () async {
    final adapter = FakeAdapter(
      (o) => o.path == '/rest/v1/rpc/studio_directors'
          ? json(200, {
              '1': [1, 2],
            })
          : json(200, []),
    );
    final dio = dioWith(adapter);
    final lookups = Lookups(
      SupabaseMovieRepository(dio),
      SupabaseDirectorRepository(dio),
      SupabaseGenreRepository(dio),
      SupabaseStudioRepository(dio),
    );

    await Future.wait([lookups.ensureLoaded(), lookups.ensureLoaded()]);
    await lookups.ensureLoaded(); // повторное открытие формы
    expect(adapter.requests, hasLength(4));
    expect(lookups.directorsOfStudio(1), {1, 2});

    await lookups.invalidate(LookupPart.genres);
    expect(adapter.requests, hasLength(5));
    expect(adapter.requests.last.path, '/rest/v1/genres');
  });

  test('__fail из меню «Проверка» имитирует сбой только у следующего запроса', () async {
    final flags = ApiDebugFlags()..failNext(500);
    final adapter = FakeAdapter((_) => json(200, [], contentRange: '*/0'));
    final repo = SupabaseGenreRepository(dioWith(adapter, flags: flags));

    await expectLater(repo.find(SimpleQuery(genreQuerySpec)), throwsA(isA<ServerException>()));
    // Сбой имитируется на клиенте: первый запрос до сервера не дошёл
    expect(adapter.requests, hasLength(0));
    expect((await repo.find(SimpleQuery(genreQuerySpec))).total, 0);
  });
}
