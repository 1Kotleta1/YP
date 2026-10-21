import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

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
import 'screens/details_screens.dart';
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
        create: (context) => formNotifier(context, id)..load(),
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

/// После сохранения в форме обновляются справочники и открытые списки.
VoidCallback _afterSave<T extends Entity, Q extends ListQuery>(BuildContext context) {
  final lookups = context.read<Lookups>();
  final list = context.read<PagedListNotifier<T, Q>>();
  final movies = context.read<MovieListNotifier>();
  return () {
    lookups.load();
    list.refresh();
    movies.refresh();
  };
}

Map<String, String> _err(bool taken, String key, String message) => taken ? {key: message} : {};

GoRouter createRouter() {
  return GoRouter(
    initialLocation: '/movies',
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/movies'),
      ..._entityRoutes<Movie, MovieDetails>(
        path: '/movies',
        list: (s) => MovieListScreen(query: MovieQuery.fromQueryParameters(s.uri.queryParameters)),
        details: const MovieDetailsScreen(),
        detailsNotifier: (context, id) {
          final movies = context.read<MovieRepository>();
          final directors = context.read<DirectorRepository>();
          return DetailsNotifier<MovieDetails>(id, () async {
            final m = await movies.findById(id);
            if (m == null) return null;
            final all = await directors.findAll(includeDeleted: true);
            return MovieDetails(m, all.where((d) => m.directorIds.contains(d.id)).toList());
          });
        },
        form: const MovieFormScreen(),
        formNotifier: (context, id) {
          final repo = context.read<MovieRepository>();
          return FormNotifier<Movie>(repo, id,
              onSaved: _afterSave<Movie, MovieQuery>(context),
              uniqueCheck: (m) async => _err(
                  await repo.licenseTaken(m.licenseNumber, exceptId: m.id),
                  'licenseNumber',
                  'Фильм с таким номером удостоверения уже есть в каталоге'));
        },
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
            return d == null ? null : WithMovies(d, await movies.findByDirector(id));
          });
        },
        form: const DirectorFormScreen(),
        formNotifier: (context, id) => FormNotifier<Director>(context.read<DirectorRepository>(), id,
            onSaved: _afterSave<Director, DirectorQuery>(context)),
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
            return WithMovies(g, (await movies.findAll()).where((m) => m.genreIds.contains(id)).toList());
          });
        },
        form: const GenreFormScreen(),
        formNotifier: (context, id) {
          final repo = context.read<GenreRepository>();
          return FormNotifier<Genre>(repo, id,
              onSaved: _afterSave<Genre, SimpleQuery>(context),
              uniqueCheck: (g) async =>
                  _err(await repo.nameTaken(g.name, exceptId: g.id), 'name', 'Такой жанр уже есть'));
        },
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
            return WithMovies(st, (await movies.findAll()).where((m) => m.studioId == id).toList());
          });
        },
        form: const StudioFormScreen(),
        formNotifier: (context, id) => FormNotifier<Studio>(context.read<StudioRepository>(), id,
            onSaved: _afterSave<Studio, SimpleQuery>(context)),
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
        formNotifier: (context, id) {
          final repo = context.read<ViewerRepository>();
          return FormNotifier<Viewer>(repo, id,
              onSaved: _afterSave<Viewer, SimpleQuery>(context),
              uniqueCheck: (v) async => {
                    ..._err(await repo.emailTaken(v.email, exceptId: v.id), 'email',
                        'Зритель с такой почтой уже зарегистрирован'),
                    ..._err(await repo.cardTaken(v.card.number, exceptId: v.id), 'cardNumber',
                        'Карта с таким номером уже выдана'),
                  });
        },
      ),
    ],
    errorBuilder: (context, state) => NotFoundScreen(location: state.uri.toString()),
  );
}
