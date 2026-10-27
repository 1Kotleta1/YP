import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'auth/auth_notifier.dart';
import 'auth/permissions.dart';
import 'models/director.dart';
import 'models/director_query.dart';
import 'models/entity.dart';
import 'models/genre.dart';
import 'models/list_query.dart';
import 'models/movie.dart';
import 'models/movie_query.dart';
import 'models/simple_query.dart';
import 'models/studio.dart';
import 'models/viewer.dart';
import 'repositories/entity_repository.dart';
import 'screens/account_screens.dart';
import 'screens/auth_screens.dart';
import 'screens/details_screens.dart';
import 'screens/home_screen.dart';
import 'screens/director_list_screen.dart';
import 'screens/form_screens.dart';
import 'screens/movie_list_screen.dart';
import 'screens/not_found_screen.dart';
import 'screens/simple_list_screen.dart';
import 'state/details_notifier.dart';
import 'state/form_notifier.dart';
import 'state/lookups.dart';
import 'state/paged_list_notifier.dart';
import 'state/unsaved_changes.dart';
import 'widgets/entity_form.dart';

/// Страница без анимации: смена условий отбора — это тот же экран,
/// и ключ pageKey не меняется, поэтому поле поиска не теряет фокус.
Page<void> _page(GoRouterState state, Widget child) =>
    NoTransitionPage(key: state.pageKey, child: child);

int? _id(GoRouterState state) => int.tryParse(state.pathParameters['id'] ?? '');

/// Уход с формы с несохранёнными изменениями — по кнопке, пункту меню
/// или кнопкой «назад» браузера — требует подтверждения.
FutureOr<bool> _confirmExit(BuildContext context, GoRouterState state) async {
  final guard = context.read<UnsavedChanges>();
  if (!guard.dirty) return true;
  final leave = await confirmLeave(context);
  if (leave) guard.dirty = false;
  return leave;
}

/// Четыре маршрута одной сущности: список, создание, карточка, изменение.
/// /new объявлен раньше /:id, иначе «new» разбирался бы как номер записи.
List<GoRoute> _entityRoutes<T extends Entity, D>({
  required String path,
  required Widget Function(GoRouterState state) list,
  required Widget details,
  required DetailsNotifier<D> Function(BuildContext context, int id) detailsNotifier,
  required Widget form,
  required FormNotifier<T> Function(BuildContext context, int? id) formNotifier,
}) {
  Widget formPage(int? id) => ChangeNotifierProvider<FormNotifier<T>>(
        create: (context) {
          // Справочники берутся из кэша; запрос уходит, только если их ещё нет
          context.read<Lookups>().ensureLoaded();
          return formNotifier(context, id)..load();
        },
        child: form,
      );
  return [
    GoRoute(path: path, pageBuilder: (c, s) => _page(s, list(s))),
    GoRoute(
      path: '$path/new',
      onExit: _confirmExit,
      pageBuilder: (c, s) => _page(s, formPage(null)),
    ),
    GoRoute(
      path: '$path/:id',
      pageBuilder: (c, s) {
        final id = _id(s);
        if (id == null) return _page(s, NotFoundScreen(location: s.uri.toString()));
        return _page(
          s,
          ChangeNotifierProvider<DetailsNotifier<D>>(
              create: (context) => detailsNotifier(context, id)..load(), child: details),
        );
      },
    ),
    GoRoute(
      path: '$path/:id/edit',
      onExit: _confirmExit,
      pageBuilder: (c, s) {
        final id = _id(s);
        if (id == null) return _page(s, NotFoundScreen(location: s.uri.toString()));
        return _page(s, formPage(id));
      },
    ),
  ];
}

/// После сохранения в форме обновляются открытые списки и только та часть
/// кэша справочников, которую затронула правка.
VoidCallback _afterSave<T extends Entity, Q extends ListQuery>(BuildContext context, LookupPart? part) {
  final lookups = context.read<Lookups>();
  final list = context.read<PagedListNotifier<T, Q>>();
  final movies = context.read<MovieListNotifier>();
  return () {
    if (part != null) lookups.invalidate(part);
    list.refresh();
    if (list != movies) movies.refresh();
  };
}

/// Карточки используют справочники для подписей, поэтому ждут их загрузки.
Future<void> _withLookups(Lookups lookups) async {
  await lookups.ensureLoaded();
  if (lookups.status == LoadStatus.error) throw Exception(lookups.error);
}

/// Проверка перед каждым переходом. null — переход разрешён,
/// строка — куда перенаправить.
///
/// Это удобство интерфейса, а не защита: запрос к API всё равно
/// проверит сервер по роли из подписанного токена.
String? authRedirect(AuthNotifier auth, Uri uri) {
  final path = uri.path;
  final isPublic = path == '/login' || path == '/register';

  // Не вошёл и идёт на закрытый экран — на вход,
  // запомнив адрес, куда он хотел попасть
  if (!auth.isAuthenticated) {
    if (isPublic) return null;
    final target = uri.toString();
    return target == '/' ? '/login' : '/login?from=${Uri.encodeComponent(target)}';
  }

  // Уже вошёл и идёт на экран входа — туда, откуда его перенаправили
  if (isPublic) {
    final from = uri.queryParameters['from'];
    // Только адреса внутри приложения: «//сайт» увёл бы на чужой сервер
    return from != null && from.startsWith('/') && !from.startsWith('//') ? from : '/';
  }

  // Роль не позволяет открыть раздел — экран отказа, а не пустой экран
  final need = permissionForLocation(path);
  if (need != null && !auth.can(need)) {
    return '/forbidden?from=${Uri.encodeComponent(uri.toString())}';
  }
  return null;
}

GoRouter createRouter(AuthNotifier auth) {
  return GoRouter(
    // Маршрутизатор пересчитает redirect при каждом notifyListeners():
    // вход, выход, истечение сессии
    refreshListenable: auth,
    initialLocation: '/',
    redirect: (context, state) => authRedirect(auth, state.uri),
    routes: [
      GoRoute(path: '/login', builder: (c, s) => LoginScreen(from: s.uri.queryParameters['from'])),
      GoRoute(path: '/register', builder: (c, s) => const RegisterScreen()),
      GoRoute(path: '/', pageBuilder: (c, s) => _page(s, const HomeScreen())),
      GoRoute(
          path: '/forbidden',
          pageBuilder: (c, s) => _page(s, ForbiddenScreen(from: s.uri.queryParameters['from']))),
      GoRoute(path: '/my-card', pageBuilder: (c, s) => _page(s, const MyCardScreen())),
      GoRoute(path: '/box-office', pageBuilder: (c, s) => _page(s, const BoxOfficeScreen())),
      GoRoute(path: '/admin/users', pageBuilder: (c, s) => _page(s, const UsersScreen())),
      GoRoute(path: '/admin/stats', pageBuilder: (c, s) => _page(s, const StatsScreen())),
      ..._entityRoutes<Movie, MovieDetails>(
        path: '/movies',
        list: (s) => MovieListScreen(query: MovieQuery.fromQueryParameters(s.uri.queryParameters)),
        details: const MovieDetailsScreen(),
        detailsNotifier: (context, id) {
          final movies = context.read<MovieRepository>();
          final lookups = context.read<Lookups>();
          return DetailsNotifier<MovieDetails>(id, () async {
            await _withLookups(lookups);
            final m = await movies.findById(id);
            if (m == null) return null;
            return MovieDetails(m, m.directorIds.map(lookups.director).whereType<Director>().toList());
          });
        },
        form: const MovieFormScreen(),
        formNotifier: (context, id) => FormNotifier<Movie>(context.read<MovieRepository>(), id,
            onSaved: _afterSave<Movie, MovieQuery>(context, LookupPart.cascade)),
      ),
      ..._entityRoutes<Director, WithMovies<Director>>(
        path: '/directors',
        list: (s) => DirectorListScreen(query: DirectorQuery.fromQueryParameters(s.uri.queryParameters)),
        details: const DirectorDetailsScreen(),
        detailsNotifier: (context, id) {
          final directors = context.read<DirectorRepository>();
          final movies = context.read<MovieRepository>();
          return DetailsNotifier<WithMovies<Director>>(id, () async {
            final d = await directors.findById(id);
            return d == null ? null : WithMovies(d, await movies.findRelated(directorId: id));
          });
        },
        form: const DirectorFormScreen(),
        formNotifier: (context, id) => FormNotifier<Director>(context.read<DirectorRepository>(), id,
            onSaved: _afterSave<Director, DirectorQuery>(context, LookupPart.directors)),
      ),
      ..._entityRoutes<Genre, WithMovies<Genre>>(
        path: '/genres',
        list: (s) => SimpleListScreen<Genre>(
            config: genreListConfig,
            query: SimpleQuery.fromQueryParameters(genreQuerySpec, s.uri.queryParameters)),
        details: const GenreDetailsScreen(),
        detailsNotifier: (context, id) {
          final genres = context.read<GenreRepository>();
          final movies = context.read<MovieRepository>();
          return DetailsNotifier<WithMovies<Genre>>(id, () async {
            final g = await genres.findById(id);
            if (g == null) return null;
            return WithMovies(g, await movies.findRelated(genreId: id));
          });
        },
        form: const GenreFormScreen(),
        formNotifier: (context, id) => FormNotifier<Genre>(context.read<GenreRepository>(), id,
            onSaved: _afterSave<Genre, SimpleQuery>(context, LookupPart.genres)),
      ),
      ..._entityRoutes<Studio, WithMovies<Studio>>(
        path: '/studios',
        list: (s) => SimpleListScreen<Studio>(
            config: studioListConfig,
            query: SimpleQuery.fromQueryParameters(studioQuerySpec, s.uri.queryParameters)),
        details: const StudioDetailsScreen(),
        detailsNotifier: (context, id) {
          final studios = context.read<StudioRepository>();
          final movies = context.read<MovieRepository>();
          return DetailsNotifier<WithMovies<Studio>>(id, () async {
            final st = await studios.findById(id);
            if (st == null) return null;
            return WithMovies(st, await movies.findRelated(studioId: id));
          });
        },
        form: const StudioFormScreen(),
        formNotifier: (context, id) => FormNotifier<Studio>(context.read<StudioRepository>(), id,
            onSaved: _afterSave<Studio, SimpleQuery>(context, LookupPart.studios)),
      ),
      ..._entityRoutes<Viewer, Viewer>(
        path: '/viewers',
        list: (s) => SimpleListScreen<Viewer>(
            config: viewerListConfig,
            query: SimpleQuery.fromQueryParameters(viewerQuerySpec, s.uri.queryParameters)),
        details: const ViewerDetailsScreen(),
        detailsNotifier: (context, id) {
          final viewers = context.read<ViewerRepository>();
          return DetailsNotifier<Viewer>(id, () => viewers.findById(id));
        },
        form: const ViewerFormScreen(),
        formNotifier: (context, id) => FormNotifier<Viewer>(context.read<ViewerRepository>(), id,
            onSaved: _afterSave<Viewer, SimpleQuery>(context, null),
            // Сервер называет поля вложенной карты путём в JSON
            errorKeys: const {
              'card.number': 'cardNumber',
              'card.tariff': 'tariff',
              'card.visitsLeft': 'visitsLeft',
              'card.issuedAt': 'issuedAt',
            }),
      ),
    ],
    errorBuilder: (context, state) => NotFoundScreen(location: state.uri.toString()),
  );
}
