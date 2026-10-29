import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinoteka/auth/auth_api.dart';
import 'package:kinoteka/auth/auth_notifier.dart';
import 'package:kinoteka/auth/permissions.dart';
import 'package:kinoteka/core/api_debug.dart';
import 'package:kinoteka/core/server_status.dart';
import 'package:kinoteka/main.dart';
import 'package:kinoteka/models/director.dart';
import 'package:kinoteka/models/director_query.dart';
import 'package:kinoteka/models/entity.dart';
import 'package:kinoteka/models/genre.dart';
import 'package:kinoteka/models/list_query.dart';
import 'package:kinoteka/models/movie.dart';
import 'package:kinoteka/models/movie_query.dart';
import 'package:kinoteka/models/page_result.dart';
import 'package:kinoteka/models/simple_query.dart';
import 'package:kinoteka/models/studio.dart';
import 'package:kinoteka/models/viewer.dart';
import 'package:kinoteka/repositories/entity_repository.dart';
import 'package:kinoteka/router.dart';
import 'package:kinoteka/services/preferences_service.dart';
import 'package:kinoteka/state/lookups.dart';
import 'package:kinoteka/state/paged_list_notifier.dart';
import 'package:kinoteka/state/theme_controller.dart';
import 'package:kinoteka/state/unsaved_changes.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Хранилище в памяти вместо API. Ответ на запрос списка можно задержать
/// ([gate]) или заменить ошибкой ([error]) — так проверяются состояния экрана.
class FakeRepository<T extends Entity, Q extends ListQuery> implements EntityRepository<T, Q> {
  FakeRepository([List<T>? items]) : items = items ?? [];

  List<T> items;
  Object? error;
  Completer<void>? gate;
  int findCalls = 0;
  final List<T> created = [];

  @override
  Future<PageResult<T>> find(Q query) async {
    findCalls++;
    if (gate != null) await gate!.future;
    if (error != null) throw error!;
    return PageResult.slice(items, query.page, query.size);
  }

  @override
  Future<T?> findById(int id) async => items.where((e) => e.id == id).firstOrNull;

  @override
  Future<List<T>> findAll({bool includeDeleted = false}) async => items;

  @override
  Future<T> create(T item) async {
    created.add(item);
    return item;
  }

  @override
  Future<T> update(T item) async => item;

  @override
  Future<void> softDelete(int id) async {}

  @override
  Future<void> hardDelete(int id) async {}

  @override
  Future<void> restore(int id) async {}

  @override
  Future<int> deleteMany(List<int> ids) async => ids.length;

  @override
  Future<int> hardDeleteMany(List<int> ids) async => ids.length;
}

class FakeMovieRepository extends FakeRepository<Movie, MovieQuery> implements MovieRepository {
  @override
  Future<List<Movie>> findRelated({int? directorId, int? genreId, int? studioId}) async => [];

  @override
  Future<Map<int, Set<int>>> studioDirectors() async => {};
}

class FakeViewerRepository extends FakeRepository<Viewer, SimpleQuery> implements ViewerRepository {
  @override
  Future<Viewer> registerVisit(int id) async => items.firstWhere((v) => v.id == id);
}

const drama = Genre(id: 1, name: 'Драма', category: 'Игровое кино', description: 'Серьёзные сюжеты');
const comedy = Genre(id: 2, name: 'Комедия', category: 'Игровое кино');

/// Приложение целиком — с маршрутизатором, оболочкой и проверкой прав,
/// как в main.dart, — но поверх хранилищ в памяти.
class TestApp {
  TestApp._(this.widget, this.auth, this.genres);

  final Widget widget;
  final AuthNotifier auth;
  final FakeRepository<Genre, SimpleQuery> genres;

  /// Сессия пользователя с ролью [role] уже сохранена в localStorage
  /// и восстанавливается без обращения к серверу.
  static Future<TestApp> create(
    WidgetTester tester, {
    required Role role,
    String location = '/genres',
    FakeRepository<Genre, SimpleQuery>? genres,
    Size size = const Size(1280, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final now = DateTime.now().millisecondsSinceEpoch;
    SharedPreferences.setMockInitialValues({
      AuthNotifier.kAccess: _token(),
      AuthNotifier.kRefresh: 'refresh',
      AuthNotifier.kStarted: now,
      AuthNotifier.kActivity: now,
      AuthNotifier.kUser: jsonEncode({
        'id': 1,
        'username': role.code,
        'firstName': 'Алексей',
        'lastName': 'Иванов',
        'role': role.code,
      }),
    });
    // Сеть в тестах не нужна: Dio без адаптера сюда не дойдёт
    final auth = AuthNotifier(await SharedPreferences.getInstance(), AuthApi(Dio()));
    await auth.restore();

    final genreRepo = genres ?? FakeRepository<Genre, SimpleQuery>([drama, comedy]);
    final movies = FakeMovieRepository();
    final directors = FakeRepository<Director, DirectorQuery>();
    final studios = FakeRepository<Studio, SimpleQuery>();
    final viewers = FakeViewerRepository();
    final lookups = Lookups(movies, directors, genreRepo, studios);

    final widget = MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: ApiDebugFlags()),
        Provider.value(value: UnsavedChanges()),
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider(create: (_) => ServerStatus(() async => true)),
        Provider<MovieRepository>.value(value: movies),
        Provider<DirectorRepository>.value(value: directors),
        Provider<GenreRepository>.value(value: genreRepo),
        Provider<StudioRepository>.value(value: studios),
        Provider<ViewerRepository>.value(value: viewers),
        ChangeNotifierProvider.value(value: lookups),
        ChangeNotifierProvider(create: (_) => MovieListNotifier(movies, MovieQuery())),
        ChangeNotifierProvider(create: (_) => DirectorListNotifier(directors, DirectorQuery())),
        ChangeNotifierProvider(
          create: (_) => GenreListNotifier(genreRepo, SimpleQuery(genreQuerySpec), onLoaded: lookups.ensureLoaded),
        ),
        ChangeNotifierProvider(create: (_) => StudioListNotifier(studios, SimpleQuery(studioQuerySpec))),
        ChangeNotifierProvider(create: (_) => ViewerListNotifier(viewers, SimpleQuery(viewerQuerySpec))),
        ChangeNotifierProvider(create: (_) => ThemeController(PreferencesService())),
      ],
      child: KinotekaApp(router: createRouter(auth, initialLocation: location)),
    );
    return TestApp._(widget, auth, genreRepo);
  }

  /// Снимает дерево и таймер сессии: незавершённый таймер тест считает ошибкой.
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
  }

  static String _token() {
    String part(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
    final exp = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
    return '${part({'alg': 'HS256'})}.${part({'type': 'access', 'exp': exp})}.sig';
  }
}
